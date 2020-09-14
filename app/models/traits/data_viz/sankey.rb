require "set"

# represents Sankey chart shown on certain trait search result pages
class Traits::DataViz::Sankey
  MAX_NODES_PER_AXIS = 10

  attr_reader :nodes, :links

  class << self
    def create_from_query(query)
      results = TraitBank::Stats.sankey_data(query)
      self.new(results, query)
    end
  end

  private
  def initialize(query_results, query)
    qt_results = []
    other_results = []

    query_results.each do |r|
      result_row = ResultRow.new(r, query)

      if result_row.any_query_terms?
        qt_results << result_row
      else
        other_results << result_row
      end
    end

    results = merge_and_sort_results(qt_results, other_results)
    build_nodes_and_links(results, query)
  end

  def merge_and_sort_results(qt_results, other_results)
    fix_qt_result_page_ids(qt_results, other_results)
    results = qt_results + other_results
    results.sort { |a, b| b.page_ids.length <=> a.page_ids.length } 
    results
  end

  def fix_qt_result_page_ids(qt_results, other_results)
    other_page_ids = Set.new
    other_results.each do |r| 
      other_page_ids.merge(r.page_ids)
      r.add_page_ids_to_nodes
    end

    qt_results.each do |r|
      r.remove_page_ids(other_page_ids) 
      r.add_page_ids_to_nodes
    end
  end

  def build_nodes_and_links(results, query)
    links = Hash.new # used to keep track of a single 'canonical' link per pair of nodes (see comment about equality/hash in Link)
    nodes_per_axis = Array.new(query.filters.length) { |_| Hash.new } # same here, except per-axis

    results.each do |r|
      prev_node = false
      result_links = Array.new(query.filters.length, false)

      query.page_count_sorted_filters.each_with_index do |f, i|
        node = r.nodes[i]

        if node
          if prev_node
            result_links[i] = Link.new(prev_node, node, r.page_ids)
          end

          prev_node = node
        end
      end

      add_nodes_and_links(result_links, nodes_per_axis, links)
    end

    @nodes = nodes_per_axis.map { |node_hash| node_hash.values }.flatten
    @links = links.values
  end

  def add_nodes_and_links(result_links, nodes_per_axis, links)
    result_links.each_with_index do |link, i|
      if link
        canonical_source = nodes_per_axis[link.source.axis_id][link.source]
        canonical_target = nodes_per_axis[link.target.axis_id][link.target]

        if (
          (canonical_source || nodes_per_axis[link.source.axis_id].length < MAX_NODES_PER_AXIS) &&
          (canonical_target || nodes_per_axis[link.target.axis_id].length < MAX_NODES_PER_AXIS)
        )
          merge_or_add_node(canonical_source, link.source, nodes_per_axis)
          merge_or_add_node(canonical_target, link.target, nodes_per_axis)
          merge_or_add_link(link, links)
        end
      end
    end
  end

  def merge_or_add_node(existing_node, node, nodes_per_axis)
    if existing_node
      merge(existing_node, node)
    else
      nodes_per_axis[node.axis_id][node] = node
    end
  end

  def merge_or_add_link(link, links)
    existing = links[link]

    if existing
      merge(existing, link)
    else
      links[link] = link
    end
  end

  def merge(canonical, other)
    canonical.add_page_ids(other.page_ids)
  end

  class ResultRow
    attr_reader :nodes, :page_ids

    def initialize(row, query)
      query_uris = Set.new(query.filters.map { |f| f.obj_uri })

      @nodes = []
      @page_ids = Set.new(row[:page_ids])

      query.page_count_sorted_filters.each_with_index do |_, i|
        uri_key = :"child#{i}_uri"
        node_query = query.deep_dup
        node_query.page_count_sorted_filters[i].obj_uri = row[uri_key]

        node = Node.new(
          row[uri_key], 
          i,
          query_uris.include?(row[uri_key]),
          node_query
        )

        # Due to the fact that some terms have multiple parents, it's possible that a term will
        # appear in multiple result columns. This breaks the graph display, so only include a given
        # term in a single column (the first one in which it appears)
        if @nodes.include?(node) 
          @nodes << false
        else
          @nodes << node
        end
      end
    end

    def any_query_terms?
      !!(@nodes.find { |n| n.query_term? })
    end

    def remove_page_ids(to_remove)
      @page_ids.subtract(to_remove)
    end

    def add_page_ids_to_nodes
      @nodes.each { |n| n.add_page_ids(@page_ids) if n }
    end
  end

  class Node
    attr_reader :uri, :axis_id, :page_ids, :query

    def initialize(uri, axis_id, is_query_term, query)
      @uri = uri
      @axis_id = axis_id
      @is_query_term = is_query_term
      @query = query
    end

    def query_term?
      @is_query_term
    end

    def size
      @page_ids.length
    end

    def add_page_ids(other)
      @page_ids ||= Set.new
      @page_ids.merge(other)
    end

    def ==(other)
      self.class === other and
        other.uri == @uri
    end

    alias eql? ==

    def hash
      @uri.hash
    end
  end

  class Link
    attr_reader :source, :target, :page_ids

    def initialize(source, target, page_ids)
      @source = source
      @target = target
      @page_ids = page_ids
    end

    def add_page_ids(new_page_ids)
      @page_ids.merge(new_page_ids)
    end

    def size
      @page_ids.length
    end

    # page ids are not considered for equality/hash due to how this class is used
    def ==(other)
      self.class === other and
        other.source == @source and
        other.target == @target
    end

    alias eql? ==

    def hash
      @source.hash ^ @target.hash
    end
  end
end
