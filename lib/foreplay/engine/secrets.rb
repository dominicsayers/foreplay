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
      secrets.merge! fetch_from(secret_location)
    end

    secrets
  end

  def fetch_from(secret_location)
    return unless secret_location['url']

    headers = secret_location['headers'].map { |k, v| " -H \"#{k}: #{v}\"" }.join
    command = "curl -k -L#{headers} #{secret_location['url']}"

    secrets_all = YAML.load(`#{command}`)
    secrets_all[environment]
  rescue Psych::SyntaxError
    nil
  end
end
