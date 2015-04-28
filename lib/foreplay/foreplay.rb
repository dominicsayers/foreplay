require 'active_support/core_ext/object'
require 'active_support/core_ext/hash'

module Foreplay
  INDENT = "\t"

  def terminate(message)
    fail message
  end
end
