# frozen_string_literal: true

require "stringio"
require "uri"
require "base64"
require "rack"
require "rack/test"

require "rack/data_uri_uploads"

module Rack
  module WASI
    class Result < Data.define(:value, :error)
      def tag = error ? "error" : "ok"
    end

    #  resource incoming-request {
    #    method: func() -> method;
    #    path-with-query: func() -> option<string>;
    #    scheme: func() -> option<scheme>;
    #    authority: func() -> option<string>;
    #    headers: func() -> headers;
    #    consume: func() -> result<incoming-body>;
    # }
    # https://github.com/WebAssembly/wasi-http/blob/d163277b8684483a2334363ca1492ca298ea526d/wit/types.wit#L274
    class IncomingRequest
      # We use a reference to the global JS object to access the incoming request data.
      def initialize(js_object_id)
        @js_object = ::JS.global[js_object_id]
      end

      def method = @js_object.call(:method).to_s

      def path_with_query
        path = @js_object.call(:pathWithQuery)
        if path.typeof == "string"
          path.to_s
        end
      end

      def scheme
        sch = @js_object.call(:scheme)
        if sch.typeof == "string"
          sch.to_s
        end
      end

      def authority
        auth = @js_object.call(:authority)
        if auth.typeof == "string"
          auth.to_s
        end
      end

      def headers
        entries = ::JS.global[:Object].entries(@js_object.call(:headers))
        entries.to_a.each.with_object({}) do |entry_val, acc|
          key, val = entry_val.to_a
          acc[key.to_s] = val.to_s
          acc
        end
      end

      # NOTE: Currently, we only support text bodies
      def consume
        body = @js_object.call(:consume)
        if body.typeof == "string"
          body.to_s
        end
      end
    end

    #  resource response-outparam {
    #    set: static func(
    #      param: response-outparam,
    #      response: result<outgoing-response, error-code>,
    #    );
    #  }
    #
    # https://github.com/WebAssembly/wasi-http/blob/d163277b8684483a2334363ca1492ca298ea526d/wit/types.wit#L437
    class ResponseOutparam
      # We use a reference to the global JS object to access the incoming request data
      def initialize(js_object_id)
        @js_object = ::JS.global[js_object_id]
      end

      def set(result)
        @js_object.call(:set, ::JS::Object.wrap(result))
      end
    end

    #  resource outgoing-response {
    #    constructor(headers: headers);
    #    status-code: func() -> status-code;
    #    set-status-code: func(status-code: status-code) -> result;
    #    headers: func() -> headers;
    #    body: func() -> result<outgoing-body>;
    #  }
    #
    #  resource outgoing-body {
    #    write: func() -> result<output-stream>;
    #    finish: static func(
    #        this: outgoing-body,
    #        trailers: option<trailers>
    #      ) -> result<_, error-code>;
    #    }
    #  }
    #
    # https://github.com/WebAssembly/wasi-http/blob/d163277b8684483a2334363ca1492ca298ea526d/wit/types.wit#L572
    class OutgoingResponse
      attr_reader :status_code, :headers, :body

      def initialize(headers:, status_code: 200)
        @headers = headers
        @status_code = status_code
        @body = nil
      end

      def write(response_body)
        @body = response_body
      end
    end

    # wasi:http/proxy-like handler implementation for Rack apps
    class IncomingHandler
      private attr_reader :base_url

      def initialize(app, base_url: "http://localhost:3000", skip_data_uri_uploads: false)
        @app = app

        @app = Rack::DataUriUploads.new(@app) unless skip_data_uri_uploads

        @base_url = base_url
      end

      # Takes Wasi request, converts it to Rack request,
      # calls the Rack app, and write Rack response back to the Wasi response.
      #
      # @param [Rack::WASI::HTTP::IncomingRequest] req
      # @param [Rack::WASI::HTTP::ResponseOutparam] res
      def handle(req, res)
        uri = URI.join(base_url, req.path_with_query || "")
        headers = req.headers.each.with_object({}) do |(key, value), headers|
          headers["HTTP_#{key.upcase.gsub("-", "_")}"] = value
          headers
        end

        http_method = req.method.upcase
        headers[:method] = http_method

        body = req.consume
        headers[:input] = StringIO.new(body) if body

        request = Rack::MockRequest.env_for(uri.to_s, headers)
        begin
          response = Rack::Response[*@app.call(request)]
          response_status, response_headers, bodyiter = *response.finish

          out_response = OutgoingResponse.new(headers: response_headers, status_code: response_status)

          body = ""
          body_is_set = false

          bodyiter.each do |part|
            body += part
            body_is_set = true
          end

          # Serve images as base64 from Ruby and decode back in JS
          # FIXME: extract into a separate middleware and add a header to indicate the transformation
          if response_headers["Content-Type"]&.start_with?("image/")
            body = Base64.strict_encode64(body)
          end

          out_response.write(body) if body_is_set
          res.set(Result.new(out_response, nil))
        rescue Exception => e
          res.set(Result.new(e.message, 503))
        end
      end
    end
  end
end
