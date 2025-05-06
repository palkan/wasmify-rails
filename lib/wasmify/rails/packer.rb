# frozen_string_literal: true

require "wasmify-rails"
require "tmpdir"

module Wasmify
  module Rails
    # A wrapper for wasi-vfs to add application source code to the
    # ruby.wasm module
    class Packer
      ROOT_FILES = %w[Gemfile config.ru .ruby-version Rakefile]

      attr_reader :output_dir

      if defined?(ActionView::Helpers::NumberHelper)
        include ActionView::Helpers::NumberHelper
      else
        include(Module.new do
          def number_to_human_size(num)
            num = num.to_i
            human_size = case
            when num < 1024
              "#{num} bytes"
            when num < 1024*1024
              "#{(num.to_f/1024).round(1)} KB"
            else
              "#{(num.to_f/1024/1024).round(1)} MB"
            end
            human_size
          end
        end)
      end

      def initialize(output_dir: Wasmify::Rails.config.output_dir)
        @output_dir = output_dir
      end

      def run(ruby_wasm_path:, name:, directories: Wasmify::Rails.config.pack_directories, storage_dir: nil)
        unless system("which wasi-vfs > /dev/null 2>&1")
          raise "wasi-vfs is required to pack the application.\n" +
               "Please see installations instructions at: https://github.com/kateinoigakukun/wasi-vfs"
        end

        pack_root = Wasmify::Rails.config.pack_root

        args = %W[
          pack #{ruby_wasm_path}
        ]

        directories.each do |dir|
          args << "--dir #{Wasmify::Rails.config.root_dir.join(dir)}::#{pack_root}/#{dir}"
        end

        output_path = File.join(output_dir, name)

        FileUtils.mkdir_p(output_dir)

        # Generate a temporary directory with the require root files
        Dir.mktmpdir do |tdir|
          (ROOT_FILES + (Wasmify::Rails.config.additional_root_files || [])).each do |file|
            FileUtils.cp(Wasmify::Rails.config.root_dir.join(file), tdir) if File.exist?(Wasmify::Rails.config.root_dir.join(file))
          end

          # Create a storage/ directory for Active Storage attachments
          FileUtils.mkdir_p(File.join(tdir, storage_dir)) if storage_dir

          args << "--dir #{tdir}::#{pack_root}"

          args << "-o #{output_path}"

          spawn("wasi-vfs #{args.join(" ")}").then { Process.wait(_1) }
        end

        $stdout.puts "Packed the application to #{output_path}\n" \
                     "Size: #{number_to_human_size(File.size(output_path))}"
      end
    end
  end
end
