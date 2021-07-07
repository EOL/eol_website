class ReconciliationResult
  class RankScorer
    NO_PAGE_RANK_SCORE = 50
    MISMATCH_SCORE = 0

    def initialize(rank_str)
      @treat_as = "r_#{rank_str}"
      @valid_treat_as = Rank.treat_as.include?(@treat_as)
    end

    def should_score?
      @valid_treat_as # invalid rank strings shouldn't affect total score either way
    end

    def score(page)
      raise TypeError "rank guess #{treat_as} is unscorable" unless should_score?

      if page.rank.nil?
        NO_PAGE_RANK_SCORE
      elsif page.rank.treat_as == @treat_as
        ReconciliationResult::MAX_SCORE
      else
        MISMATCH_SCORE         
      end
    end
  end
end
