module TraitBank
  class TermSearchCounts
    # NOTE -- taxon search results do not include records, but record results do include taxa
    attr_reader :records, :pages

    def initialize(res)
      record_count_index = res["columns"].index("record_count")
      page_count_index = res["columns"].index("page_count")

      if page_count_index.nil?
        raise TypeError.new("page_count missing from result")
      end

      if record_count_index.nil?
        @records = 0
      else
        @records = res["data"].first[record_count_index]
      end

      @pages = res["data"].first[page_count_index]
    end

    def primary_for_query(query)
      if query.record?
        records
      else
        pages
      end
    end

    def to_s
      "TraitBank::TermSearchCounts( records: #{records}, pages: #{pages} )"
    end
  end
end
