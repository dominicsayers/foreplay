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
    puts "#{host}#{INDENT}#{(step['commentary'] || step['command']).yellow}" unless step['silent'] == true
    output Foreplay::Engine::Step.new(step, instructions).build.map { |command| execute_command(command) }.join
  end

  def execute_command(command)
    o = ''
    process = shell.execute command
    process.on_output { |_, po| o = po }
    shell.wait!
    terminate(o) unless step['ignore_error'] == true || process.exit_status == 0
    o
  end

  def output(o)
    puts o.gsub!(/^/, "#{host}#{INDENT * 2}") unless step['silent'] == true || o.blank?
    o
  end
end
