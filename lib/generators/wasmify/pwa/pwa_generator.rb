# frozen_string_literal: true

class Wasmify::PwaGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  def copy_files
    directory "pwa", "pwa"
  end

  def configure_wasm_dist
    prepend_to_file "config/wasmify.yml", <<~EOF
      output_dir: pwa
    EOF
  end

  def install_npm_deps
    begin
      in_root do
        run "(cd pwa/ && yarn install)"
      end
    rescue
      say "Please, make sure to run `yarn install` within the pwa/ folder", :red
    end
  end

  private

  def wasmify_rails_version = Wasmify::Rails::VERSION
end
