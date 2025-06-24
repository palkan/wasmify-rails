# frozen_string_literal: true

# Update the $LOAD_PATH to include the pg stub
$LOAD_PATH.unshift(File.expand_path(File.join(__dir__, "pglite_shims")))

module PGlite
  class << self
    attr_accessor :logger

    def log(message)
      logger&.debug "[pglite] #{message}"
    end
  end

  class Result
    def initialize(res)
      @res = res
    end

    def map_types!(map)
      self
    end

    def values
      results = []
      columns = self.fields
      @res[:rows].to_a.each do |raw_row|
        row = []
        columns.each do |col|
          value = raw_row[col]
          row << translate_value(value)
        end
        results << row
      end
      results
    end

    def fields
      @res[:fields].to_a.map { |col| col[:name].to_s }
    end

    def ftype(index)
      @res[:fields][index][:dataTypeID]
    end

    def fmod(index)
      0
    end

    def cmd_tuples
      @res[:affectedRows].to_i
    end

    def clear
    end

    include Enumerable

    def each
      columns = self.fields
      @res[:rows].to_a.each do |raw_row|
        row = {}
        columns.each do |col|
          value = raw_row[col]
          row[col.to_s] = translate_value(value)
        end
        yield row
      end
    end

    private
      def translate_value(value)
        case value.typeof
        when "number"
          value.to_i
        when "boolean"
          value == JS::True
        when "undefined"
          nil
        else
          if value == JS::Null
            nil
          else
            value.to_s
          end
        end
      end
  end
end

require "active_record/connection_adapters/postgresql_adapter"

module ActiveRecord
  module ConnectionHandling # :nodoc:
    def pglite_adapter_class
      ConnectionAdapters::PGliteAdapter
    end

    def pglite_connection(config)
      pglite_adapter_class.new(config)
    end
  end

  module ConnectionAdapters
    class PGliteAdapter < PostgreSQLAdapter
      class ExternalInterface
        private attr_reader :js_interface

        def initialize(config)
          @js_interface =
            if config[:js_interface]
              config[:js_interface]
            else
              # Set up the database in JS and get the idenfier back
              JS.global[:pglite].create_interface(config[:database]).await.to_s
            end.to_sym
          @last_result = nil
          @prepared_statements_map = {}
        end

        def finished? = true

        def set_client_encoding(encoding)
        end

        def transaction_status
          PG::PQTRANS_IDLE
        end

        def escape(str)
          str
        end

        def raw_query(sql, params)
          PGlite.log "[pglite] query: #{sql} with params: #{params}"
          params = params.map { |param| param.to_js }
          raw_res = JS.global[js_interface].query(sql, params.to_js).await
          result = PGlite::Result.new(raw_res)
          PGlite.log "[pglite] result: #{result.values}"
          @last_result = result
          result
        rescue => e
          raise PG::Error, e.message
        end

        def exec(sql)
          raw_query(sql, [])
        end

        alias query exec
        alias async_exec exec
        alias async_query exec

        def exec_params(sql, params)
          if params.empty?
            return exec(sql)
          end
          raw_query(sql, params)
        end

        def exec_prepared(name, params)
          sql = @prepared_statements_map[name]
          exec_params(sql, params)
        end

        def prepare(name, sql, param_types = nil)
          @prepared_statements_map[name] = sql
        end

        def get_last_result
          @last_result
        end

        def reset
          @prepared_statements_map = {}
        end
      end

      class << self
        def database_exists?(config)
          true
        end

        def new_client(...) = ExternalInterface.new(...)
      end

      def initialize(...)
        AbstractAdapter.instance_method(:initialize).bind_call(self, ...)
        @connection_parameters = @config.compact

        @max_identifier_length = nil
        @type_map = ActiveRecord::Type::HashLookupTypeMap.new
        @raw_connection = nil
        @notice_receiver_sql_warnings = []

        @use_insert_returning = true
      end

      def get_database_version = 150000 # 15devel

      def configure_connection
      end

      module Type
        class BigintArray < ActiveRecord::Type::Value
          def deserialize(value)
            return nil if value.nil? || value == ""
            value[1..-2].split(",").map(&:to_i)
          end

          def serialize(value)
            return nil if value.nil? || value == ""
            "{" + value.map(&:to_s).join(", ") + "}"
          end

          def cast(value)
            value
          end
        end
      end

      def get_oid_type(oid, fmod, column_name, sql_type = "")
        # https://github.com/postgres/postgres/blob/master/src/include/catalog/pg_type.dat
        oid = oid.to_i
        ty = case oid
        when 16
          ActiveRecord::Type::Boolean.new
        when 20
          ActiveRecord::Type::Integer.new(limit: 8)
        when 21
          ActiveRecord::Type::Integer.new
        when 23
          ActiveRecord::Type::Integer.new
        when 25
          ActiveRecord::Type::String.new
        when 114
          ActiveRecord::Type::String.new
        when 700, 701
          ActiveRecord::Type::Float.new
        when 1015
          ActiveRecord::Type::String.new
        when 1016 # bigint[]
          Type::BigintArray.new
        when 1043
          ActiveRecord::Type::String.new
        when 1082
          ActiveRecord::Type::Date.new
        when 1083
          ActiveRecord::Type::Time.new
        when 1114
          ActiveRecord::Type::DateTime.new
        when 1184
          ActiveRecord::Type::DateTime.new
        when 1700
          ActiveRecord::Type::Decimal.new
        when 3802
          ActiveRecord::Type::Json.new
        else
          ActiveRecord::Type.default_value
        end
        @type_map.register_type(oid, ty)
        ty
      end
    end
  end
end
