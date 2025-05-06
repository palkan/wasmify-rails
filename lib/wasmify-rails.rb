# frozen_string_literal: true

require "wasmify/rails/version"
require "wasmify/rails/configuration"
require "wasmify/rails/shim"
require "wasmify/rails/railtie" if defined?(::Rails::Railtie)

module Wasmify
  module Rails
    class << self
      def config = @config ||= Configuration.new
    end
  end
end

# Autoloadable extensions
module ImageProcessing
  autoload :Null, "image_processing/null"
end
