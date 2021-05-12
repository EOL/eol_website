module TraitBank
  module Queries
    class << self
      include TraitBank::Constants

      def limit_and_skip_clause(page = 1, per = 50)
        # I don't know why the default values don't work, but:
        page ||= 1
        per ||= 50
        skip = (page.to_i - 1) * per.to_i
        add = " LIMIT #{per}"
        add = " SKIP #{skip}#{add}" if skip > 0
        add
      end

      def count_by_resource(id)
        Rails.cache.fetch("trait_bank/count_by_resource/#{id}") do
          count_traits_by_resource_nocache(id)
        end
      end

      def count_supplier_nodes_by_resource_nocache(id)
        q = <<~CYPHER
          MATCH (:Resource{ resource_id: $id })<-[:supplier]-(any)
          RETURN count(DISTINCT any) AS count
        CYPHER

        ActiveGraph::Base.query(q, id: id).first[:count]
      end

      def count_traits_by_resource_nocache(id)
        res = TraitBank.query(
          "MATCH (res:Resource { resource_id: #{id} })<-[:supplier]-(trait:Trait)<-[#{TRAIT_RELS}]-(page:Page) "\
          "USING INDEX res:Resource(resource_id) "\
          "WITH count(trait) as count "\
          "RETURN count")
        res["data"] ? res["data"].first.first : false
      end

      def count_by_resource_and_page(resource_id, page_id)
        Rails.cache.fetch("trait_bank/count_by_resource/#{resource_id}/pages/#{page_id}") do
          res = TraitBank.query(
            "MATCH (res:Resource { resource_id: #{resource_id} })<-[:supplier]-(trait:Trait)<-[#{TRAIT_RELS}]-(page:Page { page_id: #{page_id} }) "\
            "USING INDEX res:Resource(resource_id) USING INDEX page:Page(page_id) "\
            "WITH count(trait) as count "\
            "RETURN count")
          res["data"] ? res["data"].first.first : false
        end
      end

      def count_by_page(page_id)
        Rails.cache.fetch("trait_bank/count_by_page/#{page_id}", expires_in: 1.day) do
          res = TraitBank.query(
            "MATCH (trait:Trait)<-[#{TRAIT_RELS}]-(page:Page { page_id: #{page_id} }) "\
            "WITH count(trait) as count "\
            "RETURN count")
          res["data"] ? res["data"].first.first : false
        end
      end

      def predicate_count_by_page(page_id)
        Rails.cache.fetch("trait_bank/predicate_count_by_page/#{page_id}", expires_in: 1.day) do
          res = TraitBank.query(
            "MATCH (page:Page { page_id: #{page_id} }) -[#{TRAIT_RELS}]->"\
            "(trait:Trait)-[:predicate]->(term:Term) "\
            "WITH count(distinct(term.uri)) AS count "\
            "RETURN count")
          res["data"] ? res["data"].first.first : 0
        end
      end

      def predicate_count
        Rails.cache.fetch("trait_bank/predicate_count", expires_in: 1.day) do
          res = TraitBank.query(
            "MATCH (trait:Trait)-[:predicate]->(term:Term) "\
            "WITH count(distinct(term.uri)) AS count "\
            "RETURN count")
          res["data"] ? res["data"].first.first : false
        end
      end

      def data_dump_trait(pk)
        id = pk.gsub(/"/, '""')
        TraitBank.query(%{
          MATCH (trait:Trait { eol_pk: "#{id}" })-[:metadata]->(meta:MetaData)-[:predicate]->(meta_predicate:Term)
          OPTIONAL MATCH (meta)-[:units_term]->(meta_units_term:Term)
          OPTIONAL MATCH (meta)-[:object_term]->(meta_object_term:Term)
          OPTIONAL MATCH (meta)-[:sex_term]->(sex_term:Term)
          OPTIONAL MATCH (meta)-[:lifestage_term]->(lifestage_term:Term)
          OPTIONAL MATCH (meta)-[:statistical_method_term]->(statistical_method_term:Term)
          RETURN meta.eol_pk, trait.eol_pk, meta_predicate.uri, meta.literal, meta.measurement, meta_object_term.uri,
            meta_units_term.uri, sex_term.uri, lifestage_term.uri, statistical_method_term.uri, meta.source
        })
      end

      def by_page(page_id, page = 1, per = 100)
        Rails.cache.fetch("trait_bank/by_page/#{page_id}", expires_in: 1.day) do
          q = "MATCH (page:Page { page_id: #{page_id} })-[#{TRAIT_RELS}]->(trait:Trait)"\
              "-[:supplier]->(resource:Resource) "\
            "MATCH (trait:Trait)-[:predicate]->(predicate:Term) "\
            "OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term) "\
            "OPTIONAL MATCH (trait)-[:sex_term]->(sex_term:Term) "\
            "OPTIONAL MATCH (trait)-[:lifestage_term]->(lifestage_term:Term) "\
            "OPTIONAL MATCH (trait)-[:statistical_method_term]->(statistical_method_term:Term) "\
            "OPTIONAL MATCH (trait)-[:units_term]->(units:Term) "\
            "OPTIONAL MATCH (trait)-[:object_page]->(object_page:Page) "\
            "RETURN resource, trait, predicate, object_term, object_page, units, sex_term, lifestage_term, statistical_method_term"

          # q += order_clause(by: ["toLower(predicate.name)", "toLower(object_term.name)",
          #   "toLower(trait.literal)", "trait.normal_measurement"])
          q += limit_and_skip_clause(page, per)
          res = TraitBank.query(q)
          TraitBank::ResultHandling.build_trait_array(res)
        end
      end

      def data_dump_page(page_id)
        TraitBank.query(%{
          MATCH (page:Page { page_id: #{page_id} })-[#{TRAIT_RELS}]->(trait:Trait)-[:supplier]->(resource:Resource),
            (trait:Trait)-[:predicate]->(predicate:Term)
          OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term)
          OPTIONAL MATCH (trait)-[:sex_term]->(sex_term:Term)
          OPTIONAL MATCH (trait)-[:lifestage_term]->(lifestage_term:Term)
          OPTIONAL MATCH (trait)-[:statistical_method_term]->(statistical_method_term:Term)
          OPTIONAL MATCH (trait)-[:units_term]->(units:Term)
          OPTIONAL MATCH (trait)-[:normal_units_term]->(normal_units:Term)
          RETURN trait.eol_pk, page.page_id, trait.scientific_name, trait.resource_pk, predicate.uri, sex_term.uri,
            lifestage_term.uri, statistical_method_term.uri, trait.source, trait.object_page_id,
            trait.target_scientific_name, object_term.uri, trait.literal, trait.measurement, units.uri,
            trait.normal_measurement, normal_units.uri, resource.resource_id
        })
      end

      # each argument is expected to be an Array of strings
      def array_to_qs(*args)
        result = []
        args.each do |uris|
          result.concat(uris.collect { |uri| "'#{uri}'" })
        end
        "[#{result.join(", ")}]"
      end

      private
      def quote(string)
        return string if string.is_a?(Numeric) || string =~ /\A[-+]?[0-9,]*\.?[0-9]+\Z/
        %Q{"#{string.gsub(/"/, "\\\"")}"}
      end

      def order_clause(options)
        %Q{ ORDER BY #{order_clause_array(options).join(", ")}}
      end
      
      # TODO: add association to the sort... normal_measurement comes after literal, so it will be ignored
      def order_clause_array(options)
        options[:sort] ||= ""
        options[:sort_dir] ||= ""
        sorts =
          if options[:by]
            options[:by]
          elsif options[:object_term]
            [] # You already have a SINGLE term. Don't sort it.
          elsif options[:sort].downcase == "measurement"
            ["trait.normal_measurement"]
          else
            # TODO: this is not good. multiple types of values will not
            # "interweave", and the only way to change that is to store a
            # "normal_value" value for all different "stringy" types (literals,
            # object terms, and object page names). ...This is a resonable approach,
            # though it will require more work to keep "up to date" (e.g.: if the
            # name of an object term changes, all associated traits will have to
            # change).
            ["toLower(predicate.name)", "toLower(info_term.name)", "trait.normal_measurement", "toLower(trait.literal)"]
          end
        # NOTE: "ties" for traits are resolved by species name.
        sorts << "page.name" unless options[:by]
        if options[:sort_dir].downcase == "desc"
          sorts.map! { |sort| "#{sort} DESC" }
        end
        sorts
      end
    end
  end
end
