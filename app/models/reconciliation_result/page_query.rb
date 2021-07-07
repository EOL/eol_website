class ReconciliationResult
  class PageQuery
    attr_reader :query_string, :searchkick_query

    MAX_LIMIT = 50

    def initialize(query_string, limit)
      @query_string = query_string
      @searchkick_query = build_searchkick_query
      @limit = [limit || MAX_LIMIT, MAX_LIMIT].min
    end

    def build_searchkick_query
      match = @query_string.split.length > 1 ? :text_start : :phrase

      Page.search(
        @query_string, 
        fields: %w[
          preferred_vernacular_strings^2 preferred_scientific_names^2 
          vernacular_strings scientific_name synonyms
        ], 
        match: match, 
        includes: [{ native_node: { node_ancestors: :ancestor } }],
        highlight: { tag: '' }, 
        limit: @limit,
        execute: false
      )
    end
  end
end
