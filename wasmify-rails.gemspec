# frozen_string_literal: true

require_relative "lib/wasmify/rails/version"

Gem::Specification.new do |s|
  s.name = "wasmify-rails"
  s.version = Wasmify::Rails::VERSION
  s.authors = ["Vladimir Dementyev"]
  s.email = ["Vladimir Dementyev"]
  s.homepage = "https://github.com/palkan/wasmify-rails"
  s.summary = "Tools and extensions to package Rails apps as Wasm modules"
  s.description = "Tools and extensions to package Rails apps as Wasm modules"

  s.metadata = {
    "bug_tracker_uri" => "https://github.com/palkan/wasmify-rails/issues",
    "changelog_uri" => "https://github.com/palkan/wasmify-rails/blob/master/CHANGELOG.md",
    "documentation_uri" => "https://github.com/palkan/wasmify-rails",
    "homepage_uri" => "https://github.com/palkan/wasmify-rails",
    "source_code_uri" => "https://github.com/palkan/wasmify-rails"
  }

  s.license = "MIT"

  s.executables = %w[]

  s.files = Dir.glob("lib/**/*") + Dir.glob("bin/**/*") + %w[README.md LICENSE.txt CHANGELOG.md]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.2"

  s.add_dependency "railties", ">= 7.0", "< 9.0"
  s.add_dependency "ruby_wasm", ">= 2.6", "< 3.0"
  s.add_dependency "js", ">= 2.6", "< 3.0"

  s.add_development_dependency "bundler", ">= 1.15"
  s.add_development_dependency "rake", ">= 13.0"
  s.add_development_dependency "minitest", "~> 5.0"
end
