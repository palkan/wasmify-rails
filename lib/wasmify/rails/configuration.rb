# frozen_string_literal: true

module Wasmify
  module Rails
    RUBY_VERSION_TO_WASM_RUBY_VERSION = {
      "3.3" => "3.3.3",
      "3.2" => "3.2.4"
    }

    class Configuration
      attr_reader :pack_directories, :exclude_gems, :ruby_version,
                  :tmp_dir, :output_dir, :wasm_target,
                  :skip_assets_precompile

      def initialize
        config_path = ::Rails.root.join("config", "wasmify.yml")
        raise "config/wasmify.yml not found" unless File.exist?(config_path)

        config = YAML.load_file(config_path)

        @pack_directories = config["pack_directories"]
        @exclude_gems = config["exclude_gems"]
        @ruby_version = config["ruby_version"] || ruby_version_from_file || "3.3"
        @tmp_dir = config["tmp_dir"] || ::Rails.root.join("tmp", "wasmify")
        @output_dir = config["output_dir"] || ::Rails.root.join("dist")
        @skip_assets_precompile = config["skip_assets_precompile"] || false
        @wasm_target = config["wasm_target"] || "wasm32-unknown-wasip1"
      end

      def short_ruby_version
        if (matches = ruby_version.match(/^(\d+\.\d+)/))
          matches[1]
        else
          ruby_version
        end
      end

      def ruby_version = @ruby_version ||= ruby_version_from_file || "3.3"

      private

      def ruby_version_from_file
        return unless File.file?(::Rails.root.join(".ruby-version"))

        File.read(::Rails.root.join(".ruby-version")).strip.match(/(\d+\.\d+(?:\.d+)?)/).then do |matches|
          matches[1] if matches
        end
      end
    end
  end
end
