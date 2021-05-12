# frozen_string_literal: true
# Warm the CSV Downloads for several "common" expensive searches.
class CsvDownloadWarmer
  @record_and_taxa_search_predicates = %w[
    http://eol.org/schema/terms/Present
    http://eol.org/schema/terms/TrophicGuild
    http://purl.obolibrary.org/obo/RO_0002303
  ]
  @taxa_search_predicates = %w[
    http://purl.obolibrary.org/obo/GO_0000003
    http://eol.org/schema/terms/SexualSystem
    http://purl.obolibrary.org/obo/UBERON_4000013
    https://eol.org/schema/terms/tissue_contains
    http://www.wikidata.org/entity/Q33596
    http://purl.obolibrary.org/obo/RO_0003000
    http://eol.org/schema/terms/EcomorphologicalGuild
  ]

  class << self
    def warm
      @record_and_taxa_search_predicates.each do |uri|
        warm_query(:record, uri)
        warm_query(:taxa, uri)
      end
      @taxa_search_predicates.each do |uri|
        warm_query(:taxa, uri)
      end
    end

    def warm_query(type, uri)
      term = TermNode.find_by(uri: uri)
      tq_params = { result_type: type, filters_attributes: [{ predicate_id: term.id }] }
      url = Rails.application.routes.url_helpers.term_search_results_url(:term_query => tq_params)
      begin
        Rails.logger.warn("[#{Time.now.strftime('%F %T')} WARM] Warming #{type} for #{uri}...")
        TraitBank::DataDownload.term_search(TermQuery.new(tq_params), 1, url, force_new: true)
      rescue => e
        Rails.logger.warn("[#{Time.now.strftime('%F %T')} WARM] FAILED warming #{type} for #{uri}. (#{e.class})")
        Rails.logger.warn("[#{Time.now.strftime('%F %T')} WARM] ERROR: #{e.message}")
      end
    end
  end
end
