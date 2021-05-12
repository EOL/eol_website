require 'set'

class Traits::DataViz::TaxonSummary
  attr_reader :parent_nodes, :child_node_count

  def initialize(query)
    results = TraitBank::Stats.taxon_summary_data(query)
    page_ids = Set.new
    results.each do |row|
      page_ids.add(row[:group_taxon_id])
      page_ids.add(row[:taxon_id])
    end

    @child_node_count = results.length

    pages_by_id = Page.where(id: page_ids).map { |p| [p.id, p] }.to_h

    parent_nodes_by_id = {}    

    results.each do |row|
      group_taxon = get_page(pages_by_id, row[:group_taxon_id])
      taxon = get_page(pages_by_id, row[:taxon_id])
      count = row[:count]

      parent_node = parent_nodes_by_id[group_taxon.id]

      if parent_node.nil?
        parent_node = ParentNode.new(group_taxon, query, row[:group_count])
        parent_nodes_by_id[group_taxon.id] = parent_node
      end

      parent_node.add_child(LeafNode.new(taxon, query, count))
    end

    @parent_nodes = parent_nodes_by_id.values
  end

  def to_json
    # d3 requires a root node even though we're going to ignore it
    {
      name: 'root',
      children: @parent_nodes.map { |n| n.to_h }
    }.to_json
  end

  def length
    @parent_nodes.length
  end

  def any?
    @parent_nodes.any?
  end

  private
  def get_page(pages_by_id, page_id)
    raise TypeError, "invalid page id in results: #{page_id}" unless pages_by_id.include?(page_id)

    pages_by_id[page_id]
  end

  class ParentNode
    attr_reader :delegate
    delegate_missing_to :delegate

    def initialize(page, query, count)
      @delegate = Node.new(page, query, count)
    end
  end

  class LeafNode
    attr_reader :delegate
    delegate_missing_to :delegate

    def initialize(page, query, count)
      raise TypeError, "count can't be nil" if count.nil?

      @delegate = Node.new(page, query, count)
    end
  end


  class Node
    attr_reader :page, :children, :count, :query

    def initialize(page, query, count)
      @page = page
      @children = Set.new
      @count = count

      @query = query.deep_dup
      @query.clade = page
    end

    def add_child(node)
      @children.add(node)
    end
  end
end
