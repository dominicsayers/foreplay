require 'pp' # debug

class Foreplay::Engine::Role
  attr_reader :environment, :mode, :instructions, :servers
  def initialize(e, m, i)
    @environment  = e
    @mode         = m
    @instructions = i
    @servers      = @instructions['servers']

    preposition = mode == :deploy ? 'to' : 'for'

    return if @servers.length == 1

    puts "#{mode.capitalize}ing #{instructions['name'].yellow} #{preposition} #{@servers.join(', ').yellow} "\
         "for the #{instructions['role'].dup.yellow} role in the #{environment.dup.yellow} environment..."
  end

  def threads
    servers.map do |server|
      Thread.new { Foreplay::Engine::Server.new(environment, mode, instructions, server).execute }
    end
  end
end
