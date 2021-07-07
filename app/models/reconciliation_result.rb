class ReconciliationResult
  ManifestType = Struct.new(:id, :name)
  TYPE_TAXON = ManifestType.new("taxon", "Taxon")
  MANIFEST_TYPES = [ReconciliationResult::TYPE_TAXON]
  MAX_SCORE = 100

  def initialize(query_hash)
    @raw_queries = query_hash
    build_results
  end

  def to_h
    @queries.map { |q| [q.key, q.result_hash] }.to_h
  end

  private
  def build_results
    @queries = @raw_queries.map { |k, v| Query.new(k, v) }
    execute_queries
  end

  def execute_queries
    all_queries = []

    # flatten *doesn't* work here -- it will execute each query since they respond to flatten!
    @queries.each do |q| 
      q.all_searchkick_queries.each do |sq|
        all_queries << sq
      end
    end

    Searchkick.multi_search(all_queries)
  end
end

