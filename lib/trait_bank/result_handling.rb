module TraitBank::ResultHandling
  class << self
    include TraitBank::Constants

    # For results where each column is labeled <node_label>.<property>, e.g., "predicate.uri",
    # and the values are all strings or numbers
    def flat_results_to_hashes(results, options = {})
      id_col_label = options[:id_col_label] || "trait.eol_pk"
      id_col = results["columns"].index(id_col_label)
      id_col ||= 0 # If there is no trait column and nothing was specified...
      raise "missing id column #{id_col_label}" if id_col.nil?
      hashes = []
      previous_id = nil
      hash = {}

      results["data"].each do |row|
        row_id = row[id_col]
        raise("Found row with no ID on row: #{row.inspect}") if row_id.nil?

        if row_id != previous_id
          previous_id = row_id
          hashes << hash unless hash.empty?
          hash = {}
        end

        nodes = {}
        results["columns"].each_with_index do |col, i|
          node_label, node_prop = col.split(".")
          raise "unexpected column name -- expect <label>.<prop> format" unless node_label && node_prop

          node_label = node_label.to_sym
          node_prop = node_prop.to_sym
          value = row[i]

          nodes[node_label] ||= {}
          if value.present?
            nodes[node_label][node_prop] = row[i]
          end
        end

        nodes.each do |label, node|
          if hash.has_key?(label)
            if hash[label].is_a?(Array)
              hash[label] << node
            elsif hash[label] != node
              # ...turn it into an array and add the new value.
              hash[label] = [hash[label], node]
            # Note the lack of "else" ... if the value is the same as the last
            # row, we ignore it (assuming it's a duplicate value and another
            # column is changing)
            end
          else
            # See note in results_to_hashes
            if label.to_s =~ /\Ameta/
              hash[label] = [node]
            else
              hash[label] = node unless node.empty?
            end
          end
        end
      end
      hashes << hash unless hash.empty?
      hashes
    end

    # Given a results array and the name of one of the returned columns to treat
    # as the "identifier" (meaning the field who's ID will uniquely identify a
    # row of related data ... e.g.: the "trait" for trait data)
    def results_to_hashes(results, identifier = nil)
      id_col = results["columns"].index(identifier ? identifier.to_s : "trait")
      id_col ||= 0 # If there is no trait column and nothing was specified...
      hashes = []
      previous_id = nil
      hash = nil
      results["data"].each do |row|
        id_col_val = row[id_col]
        row_id = if id_col_val.is_a? String
                   id_col_val
                 else
                   id_col_val.dig("metadata", "id")
                 end
        raise("Found row with no ID on row: #{row.inspect}") if row_id.nil?
        if row_id != previous_id
          previous_id = row_id
          hashes << hash unless hash.nil?
          hash = {}
        end
        results["columns"].each_with_index do |column, i|
          col = column.to_sym

          # This is pretty complicated. It symbolizes any hash that might be a
          # return value, and leaves it alone otherwise. It also checks for a
          # value in "data" first, but returns whatever it gets if that is
          # missing. Just being flexible, since neography returns a variety of
          # results.
          value = if row[i]
                    if row[i].is_a?(Hash)
                      if row[i]["data"].is_a?(Hash)
                        row[i]["data"].symbolize_keys
                      else
                        row[i]["data"] ? row[i]["data"] : row[i].symbolize_keys
                      end
                    else
                      row[i]
                    end
                  else
                    nil
                  end
          if hash.has_key?(col)
            # NOTE: this assumes neo4j never naturally returns an array...
            if hash[col].is_a?(Array)
              hash[col] << value
            # If the value is changing (or if it's metadata)...
            elsif hash[col] != value
              # ...turn it into an array and add the new value.
              hash[col] = [hash[col], value]
            # Note the lack of "else" ... if the value is the same as the last
            # row, we ignore it (assuming it's a duplicate value and another
            # column is changing)
            end
          else
            # Metadata will *always* be returned as an array...
            # NOTE: it's important to catch columns that we KNOW could have
            # multiple values for a given "row"! ...Otherwise, the "ignore
            # duplicates" code will cause problems, above. If you know of a
            # column that could have multiple values, you need to add detection
            # for it here.
            # TODO: this isn't a very general solution. Really we should pass in
            # some knowledge of this, either something like "these columns could
            # have multiple values" or the opposite: "these columns identify a
            # row and cannot change". I prefer the latter, honestly.
            if column =~ /\Ameta/
              hash[col] = [value]
            else
              hash[col] = value unless value.nil?
            end
          end
        end
      end
      hashes << hash unless hash.nil? || hash == {}
      # Symbolize everything!
      hashes.each do |k,v|
        if v.is_a?(Hash)
          hashes[k] = v.symbolize_keys
        elsif v.is_a?(Array)
          hashes[k] = v.map { |sv| sv.symbolize_keys }
        end
      end
      hashes
    end

    # NOTE: this method REQUIRES that some fields have a particular name.
    # ...which isn't very generalized, but it will do for our purposes...
    def build_trait_array(results, options={})
      hashes = options[:flat_results] ? flat_results_to_hashes(results) : results_to_hashes(results, options[:identifier])
      key = options[:key]
      TraitBank::Logger.log("RESULT COUNT #{key}: #{hashes.length} after results_to_hashes") if key
      data = []
      hashes.each do |hash|
        has_trait = hash.keys.include?(:trait)
        hash.merge!(hash[:trait]) if has_trait
        hash[:resource_id] =
          if hash[:resource]
            if hash[:resource].is_a?(Array)
              hash[:resource].first[:resource_id]
            else
              hash[:resource][:resource_id]
            end
          else
            "MISSING"
          end

        if hash[:predicate].is_a?(Array)
          TraitBank::Logger.log_error("Trait {#{hash[:trait][:resource_pk]}} from resource #{hash[:resource_id]} has "\
            "#{hash[:predicate].size} predicates")
          hash[:predicate] = hash[:predicate].first
        end

        hash[:object_page_id] ||= hash.dig(:object_page, :page_id)

        # TODO: extract method
        if hash.has_key?(:meta)
          raise "Metadata not returned as an array" unless hash[:meta].is_a?(Array)
          length = hash[:meta].size
          raise "Missing meta column meta_predicate: #{hash.keys}" unless hash.has_key?(:meta_predicate)
          %i[meta_predicate meta_units_term meta_object_term meta_sex_term meta_lifestage_term meta_statistical_method_term].each do |col|
            next unless hash.has_key?(col)
            raise ":#{col} data was not the same size as :meta" unless hash[col].size == length
          end

          process_hash_metadata(hash)
        end
        if has_trait
          hash[:id] = hash[:trait][:eol_pk]
        end
        hashes = replicate_trait_hash_for_pages(hash)
        data = data + hashes
      end
      TraitBank::Logger.log("RESULT COUNT #{key}: #{data.length} after build_trait_array") if key
      data
    end

    def process_hash_metadata(hash)
      grouped_value_metas = {}

      hash[:meta].compact!
      hash[:metadata] = []

      unless hash[:meta].empty?
        hash[:meta].each_with_index do |meta, i|
          m_hash = meta
          m_hash[:predicate] = hash[:meta_predicate] && hash[:meta_predicate][i]
          m_hash[:object_term] = hash[:meta_object_term] && hash[:meta_object_term][i]
          m_hash[:sex_term] = hash[:meta_sex_term] && hash[:meta_sex_term][i]
          m_hash[:lifestage_term] = hash[:meta_lifestage_term] && hash[:meta_lifestage_term][i]
          m_hash[:statistical_method_term] = hash[:meta_statistical_method_term] && hash[:meta_statistical_method_term][i]
          m_hash[:units] = hash[:meta_units_term] && hash[:meta_units_term][i]

          uri = m_hash[:predicate]&.[](:uri)
          if GROUP_META_VALUE_URIS.include?(uri)
            if grouped_value_metas[uri].nil?
              m_hash[:combined_measurements] = []
              grouped_value_metas[uri] = m_hash
            end

            measurement = m_hash[:measurement]

            if measurement
              grouped_value_metas[uri][:combined_measurements] << measurement
            end
          else
            hash[:metadata] << m_hash
          end
        end

        grouped_value_metas.each do |_, meta|
          hash[:metadata] << meta
        end
      end
    end

    def replicate_trait_hash_for_pages(hash)
      return [hash] if !hash[:page]

      if !hash[:page]
        hashes = [hash]
      elsif hash[:page].is_a?(Array)
        hashes = hash[:page].collect do |page|
          copy = hash.dup
          copy[:page_id] = page[:page_id]
          copy
        end
      else
        hash[:page_id] = hash[:page][:page_id]
        hashes = [hash]
      end

      hashes
    end
  end
end

