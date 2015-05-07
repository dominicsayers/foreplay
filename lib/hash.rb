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
