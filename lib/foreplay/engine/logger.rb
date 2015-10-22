module Foreplay
  class Engine
    class Logger
      INDENT = 4
      MARGIN = 24

      attr_reader :message, :options

      def initialize(m, o = {})
        @message = m
        @options = o

        output
      end

      def output
        puts formatted_message unless silent?
      end

      def formatted_message
        @formatted_message ||= header + message
                                        .gsub(/\A\s+/, '')
                                        .gsub(/\s+\z/, '')
                                        .gsub(/(\r\n|\r|\n)/, "\n#{margin}")
      end

      def header
        @header ||= (margin_format % header_content[0, margin_width - 1]).white
      end

      def header_content
        @header_content ||= (options[:host] || '')
      end

      def margin
        @margin ||= margin_format % ''
      end

      def silent?
        @silent ||= (options[:silent] == true) || message.blank?
      end

      def margin_width
        @margin_width ||= MARGIN + INDENT * (options[:indent] || 0)
      end

      def margin_format
        @margin_format ||= "%-#{margin_width}s"
      end
    end
  end
end
