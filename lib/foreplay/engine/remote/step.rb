class Foreplay::Engine::Remote::Step
  include Foreplay
  attr_reader :shell, :step, :instructions

  def initialize(sh, st, i)
    @shell = sh
    @step = st
    @instructions = i
  end

  def deploy
    puts "#{host}#{INDENT}#{(step['commentary'] || step['command']).yellow}" unless step['silent'] == true

    # Output from this step
    output    = ''
    previous  = '' # We don't need or want the final CRLF
    commands  = Foreplay::Engine::Step.new(step, instructions).build

    commands.each do |command|
      process = shell.execute command

      process.on_output do |_, o|
        previous = o
        output += previous
      end

      shell.wait!

      if step['ignore_error'] == true || process.exit_status == 0
        print output.gsub!(/^/, "#{host}#{INDENT * 2}") unless step['silent'] == true || output.blank?
      else
        terminate(output)
      end
    end
  end
end
