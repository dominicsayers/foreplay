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

require 'active_support'
require 'active_support/core_ext'
require 'active_support/core_ext/object'

class Hash
  # Returns a new hash with +hash+ and +other_hash+ merged recursively, including arrays.
  #
  #   h1 = { x: { y: [4,5,6] }, z: [7,8,9] }
  #   h2 = { x: { y: [7,8,9] }, z: 'xyz' }
  #   h1.supermerge(h2)
  #   #=> {:x=>{:y=>[4, 5, 6, 7, 8, 9]}, :z=>[7, 8, 9, "xyz"]}
  def supermerge(other_hash)
    fail 'supermerge only works if you pass a hash. '\
      "You passed a #{self.class} and a #{other_hash.class}." unless other_hash.is_a?(Hash)

    new_hash = deep_dup

    other_hash.each_pair do |k, v|
      tv = new_hash[k]

      if tv.is_a?(Hash) && v.is_a?(Hash)
        new_hash[k] = tv.supermerge(v)
      elsif tv.is_a?(Array) || v.is_a?(Array)
        new_hash[k] = Array.wrap(tv) + Array.wrap(v)
      else
        new_hash[k] = v
      end
    end

    new_hash
  end
end

# Some useful additions to the String class
class String
  colors = %w(black red green yellow blue magenta cyan white)

  colors.each_with_index do |fg_color, i|
    fg = 30 + i
    define_method(fg_color) { ansi_attributes(fg) }

    colors.each_with_index do |bg_color, j|
      define_method("#{fg_color}_on_#{bg_color}") { ansi_attributes(fg, 40 + j) }
    end
  end

  def ansi_attributes(*args)
    "\e[#{args.join(';')}m#{self}\e[0m"
  end

  def fake_erb
    gsub(/(<%=\s+([^%]+)\s+%>)/) { |e| eval "_ = #{e.split[1]}" }
  end
end
