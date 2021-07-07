module CacheWarming
  module PageBriefSummaryWarmer
    class << self
      def run
        log "Calling brief summary for all pages"

        # Only for 'en'
        I18n.locale = I18n.default_locale

        Page.with_hierarchy_no_media.where.not(native_node_id: nil).find_in_batches.with_index do |batch, i|
          log "Processing batch #{i}"
          decorated_batch = PageDecorator.decorate_collection(batch)

          decorated_batch.each do |p|
            begin
              p.cached_summary
            rescue ActiveGraph::Node::Labels::RecordNotFound
              # I had some missing neo4j PageNodes that threw this -- skip 'em and move on
              log "WARNING: missing PageNode with id #{p.id}. Skipping"
            end
          end
        end

        puts "Done"
      end

      def log(msg)
        Rails.logger.info("(#{Time.now}) #{msg}")
      end
    end
  end
end

