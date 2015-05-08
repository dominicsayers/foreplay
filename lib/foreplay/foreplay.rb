module Foreplay
  def log(message, options = {})
    Foreplay::Engine::Logger.new(message, options)
  end

  def terminate(message)
    fail message
  end
end
