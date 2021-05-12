class TraitSearch
  attr_accessor :query

  def initialize(term_query)
    raise TypeError, "term_query can't be nil" if term_query.nil?

    @query = term_query
    @per_page = DEFAULT_PER_PAGE
    @page = DEFAULT_PAGE
  end  

  def per_page(value)
    raise TypeError, 'must be > 0' unless value > 0

    @per_page = value

    self
  end

  def page(value)
    raise TypeError, 'must be > 0' unless value > 0    

    @page = value

    self
  end

  def count
    counts.primary_for_query(@query)
  end

  def page_count
    counts.pages
  end

  def grouped_data
    return @grouped_data if @grouped_data

    data = query_response[:data]
    processed_data = @query.record? ? process_trait_data(data) : process_page_data(data)
    @grouped_data = Kaminari.paginate_array(processed_data, total_count: count).page(@page).per(@per_page)
  end

  def pretty_cypher
    return @pretty_cypher if @pretty_cypher

    cypher = query_response[:raw_query].gsub(/^\ +/, '') # get rid of leading whitespace

    query_response[:params].each do |k, v|
      val = v.is_a?(String) ? "\"#{v}\"" : v
      cypher = cypher.gsub("$#{k}", val.to_s)
    end

    @pretty_cypher = cypher
  end

  def query_response
    options = {
      page: @page,
      per: @per_page,
      id_only: true
    }

    @query_response ||= TraitBank::Search.term_search(@query, options)
  end

  private
  DEFAULT_PER_PAGE = 50
  DEFAULT_PAGE = 1

  def counts
    @counts ||= TraitBank::Search.term_search(@query, count: true)
  end

  def process_trait_data(data)
    Trait.for_eol_pks(data)
  end

  def process_page_data(data)
    PageSearchDecorator.decorate_collection(Page.where(id: data).with_hierarchy)
  end
end
