# frozen_string_literal: true

require "wasmify-rails"

require "ruby_wasm"
require "ruby_wasm/cli"

module Wasmify
  module Rails
    # A wrapper for rbwasm build command
    class Builder
      attr_reader :output_dir, :target

      def initialize(output_dir: Wasmify::Rails.config.tmp_dir, target: Wasmify::Rails.config.wasm_target)
        @output_dir = output_dir
        @target = target
      end

      def run(name:, exclude_gems: [], opts: "")
        $exclude_exts = []

        # Add configured excluded gems
        Wasmify::Rails.config.exclude_gems.each do |gem_name|
          $exclude_exts << gem_name
        end

        # Add additional excluded gems
        exclude_gems.each do |gem_name|
          $exclude_exts << gem_name
        end

        RubyWasm::Packager::Core::BuildStrategy.prepend(Module.new do
          def specs_with_extensions
            super.reject do |spec|
              $exclude_exts.include?(spec.first.name)
            end
          end
        end)

        opts = opts&.split(" ") || []

        args = %W(
          build
          --ruby-version #{Wasmify::Rails.config.short_ruby_version}
          --target #{target}
          -o #{File.join(output_dir, name)}
        ) + opts

        patches_dir = ::Rails.root.join("ruby_wasm_patches").to_s

        if File.directory?(patches_dir)
          Dir.children(patches_dir).each do |patch|
            args << "--patch=#{File.join(patches_dir, patch)}"
          end
        end

        FileUtils.mkdir_p(output_dir)
        RubyWasm::CLI.new(stdout: $stdout, stderr: $stderr).run(args)
      end
    end
  end
end
