class BriefSummaryWarmingJob < ApplicationJob
  def perform
    CacheWarming::PageBriefSummaryWarmer.run
  end
end

