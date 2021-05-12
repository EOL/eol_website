class DataIntegrityCheck::TermAncestryHeight
  include DataIntegrityCheck::HasDetailedReport

  def run
    query = <<~CYPHER
      #{query_common}
      RETURN max(min_length) AS height
    CYPHER

    height = ActiveGraph::Base.query(query).to_a.first[:height]

    DataIntegrityCheck::Result.new(
      :passed, 
      "The height of the Term ancestry (max shortest path from an ancestor to a descendant) is #{height}. This test always passes."
    )
  end

  def self.show_detailed_report_on_pass?
    true
  end

  private

  def detailed_report_query
    <<~CYPHER
      MATCH p = (t1:Term)-[:parent_term|synonym_of*1..]->(t2:Term)
      WHERE t1 <> t2
      WITH t1, t2, collect(p) AS paths, min(length(p)) AS min_length
      WITH collect({ paths: paths, min_length: min_length }) AS rows, max(min_length) AS max
      UNWIND rows AS row
      WITH row.paths AS paths, row.min_length AS min_length, max
      WHERE min_length = max
      UNWIND paths AS path
      WITH path, min_length, max
      WHERE length(path) = min_length
      WITH path, nodes(path) AS terms
      UNWIND terms AS term
      WITH path, collect(term.name) AS term_names
      WITH DISTINCT term_names
      RETURN term_names
    CYPHER
  end

  def query_common
    <<~CYPHER
      MATCH p = (t1:Term)-[:parent_term|synonym_of*1..]->(t2:Term)
      WHERE t1 <> t2
      WITH t1, t2, min(length(p)) AS min_length
    CYPHER
  end
end
