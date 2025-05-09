# frozen_string_literal: true

require "rack"
require "base64"

module Rack
  class DataUriUploads
    # A specific prefix we use to identify data URIs that must be transformed
    # into file uploads.
    PREFIX = "BbC14y"
    DATAURI_REGEX = %r{^#{PREFIX}data:(.*?);(.*?),(.*)$}

    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless env[RACK_INPUT]

      request = Rack::Request.new(env)

      if (
        request.post? || request.put? || request.patch?
      ) && request.get_header("HTTP_CONTENT_TYPE").match?(%r{multipart/form-data})
        transform_params(request.params)
        env["action_dispatch.request.request_parameters"] = request.params
      end

      @app.call(env)
    end

    private

    def transform_params(params)
      return params unless params.is_a?(Hash)
      params.each do |key, value|
        if value.is_a?(String) && value.match?(DATAURI_REGEX)
          params[key] = from_data_uri(value)
        elsif value.is_a?(Hash)
          transform_params(value)
        elsif value.is_a?(Array)
          value.each { transform_params(_1) }
        end
      end
    end

    def from_data_uri(data_uri)
      matches = data_uri.match(DATAURI_REGEX)

      content_type = matches[1]
      encoding = matches[2]
      data = matches[3]

      return if data.empty?

      file_data = Base64.decode64(data)

      file = Tempfile.new(["upload", mime_to_extension(content_type)])
      file.binmode
      file.write(file_data)
      file.rewind

      # Create a Rack::Test::UploadedFile, so it works with strong parameters
      Rack::Test::UploadedFile.new(file.path, content_type)
    end

    def mime_to_extension(mime_type)
      mime_type.split("/").then do |parts|
        next "" unless parts.length == 2
        ".#{parts.last}"
      end
    end
  end
end
