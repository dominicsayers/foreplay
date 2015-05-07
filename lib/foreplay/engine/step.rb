class Foreplay::Engine::Step
  attr_reader :step, :instructions

  def initialize(s, i)
    @step = s
    @instructions = i
  end

  def build
    # Each step can be (1) a command or (2) a series of values to add to a file
    if step.key?('key')
      instructions.key?(step['key']) ? commands : []
    else
      # ...or just execute the command specified
      [step['command']]
    end
  end

  def commands
    return @commands if @commands

    step['silent'] = true

    if header?
      @commands  = ["echo \"#{header}\" > #{filename}"]
      redirect
    else
      @commands  = []
    end

    if instructions[key].is_a? Hash
      build_commands_from_hash
    else
      build_commands_from_string
    end

    @commands
  end

  def build_commands_from_hash
    instructions[key].each do |k, v|
      @commands << "echo \"#{before}#{k}#{delimiter}#{v}#{after}\" #{redirect} #{filename}"
    end
  end

  def build_commands_from_string
    @commands << "echo \"#{before}#{delimiter}#{instructions[key]}#{after}\" #{redirect} #{filename}"
  end

  def redirect
    if @redirect
      '>>'
    else
      @redirect = true
      '>'
    end
  end

  def filename
    @filename ||= "#{path}#{prefix}#{key}#{suffix}"
  end

  def key
    @key ||= step['key']
  end

  def prefix
    @prefix ||= step['prefix'] || ''
  end

  def suffix
    @suffix ||= step['suffix'] || ''
  end

  def path
    @path ||= step['path'] || ''
  end

  def before
    @before ||= step['before'] || ''
  end

  def delimiter
    @delimiter ||= step['delimiter'] || ''
  end

  def after
    @after ||= step['after'] || ''
  end

  def header
    @header ||= step['header']
  end

  def header?
    header.present?
  end
end
