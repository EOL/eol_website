module DataIntegrityCheck::HasPairUriDetailedReport
  include DataIntegrityCheck::HasDetailedReport

  def detailed_report_query
    <<~CYPHER
      #{query_common}
      RETURN t1.uri AS uri1, t2.uri AS uri2
    CYPHER
  end
end
