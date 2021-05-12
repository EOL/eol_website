module TraitBank
  module Admin
    class << self
      def setup
        create_indexes
        create_constraints
      end

      # You only have to run this once, and it's best to do it before loading TB:
      def create_indexes
        indexes = %w{ Term(name) }
        indexes.each do |index|
          TraitBank.query("CREATE INDEX ON :#{index};")

          # TraitBank.query no longer uses Neography. Preserving in case this is needed.
          # - mvitale
          #rescue Neography::NeographyError => e
          #  if e.to_s =~ /already created/
          #    puts "Already have an index on #{index}, skipping."
          #  else
          #    raise e
          #  end
          #end
        end
      end

      # NOTE: You only have to run this once, and it's best to do it before
      # loading TB:
      def create_constraints(drop = nil)
        contraints = {
          "Page" => [:page_id],
          "Term" => [:uri, :eol_id],
          "Trait" => [:eol_pk],
          "Resource" => [:resource_id],
          "MetaData" => [:eol_pk]
        }
        contraints.each do |label, fields|
          fields.each do |field|
            name = 'o'
            name = label.downcase if drop && drop == :drop
            # You cannot have an index on a constrained field. Sorry about the rescue nil, this is a MINOR operation
            # and it throws an error if the index doesn't exist:
            TraitBank.query("DROP INDEX ON :#{label}(#{field})") rescue nil

            constraint_query = "#{drop && drop == :drop ? 'DROP' : 'CREATE'} CONSTRAINT ON (#{name}:#{label}) ASSERT #{name}.#{field} IS UNIQUE;"
            puts constraint_query
            puts TraitBank.query(constraint_query)

            # Same as above.
            #rescue Neography::NeographyError => e
            #  raise e unless e.message =~ /already exists/ || e.message =~ /No such constraint/
            #end
          end
        end
      end

      # Your gun, your foot: USE CAUTION. This erases EVERYTHING irrevocably.
      def nuclear_option!
        remove_with_query(name: :n, q: "(n)")
        Rails.cache.clear # Sorry, this is easiest. :|
      end

      # Your gun, your foot: USE CAUTION. This erases (almost) EVERYTHING irrevocably.
      def remove_all_data_leave_terms!
        remove_with_query(name: :meta, q: "(meta:MetaData)")
        remove_with_query(name: :trait, q: "(trait:Trait)")
        remove_with_query(name: :page, q: "(page:Page)")
        remove_with_query(name: :res, q: "(res:Resource)")
        Rails.cache.clear # Sorry, this is easiest. :|
      end

      def remove_for_resource(resource)
        remove_with_query(
          name: :meta,
          q: "(meta:MetaData)<-[:metadata]-(trait:Trait)-[:supplier]->(:Resource { resource_id: #{resource.id} })"
        )
        remove_with_query(
          name: :meta,
          q: "(meta:MetaData)-[:supplier]->(:Resource { resource_id: #{resource.id} })"
        )
        remove_with_query(
          name: :rel,
          q: "()-[rel:inferred_trait]-(:Trait)-[:supplier]->(:Resource { resource_id: #{resource.id} })"
        )
        remove_with_query(
          name: :trait,
          q: "(trait:Trait)-[:supplier]->(:Resource { resource_id: #{resource.id} })"
        )
        remove_with_query(
          name: :vernacular,
          q: "(vernacular:Vernacular)-[:supplier]->(:Resource { resource_id: #{resource.id} })"
        )
        Rails.cache.clear # Sorry, this is easiest. :|
      end

      # options = {name: :meta, q: "(meta:MetaData)<-[:metadata]-(trait:Trait)-[:supplier]->(:Resource { resource_id: 640 })"}
      def remove_with_query(options = {})
        name = options[:name]
        q = options[:q]
        delay = options[:delay] || 1 # Increasing this did not really help site performance. :|
        size = options[:size] || 64
        count_before = count_type_for_resource(name, q)
        count = 0
        return if count_before.nil? || ! count_before.positive?
        loop do
          time_before = Time.now
          apoc = "CALL apoc.periodic.iterate('MATCH #{q} WITH #{name} LIMIT #{size} RETURN #{name}', 'DETACH DELETE #{name}', { batchSize: 32 })"
          TraitBank::Logger.log("--TB_DEL: #{apoc}")
          TraitBank.query(apoc)
          time_delta = Time.now - time_before
          TraitBank::Logger.log("--TB_DEL: Took #{time_delta}.")
          count += size
          if count >= count_before
            count = count_type_for_resource(name, q)
            break unless count.positive?
            if count >= 2 * count_before
              raise "I have been attempting to delete #{name} data for twice as long as expected. "\
                    "Started with #{count_before} entries, now there are #{count}. Aborting."
            end
          end
          size *= 2 if time_delta < 15 and size <= 8192
          size /= 2 if time_delta > 30
          sleep(delay)
        end
      end

      def count_type_for_resource(name, q)
        TraitBank.query("MATCH #{q} RETURN COUNT(DISTINCT #{name})")['data']&.first&.first
      end

      # NOTE: this code is unused, but please don't delete it; we call it manually.
      def delete_terms_in_domain(domain)
        before = TraitBank.query("MATCH (term:Term) WHERE term.uri =~ '#{domain}.*' RETURN COUNT(term)")["data"].first.first
        remove_with_query(name: :term, q: "(term:Term) WHERE term.uri =~ '#{domain}.*'")
        before
      end

      def delete_terms_with_no_relationships
        raise "Naw." # TODO: See if this works properly (in a test graph), then remove this line.
        remove_with_query(name: :term, q: "(term:Term) WHERE NOT ()-->(term) AND NOT (term)-->()")
      end

      # AGAIN! Use CAUTION. This is intended to delete all parent relationships between pages, and then rebuild them
      # based on what's currently in the database. It skips relationships to pages that are missing (but reports on
      # which those are), and it does not repeat any relationships. It takes a about a minute per 3000 nodes on jrice's
      # machine.
      def rebuild_hierarchies(remove_old = false)
        if remove_old
          remove_with_query(name: :parent, q: "(:Page)-[parent:parent]->(:Page)")
        end
        related = {}
        eol = Resource.native
        raise "I tried to use EOL as the native node for the relationships, but it wasn't there." unless eol
        nodes = Node.where(["resource_id = ? AND parent_id IS NOT NULL AND page_id IS NOT NULL", eol.id])
        count = nodes.count
        per_cent = count / 100
        i = 0
        dumb_log('Starting')
        nodes.includes(:parent).find_each do |node|
          i += 1
          dumb_log("Percent complete: #{((i / count.to_f) * 100).ceil}% (#{i}/#{count})") if (i % per_cent).zero?
          page_id = node.page_id
          next if node.parent.nil?
          parent_id = node.parent.page_id
          next if page_id == parent_id
          next if related.key?(page_id) # Pages may only have ONE parent.
          tries = 0
          begin
            res = TraitBank.query("MERGE (from_page:Page { page_id: #{page_id}}) "\
              "MERGE (to_page:Page { page_id: #{parent_id}}) "\
              "MERGE(from_page)-[:parent]->(to_page)")
          rescue
            tries += 1
            raise "Too many retries to relate page #{page_id} to its parent #{parent_id}!" if tries >= 10
            sleep(tries)
            retry
          end
          related[page_id] = parent_id
        end
        dumb_log('Done.')
      end

      def dumb_log(what)
        puts "[#{Time.now}] #{what}"
        STDOUT.flush
      end

      def rebuild_names
        TraitBank.query("MATCH (page:Page) REMOVE page.name RETURN COUNT(*)")
        dynamic_hierarchy = Resource.native
        Node.where(["resource_id = ?", dynamic_hierarchy.id]).find_each do |node|
          name = node.canonical_form
          page = PageNode.where(page_id: node.page_id)&.first
          next unless page
          page.update!(name: name)
          puts "#{node.page_id} => #{name}"
        end
      end

      # NOTE: if you add any new caches IN THE TB CLASS, add them here.
      def clear_caches
        TraitBank::Logger.warn("TRAITBANK CACHES CLEARED.")
        [
          "trait_bank/predicate_count",
          "trait_bank/terms_count",
          "trait_bank/predicate_glossary/count",
          "trait_bank/object_term_glossary/count",
          "trait_bank/units_term_glossary/count",
        ].each do |key|
          Rails.cache.delete(key)
        end
        count = TraitBank::Term.count
        # NOTE: unfortunately, we don't KNOW here how many there are per page.
        # Yech! Perhaps a Rails config?
        lim = (count / Rails.configuration.data_glossary_page_size.to_f).ceil
        (0..lim).each do |index|
          Rails.cache.delete("trait_bank/full_glossary/#{index}")
          Rails.cache.delete("trait_bank/predicate_glossary/#{index}")
          Rails.cache.delete("trait_bank/object_term_glossary/#{index}")
          Rails.cache.delete("trait_bank/units_term_glossary/#{index}")
        end
        Resource.pluck(:id).each do |id|
          Rails.cache.delete("trait_bank/count_by_resource/#{id}")
          # NOTE: there's also a resource-by-page, but... that's waaaaay too much work to do here.
        end
        true
      end
    end
  end
end
