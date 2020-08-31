# q.v.:
class TraitBank
  # Handles all of the methods specific to a :Term node.
  module Term
    class << self
      BOOLEAN_PROPERTIES =
        %w[is_text_only is_hidden_from_select is_hidden_from_overview is_hidden_from_glossary is_verbatim_only].freeze

      # This method will detect existing Terms and either return the existing term or, if the :force option is set, update the
      # Term instead.
      def create(properties)
        properties = properties.transform_keys(&:to_s)
        raise 'Cannot create a term without a URI' unless properties['uri']
        existing_term = term(properties['uri'])
        return existing_term if existing_term && !properties.delete(:force)

        clean_properties(properties)
        return update_existing(existing_term, properties) if existing_term

        create_new(properties)
      end

      # This method assumes you have an existing term object that you pulled from neo4j. Use #update if you just have a hash.
      def update_existing(existing_term, properties)
        properties.delete('uri') # We already have this.
        begin
          connection.set_node_properties(existing_term, properties) # Cypher is alergic to nils.
        rescue => e # rubocop:disable Style/RescueStandardError
          # This method is typically run as part of a script, so I'm just using STDOUT here:
          puts "ERROR: failed to update term #{properties['uri']}"
          puts "EXISTING: #{existing_term.inspect}"
          puts "DESIRED: #{properties.inspect}"
          puts "You will need to fix this manually. Make note!"
        end
        existing_term
      end

      # This method takes a hash as its argument. If you pulled a term from neo4j, use #update_existing
      # This method will only update fields that are passed in. Other fields will keep their existing values.
      # On success, this always returns a hash with *symbolized* keys.
      def update(properties)
        properties = properties.transform_keys(&:to_s)
        raise 'Cannot update a term without a URI.' unless properties['uri']
        clean_properties(properties)
        res = query(query_for_update(properties))
        raise ActiveRecord::RecordNotFound if res.nil?
        res['data'].first.first.symbolize_keys
      end

      def query_for_update(properties)
        sets = []
        sets += properties.map do |property|
          if BOOLEAN_PROPERTIES.include?(property) # Booleans are handled separately.
            "term.#{field} = #{properties[field] ? 'true' : 'false'}"
          else
            "term.#{property} = '#{properties[property].gsub("'", "''")}'"
          end
        end
        "MATCH (term:Term { uri: '#{properties['uri']}' }) SET #{sets.join(', ')} RETURN term"
      end

      def clean_properties(properties)
        properties.delete('section_ids') # Vestigial, do not allow anymore.
        properties['definition'] ||= "{definition missing}"
        properties['definition'].gsub!(/\^(\d+)/, "<sup>\\1</sup>")
        set_boolean_properties(properties)
        set_nil_properties_to_blank(properties)
      end

      def set_boolean_properties(properties)
        BOOLEAN_PROPERTIES.each do |key|
          properties[key] = treat_property_as_true?(properties, key) ? true : false
        end
      end

      def treat_property_as_true?(properties, key)
        properties.key?(key) && properties[key] && !properties[key].to_s.downcase == 'false'
      end

      def create_new(properties)
        term_node = connection.create_node(properties)
        # ^ I got a "Could not set property "uri", class Neography::PropertyValueException here.
        connection.set_label(term_node, "Term")
        # ^ I got a Neography::BadInputException here saying I couldn't add a label. In that case, the URI included
        # UTF-8 chars, so I think I fixed it by causing all URIs to be escaped...
        count = Rails.cache.read("trait_bank/terms_count") || 0
        Rails.cache.write("trait_bank/terms_count", count + 1)
        term_node
      end

      def set_nil_properties_to_blank(hash)
        bad_keys = [] # Never modify a hash as you iterate over it.
        hash.each { |key, val| bad_keys << key if val.nil? }
        # NOTE: removing the key entirely would just skip updating it; we want the value to be empty.
        bad_keys.each { |key| hash[key] = '' }
        hash
      end

      # TODO: I think we need a TraitBank::Term::Relationship class with these in it! Argh!

      # TODO: SOMEONE ONE SHOULD MOVE THIS TO TraitBank::Term (new class)!
      def child_has_parent(curi, puri)
        cterm = term(curi)
        pterm = term(puri)
        raise "missing child" if cterm.nil?
        raise "missing parent" if pterm.nil?
        child_term_has_parent_term(cterm, pterm)
      end

      # TODO: SOMEONE ONE SHOULD MOVE THIS TO TraitBank::Term (new class)!
      def is_synonym_of(curi, puri)
        cterm = term(curi)
        pterm = term(puri)
        raise "missing synonym" if cterm.nil?
        raise "missing source of synonym" if pterm.nil?
        relate(:synonym_of, cterm, pterm)
      end

      # TODO: SOMEONE ONE SHOULD MOVE THIS TO TraitBank::Term (new class)!
      def child_term_has_parent_term(cterm, pterm)
        relate(:parent_term, cterm, pterm)
      end

      # TODO: SOMEONE ONE SHOULD MOVE THIS TO TraitBank::Term (new class)!
      def term_as_hash(uri)
        return nil if uri.nil? # Important for param-management!
        hash = term(uri)
        raise ActiveRecord::RecordNotFound if hash.nil?
        hash.symbolize_keys
      end

      # TODO: SOMEONE ONE SHOULD MOVE THIS TO TraitBank::Term (new class)!
      # Raises ActiveRecord::RecordNotFound if uri is invalid
      def term_record(uri)
        result = term(uri)
        result&.[]("data")&.symbolize_keys
      end

      # TODO: SOMEONE ONE SHOULD MOVE THIS TO TraitBank::Term (new class)!
      # This version returns an "empty" term hash if there is no URI.
      # This version caches results for efficiency.
      def term(uri)
        return { name: '', uri: '' } if uri.blank?
        @terms ||= {}
        return @terms[uri] if @terms.key?(uri)
        res = query(%Q{MATCH (term:Term { uri: "#{uri.gsub(/"/, '""')}" }) RETURN term})
        return nil unless res && res["data"] && res["data"].first
        @terms[uri] = res["data"].first.first
      end

      # TODO: SOMEONE ONE SHOULD MOVE THIS TO TraitBank::Term (new class)!
      def descendants_of_term(uri)
        terms = query(%{MATCH (term:Term)-[:parent_term|:synonym_of*]->(:Term { uri: "#{uri}" }) RETURN DISTINCT term})
        terms["data"].map { |r| r.first["data"] }
      end

      # TODO: SOMEONE ONE SHOULD MOVE THIS TO TraitBank::Term (new class)!
      def term_member_of(uri)
        terms = query(%{MATCH (:Term { uri: "#{uri}" })-[:parent_term|:synonym_of*]->(term:Term) RETURN term})
        terms["data"].map { |r| r.first }
      end

      # TODO: extract a Predicate class. There's a lot here and that's a logic way to break this up.

      # Keep checking the following methods for use in the codebase:
      def obj_terms_for_pred(pred_uri, orig_qterm = nil)
        qterm = orig_qterm.delete('"').downcase.strip
        Rails.cache.fetch("trait_bank/obj_terms_for_pred/#{I18n.locale}/#{pred_uri}/#{qterm}", expires_in: CACHE_EXPIRATION_TIME) do
          name_field = Util::I18nUtil.term_name_property
          q = "MATCH (object:Term { type: 'value', is_hidden_from_select: false })-[:object_for_predicate]->(:Term{ uri: '#{pred_uri}' })"
          q += "\nWHERE #{term_name_prefix_match("object", qterm)}" if qterm
          q +=  "\nRETURN object ORDER BY object.position LIMIT #{DEFAULT_GLOSSARY_PAGE_SIZE}"
          res = query(q)
          res["data"] ? res["data"].map do |t|
            hash = t.first["data"].symbolize_keys
            hash[:name] = hash[:"#{name_field}"]
            hash
          end : []
        end
      end

      def any_obj_terms_for_pred?(pred)
        Rails.cache.fetch("trait_bank/pred_has_object_terms_2_checks/#{pred}", expires_in: CACHE_EXPIRATION_TIME) do
          query(
            %{MATCH (term:Term)<-[:object_term]-(:Trait)-[:predicate]->(:Term)<-[:synonym_of|:parent_term*0..]-(:Term { uri: '#{pred}'}) RETURN term.uri LIMIT 1}
          )["data"].any? ||
          query(
            %{MATCH (term:Term)<-[:object_term]-(:Trait)-[:predicate]->(:Term)-[:synonym_of|:parent_term*0..]->(:Term { uri: '#{pred}'}) RETURN term.uri LIMIT 1}
          )["data"].any?
        end
      end

      # NOTE the order of args, here.
      def set_units_for_pred(units_uri, pred_uri)
        if units_uri =~ /^u/ # 'unitless', a secret code for "this is an ordinal measurement (and has no units)"
          query(%{MATCH (predicate:Term { uri: "#{pred_uri}" }) SET predicate.is_ordinal = true})
        else
          query(%{MATCH (predicate:Term { uri: "#{pred_uri}" }), (units_term:Term { uri: "#{units_uri}"})
            CREATE (predicate)-[:units_term]->(units_term)})
        end
      end

      def units_for_pred(pred_uri)
        key = "trait_bank/normal_unit_for_pred/#{pred_uri}"

        Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          ordinal = query(%{
            MATCH (predicate:Term { uri: "#{pred_uri}", is_ordinal: true }) RETURN predicate LIMIT 1
          })["data"].any?
          if ordinal
            :ordinal
          else
            res = query(%{
              MATCH (predicate:Term { uri: "#{pred_uri}" })-[:units_term]->(units_term:Term)
              RETURN units_term.name, units_term.uri LIMIT 1
            })["data"]
            if (result = res&.first)
              (name, uri) = result
              { units_name: name, units_uri: uri, normal_units_name: name, normal_units_uri: uri }
            else
              nil
            end
          end
        end
      end

      def any_direct_records_for_pred?(uri)
        key = "trait_bank/any_direct_records_for_pred?/#{uri}"
        Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          res = query(%{
            MATCH (t:Trait)-[:predicate]->(:Term{uri: '#{uri}'})
            RETURN t LIMIT 1
          })["data"]
          res.any?
        end
      end

      def parent_of_term(term_uri)
        result = query(%Q(
          MATCH (:Term{ uri: "#{term_uri}" })-[:parent_term]->(parent:Term)
          RETURN parent.uri
          LIMIT 1
        ))
        return nil unless result&.key?('data') && !result['data'].empty? && !result['data'].first.empty?
        result['data'].first.first
      end

      def synonym_of_term(term_uri)
        result = query(%Q(
          MATCH (:Term{ uri: "#{term_uri}" })-[:synonym_of]->(parent:Term)
          RETURN parent.uri
          LIMIT 1
        ))
        return nil unless result&.key?('data') && !result['data'].empty? && !result['data'].first.empty?
        result['data'].first.first
      end

      def term_descendant_of_other?(term_uri, other_uri)
        result = query(%Q(
          MATCH p=(:Term{ uri: "#{term_uri}" })-[:parent_term*1..]->(:Term{ uri: "#{other_uri}" })
          RETURN p
          LIMIT 1
        ))

        result["data"].any?
      end

      private
      def term_name_prefix_match(label, qterm)
        "LOWER(#{label}.#{Util::I18nUtil.term_name_property}) =~ \"#{qterm.delete(/"/).downcase}.*\" "
      end
    end
  end
end
