require 'foreplay/version'
require 'foreplay/engine'
require 'foreplay/launcher'

module Foreplay
  DEFAULT_PORT = 50_000
  PORT_GAP = 1_000

  def log(message, options = {})
    Foreplay::Engine::Logger.new(message, options)
  end

  def terminate(message)
    fail message
  end
end
