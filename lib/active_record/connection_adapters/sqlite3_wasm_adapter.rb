require "active_record/connection_adapters/sqlite3_adapter"

module SQLite3
  module Database
    def self.quote(s) = s.gsub("'", "''")
  end

  module Pragmas
  end
end

module ActiveRecord
  module ConnectionHandling # :nodoc:
    def sqlite3_wasm_adapter_class
      ConnectionAdapters::SQLite3WasmAdapter
    end

    def sqlite3_wasm_connection(config)
      sqlite3_wasm_adapter_class.new(config)
    end
  end

  module ConnectionAdapters
    class SQLite3WasmAdapter < SQLite3Adapter
      class ExternalInterface
        private attr_reader :js_interface

        def initialize(config)
          @js_interface = config.fetch(:js_interface, "sqlite4rails").to_sym
        end

        def exec(...)
          JS.global[js_interface].exec(...)
        end

        def busy_timeout(...) = nil

        def execute(sql)
          @last_statement = Statement.new(self, sql)
          @last_statement.result
        end

        def prepare(sql) = Statement.new(self, sql)

        def closed? = false

        def transaction(mode = nil)
          # deferred doesn't work 🤷‍♂️
          mode = nil if mode.nil?
          execute "begin #{mode} transaction"

          if block_given?
            abort = false
            begin
              yield self
            rescue
              abort = true
              raise
            ensure
              abort and rollback or commit
            end
          else
            true
          end
        end

        def commit
          execute "commit transaction"
          true
        end

        def rollback
          execute "rollback transaction"
          true
        end

        def changes
          JS.global[js_interface].changes.to_i
        end
      end

      class Statement
        attr_reader :interface, :sql

        def initialize(interface, sql)
          @interface = interface
          @sql = sql
          @columns = nil
          @rows = nil
        end

        def close = nil

        def columns
          execute
          @columns
        end

        def result
          execute
          @rows.map { @columns.zip(_1).to_h }.freeze
        end

        def to_a
          execute
          @rows
        end

        def execute
          return if @rows

          res = interface.exec(sql)
          # unwrap column names
          cols = res[:cols].to_a.map(&:to_s)
          # unwrap row values
          rows = res[:rows].to_a.map do |row|
            row.to_a.map do |val|
              str_val = val.to_s
              next str_val if val.typeof == "string"
              next str_val == "true" if val.typeof == "boolean"
              next nil if str_val == "null"

              # handle integers and floats
              next str_val.include?(".") ? val.to_f : val.to_i if val.typeof == "number"

              str_val
            end
          end

          @columns = cols
          @rows = rows
        end

        def reset!
          @rows = nil
          @columns = nil
        end
      end

      # This type converts byte arrays represented as strings from JS to binaries in Ruby
      class JSBinary < ActiveModel::Type::Binary
        def deserialize(value)
          bvalue = value
          if value.is_a?(String)
            bvalue = value.split(",").map(&:to_i).pack("c*")
          end

          super(bvalue)
        end
      end

      ActiveRecord::Type.register(:binary, JSBinary, adapter: :sqlite3_wasm)

      class << self
        def database_exists?(config)
          true
        end

        def new_client(config) = ExternalInterface.new(config)

        private
          def initialize_type_map(m)
            super
            register_class_with_limit m, %r(binary)i, JSBinary
          end
      end

      # Re-initialize type map to include JSBinary
      TYPE_MAP = Type::TypeMap.new.tap { |m| initialize_type_map(m) }

      attr_reader :external_interface

      def initialize(...)
        AbstractAdapter.instance_method(:initialize).bind_call(self, ...)

        @prepared_statements = false
        @memory_database = false
        @connection_parameters = @config.merge(database: @config[:database].to_s, results_as_hash: true)
        @use_insert_returning = @config.key?(:insert_returning) ? self.class.type_cast_config_to_boolean(@config[:insert_returning]) : true
      end

      def database_exists? = true

      def database_version = SQLite3Adapter::Version.new("3.45.1")
    end
  end
end
