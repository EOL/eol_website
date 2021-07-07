# Bridge between TraitNodes and their associated ActiveRecord models (e.g., Page, Resource)
# Efficiently loads these associated models in batches.
# TODO: should this live in app/models or lib? It behaves like a model (and is intended to be used as such), so maybe this is the right place?
class Trait
  DEFAULT_INCLUDES = [
    :predicate, 
    :object_term, 
    :units_term, 
    :lifestage_term, 
    :statistical_method_term, 
    :sex_term, 
    :object_page, 
    :page, 
    :resource
  ]

  attr_accessor :trait_node
  delegate_missing_to :trait_node

  def initialize(trait_node, record_assocs)
    @trait_node = trait_node
    @record_assocs = record_assocs
  end

  private_class_method :new # use for_eol_pks

  # TODO: can/should these be generalized?
  def resource
    @resource ||= @record_assocs.resource(@trait_node.resource&.resource_id)
  end

  def page
    @page ||= @record_assocs.page(@trait_node.page&.page_id)
  end

  def object_page
    @object_page ||= @record_assocs.page(@trait_node.object_page&.page_id)
  end

  # Not eager-loaded
  def inferred_pages
    @inferred_pages = Page.where(id: @trait_node.inferred_pages.map { |p| p.id })
  end

  class << self
    def find(eol_pk, options = {})
      wrap_node(TraitNode.find(eol_pk))
    end

    # Factory method
    def for_eol_pks(eol_pks, options = {})
      nodes = TraitNode.where(eol_pk: eol_pks)
        .with_associations(options[:includes] || DEFAULT_INCLUDES)

      record_assocs = RecordAssociations.new(nodes)
      nodes.map { |n| new(n, record_assocs) }
    end
    
    def wrap_node(trait_node)
      return nil if trait_node.nil?
      new(trait_node, RecordAssociations.new([trait_node]))
    end

    def populate_pk_result(result, options = {})
      result_a = result.to_a
      traits_by_id = for_eol_pks(result_a.map { |row| row[:trait_pk] }, options).map { |t| [t.id, t] }.to_h
      value = result_a.map do |row|
        row_h = row.to_h
        row_h[:trait] = traits_by_id[row[:trait_pk]]
        row_h
      end

      value
    end
  end
  # end class << self

  private

  class RecordAssociations
    def initialize(trait_nodes)
      @trait_nodes = trait_nodes
    end

    def resource(id)
      return nil if id.nil?

      @resources ||= Resource.where(id: @trait_nodes.map { |t| t.resource&.resource_id }.uniq)
        .map { |r| [r.id, r] }.to_h

      @resources[id]
    end

    def page(id)
      return nil if id.nil?

      unless @pages
        page_ids = []

        @trait_nodes.each do |t|
          page_ids << t.page.id if t.page
          page_ids << t.object_page.id if t.object_page
        end

        @pages = Page.where(id: page_ids.uniq).map { |p| [p.id, p] }.to_h
      end

      @pages[id]
    end

  end
  # end private
end
