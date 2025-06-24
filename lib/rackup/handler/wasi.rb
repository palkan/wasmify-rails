module Rackup
  module Handler
    class WASIServer
      def self.run(app, **options)
        require "rack/wasi/incoming_handler"
        port = options[:Port]

        $incoming_handler = ::Rack::WASI::IncomingHandler.new(app)

        ::Wasmify::ExternalCommands.server(port)
      end
    end

    register :wasi, WASIServer
  end
end
