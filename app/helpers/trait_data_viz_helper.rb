module TraitDataVizHelper
  def count_viz_data(query, data)
    result = data.map.with_index do |datum, i|
      {
        label_short: bar_label(datum, 50),
        label_long: bar_label(datum, 75),
        prompt_long: bar_prompt(query, datum, 50),
        prompt_short: bar_prompt(query, datum, 25),
        search_path: datum.noclick? ? nil : term_search_results_path(tq: datum.query.to_short_params),
        count: datum.count,
        index: i
      }
    end

    result
  end

  def histogram_data(query, data)
    units_text = i18n_term_name(data.units_term)
    buckets = data.buckets.collect do |b|
      {
        min: b.min,
        limit: b.limit,
        count: b.count,
        queryPath: term_search_results_path(tq: b.query.to_short_params),
        promptText: hist_prompt_text(query, b, units_text)
      }
    end

    {
      maxBi: data.max_bi,
      bw: data.bw,
      min: data.min,
      maxCount: data.max_count, 
      valueLabel: t("traits.data_viz.hist_value_label", units: units_text),
      yAxisLabel: t("traits.data_viz.num_records_label"),
      buckets: buckets
    }
  end

  def sankey_nodes(nodes)
    nodes.map do |n|
      name = n.term.i18n_name
      name = t("traits.data_viz.other_term_name", term_name: name) if n.query_term?

      {
        id: n.id,
        name: name,
        fixedValue: n.size,
        pageIds: n.page_ids.to_a,
        axisId: n.axis_id,
        clickable: !n.query_term?,
        searchPath: term_search_results_path(tq: n.query.to_short_params),
        promptText: t("traits.data_viz.sankey_node_hover", term_name: name)
      } 
    end
  end

  def sankey_links(links)
    links.map.with_index do |l, i|
      {
        source: l.source.id,
        target: l.target.id,
        value: l.size,
        selected: true,
        names: [l.source.term.i18n_name, l.target.term.i18n_name],
        id: "link-#{i}",
        pageIds: l.page_ids.to_a
      }
    end
  end

  def taxon_summary_json(data)
    {
      name: 'root',
      children: data.parent_nodes.map { |n| taxon_summary_node_data(n) }
    }.to_json
  end

  private
  def taxon_summary_node_data(node)
    page_name = name_for_breadcrumb_type(node.page)

    data = {
      pageId: node.page.id,
      name: page_name,
      searchPath: term_search_results_path(tq: node.query.to_short_params),
      promptText: t('traits.data_viz.taxon_summary.click_to_filter_by', name: page_name)
    }

    if node.children.any?
      data[:children] = node.children.map { |c| taxon_summary_node_data(c) }
    end

    if node.count
      data[:count] = node.count
    end

    data
  end

  def name_for_breadcrumb_type(page)
    breadcrumb_type == BreadcrumbType.vernacular ? page.vernacular_or_canonical : page.canonical
  end

  def bar_label(datum, limit)
    truncate(datum.label, length: limit)
  end

  def bar_prompt(query, datum, label_limit)
    term_label = bar_label(datum, label_limit)
    prompt_prefix = datum.noclick? ? "" : "see_"

    if query.record?
      I18n.t("traits.data_viz.#{prompt_prefix}n_obj_records", count: datum.count, obj_name: term_label)
    else
      I18n.t("traits.data_viz.#{prompt_prefix}n_taxa_with", count: datum.count, obj_name: term_label)
    end
  end

  def obj_prompt_text(query, datum, name)
  end

  def hist_prompt_text(query, bucket, units_text)
    if bucket.count.positive?
      if query.record?
        t("traits.data_viz.show_n_records_between", count: bucket.count, min: bucket.min, limit: bucket.limit, units: units_text)
      else
        t("traits.data_viz.show_n_taxa_between", count: bucket.count, min: bucket.min, limit: bucket.limit, units: units_text)
      end
    else
      ""
    end
  end
end
