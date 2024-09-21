# frozen_string_literal: true

module Wasmify
  module Rails
    # A wrapper for the wasmtime CLI used to
    # verify compiled modules.
    module Wasmtimer
      class << self
        def run(wasm_path, script)
          return unless wasmtime_installed?

          exec(%Q(wasmtime run --dir ./storage::/rails/storage #{wasm_path} -W0 -r/bundle/setup -e '#{script}'))
        end

        private

        def wasmtime_installed?
          unless system("which wasmtime > /dev/null 2>&1")
            $stderr.puts "Wasmtime is required to verify Wasm builds.\nPlease see installations instructions at https://wasmtime.dev."
            if RUBY_PLATFORM =~ /darwin/
              $stderr.puts "You can also install it via Homebrew:\n  brew install wasmtime"
            end
            return false
          end

          true
        end
      end
    end
  end
end
