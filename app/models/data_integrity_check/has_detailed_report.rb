module DataIntegrityCheck::HasDetailedReport
  #including classes must implement detailed_report_query method
 
  def detailed_report
    limited_query = <<~CYPHER
      #{detailed_report_query}
      LIMIT 100
    CYPHER

    params = respond_to?(:query_params, true) ? query_params : {}
    result = ActiveGraph::Base.query(limited_query, params).to_a

    display_result = result.map do |r|
      '[' + r.keys.map { |k| r[k] }.join(', ') + ']'
    end.join("\n")

    <<~END
      Query:
      #{limited_query}
      
      Result:
      #{display_result}
    END
  end
end
