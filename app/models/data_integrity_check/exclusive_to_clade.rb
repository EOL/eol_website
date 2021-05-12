class DataIntegrityCheck::ExclusiveToClade
  include DataIntegrityCheck::ZeroCountCheck
  include DataIntegrityCheck::HasDetailedReport

  private
  def query
    <<~CYPHER
      MATCH (page:Page)-[:trait]->(trait:Trait),
      (trait)-[:predicate]->(predicate:Term)-[:exclusive_to_clade]->(clade:Page)
      WHERE (page)-[:parent]->(:Page) AND NOT (page)-[:parent*0..]->(clade)
      RETURN count(distinct trait) AS count
    CYPHER
  end

  def detailed_report_query
    <<~CYPHER
      MATCH (page:Page)-[:trait]->(trait:Trait),
      (trait)-[:supplier]->(resource:Resource),
      (trait)-[:predicate]->(predicate:Term)-[:exclusive_to_clade]->(clade:Page)
      WHERE (page)-[:parent]->(:Page) AND NOT (page)-[:parent*0..]->(clade)
      WITH resource.resource_id AS resource_id, predicate.uri AS predicate_uri, count(distinct trait) AS trait_count
      RETURN resource_id, predicate_uri, trait_count
      ORDER BY resource_id, trait_count DESC
    CYPHER
  end

  def build_count_message(count)
    "Found #{count} trait(s) with exclusive_to_clade predicates where the trait's page is not a member of the required clade."
  end
end

