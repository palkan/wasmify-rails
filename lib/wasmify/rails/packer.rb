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

      include ActionView::Helpers::NumberHelper

      def initialize(output_dir: Wasmify::Rails.config.output_dir)
        @output_dir = output_dir
      end

      def run(ruby_wasm_path:, name:, directories: Wasmify::Rails.config.pack_directories, storage_dir: nil)
        unless system("which wasi-vfs > /dev/null 2>&1")
          raise "wasi-vfs is required to pack the application.\n" +
               "Please see installations instructions at: https://github.com/kateinoigakukun/wasi-vfs"
        end

        args = %W[
          pack #{ruby_wasm_path}
        ]

        directories.each do |dir|
          args << "--dir #{::Rails.root.join(dir)}::/rails/#{dir}"
        end

        output_path = File.join(output_dir, name)

        FileUtils.mkdir_p(output_dir)

        # Generate a temporary directory with the require root files
        Dir.mktmpdir do |tdir|
          ROOT_FILES.each do |file|
            FileUtils.cp(::Rails.root.join(file), tdir) if File.exist?(::Rails.root.join(file))
          end

          # Create a storage/ directory for Active Storage attachments
          FileUtils.mkdir_p(File.join(tdir, storage_dir)) if storage_dir

          args << "--dir #{tdir}::/rails"

          args << "-o #{output_path}"

          spawn("wasi-vfs #{args.join(" ")}").then { Process.wait(_1) }
        end

        $stdout.puts "Packed the application to #{output_path}\n" \
                     "Size: #{number_to_human_size(File.size(output_path))}"
      end
    end
  end
end
