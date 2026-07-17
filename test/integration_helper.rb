# frozen_string_literal: true

require "bundler"
require "fileutils"
require "open3"
require "shellwords"

module Wasmify
  module Integration
    # Verifies that a fresh minimal Rails app wasmifies end-to-end for a single
    # (Ruby, Rails) combination:
    #
    #   rails new --minimal -> wasmify:install -> build:core:verify -> pack:core:verify
    #
    # Generated apps and the rbwasm toolchain (build/, rubies/) are cached and
    # symlinked into per-cell working copies so repeated runs stay cheap.
    class Helper
      class Error < StandardError; end

      DEFAULT_RUBY_VERSION = "3.3"
      DEFAULT_RAILS_VERSION = "8.0"

      # wasi-vfs absence is a hard failure in the gem; wasmtime absence makes
      # verify a silent no-op (hence the marker checks below), so we fail fast
      # on both before doing any work.
      REQUIRED_TOOLS = %w[wasmtime wasi-vfs].freeze

      # stdout markers the verify tasks print. Exit code alone is not enough:
      # Wasmtimer.run exits 0 without doing anything when wasmtime is missing,
      # so a green exit without the marker is a false pass.
      BUILD_VERIFY_MARKER = "Your Rails version is:"
      PACK_VERIFY_MARKER = "Rails application initialized!"

      # RUBY_VERSION/RAILS_VERSION are the task interface only; unset them in
      # child processes (RUBY_VERSION is also read by Ruby/Bundler).
      SCRUBBED_ENV = {"RUBY_VERSION" => nil, "RAILS_VERSION" => nil}.freeze

      attr_reader :ruby_version, :rails_version, :root

      def initialize(ruby_version: DEFAULT_RUBY_VERSION, rails_version: DEFAULT_RAILS_VERSION, root: Dir.pwd)
        @ruby_version = ruby_version
        @rails_version = rails_version
        @root = File.expand_path(root)
      end

      def run
        check_preconditions!
        ensure_base_app
        prepare_working_copy
        install
        build_and_verify
        pack_and_verify
        true
      end

      private

      # --- Preconditions ------------------------------------------------------

      # RUBY_VERSION is the ruby.wasm build target (set in wasmify.yml), not the
      # host Ruby — the host version is irrelevant, so we only check the tools.
      def check_preconditions!
        missing = REQUIRED_TOOLS.reject { |tool| tool_available?(tool) }
        return if missing.empty?

        raise Error, "Missing required tool(s): #{missing.join(", ")}. " \
          "Install wasmtime (https://wasmtime.dev) and wasi-vfs " \
          "(https://github.com/kateinoigakukun/wasi-vfs) first."
      end

      # --- Paths --------------------------------------------------------------

      def integration_dir = File.join(root, "tmp", "integration")

      def base_app_dir = File.join(integration_dir, "apps", "rails-#{rails_version}")

      def work_dir = File.join(integration_dir, "work", "#{ruby_version}-#{rails_version}")

      # rbwasm writes these cwd-relative; kept at repo root so they are cached
      # once per Ruby version and symlinked into each working copy.
      def shared_build_dir = File.join(root, "build")

      def shared_rubies_dir = File.join(root, "rubies")

      # --- Steps --------------------------------------------------------------

      # Generate the pristine base app once per Rails version; reuse otherwise.
      def ensure_base_app
        return log("reusing cached base app: #{base_app_dir}") if base_app_generated?

        FileUtils.mkdir_p(File.dirname(base_app_dir))
        gemfile = write_rails_gemfile
        log("rails new (Rails #{rails_version})")
        sh!(rails_new_command(gemfile), chdir: root)
      ensure
        FileUtils.rm_rf(File.dirname(gemfile)) if gemfile
      end

      def base_app_generated?
        File.file?(File.join(base_app_dir, "config", "application.rb"))
      end

      # Copy the pristine app into an isolated working copy and symlink the
      # shared toolchain so the build reuses cached artifacts.
      def prepare_working_copy
        FileUtils.rm_rf(work_dir)
        FileUtils.mkdir_p(File.dirname(work_dir))
        FileUtils.cp_r(base_app_dir, work_dir)

        FileUtils.mkdir_p(shared_build_dir)
        FileUtils.mkdir_p(shared_rubies_dir)
        symlink_force(shared_build_dir, File.join(work_dir, "build"))
        symlink_force(shared_rubies_dir, File.join(work_dir, "rubies"))

        add_wasmify_gem
      end

      # bundle install (makes the generator discoverable) -> wasmify:install
      # (regenerates config and re-bundles via its finish hook, against the
      # host Ruby) -> pin the wasm target Ruby -> assert the lock exists.
      def install
        log("bundle install + wasmify:install")
        sh!("bundle install", chdir: work_dir)
        # HACK: add openssl gem so we can fetch ruby.wasm artifacts
        sh!("bundle add openssl", chdir: work_dir)
        sh!("bundle exec rails generate wasmify:install --force", chdir: work_dir)
        # ensure all deps are installed
        sh!("bundle install", chdir: work_dir)
        update_wasmify_yml
        pin_wasm_ruby_version

        unless File.file?(File.join(work_dir, "Gemfile.lock"))
          raise Error, "Expected Gemfile.lock after wasmify:install in #{work_dir}."
        end
      end

      def build_and_verify
        log("build:core + verify")
        sh!("bundle exec rails wasmify:build:core", chdir: work_dir)
        verify!("bundle exec rails wasmify:build:core:verify", BUILD_VERIFY_MARKER)
      end

      def pack_and_verify
        log("pack:core + verify")
        sh!("bundle exec rails wasmify:pack:core", chdir: work_dir)
        verify!("bundle exec rails wasmify:pack:core:verify", PACK_VERIFY_MARKER)
      end

      # --- Helpers ------------------------------------------------------------

      # Each verify runs as its own process (Wasmtimer.run uses Kernel#exec).
      # Success requires a clean exit AND the marker; a marker-less exit 0 means
      # wasmtime was absent and nothing was actually verified.
      def verify!(command, marker)
        output = sh!(command, chdir: work_dir)
        return if output.include?(marker)

        raise Error, "#{command}\nexited 0 but did not print #{marker.inspect} — " \
          "wasmtime is likely not on PATH, so verification was silently skipped.\n#{output}"
      end

      # Run tmp-app commands with a clean Bundler env. rake runs inside the
      # gem's bundle, and its BUNDLE_GEMFILE/RUBYOPT/GEM_* leak into children —
      # so bundle/rails in the working copy would target the gem's bundle
      # instead of the app's unless we strip them here.
      def sh!(command, chdir:)
        stdout, stderr, status = Bundler.with_unbundled_env do
          Open3.capture3(SCRUBBED_ENV, command, chdir: chdir)
        end
        output = "#{stdout}#{stderr}"
        return output if status.success?

        raise Error, "Command failed (exit #{status.exitstatus}): #{command}\n#{output}"
      end

      # Isolated Gemfile pinning the Rails minor series, used only to drive
      # `rails new` at the requested version without touching global gems.
      def write_rails_gemfile
        dir = File.join(integration_dir, "gemfiles", "rails-#{rails_version}-#{object_id}")
        FileUtils.mkdir_p(dir)
        path = File.join(dir, "Gemfile")
        File.write(path, <<~GEMFILE)
          source "https://rubygems.org"
          gem "rails", "~> #{rails_version}.0"
        GEMFILE
        path
      end

      def rails_new_command(gemfile)
        gemfile = Shellwords.escape(gemfile)
        dest = Shellwords.escape(base_app_dir)
        "BUNDLE_GEMFILE=#{gemfile} bundle install && " \
          "BUNDLE_GEMFILE=#{gemfile} bundle exec rails new #{dest} --minimal --skip-bundle --skip-git"
      end

      # Add the gem under test as a path dependency so `rails g wasmify:install`
      # and the wasmify:* tasks are available in the working copy.
      def add_wasmify_gem
        File.open(File.join(work_dir, "Gemfile"), "a") do |f|
          f.write(%(\ngem "wasmify-rails", path: #{root.inspect}\n))
        end
      end

      # Add/remove exluded gems depending on the target Ruby version
      def update_wasmify_yml
        path = File.join(work_dir, "config", "wasmify.yml")
        return unless File.file?(path)

        contents = File.read(path)

        unless ruby_version == "3.3" && rails_version == "8.0"
          contents.sub!(/^\s+\- bigdecimal.*$\n/, "")
        end

        File.write(path, contents)
      end

      # Add (not edit) a top-level ruby_version key to config/wasmify.yml. The
      # template ships without one; configuration.rb resolves the wasm target as
      # config["ruby_version"] || .ruby-version || "3.3", so this takes
      # precedence over the app's auto-generated .ruby-version.
      def pin_wasm_ruby_version
        path = File.join(work_dir, "config", "wasmify.yml")
        return unless File.file?(path)

        contents = File.read(path)
        return if contents.match?(/^ruby_version:/)

        File.write(path, "ruby_version: \"#{ruby_version}\"\n\n#{contents}")
      end

      def symlink_force(target, link)
        FileUtils.rm_rf(link)
        FileUtils.ln_s(target, link)
      end

      def tool_available?(tool)
        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |dir|
          path = File.join(dir, tool)
          File.executable?(path) && !File.directory?(path)
        end
      end

      def log(message) = puts("[integration] #{message}")
    end
  end
end
