class PageStatUpdater
  BATCH_SIZE = 100
  
  class << self
    def run
      batch = 0
      page_count = PageNode.query_as(:p).where('(:Page)-[:parent*2]->(p)').count('distinct p')
      num_batches = page_count / BATCH_SIZE
      num_batches += BATCH_SIZE if page_count % BATCH_SIZE > 0
      time_elapsed = 0

      while batch < num_batches # batch starts at 0, hence <
        start = Time.now
        puts "Updating page batch #{batch + 1} / #{num_batches} (x #{BATCH_SIZE})"
        update_batch(batch)
        batch += 1
        time_elapsed += (Time.now - start)
        avg = time_elapsed / (batch + 1)
        minutes_remain = (num_batches - batch - 1) * avg / 60
        time_remain_str = minutes_remain > 60 ? "#{minutes_remain / 60} hours" : "#{minutes_remain} minutes"
        puts "Estimated time remaining: #{time_remain_str}"
      end 
    end

    private
    def page_batch_part(batch)
      %Q(
        MATCH (anc:Page)
        WHERE (:Page)-[:parent*2]->(anc)
        WITH anc
        ORDER BY anc.page_id
        SKIP #{batch * BATCH_SIZE}
        LIMIT #{BATCH_SIZE}
        MATCH (p:Page)-[:parent*0..]->(anc)
      )
    end

    # TODO: Add count of distinct objects for subject traits
    def update_batch(batch)
      update_subj_trait_stats(batch)
      update_obj_trait_stats(batch)
    end

    def update_subj_trait_stats(batch)
      ActiveGraph::Base.query(%Q(
        #{page_batch_part(batch)}
        OPTIONAL MATCH trait_row=(p)-[:trait|inferred_trait]->(trait:Trait)
        OPTIONAL MATCH (trait)-[:object_page]->(obj:Page)
        WITH anc, count(distinct p) AS desc_count, collect(distinct trait_row) AS trait_rows, collect(distinct obj) as objs
        UNWIND trait_rows AS trait_row
        WITH anc, desc_count, sum(CASE WHEN trait_row IS NULL THEN 0 ELSE 1 END) AS trait_row_count, objs
        UNWIND objs AS obj
        WITH anc, desc_count, trait_row_count, sum(CASE WHEN obj IS NULL THEN 0 ELSE 1 END) AS obj_count
        SET anc.descendant_count = desc_count
        SET anc.subj_trait_row_count = trait_row_count
        SET anc.subj_trait_distinct_obj_count = obj_count
      ))
    end

    def update_obj_trait_stats(batch)
      ActiveGraph::Base.query(%Q(
        #{page_batch_part(batch)}
        OPTIONAL MATCH (subj:Page)-[:trait|inferred_trait]->(trait:Trait)-[:object_page]->(p)
        WITH anc, collect(distinct trait) AS traits, collect(distinct subj) AS subjs
        UNWIND traits AS trait
        WITH anc, sum(CASE WHEN trait IS NULL THEN 0 ELSE 1 END) AS trait_count, subjs
        UNWIND subjs AS subj
        WITH anc, trait_count, sum(CASE WHEN subj IS NULL THEN 0 ELSE 1 END) AS subj_count
        SET anc.obj_trait_count = trait_count
        SET anc.obj_trait_distinct_subj_count = subj_count
      ))
    end
  end
end

