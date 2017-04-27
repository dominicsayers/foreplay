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

          case @secrets
          when Hash
            log "Loaded #{secrets.keys.length} secrets"
            @secrets
          when String
            log "Unexpected secrets found: #{@secrets}"
            @secrets = {}
          else
            url ? log("No secrets found at #{url}") : log('No url for secrets found')
            log("Secrets #{all_secrets.key?(environment) ? 'has a' : 'has no'} key #{environment}") if all_secrets
            @secrets = {}
          end
        end

        def all_secrets
          return @all_secrets if @all_secrets
          @all_secrets = url ? YAML.safe_load(raw_secrets, [Date, Symbol, Time], [], true) : {}
        rescue Psych::SyntaxError => e
          log "Exception caught when loading secrets from this location: #{url}"
          log "#{e.class}: #{e.message}".red
          @all_secrets = {}
        end

        def raw_secrets
          @raw_secrets ||= `#{command}`
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
