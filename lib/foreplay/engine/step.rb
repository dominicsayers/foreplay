module Foreplay
  class Engine
    class Step
      include Foreplay
      attr_reader :host, :step, :instructions

      def initialize(h, s, i)
        @host = h
        @step = s
        @instructions = i
        @redirect = false
      end

      def commands
        return @commands if @commands
        @commands = []

        # Each step can be (1) a command or (2) a series of values to add to a file
        if step.key?('key')
          build_commands if instructions.key?(step['key'])
        else
          # ...or just execute the command specified
          @commands = [command]
        end

        @commands
      end

      def build_commands
        step['silent'] = !instructions.key?('verbose')
        instructions[key].is_a?(Hash) ? build_commands_from_hash : build_commands_from_string
      end

      def build_commands_from_hash
        delimiter == ': ' ? build_commands_from_hash_to_yaml : build_commands_from_hash_to_env
      end

      def build_commands_from_hash_to_yaml
        instructions_yaml.each_line do |l|
          @commands << "echo \"#{l.remove_trailing_newline.escape_double_quotes}\" #{redirect} #{filename}"
        end
      end

      def instructions_hash
        header? ? { header => instructions[key] } : instructions[key]
      end

      def instructions_yaml
        YAML.dump instructions_hash
      end

      def build_commands_from_hash_to_env
        instructions[key].each do |k, v|
          @commands << "echo \"#{before}#{k}#{delimiter}#{v}#{after}\" #{redirect} #{filename}"
        end
      end

      def build_commands_from_string
        @commands << "echo \"#{before}#{delimiter}#{instructions[key]}#{after}\" #{redirect} #{filename}"
      end

      def redirect
        arrow = @redirect ? '>>' : '>'
        @redirect = true
        arrow
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

      def silent?
        @silent ||= step['silent']
      end

      def announce
        log (step['commentary'] || command).yellow.to_s, host: host, silent: silent?
        log command.cyan, host: host, silent: silent? if instructions['verbose'] && step['commentary'] && command
      end
    end
  end
end
