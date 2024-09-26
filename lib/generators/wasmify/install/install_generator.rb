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
      " unless RUBY_PLATFORM =~ /wasm/"
    end
  end

  def add_tzinfo_data_to_gemfile
    append_to_file "Gemfile", <<~RUBY

      group :wasm do
        gem "tzinfo-data"
      end
    RUBY

    run "bundle install"
  end

  def finish
    say_status :info, "✅ The application is prepared for Wasm-ificaiton!\n\n" \
                      "Next steps are:\n" \
                      " - Gemfile: Add `group: [:default, :wasm]` to the dependencies required in Wasm runtime" \
                      " - Run `bin/rails wasmify:build:core:verify` to see if the bundle compiles"
  end
end
