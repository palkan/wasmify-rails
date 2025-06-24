# frozen_string_literal: true

require "wasmify/patcha"

require "wasmify/rails/patches/rails"
require "wasmify/rails/patches/action_text"

Wasmify::Patcha.setup!
