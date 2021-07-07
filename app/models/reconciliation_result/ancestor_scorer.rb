class ReconciliationResult
  class AncestorScorer
    QUERY_LIMIT = 10

    def initialize(query_string, entity_hash)
      @query_string = query_string
      @page_from_entity = resolve_entity(entity_hash)
    end

    class << self
      private :new

      def for_query_string(s)
        new(s, nil)
      end

      def for_entity_hash(h)
        new(nil, h)
      end
    end

    def searchkick_query
      if @query_string
        unless @query
          @query = PageQuery.new(@query_string, QUERY_LIMIT)
        end

        @query.searchkick_query
      else
        nil
      end
    end

    def should_score?
      true
    end

    def score(page)
      candidates.each do |c|
        return c.score if page.ancestry_ids.include?(c.page.id)
      end

      return 0
    end

    private
    def resolve_entity(entity_hash)
      entity_hash.nil? ? nil : TaxonEntityResolver.new(entity_hash).page
    end

    def candidates
      if @query_string
        ScoredPage.from_searchkick_results(@query_string, @query.searchkick_query)
      elsif @page_from_entity
        [ScoredPage.new(@page_from_entity, ReconciliationResult::MAX_SCORE, true)]
      else
        []
      end
    end
  end
end

