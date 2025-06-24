module ActiveRecord
  module Tasks # :nodoc:
    class PGliteDatabaseTasks # :nodoc:
      def self.using_database_configurations?
        true
      end

      attr_reader :db_config, :configuration_hash

      def initialize(db_config)
        @db_config = db_config
        @configuration_hash = db_config.configuration_hash
      end

      def create(connection_already_established = false)
        JS.global[:pglite].create_interface(db_config.database).await
      end

      def purge(...)
        # skip for now
      end
    end
  end
end
