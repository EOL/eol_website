module TraitBank
  module Page
    class << self
      include TraitBank::Constants
      delegate :query, to: TraitBank

      def grouped_traits_for_page(page, options = {})
        raise TypeError, "must include limit or selected_predicate option" unless options[:limit] || options[:selected_predicate]

        subj_trait_pks_by_group = subj_trait_pks_for_page(page.page_node, options)
        obj_trait_pks_by_group = obj_trait_pks_for_page(page.page_node, options)
        subj_trait_pks = extract_grouped_trait_pks(subj_trait_pks_by_group)
        obj_trait_pks = extract_grouped_trait_pks(obj_trait_pks_by_group)
        all_trait_pks = (subj_trait_pks + obj_trait_pks).uniq
        all_traits = Trait.for_eol_pks(all_trait_pks)
        all_traits_by_id = all_traits.map { |t| [t.id, t] }.to_h

        subj_traits_by_pred = build_traits_by_pred(subj_trait_pks_by_group, all_traits_by_id)
        obj_traits_by_pred = build_traits_by_pred(obj_trait_pks_by_group, all_traits_by_id)
        grouped_traits = subj_traits_by_pred.merge(obj_traits_by_pred)

        { all_traits: all_traits, grouped_traits: grouped_traits }
      end

      def all_page_trait_resource_ids(page_id, options = {})
        key = "trait_bank/all_page_trait_resource_ids/v1/#{page_id}"
        TraitBank::Caching.add_hash_to_key(key, options)

        Rails.cache.fetch(key) do
          res = query(%Q(
            OPTIONAL MATCH (:Page { page_id: #{page_id} })-[#{TRAIT_RELS}]->(trait:Trait)-[:predicate]->(predicate:Term),
            (trait)-[:supplier]->(resource:Resource)
            WITH collect(DISTINCT resource) AS subj_resources
            OPTIONAL MATCH (:Page)-[#{TRAIT_RELS}]-(trait:Trait)-[:predicate]->(predicate:Term),
            (trait)-[:object_page]->(:Page { page_id: #{page_id} }),
            (trait)-[:supplier]->(resource:Resource)
            WITH collect(DISTINCT resource) AS obj_resources, subj_resources
            UNWIND (subj_resources + obj_resources) AS resource
            RETURN DISTINCT resource.resource_id
          ))

          res["data"].flatten
        end
      end

      def page_subj_trait_resource_ids(page_id, options = {})
        key = "trait_bank/page_subj_trait_resource_ids/v1/#{page_id}"
        add_hash_to_key(key, options)

        Rails.cache.fetch(key) do
          res = query(%Q(
            MATCH (:Page { page_id: #{page_id} })-[#{TRAIT_RELS}]->(trait:Trait)-[:predicate]->(predicate:Term)#{predicate_filter_match_part(options)},
            (trait)-[:supplier]->(resource:Resource)
            RETURN DISTINCT resource.resource_id
          ))

          res["data"].flatten
        end
      end

      def page_obj_trait_resource_ids(page_id, options = {})
        key = "trait_bank/page_obj_trait_resource_ids/v1/#{page_id}"
        add_hash_to_key(key, options)

        Rails.cache.fetch(key) do
          res = query(%Q(
            MATCH (:Page)-[#{TRAIT_RELS}]-(trait:Trait)-[:predicate]->(predicate:Term)#{predicate_filter_match_part(options)},
            (trait)-[:object_page]->(:Page { page_id: #{page_id} }),
            (trait)-[:supplier]->(resource:Resource)
            RETURN DISTINCT resource.resource_id
          ))

          res["data"].flatten
        end
      end

      def page_subj_traits_for_pred(page_id, pred_uri, options = {})
        key = "trait_bank/page_subj_traits_for_pred/v2/#{page_id}/#{pred_uri}"
        TraitBank::Caching.add_hash_to_key(key, options)

        Rails.cache.fetch(key) do
          res = query(%Q(
            MATCH (:Page { page_id: #{page_id} })-[#{TRAIT_RELS}]->(trait:Trait)-[:predicate]->(predicate:Term)-[#{PARENT_TERMS}]->(group_predicate:Term{ uri: '#{pred_uri}'}),
            (trait)-[:supplier]->(resource:Resource#{resource_filter_part(options[:resource_id])})
            OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term)
            OPTIONAL MATCH (trait)-[:sex_term]->(sex_term:Term)
            OPTIONAL MATCH (trait)-[:lifestage_term]->(lifestage_term:Term)
            OPTIONAL MATCH (trait)-[:statistical_method_term]->(statistical_method_term:Term)
            OPTIONAL MATCH (trait)-[:units_term]->(units:Term)
            OPTIONAL MATCH (trait)-[:object_page]->(object_page:Page)
            OPTIONAL MATCH #{EXEMPLAR_MATCH}
            RETURN resource, trait, predicate, group_predicate, object_term, object_page, units, sex_term, lifestage_term, statistical_method_term
            ORDER BY #{EXEMPLAR_ORDER}
          ))

          build_trait_array(res)
        end
      end

      def page_obj_traits_for_pred(page_id, pred_uri, options = {})
        key = "trait_bank/all_page_object_traits_for_pred/v2/#{page_id}/#{pred_uri}"
        TraitBank::Caching.add_hash_to_key(key, options)

        Rails.cache.fetch(key) do
          res = query(%Q(
            MATCH (page:Page)-[#{TRAIT_RELS}]->(trait:Trait)-[:predicate]->(predicate:Term)-[#{PARENT_TERMS}]->(group_predicate:Term{ uri: '#{pred_uri}'}),
            (trait)-[:supplier]->(resource:Resource#{resource_filter_part(options[:resource_id])}),
            (trait)-[:object_page]->(object_page:Page { page_id: #{page_id} })
            OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term)
            OPTIONAL MATCH (trait)-[:sex_term]->(sex_term:Term)
            OPTIONAL MATCH (trait)-[:lifestage_term]->(lifestage_term:Term)
            OPTIONAL MATCH (trait)-[:statistical_method_term]->(statistical_method_term:Term)
            OPTIONAL MATCH (trait)-[:units_term]->(units:Term)
            RETURN resource, trait, page, predicate, group_predicate, object_term, object_page, units, sex_term, lifestage_term, statistical_method_term
          ))

          build_trait_array(res)
        end
      end

      def page_trait_groups(page_id, options = {})
        key = "trait_bank/page_trait_groups/v1/#{page_id}"
        TraitBank::Caching.add_hash_to_key(key, options)
        Rails.cache.fetch(key) do
          res = query(%Q(
            OPTIONAL MATCH (:Page { page_id: #{page_id} })-[#{TRAIT_RELS}]->(trait:Trait)-[:predicate]->(:Term)-[#{PARENT_TERMS}]->(group_predicate:Term),
            (trait)-[:supplier]->(resource:Resource#{resource_filter_part(options[:resource_id])})
            WHERE NOT (group_predicate)-[:synonym_of]->(:Term)
            WITH DISTINCT group_predicate
            WITH collect({ group_predicate: group_predicate, page_assoc_role: 'subject' }) AS subj_rows
            OPTIONAL MATCH (:Page)-[#{TRAIT_RELS}]->(trait:Trait)-[:predicate]->(:Term)-[#{PARENT_TERMS}]->(group_predicate:Term),
            (trait)-[:object_page]-(:Page { page_id: #{page_id} }),
            (trait)-[:supplier]->(resource:Resource#{resource_filter_part(options[:resource_id])})
            WHERE NOT (group_predicate)-[:synonym_of]->(:Term)
            WITH DISTINCT group_predicate, subj_rows
            WITH collect({ group_predicate: group_predicate, page_assoc_role: 'object' }) AS obj_rows, subj_rows
            UNWIND (subj_rows + obj_rows) AS row
            WITH row.group_predicate AS group_predicate, row.page_assoc_role AS page_assoc_role
            WHERE group_predicate IS NOT NULL
            RETURN group_predicate, page_assoc_role
          ))

          res["data"].collect { |d| { group_predicate: d[0]["data"].symbolize_keys, page_assoc_role: d[1] } }
        end
      end

      def key_data_pks(page, limit)
        Rails.cache.fetch("trait_bank/key_data_pks/#{page.id}/v2/limit_#{limit}", expires_in: 1.day) do
          # predicate.is_hidden_from_overview <> true seems wrong but I had weird errors with NOT "" on my machine -- mvitale
          page.page_node.query_as(:page)
            .break
            .optional_match("(page)-[#{TRAIT_RELS}]->(trait:Trait)", "(trait)-[:predicate]->(predicate:Term)")
            .where("predicate.is_hidden_from_overview <> true")
            .where('(NOT (trait)-[:object_term]->(:Term) OR (trait)-[:object_term]->(:Term{ is_hidden_from_overview: false }))')
            .break
            .optional_match(EXEMPLAR_MATCH)
            .with(:page, :predicate, :trait, :exemplar_value)
            .order_by('predicate.uri ASC', EXEMPLAR_ORDER)
            .break
            .with(:page, :predicate, 'head(collect({ trait: trait, exemplar_value: exemplar_value })) AS trait_row')
            .break
            .with(:page, "collect({ predicate: predicate, trait: trait_row.trait, exemplar_value: trait_row.exemplar_value }) AS subj_rows")
            .break
            .optional_match("(:Page)-[#{TRAIT_RELS}]->(trait:Trait)-[:object_page]->(page)", '(trait)-[:predicate]->(:Term)<-[:inverse_of]-(predicate:Term)')
            .where('predicate.is_hidden_from_overview <> true')
            .break
            .optional_match(EXEMPLAR_MATCH)
            .with(:subj_rows, :trait, :page, :predicate, :exemplar_value)
            .order_by('predicate.uri ASC', EXEMPLAR_ORDER)
            .break
            .with(:subj_rows, :predicate, 'head(collect({ trait: trait, exemplar_value: exemplar_value })) AS trait_row')
            .break
            .with("(subj_rows + collect({ trait: trait_row.trait, predicate: predicate, exemplar_value: trait_row.exemplar_value })) AS rows")
            .unwind('rows AS row')
            .with('row.trait AS trait', 'row.predicate AS predicate', 'row.exemplar_value AS exemplar_value')
            .where('trait IS NOT NULL')
            .return(:predicate, 'trait.eol_pk AS trait_pk')
            .order(EXEMPLAR_ORDER)
            .limit(limit)
            .to_a
        end
      end

      def count_pages
        q = "MATCH (page:Page) RETURN COUNT(page)"
        res = query(q)
        return [] if res["data"].empty?
        res["data"] ? res["data"].first.first : 0
      end

      def page_exists?(page_id)
        res = query("MATCH (page:Page { page_id: #{page_id} }) RETURN page")
        res["data"] && res["data"].first ? res["data"].first.first : false
      end

      def association_page_ids(page_id)
        Rails.cache.fetch("trait_bank/association_page_ids/#{page_id}", expires_in: 1.day) do
          q = %Q(
            OPTIONAL MATCH (:Page { page_id: #{page_id} })-[#{TRAIT_RELS}]->(trait:Trait), (trait)-[:object_page]->(obj_page:Page)
            WITH collect(DISTINCT obj_page.page_id) AS obj_page_ids
            OPTIONAL MATCH (subj_page:Page)-[#{TRAIT_RELS}]->(trait:Trait), (trait)-[:object_page]->(:Page { page_id: #{page_id} })
            WITH collect(DISTINCT subj_page.page_id) AS subj_page_ids, obj_page_ids
            UNWIND (obj_page_ids + subj_page_ids) AS page_id
            WITH page_id
            WHERE page_id IS NOT NULL
            RETURN DISTINCT page_id
          )
          result = query(q)
          result["data"].flatten
        end
      end

      def object_traits_by_page(page_id, page = 1, per = 2000)
        Rails.cache.fetch("trait_bank/object_traits_by_page/#{page_id}", expires_in: 1.day) do
          q = %Q(
            MATCH (object_page:Page{ page_id: #{page_id} })<-[:object_page]-(trait:Trait),
            (page:Page)-[#{TRAIT_RELS}]->(trait),
            (trait)-[:predicate]->(predicate:Term),
            (trait)-[:supplier]->(resource:Resource)
            WITH trait, page, object_page, predicate, resource
            #{TraitBank::Queries.limit_and_skip_clause(page, per)}
            OPTIONAL MATCH (trait)-[:sex_term]->(sex_term:Term)
            OPTIONAL MATCH (trait)-[:lifestage_term]->(lifestage_term:Term)
            OPTIONAL MATCH (trait)-[:statistical_method_term]->(statistical_method_term:Term)
            OPTIONAL MATCH (trait)-[:units_term]->(units:Term)
            RETURN trait, page, resource, predicate, object_page, units, sex_term, lifestage_term, statistical_method_term
          )

          res = query(q)
          TraitBank::ResultHandling.build_trait_array(res)
        end
      end


      private
      TraitListWithCount = Struct.new(:traits, :count) do 
        def add(other)
          traits.concat(other.traits)
          self.count += other.count
        end
      end

      def build_traits_by_pred(rows, traits_by_id)
        rows.map do |row|
          pred = row[:group_predicate]
          trait_pks = row[:trait_pks]
          count = row[:trait_count]
          traits = trait_pks.map { |pk| traits_by_id[pk] }
          [pred, TraitListWithCount.new(traits, count)]
        end.to_h
      end

      def subj_trait_pks_for_page(page_node, options)
        trait_pks_for_page_helper(
          page_node, 
          '(page)-[:trait|:inferred_trait]->(trait:Trait)', 
          '(predicate)-[:synonym_of*0..]->(group_predicate:Term)',
          :subj,
          options
        )
      end

      def obj_trait_pks_for_page(page_node, options) 
        trait_pks_for_page_helper(
          page_node, 
          '(trait:Trait)-[:object_page]->(page)', 
          '(predicate)<-[:inverse_of]-(group_predicate:Term)',
          :obj,
          options
        )
      end

      def trait_pks_for_page_helper(page_node, trait_match, group_predicate_match, type_for_key, options)
        key = "trait_pks_for_page_helper/v2/#{page_node.id}/#{type_for_key}"
        TraitBank::Caching.add_hash_to_key(key, options)

        Rails.cache.fetch(key) do
          group_limit_str = options[:limit] ? "[0..#{options[:limit]}]" : ''
          collect_pk_str = "collect(DISTINCT trait.eol_pk)#{group_limit_str}"

          if options[:selected_predicate]
            collect_pk_part = "CASE WHEN group_predicate.eol_id = #{options[:selected_predicate].id} THEN  #{collect_pk_str} ELSE [] END AS trait_pks"
          else
            collect_pk_part = "#{collect_pk_str} AS trait_pks"
          end

          query = page_node.query_as(:page)
            .match(trait_match)
            .match('(trait)-[:predicate]->(predicate:Term)')
            .match(group_predicate_match)
            .where_not('(group_predicate)-[:synonym_of]->(:Term)')

          if options[:resource]
            query = query
              .match('(trait)-[:supplier]->(resource:Resource)')
              .where('resource.resource_id': options[:resource].id)
          end

          # NOTE: break needed to achieve correct ordering of where clauses
          query.break.optional_match(TraitBank::Constants::EXEMPLAR_MATCH)
            .with(:group_predicate, :trait)
            .order_by('group_predicate.eol_id', TraitBank::Constants::EXEMPLAR_ORDER)
            .return(:group_predicate, collect_pk_part, "count(DISTINCT trait) as trait_count").to_a
        end
      end

      def extract_grouped_trait_pks(pks_by_group)
        pks_by_group.map { |row| row[:trait_pks] }.flatten
      end

      def resource_filter_part(resource_id)
        if resource_id
          "{ resource_id: #{resource_id} }"
        else
          ""
        end
      end

      def predicate_filter_match_part(options)
        options[:pred_uri] ? "-[#{PARENT_TERMS}]->(:Term{ uri: '#{options[:pred_uri]}' })" : ""
      end
    end
  end
end
