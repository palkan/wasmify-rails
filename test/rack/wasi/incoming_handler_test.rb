# frozen_string_literal: true

require "test_helper"
require "rack/wasi/incoming_handler"

module Rack
  module WASI
    class MockResponse
      attr_reader :result

      def initialize
        @result = nil
      end

      def to_js_object
        JS::Object.new(set: ->(res) { @result = res })
      end

      def status_code
        return nil unless success?
        result.call(:value).call(:status_code).to_i
      end

      def headers
        return {} unless success?
        result.call(:value).call(:headers).to_h
      end

      def body
        return nil unless success?
        result.call(:value).call(:body).to_s
      end

      def error_code
        return nil if success?
        result.call(:error).to_i
      end

      def success?
        result&.call(:tag).to_s == "ok"
      end

      def error?
        result&.call(:tag).to_s == "error"
      end
    end

    class IncomingHandlerTest < Minitest::Test
      def setup
        JS.reset_global!
        @app = -> (env) { [200, {"Content-Type" => "text/plain"}, ["Hello World"]] }
        @handler = IncomingHandler.new(@app)
        @mock_response = MockResponse.new
        JS.global.register(:response, @mock_response.to_js_object)
      end

      attr_reader :mock_response, :handler

      def setup_request(method: "GET", pathWithQuery: "/test", headers: {}, **rest)
        js_req = JS::Object.new({method:, pathWithQuery:, headers:, **rest})
        JS.global.register(:request, js_req)
        IncomingRequest.new("request")
      end

      def test_handles_basic_get_request
        mock_req = setup_request(
          pathWithQuery: "/test?p=1",
          headers: {
            "content-type" => "text/plain",
            "accept" => "*/*"
          }
        )

        mock_res = ResponseOutparam.new("response")
        handler.handle(mock_req, mock_res)

        assert mock_response.success?
        assert_equal 200, mock_response.status_code
        assert_equal "text/plain", mock_response.headers["Content-Type"]
        assert_equal "Hello World", mock_response.body
      end

      def test_handles_request_with_body
        echo_app = -> (env) {
          body = env["rack.input"].read
          [200, {"Content-Type" => "application/json"}, [body]]
        }

        @handler = IncomingHandler.new(echo_app)

        mock_req = setup_request(
          method: "POST",
          pathWithQuery: "/test",
          headers: {
            "content-type" => "application/json",
            "accept" => "*/*"
          },
          consume: -> { '{"key":"value"}' }
        )

        mock_res = ResponseOutparam.new("response")
        handler.handle(mock_req, mock_res)

        assert mock_response.success?
        assert_equal 200, mock_response.status_code
        assert_equal "application/json", mock_response.headers["Content-Type"]
        assert_equal '{"key":"value"}', mock_response.body
      end

      def test_handles_errors_gracefully
        error_app = -> (env) { raise "Test error" }
        @handler = IncomingHandler.new(error_app)

        mock_req = setup_request(
          method: "GET",
          pathWithQuery: "/error"
        )

        mock_res = ResponseOutparam.new("response")
        handler.handle(mock_req, mock_res)

        assert mock_response.error?
        assert_equal 503, mock_response.error_code
      end
    end
  end
end
