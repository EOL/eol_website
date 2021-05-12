class DataIntegrityCheck::ExtinctionStatus
  include DataIntegrityCheck::ZeroCountCheck
  include DataIntegrityCheck::HasDetailedReport

  private
  def query
    <<~CYPHER
      #{common_query}
      RETURN count(DISTINCT p) AS count
    CYPHER
  end

  def build_count_message(count)
    "Found #{count} page(s) with extinction status: extinct plus one or more contradictory records"
  end

  def common_query
    extinction_status_uri = EolTerms.alias_uri('extinction_status')
    conservation_status_uri = EolTerms.alias_uri('conservation_status')
    extinct_uri = EolTerms.alias_uri('iucn_ex')
    extant_uri = EolTerms.alias_uri('extant')
    
    
   <<~CYPHER
      MATCH (p:Page)-[:trait|inferred_trait]->(trait:Trait),
      (trait)-[:predicate]->(:Term{ uri: '#{extinction_status_uri}' }),
      (trait)-[:object_term]->(:Term{ uri: '#{extinct_uri}' })
      OPTIONAL MATCH (p)-[:trait]->(other_trait1:Trait),
      (other_trait1)-[:predicate]->(:Term{ uri: '#{extinction_status_uri}' }),
      (other_trait1)-[:object_term]->(:Term{ uri: '#{extant_uri }' }) 
      OPTIONAL MATCH (p)-[:trait]->(other_trait2:Trait),
      (other_trait2)-[:predicate]->(:Term{ uri: '#{conservation_status_uri}' })
      WHERE NOT (other_trait2)-[:object_term]->(:Term{ uri: '#{extinct_uri }' })
      WITH p, other_trait1, other_trait2
      WHERE other_trait1 IS NOT NULL OR other_trait2 IS NOT NULL
    CYPHER
  end

  def detailed_report_query
    <<~CYPHER
      #{common_query}
      RETURN DISTINCT p.page_id AS page_id
    CYPHER
  end
end
