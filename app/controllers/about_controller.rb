class AboutController < ApplicationController
  def trait_bank
    example_query = TermQuery.new(
      filters: [
        TermQueryFilter.new(predicate_id: TermNode.find_by(uri: "http://www.wikidata.org/entity/Q1053008").id)
      ],
      result_type: :taxa
    )
    @example_search_path = term_search_results_path(term_query: example_query.to_params)
    @autogen_page_path = page_path(id: 46559130)
    @wordcloud_data = AboutController.tb_wordcloud_data
  end

  # TODO: remove. Sankey layout test page.
  def sankey_test
  end

  def self.tb_wordcloud_data
    data = nil

    begin
      data = TbWordcloudData.data  
    rescue TypeError => e
      logger.error("Failed to get wordcloud data: #{e.message}")
    end

    return [] if data.nil?

    # links are different per locale. We could cache this with the locale in the key if necessary.
    term_uris = data.map { |d| d["uri"] }
    terms_by_uri = TermNode.where(uri: term_uris).map { |t| [t.uri, t] }.to_h

    data.collect do |datum|
      term = terms_by_uri[datum["uri"]]

      unless term
        logger.error("Invalid URI in TB wordcloud data: #{datum['uri']}")
        next nil
      end

      term_query = TermQuery.new(
        filters: [
          TermQueryFilter.new(predicate_id: term.id)
        ],
        result_type: :record
      )

      {
        text: TraitBank::Record.i18n_name(datum.symbolize_keys),
        weight: Math.log(datum["count"], 2),
        link: Rails.application.routes.url_helpers.term_search_results_path(term_query: term_query.to_params)
      }
    end.compact
  end
end

