# frozen_string_literal: true

require "wasmify-rails"

require "ruby_wasm"
require "ruby_wasm/cli"

module Wasmify
  module Rails
    # A wrapper for rbwasm build command
    class Builder
      ORIGINAL_EXCLUDED_GEMS = RubyWasm::Packager::EXCLUDED_GEMS.dup.freeze

      attr_reader :output_dir

      def initialize(output_dir: Wasmify::Rails.config.tmp_dir)
        @output_dir = output_dir
      end

      def run(name:, exclude_gems: [])
        # Reset excluded gems
        RubyWasm::Packager::EXCLUDED_GEMS.replace(ORIGINAL_EXCLUDED_GEMS)

        # Add configured excluded gems
        Wasmify::Rails.config.exclude_gems.each do |gem_name|
          RubyWasm::Packager::EXCLUDED_GEMS << gem_name
        end

        # Add additional excluded gems
        exclude_gems.each do |gem_name|
          RubyWasm::Packager::EXCLUDED_GEMS << gem_name
        end

        args = %W(
          build
          --ruby-version #{Wasmify::Rails.config.short_ruby_version}
          -o #{File.join(output_dir, name)}
        )

        FileUtils.mkdir_p(output_dir)
        RubyWasm::CLI.new(stdout: $stdout, stderr: $stderr).run(args)
      end
    end
  end
end
