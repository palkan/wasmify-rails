Wasmify::Patcha.on_load("Rails::Server") do
  Rails::Server.prepend(Module.new do
    def initialize(options)
      # disable pid files
      options.delete(:pid)
      super
    end

    # Change the after_stop_callback logic
    def start(after_stop_callback = nil)
      Kernel.at_exit(&after_stop_callback) if after_stop_callback
      super()
    end
  end)
end

Wasmify::Patcha.on_load("Rails::Generators::Actions") do
  Rails::Generators::Actions.prepend(Module.new do
    # Always run Rails commands inline (we cannot spawn new processes)
    def rails_command(command, options = {})
      super(command, options.merge(inline: true))
    end
  end)
end

Wasmify::Patcha.on_load("Rails::Console::IRBConsole") do
  Rails::Console::IRBConsole.prepend(Module.new do
    def start
      # Disable default IRB behaviour but keep the configuration around
      ::IRB::Irb.prepend(Module.new { def run(*); end })
      super
      ::Wasmify::ExternalCommands.console
    end
  end)
end
