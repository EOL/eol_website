module TraitBank
  module Search
    class << self
      include TraitBank::Constants

      # NOTE: "count" means something different here! In .term_search it's used to
      # indicate you *want* the count; here it means you HAVE the count and are
      # passing it in! Be careful.
      def batch_term_search(term_query, options, count)
        found = 0
        batch_found = 1 # Placeholder; will update in query.
        page = 1
        while(found < count && batch_found > 0)
          batch = term_search(term_query, options.merge(page: page))[:data]
          batch_found = batch.size
          found += batch_found
          yield(batch)
          page += 1
        end
      end

      # Call this with an option of cache: false if you want to skip caching the RESULTS. Result counts will ALWAYS be
      # cached.
      def term_search(term_query, options={})
        key = term_query.to_cache_key
        if options[:count]
          key = "trait_bank/term_search/counts/#{key}"
          if Rails.cache.exist?(key)
            count = Rails.cache.read(key)
            TraitBank::Logger.log("&& TS USING cached count: #{key} = #{count}")
            return count
          end
        else
          TraitBank::Caching.add_hash_to_key(key, options)
        end
        if options.key?(:cache) && !options[:cache]
          term_search_uncached(term_query, key, options)
        else
          Rails.cache.fetch("term_search/v2/#{key}") do
            term_search_uncached(term_query, key, options)
          end
        end
      end

      # term_page_search_matches/term_record_search_matches/term_search_matches_helper are intentionally left public for use outside of this module
      def term_page_search_matches(term_query, params, options = {})
        term_search_matches_helper(term_query, params, options) do |i, filter, trait_var, pred_var, obj_var|
          if i == term_query.filters.length - 1
            nil
          else
            "WITH DISTINCT page"
          end
        end
      end

      def term_record_search_matches(term_query, params, options = {})
        trait_ag_var = options[:count] ? "trait_count" : "trait_rows"

        term_search_matches_helper(term_query, params, options.merge(always_match_pred: true)) do |i, filter, trait_var, pred_var, obj_var|
          if term_query.filters.length > 1
            if options[:count]
              trait_ag = "count(DISTINCT #{trait_var})"
            else
              trait_ag = "collect(DISTINCT { trait: #{trait_var}, predicate: #{pred_var}})"
            end

            if i > 0
              trait_ag = "(#{trait_ag} + #{trait_ag_var})"
            end

            "WITH page, #{trait_ag} AS #{trait_ag_var}"
          else
            nil
          end
        end
      end

      def term_search_matches_helper(term_query, params, options = {})
        filters = term_query.page_count_sorted_filters
        filter_parts = []
        clade_matched = term_query.clade_node && (
          filters.empty? ||
          term_query.clade_node.descendant_count < term_query.page_count_sorted_filters.first.min_distinct_page_count
        )
        gathered_term_matches, gathered_terms = gather_terms_matches(
          filters,
          params,
          first_filter_gather_all: clade_matched,
          include_tgt_vars: options[:with_tgt_vars]
        )

        add_clade_match(term_query, gathered_terms, filter_parts, params, clade_matched, with_tgt_vars: options[:with_tgt_vars])

        filters.each_with_index do |filter, i|
          filter_matches = []
          filter_wheres = []
          obj_term_labeler = TraitBank::QueryFieldLabeler.new(options[:obj_var], :object_term, i)
          pred_labeler = TraitBank::QueryFieldLabeler.new(options[:pred_var], :predicate, i)

          trait_var = filters.length == 1 && options[:trait_var] ? options[:trait_var] : "trait#{i}"
          base_meta_var = "meta#{i}"
          gathered_terms_for_filter = gathered_terms.shift

          clade_matched ||= add_clade_where_conditional(clade_matched, i, filter, term_query, filter_parts)
          page_node = i == 0 && !clade_matched ? "(page:Page)" : "(page)"

          filter_matches << page_trait_match_for_filter(term_query, filter, page_node, trait_var)

          if filter.object_term?
            filter_matches << filter_term_match(trait_var, obj_term_labeler.tgt_label, obj_term_labeler.label, :object_term, gathered_terms_for_filter)
          elsif options[:always_match_obj]
            filter_matches << filter_term_match_no_hier(trait_var, obj_term_labeler.label, :object_term)
          end

          if filter.obj_clade.present? || options[:always_match_obj_clade]
            gathered_clade = gathered_terms_for_filter.find { |t| t.type == :object_clade }
            obj_clade_labeler = TraitBank::QueryFieldLabeler.new(options[:obj_clade_var], :object_clade, i)
            match_clade = !gathered_clade && filter.obj_clade

            if filter.for_inverse_predicate?
              if match_clade
                filter_matches << "(#{obj_clade_labeler.label}:Page)-[:parent*0..]->(#{obj_clade_labeler.tgt_label}:Page)"
                filter_matches << "(#{obj_clade_labeler.label})-[#{trait_rels_for_query_type(term_query)}]->(#{trait_var})"
              else

                filter_matches << "(#{obj_clade_labeler.label}:Page)-[#{trait_rels_for_query_type(term_query)}]->(#{trait_var})"
              end
            else
              if match_clade
                filter_matches << "(#{trait_var})-[:object_page]->(#{obj_clade_labeler.label}:Page)-[:parent*0..]->(#{obj_clade_labeler.tgt_label}:Page)"
              else
                filter_matches << "(#{trait_var})-[:object_page]->(#{obj_clade_labeler.label}:Page)"
              end
            end
          end

          if filter.predicate?
            filter_matches << filter_term_match(trait_var, pred_labeler.tgt_label, options[:pred_var] || pred_labeler.label, :predicate, gathered_terms_for_filter)
          elsif options[:always_match_pred]
            filter_matches << filter_term_match_no_hier(trait_var, pred_labeler.label, :predicate)
          end

          filter_where = term_filter_where(filter, trait_var, pred_labeler, obj_term_labeler, obj_clade_labeler, params, gathered_terms_for_filter)
          filter_wheres << filter_where unless filter_where.nil?
          filter_wheres << "page IN pages" if term_query.clade && !clade_matched && i == filters.length - 1
          add_term_filter_meta_matches(filter, trait_var, base_meta_var, filter_matches, params)
          add_term_filter_resource_match(filter, trait_var, filter_matches, params)

          match_where = "MATCH #{filter_matches.join(", ")}"
          match_where.concat("\nWHERE #{filter_wheres.join(" AND ")}") if filter_wheres.any?

          with = options[:with_tgt_vars] ?
            yield(i, filter, trait_var, pred_labeler.label, pred_labeler.tgt_label, obj_term_labeler.label, obj_term_labeler&.tgt_label) :
            yield(i, filter, trait_var, pred_labeler&.label, obj_term_labeler&.label)

          if with.present?
            add_gathered_terms(with, gathered_terms, with_tgt_vars: options[:with_tgt_vars])

            if term_query.clade && !clade_matched
              with.concat(", pages")
            end
          end

          if with
            filter_parts << "#{match_where}\n#{with}"
          else
            filter_parts << match_where
          end
        end

        %Q(
          #{gathered_term_matches.join("\n")}
          #{filter_parts.join("\n")}
        )
      end

      private

      def page_trait_match_for_filter(term_query, filter, page_node, trait_var)
        if filter.for_inverse_predicate?
          "(#{trait_var}:Trait)-[:object_page]->#{page_node}"
        else
          "#{page_node}-[#{trait_rels_for_query_type(term_query)}]->(#{trait_var}:Trait)"
        end
      end

      def term_search_uncached(term_query, key, options)
        limit_and_skip = options[:page] ? TraitBank::Queries.limit_and_skip_clause(options[:page], options[:per]) : ""

        q = if term_query.record?
          term_record_search(term_query, limit_and_skip, options)
        else
          term_page_search(term_query, limit_and_skip, options)
        end

        res = TraitBank.query(q[:query], q[:params])

        TraitBank::Logger.log("&& TS SAVING Cache: #{key}")
        if options[:count]
          raise "&& TS Lost key" if key.blank?

          counts = TraitBank::TermSearchCounts.new(res)
          Rails.cache.write(key, counts, expires_in: 1.day)
          TraitBank::Logger.log("&& TS SAVING Cached counts: #{key} = #{counts}")
          counts
        else
          TraitBank::Logger.log("RESULT COUNT #{key}: #{res["data"] ? res["data"].length : "unknown"} raw")
          data = if options[:id_only]
                   res["data"]&.flatten
                 else
                   trait_array_options = { key: key, flat_results: true }
                   TraitBank::ResultHandling.build_trait_array(res, trait_array_options)
                 end

          { data: data, raw_query: q[:query], params: q[:params], raw_res: res }
        end
      end

      def term_filter_where_term_part(anc_term_label, child_term_label, term_uri, term_type, params, gathered_terms)
        gathered_term = gathered_terms.find { |t| t.type == term_type }

        if gathered_term
          "#{child_term_label} IN #{gathered_term.gathered_list_label}"
        else
          term_uri_param = "#{anc_term_label}_uri"
          params[term_uri_param] = term_uri
          "#{anc_term_label}.uri = $#{term_uri_param}"
        end
      end

      def term_filter_where_obj_clade_part(obj_clade_var, child_obj_clade_var, obj_clade_id, params, gathered_terms)
        gathered_term = gathered_terms.find { |t| t.type == :object_clade }

        if gathered_term
          "#{child_obj_clade_var} IN #{gathered_term.gathered_list_label}"
        else
          obj_clade_id_param = "#{obj_clade_var}_page_id"
          params[obj_clade_id_param] = obj_clade_id
          "#{obj_clade_var}.page_id = $#{obj_clade_id_param}"
        end
      end

      def term_filter_where(
        filter,
        trait_var,
        pred_labeler,
        obj_term_labeler,
        obj_clade_labeler,
        params,
        gathered_terms = []
      )
        parts = []
        term_condition = []

        if filter.predicate?
          term_condition << term_filter_where_term_part(pred_labeler.tgt_label, pred_labeler.label, filter.predicate.uri_for_search, :predicate, params, gathered_terms)
        end

        if filter.object_term?
          term_condition << term_filter_where_term_part(obj_term_labeler.tgt_label, obj_term_labeler.label, filter.object_term.uri, :object_term, params, gathered_terms)
        end

        if filter.obj_clade.present?
          term_condition << term_filter_where_obj_clade_part(obj_clade_labeler.tgt_label, obj_clade_labeler.label, filter.obj_clade.id, params, gathered_terms)
        end

        parts << "#{term_condition.join(" AND ")}" if term_condition.any?

        if filter.numeric?
          conditions = []
          if filter.eq?
            eq_param = "#{trait_var}_eq"
            conditions << { op: "=", val: filter.num_val1, param: eq_param }
          else
            if filter.gt? || filter.range?
              gt_param = "#{trait_var}_gt"
              conditions << { op: ">=", val: filter.num_val1, param: gt_param }
            end

            if filter.lt? || filter.range?
              lt_param = "#{trait_var}_lt"
              conditions << { op: "<=", val: filter.num_val2, param: lt_param }
            end
          end

          units_param = "#{trait_var}_u"
          params[units_param] = filter.units_term.uri

          parts << "("\
          "#{trait_var}.normal_measurement IS NOT NULL "\
          "#{conditions.map { |c| "AND toFloat(#{trait_var}.normal_measurement) #{c[:op]} $#{c[:param]}" }.join(" ")} "\
          "AND (#{trait_var}:Trait)-[:normal_units_term]->(:Term{ uri: $#{units_param} })"\
          ")"
          conditions.each { |c| params[c[:param]] = c[:val] }
        end

        parts.any? ? parts.join(" AND ") : nil
      end

      def add_term_filter_meta_match(rel_type, obj_uri, trait_var, meta_var, matches, params)
        obj_uri_param = "#{meta_var}_obj_uri"

        match = "(#{trait_var})-[:#{rel_type}]->(:Term{ uri: $#{obj_uri_param} })"

        matches << match
        params[obj_uri_param] = obj_uri
      end

      def add_term_filter_meta_matches(filter, trait_var, base_meta_var, matches, params)
        add_term_filter_meta_match(
          'sex_term',
          filter.sex_term.uri,
          trait_var,
          "#{base_meta_var}_sex",
          matches,
          params
        ) if filter.sex_term?

        add_term_filter_meta_match(
          'lifestage_term',
          filter.lifestage_term.uri,
          trait_var,
          "#{base_meta_var}_ls",
          matches,
          params
        ) if filter.lifestage_term?

        add_term_filter_meta_match(
          'statistical_method_term',
          filter.statistical_method_term.uri,
          trait_var,
          "#{base_meta_var}_stat",
          matches,
          params
        ) if filter.statistical_method_term?
      end

      def add_term_filter_resource_match(filter, trait_var, matches, params)
        if filter.resource
          resource_param = "#{trait_var}_resource"
          matches << "(#{trait_var})-[:supplier]->(:Resource{ resource_id: $#{resource_param} })"
          params[resource_param] = filter.resource.id
        end
      end

      def record_search_returns(include_meta)
        returns = %w[
          page.page_id
          trait.eol_pk
          trait.measurement
          trait.object_page_id
          trait.sample_size
          trait.citation
          trait.source
          trait.remarks
          trait.method
          trait.literal
          object_term.uri
          object_term.name
          object_term.definition
          object_page.page_id
          predicate.uri
          predicate.name
          predicate.definition
          units.uri
          units.name
          units.definition
          statistical_method_term.uri
          statistical_method_term.name
          statistical_method_term.definition
          sex_term.uri
          sex_term.name
          sex_term.definition
          lifestage_term.uri
          lifestage_term.name
          lifestage_term.definition
          resource.resource_id
        ]

        if include_meta # NOTE: it's necessary to return meta.eol_pk for downstream result processing
          returns.concat(%w[
            meta.eol_pk
            meta.literal
            meta.measurement
            meta_predicate.uri
            meta_predicate.name
            meta_predicate.definition
            meta_units_term.uri
            meta_units_term.name
            meta_units_term.definition
            meta_object_term.uri
            meta_object_term.name
            meta_object_term.definition
            meta_sex_term.uri
            meta_sex_term.name
            meta_sex_term.definition
            meta_lifestage_term.uri
            meta_lifestage_term.name
            meta_lifestage_term.definition
            meta_statistical_method_term.uri
            meta_statistical_method_term.name
            meta_statistical_method_term.definition
          ])
        end

        "RETURN #{returns.join(", ")}"
      end

      def add_clade_match(term_query, gathered_terms, query_parts, params, match_clade_first, options = {})
        if term_query.clade_node
          page_match = "MATCH (page:Page)-[:parent*0..]->(anc: Page { page_id: $clade_id })"
          params["clade_id"] = term_query.clade_node.page_id

          if term_query.filters.any?
            if match_clade_first
              page_match_with = "WITH DISTINCT page"
            else
              page_match_with = "WITH collect(DISTINCT page) AS pages"
            end

            add_gathered_terms(page_match_with, gathered_terms, options)
            page_match.concat("\n#{page_match_with}")
          end

          query_parts << page_match
        end
      end

      def add_clade_where_conditional(clade_matched, filter_index, filter, term_query, query_parts)
        if (
          !clade_matched &&
          term_query.clade &&
          filter_index > 0 &&
          term_query.clade_node.descendant_count < filter.min_distinct_page_count
        )
          query_parts << "WHERE page IN pages"
          true
        end

        false
      end

      def term_record_search(term_query, limit_and_skip, options)
        params = {}

        trait_var = "trait"
        pred_var = "pred"
        match_part = term_record_search_matches(term_query, params, count: options[:count] || false, trait_var: trait_var, pred_var: pred_var)

        last_part = if term_query.filters.length > 1
          if options[:count]
            %Q(
              WITH count(*) AS page_count, sum(trait_count) AS record_count
              RETURN page_count, record_count
            )
          else
            unwind = 'UNWIND trait_rows AS trait_row'
            with_return = if options[:id_only]
                            %Q(
                              WITH DISTINCT trait_row.trait AS trait
                              RETURN trait.eol_pk
                              #{limit_and_skip}
                            )
                          else
                            %Q(
                              WITH page, trait_row.trait AS trait, trait_row.predicate AS predicate
                              #{record_optional_matches_and_returns(limit_and_skip, options)}
                            )
                          end
            %Q(
              #{unwind}
              #{with_return}
            )
          end
        else
          if options[:count]
            %Q(
              WITH count(DISTINCT page) AS page_count, count(DISTINCT #{trait_var}) AS record_count
              RETURN page_count, record_count
            )
          elsif options[:id_only]
            %Q(
              WITH DISTINCT trait
              RETURN trait.eol_pk
              #{limit_and_skip}
            )
          else
            %Q(
              WITH DISTINCT page, #{trait_var} AS trait, #{pred_var} AS predicate
              #{record_optional_matches_and_returns(limit_and_skip, options)}
            )
          end
        end

        query = "#{match_part}\n#{last_part}"
        { query: query, params: params }
      end

      def term_page_search(term_query, limit_and_skip, options)
        params = {}
        match_part = term_page_search_matches(term_query, params)
        with_count_clause = options[:count] ? "WITH COUNT(DISTINCT(page)) AS page_count " : ""
        return_clause = if options[:count]
                          "RETURN page_count"
                        else options[:id_only]
                          "RETURN DISTINCT page.page_id"
                        end

        query = %Q(
          #{match_part}
          #{with_count_clause}
          #{return_clause}
          #{limit_and_skip}
        )

        { query: query, params: params }
      end

      def record_optional_matches_and_returns(limit_and_skip, options)
        optional_matches = [
          "(trait)-[:object_term]->(object_term:Term)",
          "(trait)-[:object_page]->(object_page:Page)",
          "(trait)-[:units_term]->(units:Term)",
          "(trait)-[:normal_units_term]->(normal_units:Term)",
          "(trait)-[:sex_term]->(sex_term:Term)",
          "(trait)-[:lifestage_term]->(lifestage_term:Term)",
          "(trait)-[:statistical_method_term]->(statistical_method_term:Term)",
          "(trait)-[:supplier]->(resource:Resource)"
        ]
        optional_matches += [
          "(trait)-[:metadata]->(meta:MetaData)-[:predicate]->(meta_predicate:Term)",
          "(meta)-[:units_term]->(meta_units_term:Term)",
          "(meta)-[:object_term]->(meta_object_term:Term)",
          "(meta)-[:sex_term]->(meta_sex_term:Term)",
          "(meta)-[:lifestage_term]->(meta_lifestage_term:Term)",
          "(meta)-[:statistical_method_term]->(meta_statistical_method_term:Term)"
        ] if options[:meta]

        %Q(
          #{limit_and_skip}
          #{optional_matches.map { |match| "OPTIONAL MATCH #{match}" }.join("\n")}
          #{record_search_returns(options[:meta])}
        )
      end

      def trait_rels(include_inferred)
        include_inferred ? TRAIT_RELS : ":trait"
      end

      def trait_rels_for_query_type(query)
        trait_rels(query.taxa?)
      end

      def page_match(term_query, page_var, anc_var)
        match = "(#{page_var}:Page)"
        match += "-[:parent*0..]->(#{anc_var}:Page { page_id: #{term_query.clade.id} })" if term_query.clade
        match
      end

      def gather_terms_matches(filters, params, options = {})
        first_filter_gather_all = options[:first_filter_gather_all]
        include_tgt_vars = options[:include_tgt_vars]

        matches = []
        gathered_terms = []

        filters.each_with_index do |filter, i|
          gathered_terms[i] = []

          gather_all = i > 0 || first_filter_gather_all

          if gather_all || filter.all_fields.length > 1
            fields = gather_all ? filter.all_fields : filter.max_trait_row_count_fields

            fields.each do |field|
              labeler = TraitBank::QueryFieldLabeler.create_from_field(field, i)

              if field.type == :object_clade
                page_id_param = "#{labeler.gathered_label}_page_id"
                params[page_id_param] = field.value
                match = %Q(
                  MATCH (#{labeler.gathered_label}:Page)-[:parent*0..]->(:Page { page_id: $#{page_id_param} })
                  WITH collect(DISTINCT #{labeler.gathered_label}) AS #{labeler.gathered_list_label}
                )
              else
                uri_param = "#{labeler.gathered_label}_uri"
                params[uri_param] = field.value
                match = "MATCH (#{labeler.gathered_label}:Term)-[#{PARENT_TERMS}]->(#{include_tgt_vars ? labeler.tgt_label : ""}:Term{ uri: $#{uri_param} })"
                match.concat("\nWITH collect(DISTINCT #{labeler.gathered_label}) AS #{labeler.gathered_list_label}")
                match.concat(", #{labeler.tgt_label}") if include_tgt_vars
              end

              flattened_gathered_terms = gathered_terms.flatten
              if flattened_gathered_terms.any?
                gt_part = flattened_gathered_terms.map do |t|
                  include_tgt_vars ? "#{t.gathered_list_label}, #{t.tgt_label}" : t.gathered_list_label
                end.join(", ")
                match += ", #{gt_part}"
              end

              matches << match
              gathered_terms[i] << labeler
            end
          end
        end

        [matches, gathered_terms]
      end

      def filter_term_match_no_hier(trait_var, term_var, term_type)
        "(#{trait_var})-[:#{term_type}]->(#{term_var}:Term)"
      end

      def filter_term_match(trait_var, anc_term_var, child_term_var, term_type, gathered_terms)
        gathered_term = gathered_terms.find { |t| t.type == term_type }

        if gathered_term
          filter_term_match_no_hier(trait_var, child_term_var, term_type)
        else
          "(#{trait_var})-[:#{term_type}]->(#{child_term_var}:Term)-[#{PARENT_TERMS}]->(#{anc_term_var}:Term)"
        end
      end

      def add_gathered_terms(with_query, gathered_terms, options = {})
        flattened = gathered_terms.flatten

        if flattened.any?
          gt_part = gathered_terms.flatten.map do |gt|
            options[:with_tgt_vars] ?
              "#{gt.gathered_list_label}, #{gt.tgt_label}" :
              gt.gathered_list_label
          end.join(", ")

          with_query.concat(", #{gt_part}")
        end
      end

    end
  end
end
