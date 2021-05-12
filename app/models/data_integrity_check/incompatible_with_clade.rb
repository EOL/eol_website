class DataIntegrityCheck::IncompatibleWithClade
  include DataIntegrityCheck::ZeroCountCheck
  include DataIntegrityCheck::HasDetailedReport

  private
  def query
    <<~CYPHER
      MATCH (page:Page)-[:trait]->(trait:Trait),
      (trait)-[:object_term]->(object_term:Term)-[:incompatible_with_clade]->(clade:Page)
      WHERE (page)-[:parent*0..]->(clade)
      RETURN count(distinct trait) AS count
    CYPHER
  end

  def detailed_report_query
    <<~CYPHER
      MATCH (page:Page)-[:trait]->(trait:Trait),
      (trait)-[:supplier]->(resource:Resource),
      (trait)-[:object_term]->(object_term:Term)-[:incompatible_with_clade]->(clade:Page)
      WHERE (page)-[:parent*0..]->(clade)
      WITH resource.resource_id AS resource_id, object_term.uri AS object_uri, count(distinct trait) AS trait_count
      RETURN resource_id, object_uri, trait_count
      ORDER BY resource_id, trait_count DESC
    CYPHER
  end

  def build_count_message(count)
    "Found #{count} trait(s) with incompatible_with_clade object_terms where the trait's page is a member of the incompatible clade"
  end
end

