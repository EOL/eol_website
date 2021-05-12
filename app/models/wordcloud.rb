class Wordcloud
  def initialize(page, predicate)
    @result = page.page_node.query_as(:page)
      .match(
        '(page)-[:trait|inferred_trait]->(trait:Trait)', 
        '(trait)-[:predicate]->(predicate:Term)', 
        '(trait)-[:object_term]->(object:Term)'
      )
      .where('predicate.eol_id': predicate.id)
      .return('object.name AS name', 'count(distinct trait) AS count').to_a
  end

  def length
    @result.length
  end

  def to_json
    @json ||= @result.map do |row|
      {
        text: row[:name],
        weight: row[:count]
      }
    end.to_json
  end
end
