# frozen_string_literal: true

module Wasmify
  module Rails
    class Railtie < ::Rails::Railtie
      rake_tasks do
        load "wasmify/rails/tasks.rake"
      end

      initializer "wasmify.rack_data_uri" do |app|
        require "rack/data_uri_uploads"

        app.middleware.use Rack::DataUriUploads
      end
    end
  end
end


require "action_mailer/null_delivery"

# NullDB for Active Record
ActiveRecord::ConnectionAdapters.register("nulldb", "ActiveRecord::ConnectionAdapters::NullDBAdapter", "active_record/connection_adapters/nulldb_adapter")

# SQLite3 Wasm adapter
ActiveRecord::ConnectionAdapters.register("sqlite3_wasm", "ActiveRecord::ConnectionAdapters::SQLite3WasmAdapter", "active_record/connection_adapters/sqlite3_wasm_adapter")

# PGlite adapter
ActiveRecord::ConnectionAdapters.register("pglite", "ActiveRecord::ConnectionAdapters::PGliteAdapter", "active_record/connection_adapters/pglite_adapter")
