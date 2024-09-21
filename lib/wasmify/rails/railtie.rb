# frozen_string_literal: true

module Wasmify
  module Rails
    class Railtie < ::Rails::Railtie
      rake_tasks do
        load "wasmify/rails/tasks.rake"
      end
    end
  end
end
