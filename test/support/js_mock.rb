# frozen_string_literal: true

module JS
  class Object
    class << self
      alias_method :wrap, :new
    end

    private attr_reader :data

    def initialize(data = {})
      @data = data
    end

    def call(method_name, *args)
      if @data.respond_to?(:key?) && @data.key?(method_name)
        value = @data[method_name]
        (value.is_a?(Proc) ? value.call(*args) : value).then { Object.new(_1) }
      elsif @data.respond_to?(method_name)
        @data.send(method_name, *args).then { Object.new(_1) }
      else
        Object.new(nil)
      end
    end

    def [](key)
      Object.new(@data[key])
    end

    def typeof
      case @data
      when Hash then "object"
      when String then "string"
      when Array then "array"
      when Integer, Float then "number"
      when TrueClass, FalseClass then "boolean"
      when NilClass then "object"
      else "undefined"
      end
    end

    def to_s = @data.to_s

    def to_a = @data.to_a

    def to_i = @data.to_i

    def to_h = @data

    def entries(obj)
      obj.instance_variable_get(:@data).to_a
    end
  end

  class GlobalContext
    def initialize
      @objects = {}
      @objects["Object"] = Object.new
    end

    def register(name, object)
      @objects[name.to_s] = object
    end

    def [](key)
      @objects[key.to_s]
    end
  end

  def self.global
    @global ||= GlobalContext.new
  end

  def self.reset_global!
    @global = nil
  end
end
