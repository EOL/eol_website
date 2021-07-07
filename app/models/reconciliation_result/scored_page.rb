class ReconciliationResult
  class ScoredPage
    INEXACT_TOP_SCORE = 75
    MIN_NAME_SCORE = 50

    attr_accessor :page, :score, :confident_match

    def initialize(page, score, confident_match)
      @page = page
      @score = score
      @confident_match = confident_match
    end

    class << self
      def from_searchkick_results(query_string, results)
        return [] if results.empty?

        best_match = results.first
        highlight_strs = best_match.search_highlights.values.map { |v| v.downcase }
        best_score_abs = highlight_strs.include?(query_string.downcase) ? ReconciliationResult::MAX_SCORE : INEXACT_TOP_SCORE
        best_score_rel = results.hits.first['_score']
        worst_score_rel = results.hits.last['_score']
        rel_range = best_score_rel - worst_score_rel
        abs_range = best_score_abs - MIN_NAME_SCORE
        abs_rel_ratio = rel_range > 0 ? abs_range * 1.0 / rel_range : 0 # 0 is a sentinel value, won't be used in calculations

        results.hits.map.with_index do |hit, i|
          score_rel = hit['_score']
          score_abs = abs_rel_ratio > 0 ? (score_rel - worst_score_rel) * abs_rel_ratio + MIN_NAME_SCORE : best_score_abs

          # First result is a confident match if 
          # 1) a search field matches the query exactly (best_score_abs == MAX_SCORE)
          # 2) the next result has a lower score (or doesn't exist)
          confident_match = (
            i == 0 && 
            (results.length == 1 || results.hits[1]['_score'] < score_rel) &&
            best_score_abs == MAX_SCORE
          )

          self.new(results[i], score_abs, confident_match)
        end
      end
    end
  end
end
