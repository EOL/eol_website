class DataIntegrityCheck::NamedMetadataCandidates
  def run
    query = <<~CYPHER
      MATCH (m:MetaData)-[:predicate]->(p:Term)
      WITH p.uri AS uri, count(*) AS count
      RETURN uri, count
      ORDER BY count DESC
      LIMIT 3
    CYPHER

    result = ActiveGraph::Base.query(query).to_a

    message = <<~HTML
      Top 3 metadata predicates
      <br>
      #{result.map { |r| "#{r[:uri]}: #{r[:count]}" }.join("<br>")}
      <br>
      (This test always passes)
    HTML

    DataIntegrityCheck::Result.new(:passed, message)
  end
end
