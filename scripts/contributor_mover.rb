class ContributorMover
  BATCH_SIZE = 10_000
  CONTRIB_URI = "http://purl.org/dc/terms/contributor"

  class << self
    def run
      continue = true
      batch = 0

      while continue
        puts "processing batch #{batch}"
        count = ActiveGraph::Base.query(query, pred_uri: CONTRIB_URI).first[:count]
        continue = count == BATCH_SIZE
        batch += 1
      end

      puts "done"
    end

    def query
      <<~CYPHER
        MATCH (t:Trait)-[:metadata]->(m:MetaData)-[:predicate]->(:Term{ uri: $pred_uri }),
        (m)-[:object_term]->(c:Term)
        WITH t, m, c
        LIMIT #{BATCH_SIZE}
        DETACH DELETE m
        CREATE (t)-[:contributor]->(c)
        RETURN count(m) AS count
      CYPHER
    end
  end
end

ContributorMover.run

