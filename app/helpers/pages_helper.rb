module PagesHelper
  def is_allowed_summary?(page)
    # TEMP: we're hacking this because we don't have (enough) ranks yet.
    return true
    page.rank && page.rank.respond_to?(:treat_as) &&
      ["r_species", "r_genus", "r_family"].include?(page.rank.treat_as)
  end

  def resource_names(page)
    page.resources.select do |r|
      r.name =~ /#{@q}/i
    end.uniq.map do |resource|
      n = emphasize_match(resource.name, @q)
      n += " (#{emphasize_match(resource.partner.short_name, @q)})".html_safe unless
        resource.name =~ /#{resource.partner.short_name}/
      n
    end
  end

  def vernacular_names(page)
    page.vernaculars.select do |pv|
      pv.string.downcase != page.name.downcase && pv.string =~ /#{@q}/i
    end.
      group_by(&:string).
      map do |string, names|
        (emphasize_match(string, @q) +
          "&nbsp;(#{names.map { |n| n.language.code }.uniq.join(", ")})".
          html_safe)
      end
  end

  # Options: icon, count, path, name, active
  def large_tab(options)
    text = t("pages.tabs.#{options[:name]}")
    active = options[:active] || current_page?(options[:path])
    haml_tag("li", class: "#{options[:name]} #{active ? "uk-active" : nil}", role: "presentation", title: text, uk: { tooltip: "delay: 100" } ) do
      haml_concat link_to("<div class='ui orange mini statistic'><div class='value'>#{options[:count] || "&nbsp;".html_safe}</div><div class='label'>#{text}</div></div>".html_safe, options[:path], remote: true)
    end
  end

  def small_tab(options)
    text = t("pages.tabs.#{options[:name]}")
    active = options[:active] || current_page?(options[:path])
    mobile_link = "<i class='icon #{options[:icon]}'></i>"
    haml_concat link_to("#{mobile_link} #{text}".html_safe, options[:path], remote: true, class: "#{options[:name]} #{active ? "active " : "" }item")
  end

  def index_stat(key, count)
    return '0' if count.nil?
    count =
      if count > 1_000_000
        "#{(count / 100_000) / 1.0}M"
      elsif count > 10_000
        "#{(count / 1_000) / 1.0}K"
      else
        number_with_delimiter(count)
      end
    haml_tag("div.ui.orange.statistic") do
      haml_tag("div.value") { haml_concat count }
      haml_tag("div.label") { haml_concat t("stats.#{key}") }
    end
  end

  def classification(node)
    ancestors = Array(node.ancestors.compact)
    ancestors.push(node)
    classification_helper(node, ancestors)
  end

  def classification_helper(this_node, ancestors)
    raise TypeError.new("ancestors can't be empty") if ancestors.empty?
    node = ancestors.shift
    page = node.page
    classification_content(page, this_node, node, ancestors)
  end

  def classification_content(page, this_node, node, ancestors)
    # have to capture this state here, because it will always be empty where we need the check
    show_siblings = ancestors.empty?

    haml_tag("div.item") do
      summarize(page, name: node.scientific_name, current_page: node == this_node, node: node, no_icon: true)
      if ancestors.empty?
        if this_node.children.any?
          children = this_node.children.includes(:page)

          haml_tag("div.item") do
            haml_tag("div.ui.middle.aligned.list.descends") do
              sort_nodes_by_name(children).each do |child|
                haml_tag("div.item") do
                  summarize(child.page, name: child.scientific_name, node: child, no_icon: true)
                end
              end
            end
          end
        end
      else
        haml_tag("div.ui.middle.aligned.list.descends") do
          classification_helper(this_node, ancestors)
        end
      end
    end

    if show_siblings && this_node.siblings && this_node.siblings.any?
      sort_nodes_by_name(this_node.siblings[0..99]).each do |sibling|
        haml_tag("div.item") do
          summarize(sibling.page, name: sibling.scientific_name, current_page: false, node: sibling, no_icon: true)
        end
      end
      if this_node.siblings.size > 100
        haml_tag("div.item") do
          haml_concat t('classifications.hierarchies.truncated_siblings', count: this_node.siblings.size - 100)
        end
        haml_tag("div.item") do
          link = "#{Rails.application.secrets.repository[:url]}/resources/#{this_node.resource.repository_id}"
          haml_concat t('classifications.hierarchies.see_resource_file', href: link).html_safe
        end
      end
    end
  end

  def summarize(page, options = {})
    page_id = if page
                page.id
              elsif options[:node]
                options[:node].page_id
              else
                nil
              end
    return('[unknown page]') if page_id.nil?
    name = options[:name]
    if options[:current_page]
      haml_tag('b') do
        haml_concat link_to(name.html_safe, page_id ? page_path(page_id) : '#')
      end
      haml_concat t('classifications.hierarchies.this_page')
    elsif (page && !options[:no_icon] && image = page.medium)
      haml_concat(image_tag(image.small_icon_url, class: 'ui mini image')) if page.should_show_icon?
      haml_concat link_to(name.html_safe, page_id ? page_path(page_id) : '#')
    else
      haml_concat link_to(name.html_safe, page_id ? page_path(page_id) : '#')
    end
    if page.nil?
      haml_tag('div.uk-padding-remove-horizontal.uk-text-muted') do
        haml_concat 'PAGE MISSING (bad import)' # TODO: something more elegant.
      end
    end
  end

  def tab(name_key, path)
    haml_tag(:li, :class => "tab #{(current_page?(path) ? "is-tab-selected" : "")}") do
      haml_concat link_to(t("pages.tabs.#{name_key}"), path)
    end
  end

  # TODO: we should really store the values like this! :S
  def unlink(text)
    return text.html_safe if text =~ /<a / # They already linked it.
    text.gsub(URI::ABS_URI) { |match|
      # match may have leading/trailing whitespace, which causes an error in URI::parse
      clean_match = match.strip
      if clean_match.size < 20
        "<a href=\"#{clean_match}\">#{clean_match}</a>"
      else
        host = URI::parse(clean_match).host
        "<a href=\"#{clean_match}\">#{host}</a>"
      end
    }.html_safe
  end

  def overview?
    current_page?(page_path(@page))
  end

  def summary_hierarchy(page, link)
    hierarchy_helper(page, link, :partial)
  end

  def full_hierarchy(page, link)
    hierarchy_helper(page, link, :full)
  end

  def language_header_key(l)
    "languages.#{l}"
  end

  def language_header(l)
    return t("languages.none") if l.blank?
    tl = t(language_header_key(l))
    return l if tl =~ /^translation missing/
    return l if tl =~ /^I18n:/
    tl == 0 ? l : tl
  end

  def show_page_media_filters?(filterable)
    filterable && (
      (@license_groups && @license_groups.length > 1) ||
      (@resources && @resources.length > 1) ||
      (@subclasses && @subclasses.length > 1)
    )
  end

  def sorted_grouped_vernaculars(page)
    grouped_vernaculars = page.vernaculars.includes(language: :locale).group_by do |n|
      n.language.locale&.code 
    end

    cur_locale = Locale.current.code

    sorted_keys = grouped_vernaculars.keys.sort do |a, b|
      if a == cur_locale && b != cur_locale
        -1
      elsif a != cur_locale && b == cur_locale
        1
      else
        a_exists = I18n.exists?(language_header_key(a))
        b_exists = I18n.exists?(language_header_key(b))

        # sort unmapped languages to the end
        if a_exists && !b_exists
          -1 
        elsif !a_exists && b_exists
          1
        else
          language_header(a) <=> language_header(b)
        end
      end
    end

    sorted_keys.collect do |key|
      {
        locale_code: key,
        vernaculars: grouped_vernaculars[key]
      }
    end
  end

  def group_sort_names_for_card(names, include_rank, include_status)
    names.group_by do |n|
      node = n.node
      status = n.taxonomic_status&.name
      dwh_str = n.resource&.dwh? ? "a" : "b"
      key = "#{dwh_str}.#{n.italicized}"
      key += ".#{node.rank_treat_as}" if include_rank && node&.has_rank_treat_as?
      key += ".#{status}" if include_status && status
      key
    end.values.sort_by do |v|
      first = v.first
      dwh_part = first.resource&.dwh? ? "a" : "b"
      rank_part = include_rank && first.node&.has_rank_treat_as? ? I18n.t("pages.resource_names.rank.#{first.node.rank_treat_as}") : "zzz"
      # TODO: Update once taxonomic statuses are i18n-able
      status_part = include_status && first.taxonomic_status&.name ? first.taxonomic_status&.name : "zzz"
      [dwh_part, (first.italicized || "(missing italicized form)"), rank_part, status_part]
    end
  end

private

  def hierarchy_helper(page, link, mode)
    Rails.cache.fetch("pages/hierarchy_helper/#{page.id}/link_#{link}/#{mode || :none}/#{I18n.locale}/#{breadcrumb_type}", expires_in: 1.day) do
      name_method = breadcrumb_type == BreadcrumbType.vernacular ? :vernacular_or_canonical : :canonical
      parts = []
      node = page.safe_native_node
      ancestors = if node
                    if node.node_ancestors.loaded?
                      node.node_ancestors.collect(&:ancestor).compact
                    else
                      Rails.logger.warn('INEFFICIENT LOAD OF PAGE ANCESTORS FOR #hierarchy_helper')
                      node.node_ancestors.
                        includes(ancestor: { page: [:preferred_vernaculars, { native_node: :scientific_names }] }).
                        collect(&:ancestor).compact
                    end
                  else
                    []
                  end
      shown_ellipsis = false
      unresolved = ancestors.any? && ancestors.none? { |anc| anc.use_breadcrumb? }

      if mode == :partial && unresolved
        parts << content_tag(:span, t("pages.unresolved_name"), class: "a js-show-full-hier")
      else
        ancestors.compact.each do |anc_node|
          anc_page = anc_node.page
          if anc_node.use_breadcrumb? || mode == :full
            name = anc_page.send(name_method)

            if link
              parts << link_to(name.html_safe, page_path(anc_page)).html_safe
            else
              parts << name.html_safe
            end
            shown_ellipsis = false
          elsif !shown_ellipsis
            if link
              parts << content_tag(:span, "…", class: "a js-show-full-hier")
            else
              parts << "…"
            end
            shown_ellipsis = true
          end
        end
      end

      result = parts.join(" » ").html_safe

      if mode == :full
        final_parts = []

        if unresolved
          final_parts << t("pages.unresolved_name_prefix")
        end

        final_parts << result

        if link
          final_parts << content_tag(:span, "«", class: "a js-show-summary-hier")
        end

        result = final_parts.join(" ")
      end

      result
    end
  end

  def sort_by_name_for_page(pages)
    pages.sort do |a, b|
      # sanitize so <i> tags aren't counted for sorting purposes
      a_name = sanitize(name_for_page(a), tags: [])
      b_name = sanitize(name_for_page(b), tags: [])

      a_name <=> b_name
    end
  end

  def page_resource_names_link(name, include_remarks)
    if include_remarks && name.remarks.present?
      I18n.t(
        "pages.resource_names.resource_link_w_remarks_html",
        resource_path: resource_path(name.resource),
        resource_name: name.resource.name,
        remarks: name.remarks
      )
    else
      I18n.t(
        "pages.resource_names.resource_link_html",
        resource_path: resource_path(name.resource),
        resource_name: name.resource.name
      )
    end
  end

  def gbif_species_page_url(page)
    page.gbif_node ? 
      "https://gbif.org/species/#{page.gbif_node.resource_pk}" :
      nil 
  end

  def occurrence_map_caption(page)
    url = gbif_species_page_url(page)
    name = page.name.html_safe
    url.present? ?
      t("maps.occurrence_caption_w_link_html", page_name: name, url: url) :
      t("maps.occurrence_caption", page_name: name)
  end

  private
    def sort_nodes_by_name(nodes)
      nodes.sort do |a, b|
        a_name = a.comparison_scientific_name
        b_name = b.comparison_scientific_name

        a_name <=> b_name
      end
    end
end
