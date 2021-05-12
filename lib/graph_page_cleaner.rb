require "set"

module GraphPageCleaner
  class << self
    BATCH_SIZE = 1000

    # Options:
    # dry_run (required): true to only print page ids that would be removed, false to actually remove them.
    def run(options = {})
      if !options.include?(:dry_run)
        puts "You must pass dry_run option explicitly. Aborting."
        return
      end

      no_trait_page_ids_in_batches do |ids|
        dh_page_ids = Set.new(
          Page.joins("JOIN nodes ON nodes.id = pages.native_node_id").where("pages.id" => ids).pluck("pages.id")
        )

        to_remove = ids.reject { |id| dh_page_ids.include?(id) }
        if to_remove.any?
          puts "Batch to remove: #{to_remove}"

          if options[:dry_run]
            puts "...not really, because this is a dry run"
          else
            puts "Removing"
            delete_from_graph(to_remove)
          end
        else
          puts "Nothing to remove"
        end
      end

      puts "Done"
    end

    private

    def delete_from_graph(page_ids)
      puts "Deleting pages from graph"

      q = %{
        MATCH (page:Page)
        WHERE page.page_id IN $page_ids
        DETACH DELETE page
        RETURN count(*)
      }

      result = TraitBank.query(q, page_ids: page_ids)
      deleted_count = result["data"].first.first
      puts "Deleted #{deleted_count} pages from graph."
    end

    def no_trait_page_ids_in_batches
      batch = 0
      results = []

      
      while batch == 0 || results.any?
        puts "Fetching batch #{batch} of no-trait pages from neo4j"

        skip = batch * BATCH_SIZE

        q = %{
          MATCH (p:Page)
          WHERE NOT (p)-[:trait]->(:Trait)
          RETURN p.page_id
          ORDER BY p.page_id
          SKIP $skip
          LIMIT $limit
        }

        results = TraitBank.query(q, skip: skip, limit: BATCH_SIZE)["data"].flatten
        yield results

        batch += 1
      end
    end
  end
end
