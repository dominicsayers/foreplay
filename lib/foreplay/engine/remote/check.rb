class Foreplay::Engine::Remote::Check
  attr_reader :host, :steps, :instructions

  def initialize(h, s, i)
    @host = h
    @steps = s
    @instructions = i
  end

  def perform
    steps.each do |step|
      puts "#{host}#{INDENT}#{(step['commentary'] || step['command']).yellow}" unless step['silent'] == true

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
      i.each { |k, v| puts "#{host}#{INDENT * 2}#{k}: #{v}" }
    else
      puts "#{host}#{INDENT * 2}#{i}"
    end
  end

  def list_commands(step)
    commands = Foreplay::Engine::Step.new(step, instructions).build

    commands.each do |command|
      puts "#{host}#{INDENT * 2}#{command}" unless step['silent']
    end
  end
end
