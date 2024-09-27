# frozen_string_literal: true

namespace :wasmify do
  desc "Install wasmify-rails"
  task :install do
    Rails::Command.invoke :generate, ["wasmify:install"]
  end

  desc "Generate a PWA application to serve the Rails Wasm app"
  task :pwa do
    Rails::Command.invoke :generate, ["wasmify:pwa"]
  end

  desc "Build ruby.wasm with all dependencies"
  task :build do
    unless ENV["BUNDLE_ONLY"] == "wasm"
      next spawn("RAILS_ENV=wasm BUNDLE_ONLY=wasm bundle exec rails wasmify:build").then { Process.wait(_1) }
    end

    require "wasmify/rails/builder"

    builder = Wasmify::Rails::Builder.new
    builder.run(name: "ruby.wasm")
  end

  namespace :build do
    desc "Build ruby.wasm with all dependencies but JS shim (to use with wasmtime)"
    task :core do
      unless ENV["BUNDLE_ONLY"] == "wasm"
        next spawn("RAILS_ENV=wasm BUNDLE_ONLY=wasm bundle exec rails wasmify:build:core").then { Process.wait(_1) }
      end

      require "wasmify/rails/builder"

      builder = Wasmify::Rails::Builder.new
      builder.run(name: "ruby-core.wasm", exclude_gems: ["js"])
    end

    namespace :core do
      desc "Test that compiled ruby-core.wasm works (print Rails version)"
      task :verify do
        require "wasmify/rails/wasmtimer"

        wasm_path = File.join(Wasmify::Rails.config.tmp_dir, "ruby-core.wasm")
        Wasmify::Rails::Wasmtimer.run(
          wasm_path,
          <<~'RUBY'
            require "wasmify/rails/shim"
            require "rails"
            puts "Your Rails version is: #{Rails.version} [#{RUBY_PLATFORM}]"
          RUBY
        )
      end
    end
  end

  desc "Pack the application into to a single module"
  task pack: :build do
    # First, precompile assets
    unless Wasmify::Rails.config.skip_assets_precompile
      Bundler.with_unbundled_env do
        spawn("SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production bundle exec rails assets:precompile").then { Process.wait(_1) }
      end
    end

    require "wasmify/rails/packer"

    packer = Wasmify::Rails::Packer.new

    packer.run(name: "app.wasm", ruby_wasm_path: File.join(Wasmify::Rails.config.tmp_dir, "ruby.wasm"))
  end

  namespace :pack do
    desc "Pack the application into to a single module without JS shim"
    task :core do
      # First, precompile assets
      unless Wasmify::Rails.config.skip_assets_precompile
        Bundler.with_unbundled_env do
          spawn("SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production bundle exec rails assets:precompile").then { Process.wait(_1) }
        end
      end

      require "wasmify/rails/packer"

      # Pack core module to the tmp dir (we only use it for testing purposes right now)
      packer = Wasmify::Rails::Packer.new(
        output_dir: Wasmify::Rails.config.tmp_dir
      )

      packer.run(name: "app-core.wasm",
        ruby_wasm_path: File.join(Wasmify::Rails.config.tmp_dir, "ruby-core.wasm"),
        storage_dir: "storage"
      )
    end

    namespace :core do
      desc "Test that the Rails application boots"
      task :verify do
        require "wasmify/rails/wasmtimer"

        wasm_path = File.join(Wasmify::Rails.config.tmp_dir, "app-core.wasm")
        Wasmify::Rails::Wasmtimer.run(
          wasm_path,
          <<~'RUBY'
            ENV["RAILS_ENV"] = "wasm"
            ENV["DEBUG"] = "1"
            # ENV["ACTIVE_RECORD_ADAPTER"] = "sqlite3_wasm"
            require "/rails/config/application"
            puts "Initializing Rails application..."
            Rails.application.initialize!
            puts "Rails application initialized!\n\nLets try to make a request..."

            request = Rack::MockRequest.env_for("http://localhost:3000", {"HTTP_HOST" => "localhost"})
            puts Rails.application.call(request)
          RUBY
        )
      end
    end
  end
end
