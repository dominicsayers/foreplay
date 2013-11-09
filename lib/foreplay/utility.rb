module Foreplay
  class Utility
    # Returns a new hash with +hash+ and +other_hash+ merged recursively, including arrays.
    #
    #   h1 = { x: { y: [4,5,6] }, z: [7,8,9] }
    #   h2 = { x: { y: [7,8,9] }, z: 'xyz' }
    #   h1.supermerge(h2)
    #   #=> {:x=>{:y=>[4, 5, 6, 7, 8, 9]}, :z=>[7, 8, 9, "xyz"]}
    def self.supermerge(hash, other_hash)
      raise 'supermerge only works if you pass two hashes' unless hash.is_a?(Hash) && other_hash.is_a?(Hash)

      new_hash = hash.deep_dup.with_indifferent_access

      other_hash.each_pair do |k,v|
        tv = new_hash[k]

        if tv.is_a?(Hash) && v.is_a?(Hash)
          new_hash[k] = Foreplay::Utility::supermerge(tv, v)
        elsif tv.is_a?(Array) || v.is_a?(Array)
          new_hash[k] = Array.wrap(tv) + Array.wrap(v)
        else
          new_hash[k] = v
        end
      end

      new_hash
    end
  end
end
