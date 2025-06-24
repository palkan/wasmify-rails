module Wasmify
  module ExternalCommands
    class << self
      attr_reader :command

      def register(*names)
        names.each do |name|
          module_eval <<~RUBY, __FILE__, __LINE__ + 1
            def self.#{name}(...)
              raise ArgumentError, "Command has been already defined: #{command}" if command

              ::JS.global[:externalCommands].#{name}(...)

              @command = :#{name}
            end
          RUBY
        end
      end

      def any? = !!command
    end
  end
end
