# frozen_string_literal: true

# First, expose the global #on_wasm? helper
module Kernel
  if RUBY_PLATFORM.include?("wasm")
    def on_wasm? = true
  else
    def on_wasm? = false
  end
end

# Only load shims when running within a Wasm runtime
return unless on_wasm?

# Setup Bundler
require "/bundle/setup"
require "bundler"

# Load core classes and deps patches
$LOAD_PATH.unshift File.expand_path("shims", __dir__)

# Prevent features:
#   - `bundler/setup` — we do that manually via `/bundle/setup`#
%w[
  bundler/setup
].each do |feature|
  $LOAD_PATH.resolve_feature_path(feature)&.then { $LOADED_FEATURES << _1[1] }
end

# Misc patches

# Make gem no-op
define_singleton_method(:gem) { |*| nil }

# Patch Bundler.require to simply require files without looking at specs
def Bundler.require(*groups)
  Bundler.definition.dependencies_for([:wasm]).each do |dep|
    required_file = nil
    # Based on https://github.com/rubygems/rubygems/blob/8a079e9061ad4aaf2bc0b9007da8f362b7a2e1f2/bundler/lib/bundler/runtime.rb#L57
    begin
      Array(dep.autorequire || dep.name).each do |file|
        file = dep.name if file == true
        required_file = file
        begin
          Kernel.require file
        rescue RuntimeError => e
          raise e if e.is_a?(LoadError) # we handle this a little later
          raise Bundler::GemRequireError.new e,
            "There was an error while trying to load the gem '#{file}'."
        end
      end
    rescue LoadError => e
      raise if dep.autorequire || e.path != required_file

      if dep.autorequire.nil? && dep.name.include?("-")
        begin
          namespaced_file = dep.name.tr("-", "/")
          Kernel.require namespaced_file
        rescue LoadError => e
          raise if e.path != namespaced_file
        end
      end
    end
  end
end

class Thread
  def self.new(...)
    f = Fiber.new(...)
    def f.value = resume
    f
  end
end
