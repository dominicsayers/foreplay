class Foreplay::Engine::Step
  attr_reader :step, :instructions

  def initialize(s, i)
    @step = s
    @instructions = i
  end

  def build
    # Each step can be (1) a command or (2) a series of values to add to a file
    if step.key?('key')
      instructions.key?(step['key']) ? build_commands(step, instructions) : []
    else
      # ...or just execute the command specified
      [step['command']]
    end
  end

  def build_commands(step, instructions)
    # Add values from the config file to a file on the remote machine
    key       = step['key']
    prefix    = step['prefix'] || ''
    suffix    = step['suffix'] || ''
    path      = step['path'] || ''
    before    = step['before'] || ''
    delimiter = step['delimiter'] || ''
    after     = step['after'] || ''

    step['silent'] = true
    filename = "#{path}#{prefix}#{key}#{suffix}"

    if step.key?('header')
      commands  = ["echo \"#{step['header']}\" > #{filename}"]
      redirect  = '>>'
    else
      commands  = []
      redirect  = '>'
    end

    if instructions[key].is_a? Hash
      instructions[key].each do |k, v|
        commands << "echo \"#{before}#{k}#{delimiter}#{v}#{after}\" #{redirect} #{filename}"
        redirect = '>>'
      end
    else
      commands << "echo \"#{before}#{delimiter}#{instructions[key]}#{after}\" #{redirect} #{filename}"
      redirect = '>>'
    end

    commands
  end
end
