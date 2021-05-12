class DataIntegrityCheck::MigratedMetadata
  include DataIntegrityCheck::ZeroCountCheck
  include DataIntegrityCheck::HasDetailedReport

  MIGRATED_URIS = [
    "http://rs.tdwg.org/dwc/terms/measurementUnit",
    "http://eol.org/schema/terms/statisticalMethod",
    "http://rs.tdwg.org/dwc/terms/lifeStage",
    "http://rs.tdwg.org/dwc/terms/sex",
    "http://rs.tdwg.org/dwc/terms/measurementRemarks",
    "http://rs.tdwg.org/dwc/terms/measurementMethod",
    "http://eol.org/schema/terms/SampleSize",
    "http://purl.org/dc/terms/source",
    "http://purl.org/dc/terms/bibliographicCitation",
  ]

  private
  def query
    <<~CYPHER
      #{common_query}
      RETURN count(*) AS count
    CYPHER
  end

  def query_params
    { migrated_uris: MIGRATED_URIS }
  end

  def build_count_message(count)
    "Found #{count} metadata with predicates that should be named relationships and/or attributes."
  end

  def common_query
    <<~CYPHER
      MATCH (m:MetaData)-[:predicate]->(predicate:Term)
      WHERE predicate.uri IN $migrated_uris
    CYPHER
  end

  def detailed_report_query
    <<~CYPHER
      MATCH (r:Resource)<-[:supplier]-(t:Trait)-[:metadata]->(m:MetaData),
      (m)-[:predicate]->(p:Term)
      WHERE p.uri IN $migrated_uris
      WITH r.resource_id AS resource_id, p.uri AS uri, count(distinct m) AS count
      RETURN resource_id, uri, count
      ORDER BY count DESC
    CYPHER
  end
end
