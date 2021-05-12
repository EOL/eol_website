require "set"

# represents Sankey chart shown on certain trait search result pages
class Traits::DataViz::Sankey
  MAX_NODES_PER_AXIS = 10

  attr_reader :nodes, :links, :max_axis_nodes

  class << self
    def create_from_query(query, total_taxa)
      results = TraitBank::Stats.sankey_data(query)
      self.new(results, query, total_taxa)
    end

    def result_id_key(i)
      :"anc_obj#{i}_id"
    end
  end

  def multiple_paths?
    @links.length >= @num_axes 
  end

  private
  def initialize(query_results, query, total_taxa)
    @query = query
    @num_axes = query.filters.length
    @total_taxa = total_taxa

    query_obj_terms = Set.new(query.filters.map { |f| f.object_term }.reject { |t| t.nil? })

    result_term_ids = query_results.map do |r|
      query.filters.map.with_index do |_, i|
        r[self.class.result_id_key(i)]
      end
    end.flatten.uniq
    result_terms = TermNode.where(id: result_term_ids)
    result_terms_by_id = result_terms.map { |t| [t.id, t] }.to_h

    result_rows = query_results.map { |r| ResultRow.new(r, query, result_terms_by_id, query_obj_terms) }
    nodes_per_axis = build_nodes_per_axis(result_rows)
    @max_axis_nodes = nodes_per_axis.max { |a, b| a.length <=> b.length }.length
    @nodes = nodes_per_axis.flatten
    other_nodes = build_other_nodes_per_axis(result_rows, nodes_per_axis) 
    @nodes.concat(other_nodes)
    @links = build_links(result_rows)
  end

  # Get the MAX_NODES_PER_AXIS nodes with the greatest # pages per axis, merging the 
  # sets of pages belonging to result rows containing the same nodes
  def build_nodes_per_axis(rows)
    distinct_nodes_per_axis = Array.new(@num_axes) { {} }

    rows.each do |r|
      r.nodes.each_with_index do |n, i|
        next if n.query_term? # skip these for now -- they're added later and shouldn't belong to the top nodes

        existing = distinct_nodes_per_axis[i][n]

        if existing
          existing.merge(n)
        else
          distinct_nodes_per_axis[i][n] = n
        end
      end
    end

    distinct_nodes_per_axis.map do |nodes|
      nodes.values.sort { |a, b| b.size <=> a.size }[0..MAX_NODES_PER_AXIS]
    end
  end

  # Build catchall nodes for page ids that don't belong to one of the chosen nodes per axis, and update
  # the result rows that contain them accordingly
  def build_other_nodes_per_axis(results, nodes_per_axis)
    other_nodes_per_axis = Array.new(@num_axes, nil)
    page_ids_per_axis = build_page_ids_per_axis(nodes_per_axis)

    results.each do |r|
      r.nodes = r.nodes.map.with_index do |n, i|
        matching_node = nodes_per_axis[i].find { |m| m == n }

        if matching_node
          matching_node
        else
          other_node = Node.new(
            @query.filters[i].object_term,
            i,
            r.page_ids, 
            true,
            @query
          )
          other_node.remove_page_ids(page_ids_per_axis[i])
          r.remove_page_ids(page_ids_per_axis[i])

          if other_nodes_per_axis[i]
            other_nodes_per_axis[i].merge(other_node)
          else
            other_nodes_per_axis[i] = other_node
          end

          other_nodes_per_axis[i]
        end
      end
    end

    results.reject! { |r| r.empty? }
    other_nodes_per_axis.reject { |n| n.nil? || n.empty? }
  end

  def build_page_ids_per_axis(nodes_per_axis)
    nodes_per_axis.map do |nodes|
      page_ids = Set.new

      nodes.each do |node|
        page_ids.merge(node.page_ids)
      end

      page_ids
    end
  end

  def build_links(results)
    links = {}

    results.each do |r|
      prev_node = nil

      r.nodes.each do |n|
        if prev_node
          link = Link.new(
            prev_node, 
            n, 
            r.page_ids
          )

          existing_link = links[link]

          if existing_link
            existing_link.merge(link)
          else
            links[link] = link
          end
        end

        prev_node = n
      end
    end

    links.values
  end

  class ResultRow
    attr_reader :page_ids
    attr_accessor :nodes

    def initialize(row, query, result_terms_by_id, query_obj_terms)
      @page_ids = Set.new(row[:page_ids])
      @nodes = Array.new(query.filters.length)

      query.page_count_sorted_filters.each_with_index do |f, i|
        result_id = row[Traits::DataViz::Sankey.result_id_key(i)]
        result_term = result_terms_by_id[result_id]
        node_query = query.deep_dup
        search_order_index = query.filters.find_index(f) # order of axes should match original user search
        node_query.filters[search_order_index].object_term = result_term 

        @nodes[search_order_index] = Node.new(
          result_term,
          search_order_index,
          @page_ids,
          query_obj_terms.include?(result_term),
          node_query
        )
      end
    end

    def size
      @page_ids.size
    end

    def empty?
      @page_ids.empty?
    end

    def any_query_terms?
      !!(@nodes.find { |n| n.query_term? })
    end

    def query_term_nodes
      @nodes.filter { |n| n.query_term? }
    end

    def remove_page_ids(to_remove)
      @page_ids.subtract(to_remove)
    end
  end

  class Node
    attr_reader :term, :axis_id, :page_ids, :query

    def initialize(term, axis_id, page_ids, is_query_term, query)
      @term = term
      @axis_id = axis_id
      @is_query_term = is_query_term
      @query = query
      @page_ids = Set.new(page_ids)
    end

    def merge(other)
      @page_ids.merge(other.page_ids)
    end

    def query_term?
      @is_query_term
    end

    def size
      @page_ids.length
    end

    def empty?
      @page_ids.empty?
    end

    def add_page_ids(other)
      @page_ids.merge(other)
    end

    def remove_page_ids(other)
      @page_ids.subtract(other)
    end

    def id
      "#{@term.id}-#{@axis_id}"
    end

    def ==(other)
      self.class === other and
        other.term.id == @term.id and
        other.axis_id == @axis_id
    end

    alias eql? ==

    def hash
      @term.id.hash ^ @axis_id.hash
    end
  end

  class Link
    attr_reader :source, :target, :page_ids

    def initialize(source, target, page_ids)
      @source = source
      @target = target
      @page_ids = Set.new(page_ids)
    end

    def merge(other)
      @page_ids.merge(other.page_ids)
    end

    def add_page_ids(new_page_ids)
      @page_ids.merge(new_page_ids)
    end

    def size
      @page_ids.size
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
