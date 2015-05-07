class Foreplay::Engine::Step
  include Foreplay
  attr_reader :host, :step, :instructions

  def initialize(h, s, i)
    @host = h
    @step = s
    @instructions = i
  end

  def commands
    return @commands if @commands

    # Each step can be (1) a command or (2) a series of values to add to a file
    if step.key?('key')
      if instructions.key?(step['key'])
        build_commands
      else
        @commands = []
      end
    else
      # ...or just execute the command specified
      @commands = [command]
    end

    @commands
  end

  def build_commands
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

  def command
    @command ||= step['command']
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

  def silent
    @silent ||= step['silent']
  end

  def announce
    log "#{(step['commentary'] || command).yellow}", host: host, silent: silent
    log command.cyan, host: host, silent: silent if instructions['verbose'] && step['commentary'] && command
  end
end
