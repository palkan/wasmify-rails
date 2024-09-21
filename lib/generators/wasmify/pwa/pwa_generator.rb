# frozen_string_literal: true

class Wasmify::PwaGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  def copy_files
    directory "pwa", "pwa"
  end

  private

  def wasmify_rails_version = Wasmify::Rails::VERSION
end
