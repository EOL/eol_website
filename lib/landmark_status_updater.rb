# Utility for syncing Page landmark status in Neo4j with the relational DB.

module LandmarkStatusUpdater
  class << self
    def run
      updated_count = 0
      batch_size = 1000
      page_count = Page.count

      puts "updating #{page_count} Pages in batches"

      Page.includes(:native_node).find_in_batches(batch_size: batch_size).with_index do |batch, i|
        batch_num = i + 1

        query_data = batch.map do |p|
          landmark = p.native_node&.landmark
          landmark = nil if landmark == "no_landmark"
          { page_id: p.id, landmark: landmark }
        end

        update_count = update_query(query_data)
        updated_count += update_count

        if batch_num % 50 == 0
          puts "processed  #{batch_num * batch_size} Pages so far, with #{updated_count} matched in TraitBank"
        end
      end

      puts "Done! Updated #{updated_count} Pages in TraitBank. #{page_count - updated_count} were unmatched."
    end
    
    private
    def update_query(query_data)
      result = TraitBank.query(
        %{
          WITH $pairs AS pairs
          UNWIND pairs AS pair
          MATCH (p:Page)
          WHERE p.page_id = pair.page_id
          SET p.landmark = pair.landmark
          RETURN count(p)
        },
        { pairs: query_data }
      )
      result["data"].first.first 
    end
  end
end
