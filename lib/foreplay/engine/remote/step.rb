class Foreplay::Engine::Remote::Step
  include Foreplay
  attr_reader :host, :shell, :step, :instructions

  def initialize(h, sh, st, i)
    @host = h
    @shell = sh
    @step = st
    @instructions = i
  end

  def execute
    s = Foreplay::Engine::Step.new(host, step, instructions)
    s.announce
    output s.commands.map { |command| execute_command(command) }.join
  end

  def execute_command(command)
    o = ''
    process = shell.execute command
    process.on_output { |_, po| o += po }
    shell.wait!
    terminate(o) unless step['ignore_error'] == true || process.exit_status == 0
    o
  end

  def silent
    @silent ||= instructions['verbose'] ? false : step['silent']
  end

  def output(o)
    log o, host: host, silent: silent, indent: 1
    o
  end
end
