class MetadataNode
  include ActiveGraph::Node

  self.mapped_label_name = 'MetaData'

  id_property :eol_pk
  property :measurement
  property :sample_size
  property :citation
  property :source
  property :remarks
  property :method
  property :literal
  property :scientific_name

  has_one :out, :predicate, type: :predicate, model_class: :TermNode
  has_one :out, :object_term, type: :object_term, model_class: :TermNode
  has_one :out, :units_term, type: :units_term, model_class: :TermNode
  has_one :out, :lifestage_term, type: :lifestage_term, model_class: :TermNode
  has_one :out, :statistical_method_term, type: :statistical_method_term, model_class: :TermNode
  has_one :out, :sex_term, type: :sex_term, model_class: :TermNode
  has_one :out, :object_page, type: :object_page, model_class: :PageNode
  has_one :in, :page, type: :trait, model_class: :PageNode
  has_one :out, :resource, type: :supplier, model_class: :ResourceNode
  has_one :in, :trait, type: :metadata, model_class: :TraitNode
end

