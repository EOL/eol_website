class PageNode
  include ActiveGraph::Node

  id_property :page_id
  property :descendant_count, default: 0
  property :obj_trait_count, default: 0
  property :obj_trait_distinct_subj_count, default: 0
  property :subj_trait_row_count, default: 0
  property :subj_trait_distinct_obj_count, default: 0

  self.mapped_label_name = 'Page'
  # NOTE: There's no activegraph support for multiple types, e.g., :trait|:inferred_trait, so 
  # you have to query manually if you want both types.
  has_many :out, :traits, type: :trait, model_class: :TraitNode
  has_many :out, :inferred_traits, type: :inferred_trait, model_class: :TraitNode

  def trait_resource_ids
    Rails.cache.fetch("page_node/#{id}/trait_resource_ids") do
      query_as(:page)
        .break
        .optional_match(
          '(page)-[:trait|:inferred_trait]->(trait:Trait)',
          '(trait)-[:supplier]->(resource:Resource)'
        )
        .with('page, collect(DISTINCT resource) AS subj_resources')
        .optional_match(
          '(trait:Trait)-[:object_page]->(page)',
          '(trait)-[:supplier]->(resource:Resource)'
        )
        .with('collect(DISTINCT resource) + subj_resources AS resources')
        .unwind('resources AS resource')
        .with('DISTINCT resource.resource_id AS resource_id')
        .where('resource_id IS NOT NULL')
        .pluck(:resource_id)
    end
  end
end

