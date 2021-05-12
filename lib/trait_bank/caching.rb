module TraitBank
  module Caching
    class << self
      def add_hash_to_key(key, hash)
        hash.keys.sort.each do |k|
          v = hash[k]
          key.concat("/#{k}_#{v}") if !v.nil?
        end
      end
    end
  end
end
