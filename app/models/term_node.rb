class TermNode
  include ActiveGraph::Node
  include Autocomplete

  self.mapped_label_name = 'Term'

  property :name
  property :definition
  property :distinct_page_count, default: 0
  property :comment
  property :attribution
  property :is_hidden_from_overview
  property :is_hidden_from_glossary
  property :position
  property :trait_row_count, default: 0
  property :type
  property :uri
  property :is_ordinal
  id_property :eol_id


  has_many :in, :children, type: :parent_term, model_class: :TermNode
  has_many :out, :parents, type: :parent_term, model_class: :TermNode
  has_many :out, :synonyms, type: :synonym_of, model_class: :TermNode
  has_one :out, :units_term, type: :units_term, model_class: :TermNode
  has_one :in, :trait, type: :predicate, model_class: :TraitNode
  has_one :in, :metadata, type: :predicate, model_class: :MetadataNode

  scope :not_synonym, -> (label) { as(label).where_not("(#{label})-[:synonym_of]->(:Term)") }

  autocompletes "autocomplete_name"

  @text_search_fields = %w[name]
  searchkick word_start: @text_search_fields, text_start: @text_search_fields, merge_mappings: true, mappings: {
    properties: autocomplete_searchkick_properties
  }

  OBJ_TERM_TYPE = "value"

  class << self
    def search_import
      self.all(:t).where("t.is_hidden_from_overview = false AND NOT (t)-[:synonym_of]->(:Term)")
    end
  end

  def search_data
    {
      name: name
    }.merge(autocomplete_name_fields)
  end

  def autocomplete_name_fields
    I18n.available_locales.collect do |locale|
      [:"autocomplete_name_#{locale}", i18n_name(locale)]
    end.to_h
  end

  def i18n_name(locale = I18n.locale)
    TraitBank::Record.i18n_name_for_locale({
      uri: uri,
      name: name
    }, locale)
  end

  def i18n_definition
    TraitBank::Record.i18n_defn({
      uri: uri,
      definition: definition
    })
  end

  def predicate?
    !object_term?   
  end

  def object_term?
    type == OBJ_TERM_TYPE
  end

  def known_type?
    predicate? || object_term?
  end

  def numeric_value_predicate?
    is_ordinal || units_term.present?
  end
end

