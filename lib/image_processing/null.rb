# frozen_string_literal: true

module ImageProcessing
  # Null processor for image_processing that keeps source files untouched
  # and copy them to the destination if provided.
  module Null
    extend Chainable

    def self.valid_image?(file) = true

    class Processor < ImageProcessing::Processor
      def self.call(source:, loader:, operations:, saver:, destination: nil)
        fail ArgumentError, "A string path is expected, got #{source.class}" unless source.is_a?(String)
        fail ArgumentError, "File not found: #{source}" unless File.file?(source)

        if destination
          File.delete(destination) if File.identical?(source, destination)
          FileUtils.cp(source, destination)
        end
      end
    end
  end
end
