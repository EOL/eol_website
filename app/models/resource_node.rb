class ResourceNode
  include ActiveGraph::Node

  self.mapped_label_name = 'Resource'

  id_property :resource_id
  validates :resource_id, numericality: { only_integer: true, greater_than: 0 }
  before_save :ensure_int_resource_id

  has_one :in, :trait, type: :supplier, model_class: :Trait

  def resource
    Resource.find(id)
  end

  private
  # NOTE: ideally, we'd be able to pass the type option to id_property like any other property, but that's not currently possible. See https://github.com/neo4jrb/activegraph/issues/1388.
  def ensure_int_resource_id
    self.resource_id = resource_id.to_i
  end
end
