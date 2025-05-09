# frozen_string_literal: true

begin
  require "debug" unless ENV["CI"]
rescue LoadError
end

Dir["#{__dir__}/support/**/*.rb"].sort.each { |f| require f }

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "wasmify-rails"

require "minitest/autorun"
