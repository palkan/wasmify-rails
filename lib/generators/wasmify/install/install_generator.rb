# frozen_string_literal: true

class Wasmify::InstallGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  def copy_files
    template "config/wasmify.yml"
    template "config/environments/wasm.rb"
  end

  def configure_database
     append_to_file "config/database.yml", <<~EOF
        wasm:
          adapter: <%= ENV.fetch("ACTIVE_RECORD_ADAPTER") { "nulldb" } %>
     EOF
  end

  def configure_action_cable
    in_root do
      next unless File.file?("config/cable.yml")

      append_to_file "config/cable.yml", <<~EOF

        wasm:
          adapter: <%= ENV.fetch("ACTION_CABLE_ADAPTER") { "inline" } %>
      EOF
    end
  end

  def configure_gitignore
    append_to_file ".gitignore", <<~EOF
      # Ignore the compiled WebAssembly modules
      *.wasm
      # Ignore ruby.wasm build artefacts
      build/
      rubies/
      dist/
    EOF
  end

  def inject_wasmify_shim_into_environment
    inject_into_file "config/application.rb", after: /require_relative\s+['"]boot['"]\n/ do
      <<~RUBY

        require "wasmify/rails/shim"
      RUBY
    end
  end

  def configure_boot_file
    inject_into_file "config/boot.rb", after: /require ['"]bundler\/setup['"]/ do
      " unless RUBY_PLATFORM =~ /wasm/"
    end

    # Disable bootsnap if any
    inject_into_file "config/boot.rb", after: /require ['"]bootsnap\/setup['"]/ do
      %q( unless ENV["RAILS_ENV"] == "wasm")
    end
  end

  def disable_ruby_version_check_in_gemfile
    inject_into_file "Gemfile", after: /^ruby[^#\n]+/ do
      " unless RUBY_PLATFORM =~ /wasm/"
    end
  end

  def add_tzinfo_data_to_gemfile
    # First, comment out the existing tzinfo-data gem declaration
    comment_lines "Gemfile", /^gem ['"]tzinfo-data['"]/

    append_to_file "Gemfile", <<~RUBY

      group :wasm do
        gem "tzinfo-data"
      end
    RUBY
  end

  KNOWN_NO_WASM_GEMS = %w[
    bootsnap
    puma
    sqlite3
    activerecord-enhancedsqlite3-adapter
    pg
    mysql2
    redis
    solid_cable
    solid_queue
    solid_cache
    jsbundling-rails
    cssbundling-rails
    tailwindcss-rails
    thruster
    kamal
    byebug
    web-console
    listen
    spring
    debug
  ].freeze

  def add_wasm_group_to_gemfile
    # This is a very straightforward implementation:
    # - scan the Gemfile for _root_ dependencies (not within groups)
    # - add `group: [:default, :wasm]` to those not from the exclude list

    top_gems = []

    File.read("Gemfile").then do |gemfile|
      gemfile.scan(/^gem ['"]([^'"]+)['"](.*)$/).each do |match|
        gem_name = match.first
        top_gems << gem_name unless match.last&.include?(":wasm")
      end
    end

    gems_to_include = top_gems - KNOWN_NO_WASM_GEMS

    return if gems_to_include.empty?

    regexp = /^gem ['"](?:#{gems_to_include.join("|")})['"][^#\n]*/

    gsub_file "Gemfile", regexp do |match|
      match << ", group: [:default, :wasm]"
    end
  end

  def fix_solid_queeue_production_config
    inject_into_file "config/environments/production.rb", after: %r{config.solid_queue.connects_to = [^#\n]+} do
      " if config.respond_to?(:solid_queue)"
    end
  end

  def finish
    run "bundle install"

    say_status :info, "✅ The application is prepared for Wasm-ificaiton!\n\n" \
                      "Next steps are:\n" \
                      " - Check your Gemfile: add `group: [:default, :wasm]` to the dependencies required in Wasm runtime" \
                      " - Run `bin/rails wasmify:build:core:verify` to see if the bundle compiles"
  end
end
