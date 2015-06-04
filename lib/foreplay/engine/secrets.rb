require 'foreplay/engine/secrets/location'

module Foreplay
  class Engine
    class Secrets
      attr_reader :environment, :secret_locations

      def initialize(e, sl)
        @environment = e
        @secret_locations = sl
      end

      def fetch
        return unless secret_locations

        secrets = {}
        secret_locations.each { |secret_location| secrets.merge! location_secrets(secret_location) }
        secrets
      end

      def location_secrets(secret_location)
        Location.new(secret_location, environment).secrets
      end
    end
  end
end
