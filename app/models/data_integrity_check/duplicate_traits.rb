class DataIntegrityCheck::DuplicateTraits
	BATCH_SIZE = 10_000

  def run
		page_count = PageNode.count		
		batch = 0
		total = 0

		while batch * BATCH_SIZE < page_count
			result = batch_query(batch, BATCH_SIZE)
			total += (result[:count] || 0)
			batch += 1
		end

		status = total == 0 ? :passed : :failed
		DataIntegrityCheck::Result(status, "Found #{total} pairs of identical or too-similar trait(s)")
  end

  private
	def batch_query(batch, limit)
    query = %{
			MATCH (page:Page)
			WITH page
			ORDER BY page.page_id ASC
			LIMIT $limit
			SKIP $skip	
			MATCH (t1:Trait)<-[:trait]-(page)-[:trait]->(t2:Trait),
			(t1)-[:supplier]->(:Resource)<-[:supplier]-(t2),
			(t1)-[:predicate]->(:Term)<-[:predicate]-(t2)
			WHERE t1 <> t2
			AND ((t1)-[:object_term]->(:Term)<-[:object_term]-(t2) OR (NOT (t1)-[:object_term]->(:Term) AND NOT (t2)-[:object_term]->(:Term)))
			AND ((t1)-[:sex_term]->(:Term)<-[:sex_term]-(t2) OR (NOT (t1)-[:sex_term]->(:Term) AND NOT (t2)-[:sex_term]->(:Term)))
			AND ((t1)-[:lifestage_term]->(:Term)<-[:lifestage_term]-(t2) OR (NOT (t1)-[:lifestage_term]->(:Term) AND NOT (t2)-[:lifestage_term]->(:Term)))
			AND ((t1)-[:statistical_method_term]->(:Term)<-[:statistical_method_term]-(t2) OR (NOT (t1)-[:statistical_method_term]->(:Term) AND NOT (t2)-[:statistical_method_term]->(:Term)))
			AND apoc.map.removeKey(properties(t1), 'eol_pk') = apoc.map.removeKey(properties(t2), 'eol_pk')
			WITH DISTINCT t1, t2
			RETURN count(*) / 2 AS count
		}

		ActiveGraph::Base.query(query, limit: limit, skip: batch * limit).to_a.first
	end
end
