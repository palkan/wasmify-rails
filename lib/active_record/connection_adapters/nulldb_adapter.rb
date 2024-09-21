# frozen_string_literal: true

require 'logger'
require 'stringio'
require 'singleton'
require 'pathname'

require 'active_support'
require 'active_support/deprecation'
require 'active_record/connection_adapters/nulldb_adapter'

module NullDB
  class Configuration < Struct.new(:project_root); end

  class << self
    def configure
      @configuration = Configuration.new.tap {|c| yield c}
    end

    def configuration
      if @configuration.nil?
        raise "NullDB not configured. Require a framework, ex 'nulldb/rails'"
      end

      @configuration
    end

    def nullify(options={})
      begin
        @prev_connection = ActiveRecord::Base.connection_pool.try(:spec)
      rescue ActiveRecord::ConnectionNotEstablished
      end
      ActiveRecord::Base.establish_connection(options.merge(:adapter => :nulldb))
    end

    def restore
      if @prev_connection
        ActiveRecord::Base.establish_connection(@prev_connection.config)
      end
    end

    def checkpoint
      ActiveRecord::Base.connection.checkpoint!
    end
  end
end

# Need to defer calling Rails.root because when bundler loads, Rails.root is nil
NullDB.configure {|ndb| def ndb.project_root;Rails.root;end}

class ActiveRecord::Base
  # Instantiate a new NullDB connection.  Used by ActiveRecord internally.
  def self.nulldb_connection(config)
    ActiveRecord::ConnectionAdapters::NullDBAdapter.new(config)
  end
end

require 'active_record/connection_adapters/nulldb_adapter/core'
require 'active_record/connection_adapters/nulldb_adapter/statement'
require 'active_record/connection_adapters/nulldb_adapter/checkpoint'
require 'active_record/connection_adapters/nulldb_adapter/column'
require 'active_record/connection_adapters/nulldb_adapter/configuration'
require 'active_record/connection_adapters/nulldb_adapter/empty_result'
require 'active_record/connection_adapters/nulldb_adapter/index_definition'
require 'active_record/connection_adapters/nulldb_adapter/null_object'
require 'active_record/connection_adapters/nulldb_adapter/table_definition'
require 'active_record/connection_adapters/nulldb_adapter/quoting'
