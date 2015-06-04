module Foreplay
  class Engine
    class Secrets
      class Location
        include Foreplay
        attr_reader :secret_location, :environment

        def initialize(s, e)
          @secret_location = s
          @environment = e
        end

        def secrets
          return @secrets if @secrets

          @secrets = all_secrets[environment]

          if @secrets.is_a? Hash
            log "Loaded #{secrets.keys.length} secrets"
            @secrets
          else
            log 'No secrets found'
            @secrets = {}
          end
        end

        def all_secrets
          return @all_secrets if @all_secrets

          @all_secrets = url ? YAML.load(`#{command}`) : {}
        rescue Psych::SyntaxError => e
          log "Exception caught when loading secrets using this command: #{command}"
          log "#{e.class}: #{e.message}".red
          @all_secrets = {}
        end

        def command
          @command ||= "curl -k -L#{header_string} #{url}".fake_erb
        end

        def header_string
          @header_string ||= headers.map { |k, v| " -H \"#{k}: #{v}\"" }.join if headers.is_a? Hash
        end

        def headers
          @headers ||= secret_location['headers']
        end

        def url
          @url ||= @secret_location['url']
        end
      end
    end
  end
end
