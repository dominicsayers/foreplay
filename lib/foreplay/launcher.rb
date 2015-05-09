require 'thor/group'

module Foreplay
  class Launcher < Thor::Group
    include Thor::Actions

    argument :mode,         type: :string,  required: true
    argument :environment,  type: :string,  required: true
    argument :filters,      type: :hash,    required: false

    def parse
      Foreplay::Engine.new(environment, filters).__send__ mode
    end
  end
end
