class Foreplay::Engine::Secrets
  attr_reader :environment, :secret_locations

  def initialize(e, sl)
    @environment = e
    @secret_locations = sl
  end

  def fetch
    return unless secret_locations

    secrets = {}

    secret_locations.each do |secret_location|
      secrets.merge! fetch_from(secret_location) || {}
    end

    secrets
  end

  def fetch_from(secret_location)
    url = secret_location['url'] || return

    headers       = secret_location['headers']
    header_string = headers.map { |k, v| " -H \"#{k}: #{v}\"" }.join if headers.is_a? Hash
    command       = "curl -k -L#{header_string} #{url}".fake_erb
    secrets_all   = YAML.load(`#{command}`)
    secrets       = secrets_all[environment]

    secrets if secrets.is_a? Hash
  rescue Psych::SyntaxError
    nil
  end
end
