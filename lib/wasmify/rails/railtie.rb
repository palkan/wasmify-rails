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
