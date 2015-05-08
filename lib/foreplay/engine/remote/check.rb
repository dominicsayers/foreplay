class Foreplay::Engine::Remote::Check
  include Foreplay
  attr_reader :host, :steps, :instructions

  def initialize(h, s, i)
    @host = h
    @steps = s
    @instructions = i
  end

  def perform
    steps.each do |step|
      log "#{(step['commentary'] || step['command']).yellow}", host: host, silent: step['silent']

      if step.key? 'key'
        list_file_contents step['key']
      else
        list_commands step
      end
    end

    ''
  end

  def list_file_contents(id)
    i = instructions[id]

    if i.is_a? Hash
      i.each { |k, v| log "#{k}: #{v}", host: host, indent: 1 }
    else
      log i, host: host, indent: 1
    end
  end

  def list_commands(step)
    commands = Foreplay::Engine::Step.new(host, step, instructions).commands

    commands.each do |command|
      log command, host: host, silent: step['silent']
    end
  end
end
