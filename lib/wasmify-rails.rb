# frozen_string_literal: true

require "wasmify/rails/version"
require "wasmify/rails/configuration"
require "wasmify/rails/shim"
require "wasmify/rails/railtie"

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

require "action_mailer/null_delivery"

# NullDB for Active Record
ActiveRecord::ConnectionAdapters.register("nulldb", "ActiveRecord::ConnectionAdapters::NullDBAdapter", "active_record/connection_adapters/nulldb_adapter")

# SQLite3 Wasm adapter
ActiveRecord::ConnectionAdapters.register("sqlite3_wasm", "ActiveRecord::ConnectionAdapters::SQLite3WasmAdapter", "active_record/connection_adapters/sqlite3_wasm_adapter")
