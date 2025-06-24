# Use TracePoint to wait for a particular class to load,
# so we can apply a patch right away
module Wasmify
  module Patcha
    class << self
      def on_load(name, &callback)
        callbacks[name] = callback
      end

      def on_class(event)
        # Ignore singletons
        return if event.self.singleton_class?

        class_name = name_method.bind_call(event.self)

        return unless callbacks[class_name]

        clbk = callbacks.delete(class_name)
        tracer.disable if callbacks.empty?

        clbk.call
      end

      def setup!
        return if callbacks.empty?

        @tracer = TracePoint.new(:end, &method(:on_class))
        tracer.enable
        # Use `Module#name` instead of `self.name` to handle overwritten `name` method
        @name_method = Module.instance_method(:name)
      end

      private

      attr_reader :tracer, :name_method

      def callbacks = @callbacks ||= {}
    end
  end
end
