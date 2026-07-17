# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

namespace :test do
  desc "Verify wasmification of a fresh Rails app end-to-end (RUBY_VERSION, RAILS_VERSION; default 3.3/8.0)"
  task :integration do
    require_relative "test/integration_helper"

    klass = Wasmify::Integration::Helper
    helper = klass.new(
      ruby_version: ENV["RUBY_VERSION"] || klass::DEFAULT_RUBY_VERSION,
      rails_version: ENV["RAILS_VERSION"] || klass::DEFAULT_RAILS_VERSION,
      root: __dir__
    )

    begin
      helper.run
      puts "Integration test passed: Ruby #{helper.ruby_version} x Rails #{helper.rails_version}"
    rescue klass::Error => e
      abort "Integration test failed: #{e.message}"
    end
  end
end

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new

  RuboCop::RakeTask.new("rubocop:md") do |task|
    task.options << %w[-c .rubocop-md.yml]
  end
rescue LoadError
  task(:rubocop) {}
  task("rubocop:md") {}
end

task default: %w[rubocop test]
