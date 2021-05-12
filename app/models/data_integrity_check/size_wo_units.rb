class DataIntegrityCheck::SizeWoUnits
  include DataIntegrityCheck::ZeroCountCheck
  include DataIntegrityCheck::HasDetailedReport

  private
  def detailed_report_query
    <<~CYPHER
      #{common_query}
      RETURN trait.eol_pk AS trait_pk, predicate.name AS predicate_name, predicate.uri AS predicate_uri
    CYPHER
  end

  def common_query
    size_uri = EolTerms.alias_uri('size')

    <<~CYPHER
      MATCH (trait:Trait)-[:predicate]->(predicate:Term)-[:parent_term|synonym_of*1..]->(:Term{ uri: '#{size_uri}' })
      WHERE NOT (trait)-[:units_term]->(:Term)
    CYPHER
  end

  def query
    <<~CYPHER
      #{common_query}
      RETURN count(DISTINCT trait) AS count
    CYPHER
  end

  def build_count_message(count)
    "Found #{count} trait(s) with predicates descended from 'size' that don't have units."
  end
end
