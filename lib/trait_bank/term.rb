# q.v.:
module TraitBank
  # Handles all of the methods specific to a :Term node.
  module Term
    TERM_RELATIONSHIP_PROPERTIES = {
      'parent_uris' => 'parent_term',
      'synonym_of_uri' => 'synonym_of',
      'units_term_uri' => 'units_term',
      'object_for_predicate_uri' => 'object_for_predicate',
      'inverse_of_uri' => 'inverse_of'
    }.freeze
    PAGE_RELATIONSHIP_PROPERTIES = {
      'exclusive_to_clade_id' => 'exclusive_to_clade',
      'incompatible_with_clade_id' => 'incompatible_with_clade'
    }.freeze
    ALL_RELATIONSHIP_PROPERTIES = TERM_RELATIONSHIP_PROPERTIES.merge(PAGE_RELATIONSHIP_PROPERTIES).freeze

    CACHE_EXPIRATION_TIME = 1.week # We'll have a post-import job refresh this as needed, too.
    TERM_TYPES = {
      predicate: ['measurement', 'association'],
      object_term: ['value']
    }.freeze
    DEFAULT_GLOSSARY_PAGE_SIZE = Rails.configuration.data_glossary_page_size
    UNIQUE_URI_PART_CAPTURE_REGEX = /https?:\/\/eol\.org\/schema\/terms\/(.*)/

    class << self
      delegate :reindex, to: TermNode
      
      # TODO: I don't think these three different "get" methods are really needed. Sort them out. :|
      def term_as_hash(uri)
        return nil if uri.nil? # Important for param-management!
        hash = term(uri)
        raise ActiveRecord::RecordNotFound if hash.nil?
        hash.symbolize_keys
      end
      alias_method :as_hash, :term_as_hash

      # Raises ActiveRecord::RecordNotFound if uri is invalid
      def term_record(uri)
        result = term(uri)
        result&.[]("data")&.symbolize_keys
      end
      alias_method :as_record, :term_record

      # This version returns an "empty" term hash if there is no URI.
      # This version caches results for efficiency.
      def term(uri)
        return { name: '', uri: '' } if uri.blank?
        @terms ||= {}
        return @terms[uri] if @terms.key?(uri)
        res = TraitBank.query(%Q{MATCH (term:Term { uri: "#{uri.gsub(/"/, '\"')}" }) RETURN term})
        return nil unless res && res["data"] && res["data"].first
        @terms[uri] = res["data"].first.first
      end
      alias_method :by_uri, :term

      # This method will detect existing Terms and either return the existing term or, if the :force option is set, update the
      # Term instead.
      def create(possibly_frozen_properties)
        properties = possibly_frozen_properties.dup
        force = properties.delete(:force)
        properties = properties.transform_keys(&:to_s)
        raise 'Cannot create a term without a URI' unless properties['uri']
        existing_term = TermNode.where(uri: properties['uri'])&.first
        return existing_term if existing_term && !force

        return update_existing(existing_term, properties) if existing_term

        create_new(properties)
      end

      # This method assumes you have an existing term object that you pulled from neo4j. Use #update if you just have a hash.
      def update_existing(existing_term, properties)
        clean_properties(properties)
        uri = properties.delete('uri') # We already have this.
        begin
          update_relationships(uri, properties)
          existing_term.update!(properties)
        rescue => e # rubocop:disable Style/RescueStandardError
          # This method is typically run as part of a script, so I'm just using STDOUT here:
          puts "ERROR: failed to update term #{properties['uri']}"
          puts "EXISTING: #{existing_term.inspect}"
          puts "DESIRED: #{properties.inspect}"
          puts "You will need to fix this manually. Make note!"
        end
        existing_term
      end

      # This method takes a hash as its argument. If you have a TermNode already, use #update_existing
      # This method will only update fields that are passed in. Other fields will keep their existing values.
      def update(possibly_frozen_properties)
        properties = possibly_frozen_properties.dup.transform_keys(&:to_s)
        raise 'Cannot update a term without a URI.' unless properties['uri']
        term_node = TermNode.find_by(uri: properties['uri'])
        update_existing(term_node, properties)
      end

      def update_relationships(uri, properties)
        TERM_RELATIONSHIP_PROPERTIES.each do |property, name|
          if target_uris = properties.delete(property)
            remove_relationships(uri, name)
            Array(target_uris).each do |target_uri|
              add_relationship(uri, name, target_uri)
            end
          end
        end

        PAGE_RELATIONSHIP_PROPERTIES.each do |property, name|
          if target_page_id = properties.delete(property)
            remove_relationships(uri, name)
            add_page_relationship(uri, name, target_page_id)
          end
        end
      end

      def remove_relationships(uri, name)
        TraitBank.query(%{
          MATCH (term:Term { uri: "#{uri.gsub(/"/, '\"')}"})-[rel:#{name}]->()
          DETACH DELETE rel
        })
      end

      def add_relationship(source_uri, name, target_uri)
        TraitBank.query(%{MATCH (term:Term { uri: "#{source_uri.gsub(/"/, '\"')}" }),
                          (target:Term { uri: "#{target_uri.gsub(/"/, '\"')}" })
                          CREATE (term)-[:#{name}]->(target) })
      end

      def add_page_relationship(source_uri, name, target_page_id)
        TraitBank.query(
          <<~CYPHER
            MATCH (term:Term { uri: "#{source_uri.gsub(/"/, '\"')}" }),
            (page:Page { page_id: #{target_page_id.to_i} })
            CREATE (term)-[:#{name}]->(page)
          CYPHER
        )
      end

      def clean_properties(properties)
        properties['definition'] = if properties['definition'].nil?
          ''
        else
          properties['definition'].dup.gsub(/\^(\d+)/, "<sup>\\1</sup>")
        end
        set_boolean_properties(properties)
        set_nil_properties_to_blank(properties)
      end

      def set_boolean_properties(properties)
        properties.each do |key|
          next unless key.to_s =~ /^is_/
          properties[key] = treat_property_as_true?(properties, key) ? true : false
        end
      end

      def treat_property_as_true?(properties, key)
        return false unless properties.key?(key) && properties[key]
        return false if properties[key].blank?
        !(properties[key].to_s.downcase == 'false')
      end

      def remove_relationship_properties(properties)
        removed = {}
        ALL_RELATIONSHIP_PROPERTIES.keys.each do |property|
          removed[property] = properties.delete(property) if properties.key?(property)
        end
        removed
      end

      def create_new(properties)
        removed = remove_relationship_properties(properties)
        term_node = TermNode.create!(properties)
        update_relationships(properties['uri'], removed) unless removed.blank?
        increment_terms_count_cache
        term_node
      end

      def increment_terms_count_cache
        count = Rails.cache.read('trait_bank/terms_count') || 0
        Rails.cache.write('trait_bank/terms_count', count + 1)
      end

      def set_nil_properties_to_blank(hash)
        bad_keys = [] # Never modify a hash as you iterate over it.
        hash.each { |key, val| bad_keys << key if val.nil? }
        # NOTE: removing the key entirely would just skip updating it; we want the value to be empty.
        bad_keys.each { |key| hash[key] = '' }
        hash
      end

      def delete(uri)
        TraitBank.query(%Q{MATCH (term:Term { uri: "#{uri.gsub(/"/, '\"')}"}) DETACH DELETE term})
      end

      # NOTE: unused method; this is meant for debugging.
      def yamlized_term(uri)
        add_yml_fields(yamlize_keys(term(uri)))
      end

      def yamlize_keys(term)
        hash = term.stringify_keys
        new_hash = {}
        EolTerms.valid_fields.each { |param| new_hash[param] = hash[param] if hash.key?(param) }
        new_hash
      end

      # NOTE: Very slow.
      def add_yml_fields(term)
        term['parent_uris'] = Array(parents_of_term(term['uri'])).sort
        term['synonym_of_uri'] = synonym_of_term(term['uri'])
        term['units_term_uri'] = units_for_term(term['uri'])
        term['is_hidden_from_select'] = should_hide_from_select?(term)
        term['alias'] ||= ''
        # Populate *all* fields, just for consistency:
        EolTerms.valid_fields.each do |field|
          term[field] ||= field =~ /^is_/ ? false : nil
        end
        term
      end

      def should_hide_from_select?(term)
        return true if !term['synonym_of_uri'].nil? # hide, if there are any synonym terms
        false
      end

      def descendants_of_term(uri)
        terms = TraitBank.query(%Q{MATCH (term:Term)-[:parent_term|:synonym_of*]->(:Term { uri: "#{uri.gsub(/"/, '\"')}" })
                         RETURN DISTINCT term})
        terms["data"].map { |r| r.first["data"] }
      end

      def term_member_of(uri)
        terms = TraitBank.query(%Q{MATCH (:Term { uri: "#{uri.gsub(/"/, '\"')}" })-[:parent_term|:synonym_of*]->(term:Term) RETURN term})
        terms["data"].map { |r| r.first }
      end

      # TODO: extract a Predicate class. There's a lot here and that's a logic way to break this up.

      # Keep checking the following methods for use in the codebase:
      def obj_terms_for_pred(predicate, orig_qterm = nil)
        qterm = orig_qterm.delete('"').downcase.strip
        Rails.cache.fetch("trait_bank/obj_terms_for_pred/#{I18n.locale}/#{predicate.uri}/#{qterm}",
                          expires_in: CACHE_EXPIRATION_TIME) do
          name_field = Util::I18nUtil.term_name_property
          q = %Q{MATCH (object:Term { type: 'value',
                 is_hidden_from_select: false })-[:object_for_predicate]->(:Term{ uri: '#{predicate.uri}' })}
          q += "\nWHERE #{term_name_prefix_match("object", qterm)}" if qterm
          q +=  "\nRETURN object ORDER BY object.position LIMIT #{DEFAULT_GLOSSARY_PAGE_SIZE}"
          res = TraitBank.query(q)
          res["data"] ? res["data"].map do |t|
            hash = t.first["data"].symbolize_keys
            hash[:name] = hash[:"#{name_field}"]
            hash[:id] = hash[:eol_id]
            hash
          end : []
        end
      end

      def any_obj_terms_for_pred?(pred)
        Rails.cache.fetch("trait_bank/pred_has_object_terms_2_checks/#{pred}", expires_in: CACHE_EXPIRATION_TIME) do
          TraitBank.query(
            %{MATCH (term:Term)<-[:object_term]-(:Trait)-[:predicate]->(:Term)<-[:synonym_of|:parent_term*0..]-(:Term
              { uri: '#{pred}'}) RETURN term.uri LIMIT 1}
          )["data"].any? ||
          TraitBank.query(
            %{MATCH (term:Term)<-[:object_term]-(:Trait)-[:predicate]->(:Term)-[:synonym_of|:parent_term*0..]->(:Term
              { uri: '#{pred}'}) RETURN term.uri LIMIT 1}
          )["data"].any?
        end
      end

      # NOTE the order of args, here.
      def set_units_for_pred(units_uri, pred_uri)
        if units_uri =~ /^u/ # 'unitless', a secret code for "this is an ordinal measurement (and has no units)"
          TraitBank.query(%{MATCH (predicate:Term { uri: "#{pred_uri}" }) SET predicate.is_ordinal = true})
        else
          TraitBank.query(%{MATCH (predicate:Term { uri: "#{pred_uri}" }), (units_term:Term { uri: "#{units_uri}"})
            CREATE (predicate)-[:units_term]->(units_term)})
        end
      end

      def units_for_pred(pred_uri)
        key = "trait_bank/normal_unit_for_pred/#{pred_uri}"

        Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          ordinal = TraitBank.query(%{
            MATCH (predicate:Term { uri: "#{pred_uri}", is_ordinal: true }) RETURN predicate LIMIT 1
          })["data"].any?
          if ordinal
            :ordinal
          else
            res = TraitBank.query(%{
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
          res = TraitBank.query(%{
            MATCH (t:Trait)-[:predicate]->(:Term{uri: "#{uri.gsub(/"/, '""')}"})
            RETURN t LIMIT 1
          })["data"]
          res.any?
        end
      end

      def parents_of_term(term_uri)
        result = TraitBank.query(%Q(
          MATCH (:Term{ uri: "#{term_uri}" })-[:parent_term]->(parent:Term)
          RETURN DISTINCT parent.uri
        ))
        return nil unless result&.key?('data') && !result['data'].empty? && !result['data'].first.empty?
        result['data'].flatten
      end

      # NOTE: forces a limit of one (or nil, if none)
      def synonym_of_term(term_uri)
        result = TraitBank.query(%Q(
          MATCH (:Term{ uri: "#{term_uri}" })-[:synonym_of]->(parent:Term)
          RETURN parent.uri
          LIMIT 1
        ))
        return nil unless result&.key?('data') && !result['data'].empty? && !result['data'].first.empty?
        result['data'].first.first
      end

      # NOTE: forces a limit of one (or nil, if none)
      def units_for_term(term_uri)
        result = TraitBank.query(%Q(
          MATCH (:Term{ uri: "#{term_uri}" })-[:units_term]->(unts_term:Term)
          RETURN unts_term.uri
          LIMIT 1
        ))
        return nil unless result&.key?('data') && !result['data'].empty? && !result['data'].first.empty?
        result['data'].first.first
      end

      def term_descendant_of_other?(term_uri, other_uri)
        result = TraitBank.query(%Q(
          MATCH p=(:Term{ uri: "#{term_uri}" })-[:parent_term*1..]->(:Term{ uri: "#{other_uri}" })
          RETURN p
          LIMIT 1
        ))

        result["data"].any?
      end

      def count(options = {})
        hidden = options[:include_hidden]
        key = "trait_bank/terms_count"
        key += "/include_hidden" if hidden
        Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          res = TraitBank.query(
            "MATCH (term:Term#{hidden ? '' : ' { is_hidden_from_glossary: false }'}) "\
            "WITH count(distinct(term.uri)) AS count "\
            "RETURN count"
          )
          res && res["data"] ? res["data"].first.first : false
        end
      end

      def full_glossary(page = 1, per = nil, options = {})
        options ||= {} # callers may pass nil, bypassing the default
        page ||= 1
        per ||= Rails.configuration.data_glossary_page_size
        hidden = options[:include_hidden]
        key = "trait_bank/full_glossary/#{page}"
        key += "/include_hidden" if hidden
        Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          q = "MATCH (term:Term#{hidden ? '' : ' { is_hidden_from_glossary: false }'}) "\
            "RETURN DISTINCT(term) ORDER BY toLower(term.name), toLower(term.uri)"
          q += TraitBank::Queries.limit_and_skip_clause(page, per)
          res = TraitBank.query(q)
          res["data"] ? res["data"].map { |t| t.first["data"].symbolize_keys } : false
        end
      end

      # XXX: "0-9" is considered a letter, and gets all terms that start with a digit. Everything else is an actual letter.
      def glossary_for_letter(letter, options = {})
        raise "invalid letter argument" if !letters_for_glossary.include?(letter)

        key = "trait_bank/glossary_for_letter/#{letter}"
        Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          where = if letter == "0-9"
                    "term.name =~ '[0-9].*'"
                  else
                    "substring(toLower(term.name), 0, 1) = '#{letter}'"
                  end

          q = "MATCH (term:Term{ is_hidden_from_glossary: false }) "\
              "WHERE #{where} "\
              "RETURN term "\
              "ORDER BY toLower(term.name), toLower(term.uri)"
          res = TraitBank.query(q)
          res["data"] ? res["data"].map { |t| t.first.symbolize_keys } : false
        end
      end

      def letters_for_glossary
        Rails.cache.fetch("trait_bank/letters_for_glossary", expires_in: CACHE_EXPIRATION_TIME) do
          q = "MATCH (term:Term{ is_hidden_from_glossary: false })\n"\
              "WITH substring(toLower(term.name), 0, 1) AS letter\n"\
              "RETURN DISTINCT letter\n"\
              "ORDER BY letter"
          res = TraitBank.query(q)
          res["data"] ? res["data"].map { |item| item.first } : false
        end
      end

      def letter_for_term(term)
        name = if term[:name]
                 term[:name]
               else
                 UNIQUE_URI_PART_CAPTURE_REGEX.match(term[:uri])&.[](1)
               end

        name&.downcase&.[](0)
      end

      def sub_glossary(type, page = 1, per = nil, options = {})
        count = options[:count]
        qterm = options[:qterm]
        for_select = options[:for_select]
        page ||= 1
        per ||= DEFAULT_GLOSSARY_PAGE_SIZE
        key = "trait_bank/#{type}_glossary/#{I18n.locale}/#{count ? :count : "#{page}/#{per}"}/"\
          "for_select_#{for_select ? 1 : 0}/#{qterm ? qterm : :full}"
        TraitBank::Logger.log("KK TraitBank key: #{key}")
        name_field = Util::I18nUtil.term_name_property
        Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          q = 'MATCH (term:Term'
          # NOTE: UUUUUUGGGGGGH.  This is suuuuuuuper-ugly. Alas... we don't have a nice query-builder.
          q += ' { is_hidden_from_glossary: false }' unless qterm
          q += ')'
          q += "<-[:#{type}]-(n) " if type == 'units_term'
          q += " WHERE " if qterm || TERM_TYPES.key?(type)
          q +=  term_name_prefix_match("term", qterm) if qterm
          q += " AND " if qterm && TERM_TYPES.key?(type)
          q += %{term.type IN ["#{TERM_TYPES[type].join('","')}"]} if TERM_TYPES.key?(type)
          if for_select
            q += qterm ? " AND" : " WHERE"
            q += " term.is_hidden_from_select = false "
          end
          if count
            q += "WITH COUNT(DISTINCT(term.uri)) AS count RETURN count"
          else
            q += "RETURN DISTINCT(term) ORDER BY toLower(term.#{name_field}), toLower(term.uri)"
            q += TraitBank::Queries.limit_and_skip_clause(page, per)
          end
          res = TraitBank.query(q)
          if res["data"]
            if count
              res["data"].first.first
            else
              all = res["data"].map { |t| t.first["data"].symbolize_keys }
              all.map! { |h| { name: h[:"#{name_field}"], uri: h[:uri], id: h[:eol_id] } } if qterm
              all
            end
          else
            false
          end
        end
      end

      def top_level(type)
        types = TERM_TYPES[type]
        raise TypeError.new("invalid type argument") if types.nil?

        q = "MATCH (term:Term) "\
            "WHERE NOT (term)-[:parent_term]->(:Term) "\
            "AND NOT (term)-[:synonym_of]->(:Term) "\
            "AND term.is_hidden_from_overview = false "\
            "AND term.type IN #{TraitBank::Queries.array_to_qs(types)} "\
            "RETURN term "\
            "ORDER BY toLower(term.#{Util::I18nUtil.term_name_property}), term.uri"

        term_query(q)
      end

      def children(uri)
        q = "MATCH (term:Term)-[:parent_term]->(:Term{ uri:'#{uri}' }) "\
            "WHERE NOT (term)-[:synonym_of]->(:Term) "\
            "RETURN term "\
            "ORDER BY toLower(term.#{Util::I18nUtil.term_name_property}), term.uri"
        term_query(q)
      end

      def term_query(q)
        res = TraitBank.query(q)
        all = res["data"].map { |t| t.first["data"].symbolize_keys }
        all.map! { |h| { name: h[:"#{Util::I18nUtil.term_name_property}"], uri: h[:uri], id: h[:eol_id] } }
        all
      end

      def predicate_glossary(page = nil, per = nil, options = {})
        sub_glossary(:predicate, page, per, options)
      end

      def name_for_pred_uri(uri)
        key = "trait_bank/predicate_uris_to_names/#{uri}"
        map = Rails.cache.fetch(key, :expires_in => CACHE_EXPIRATION_TIME) do
          predicate_glossary(1, 10_000).map { |item| [item[:uri], item[:name]] }.to_h
        end

        map[uri]
      end

      def name_for_uri(uri)
        return '' if uri.blank?
        Rails.cache.fetch("trait_bank/name_for_uri/#{uri}", :expires_in => CACHE_EXPIRATION_TIME) do
          res = term(uri)
          name =
            if res&.key?('data')
              if res['data']&.key?('name')
                res['data']['name']
              end
            end
          name || uri.split('/').last # Some of these end up gobbledigook, but ... hey.
        end
      end

      def name_for_obj_uri(uri)
        key = "trait_bank/name_for_obj_uri/#{uri}"
        map = Rails.cache.fetch(key, :expires_in => CACHE_EXPIRATION_TIME) do
          object_term_glossary(1, 10_000).map { |item| [item[:uri], item[:name]] }.to_h
        end

        map[uri]
      end

      def name_for_units_uri(uri)
        key = "trait_bank/name_for_units_uri/#{uri}"
        map = Rails.cache.fetch(key, :expires_in => CACHE_EXPIRATION_TIME) do
          units_glossary(1, 10_000).map { |item| [item[:uri], item[:name]] }.to_h
        end
        map[uri]
      end

      def object_term_glossary(page = nil, per = nil, options = {})
        sub_glossary(:object_term, page, per, options)
      end

      def units_glossary(page = nil, per = nil, options = {})
        sub_glossary(:units_term, page, per, options)
      end

      def predicate_glossary_count
        sub_glossary(:predicate, nil, nil, count: true)
      end

      def object_term_glossary_count
        sub_glossary(:object_term, nil, nil, count: true)
      end

      def units_glossary_count
        sub_glossary(:units_term, nil, nil, count: true)
      end

      # NOTE: I removed the units from this query after ea27411f8110b74 (q.v.)
      def page_glossary(page_id)
        q = "MATCH (page:Page { page_id: #{page_id} })-[#{TraitBank::TRAIT_RELS}]->(trait:Trait) "\
          "MATCH (trait:Trait)-[:predicate]->(predicate:Term) "\
          "OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term) "\
          "RETURN predicate, object_term"
        res = query(q)
        uris = {}
        res["data"].each do |row|
          row.each do |col|
            uris[col["data"]["uri"]] ||= col["data"].symbolize_keys if col&.dig("data", "uri")
          end
        end
        uris
      end

      private
      def term_name_prefix_match(label, qterm)
        "toLower(#{label}.#{Util::I18nUtil.term_name_property}) =~ \"#{qterm.delete('"').downcase}.*\" "
      end
    end
  end
end
