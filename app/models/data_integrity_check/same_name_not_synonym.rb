# checks for Terms with the same name that are not direct synonyms of each other
class DataIntegrityCheck::SameNameNotSynonym
  include DataIntegrityCheck::ZeroCountCheck  
  include DataIntegrityCheck::HasPairUriDetailedReport

  private
  def query_common
    <<~CYPHER
      MATCH (t1:Term), (t2:Term)
      WHERE t1 <> t2 aND t1.name = t2.name AND NOT (t1)-[:synonym_of]->(t2) AND NOT (t2)-[:synonym_of]->(t1)
      AND NOT (t2)-[:synonym_of]->(:Term)<-[:synonym_of]-(t1)
      AND t1.eol_id < t2.eol_id
      WITH DISTINCT t1, t2
    CYPHER
  end

  def query
    <<~CYPHER
      #{query_common}
      RETURN count(*) AS count
    CYPHER
  end

  def build_count_message(count)
    "Found #{count} pair(s) of terms with the same name that aren't direct synonyms of each other."
  end
end
