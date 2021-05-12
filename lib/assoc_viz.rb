class AssocViz
  MAX_PAGES = 200
  MIN_PAGES = 5 

  def initialize(query, helpers, breadcrumb_type)
    @query = query
    @helpers = helpers
    result = TraitBank::Stats.assoc_data(query)
    @allow_clicks = result.rank != :species
    result_data = result.data
    page_ids = Set.new
    obj_page_id_map = {}

    result_data.each do |row|
      subj_page_id = row[:subj_group_id]
      obj_page_id = row[:obj_group_id]
      page_ids.add(subj_page_id)
      page_ids.add(obj_page_id)
      obj_page_id_map[subj_page_id] ||= []
      obj_page_id_map[subj_page_id] << obj_page_id
    end

    if page_ids.length > MAX_PAGES || page_ids.length < MIN_PAGES 
      @should_display = false
    else
      @should_display = true

      pages = Page.includes(native_node: { node_ancestors: { ancestor: :page }}).where(id: page_ids)
      page_ancestors = pages.map do |p|
        p.node_ancestors.map { |a| a.ancestor.page }.concat([p])
      end
      @root_node = build_page_hierarchy(page_ids, obj_page_id_map, page_ancestors, breadcrumb_type)

      pages_by_id = pages.map { |p| [p.id, p] }.to_h
      seen_pair_ids = Set.new
      @data = result_data.map do |row|
        subj_group = page_hash(row, :subj_group_id, pages_by_id)
        obj_group = page_hash(row, :obj_group_id, pages_by_id)

        pair_id = [subj_group[:page_id], obj_group[:page_id]].sort.join('_')

        next nil if seen_pair_ids.include?(pair_id) # arbitrarily drop one half of circular relationships

        seen_pair_ids.add(pair_id)
        
        {
          subjGroup: subj_group,
          objGroup: obj_group
        }
      end.compact
    end
  end

  def should_display?
    @should_display
  end

  def to_json
    {
      rootNode: @root_node.to_h,
      allowClicks: @allow_clicks
    }.to_json
  end

  private
  class Node
    attr_accessor :page, :children
    def initialize(page, query, helpers, breadcrumb_type)
      @page = page
      @children = Set.new
      @obj_page_ids = Set.new
      @breadcrumb_type = breadcrumb_type
      @base_query = query
      @helpers = helpers
    end

    def add_child(node)
      @children.add(node)
    end

    def has_child?(node)
      @children.include?(node)
    end

    def add_obj_page_ids(obj_page_ids)
      @obj_page_ids.merge(obj_page_ids)
    end

    def search_path
      query = @base_query.deep_dup

      if @obj_page_ids.any?
        query.clade = @page
      else
        query.filters.first.obj_clade = @page
      end

      @helpers.term_search_results_path(tq: query.to_short_params)
    end

    def to_h
      children_h = @children.map { |c| c.to_h }

      {
        pageId: @page.id,
        name: @breadcrumb_type == BreadcrumbType.vernacular ? @page.vernacular_or_canonical : @page.canonical,
        children: children_h,
        objPageIds: @obj_page_ids.to_a,
        searchPath: search_path
      }
    end
  end

  def page_hash(row, key, pages)
    id = row[key]
    page = pages[id]

    {
      page_id: id,
      name: page.name
    }
  end

  def build_page_hierarchy(all_page_ids, obj_page_id_map, page_ancestors, breadcrumb_type)
    root_node = nil

    page_ancestors.each_with_index do |ancestry|
      page_root_node = Node.new(ancestry.first, @query, @helpers, breadcrumb_type)
      cur_node = page_root_node

      ancestry[1..].each_with_index do |page, i|
        prev_node = cur_node
        cur_node = Node.new(page, @query, @helpers, breadcrumb_type)

        if i == ancestry.length - 2 # leaf node is last element, - 2 because this is a slice starting at 1
          obj_page_ids = obj_page_id_map[page.id]
          cur_node.add_obj_page_ids(obj_page_ids) if obj_page_ids
        end

        prev_node.add_child(cur_node)
      end

      if !root_node
        root_node = page_root_node
        next
      end

      candidate_lca = root_node
      while candidate_lca.page == page_root_node.page && page_root_node.children.any?
        page_root_node = page_root_node.children.first # there's only one child
        if new_candidate_lca = candidate_lca.children.find { |c| c.page == page_root_node.page }
          candidate_lca = new_candidate_lca
        else
          candidate_lca.add_child(page_root_node)
          break
        end
      end
    end

    # We always end up with a hierarchy rooted at life, which may or may not be the actual lowest common ancestor for the pages in the result set. Walk down the tree until we get to the actual lca.
    while root_node.children.length == 1 && !all_page_ids.include?(root_node.page.id)
      root_node = root_node.children.first
    end

    root_node
  end
end

