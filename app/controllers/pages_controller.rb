require 'csv'

class PagesController < ApplicationController
  include DataAssociations
  include HasAutocomplete

  before_action :handle_page_redirects
  before_action :set_media_page_size, only: [:show, :media]
  before_action :no_main_container
  before_action :require_admin, only: [:batch_lookup, :batch_lookup_results]
  after_action :no_cache_json

  helper :data

  ALL_LOCALE_CODE = "show_all"
  BATCH_LOOKUP_COLS = {
    "query" => -> (qs, page, url) { qs },
    "match" => -> (qs, page, url) { !page.nil? },
    "canonical_name" => -> (qs, page, url) { page.nil? ? nil : page.canonical },
    "page_id" => -> (qs, page, url) { page.nil? ? nil : page.id },
    "page_url" => -> (qs, page, url) { url }
  }
  MIN_CLOUD_WORDS = 6
  WORDCLOUD_PREDICATES = [TermNode.find_by_alias('habitat')]
  TROPHIC_WEB_PREDICATES = [
    TermNode.find_by_alias('eats'),
    TermNode.find_by_alias('is_eaten_by'),
    TermNode.find_by_alias('preys_on'),
    TermNode.find_by_alias('preyed_upon_by')
  ]

  HABITAT_CHART_BLACKLIST_IDS = Set.new([
    1,
    2913056,
    2908256
  ])
  
  # See your environment config; this action should be ignored by logs.
  def ping
    if ActiveRecord::Base.connection.active?
      render text: 'pong'
    else
      render status: 500
    end
  end

  def autocomplete
    render json: autocomplete_results(Page.autocomplete(params[:query]), "pages")
  end

  # TODO: I suspect this method and its compatriots can be made redundant.
  def topics
    client = Comments.discourse
    @topics = client.latest_topics
    respond_to do |fmt|
      fmt.js { }
    end
  end

  def comments
    @page = Page.where(id: params[:page_id]).first
    client = Comments.discourse
    return nil unless client.respond_to?(:categories)
    # TODO: we should configure the name of this category:
    cat = client.categories.find { |c| c["name"] == "EOL Pages" }
    # TODO: we should probably create THAT ^ it if it's #nil?
    @url = nil
    @count = begin
      tag = client.show_tag("id:#{@page.id}")
      topic = tag["topic_list"]["topics"].first
      if topic.nil?
        0
      else
        @url = "#{Comments.discourse_url}/t/#{topic["slug"]}/#{topic["id"]}"
        topic["posts_count"]
      end
    rescue DiscourseApi::NotFoundError
      0
    end
    respond_to do |fmt|
      fmt.js { render(layout: false) }
    end
  end

  def create_topic
    @page = Page.where(id: params[:page_id]).first
    client = Comments.discourse
    name = @page.name == @page.scientific_name ?
      "#{@page.scientific_name}" :
      "#{@page.scientific_name} (#{@page.name})"
    # TODO: we should configure the name of this category:
    category = client.categories.find { |c| c["name"] == "EOL Pages" }

    # It seems their API is broken insomuch as you cannot use their
    # #create_topic method AND add tags to it. Thus, I'm just calling the raw
    # API here:
    # TODO: rescue this and look for the existing post (again) and redirect there.
    post = client.post("posts",
      "title" => "Comments on #{@page.rank&.name} #{name} page (#{@page.id})".gsub('  ', ' '),
      "category" => category["id"],
      "tags[]" => "id:#{@page.id}", # sigh.
      "unlist_topic" => false,
      "is_warning" => false,
      "archetype" => "regular",
      "nested_post" => true,
      # NOTE: we do NOT want to translate this. The comments site is English.
      "raw" => "Please leave your comments regarding <a href='#{page_url(@page)}'>#{name}</a> in this thread
        by clicking on REPLY below. If you have contents related to specific content please provide a specific URL. For
        additional information on how to use this discussion forum, <a href='http://discuss.eol.org/'>click here</a>."
    )
    client.show_tag("id:#{@page.id}")
    redirect_to Comments.post_url(post["post"])
  end

  def clear_index_stats
    respond_to do |fmt|
      fmt.html do
        Rails.cache.delete("pages/index/stats")
        # This is overkill (we only want to clear the data count, not e.g. the
        # glossary), but we want to be overzealous, not under:
        TraitBank::Admin.clear_caches
        Rails.logger.warn("LANDING PAGE STATS CLEARED.")
        flash[:notice] = t("landing_page.stats_cleared")
        redirect_to("/")
      end
    end
  end

  # This is effectively the "overview":
  def show
    @page = PageDecorator.decorate(Page.with_hierarchy.find(params[:id]))
    set_noindex_if_needed(@page)
    @page.fix_non_image_hero # TEMP: remove me when this is no longer an issue.
    @page_title = @page.name
    @key_data = @page.key_data    # get_media # NOTE: we're not *currently* showing them, but we will.
    
    # For autogen summary text
    @associations = build_page_associations(@page)

    @page.associated_pages = @associations # needed for autogen text
    # Required mostly for paginating the first tab on the page (kaminari
    # doesn't know how to build the nested view...)
    setup_habitat_bar_chart
    @show_trophic_web = @page.rank&.r_species?
    respond_to do |format|
      format.html {}
    end
  end

  def trophic_web
    @page = Page.find(params[:page_id])
    setup_trophic_web
    status = @show_trophic_web ? :ok : :no_content
    render({ status: status, layout: false })
  end

  def reindex
    require_admin
    @page = Page.where(id: params[:page_id]).first
    @page.clear
    expire_fragment(page_data_path(@page))
    expire_fragment(page_details_path(@page))
    expire_fragment(page_classifications_path(@page)) # Doesn't appear to work.
    I18n.available_locales.each do |l|
      Rails.cache.delete("pages/#{@page.id}/brief_summary/#{l}")
    end
    [0, 1].each do |link|
      %i[full partial none].each do |mode|
        BreadcrumbType::TYPES.keys.each do |breadcrumb_type|
          Rails.cache.delete("pages/hierarchy_helper/#{@page.id}/link_#{link}/#{mode}/#{breadcrumb_type}")
        end
      end
    end
    flash[:notice] = t("pages.flash.reindexed")
    redirect_to page_path(@page)
  end

  def data
    @page = PageDecorator.decorate(Page.with_hierarchy.find(params[:page_id]))
    @selected_resource = params[:resource_id] ? Resource.find(params[:resource_id]) : nil
    @selected_predicate = params[:predicate_id] ?
      TermNode.find(params[:predicate_id].to_i) :
      nil
    @traits_per_group = 5
    grouped_trait_result = TraitBank::Page.grouped_traits_for_page(
      @page, 
      resource: @selected_resource, 
      limit: @selected_predicate ? nil : @traits_per_group, 
      selected_predicate: @selected_predicate
    )
    @grouped_data = grouped_trait_result[:grouped_traits]
    @predicates = @grouped_data.keys.sort { |a, b| a.name <=> b.name }
    @selected_predicates = @selected_predicate ? [@selected_predicate] : @predicates
    @page_title = t("page_titles.pages.data", page_name: @page.name)
    @resources = @selected_predicate ? 
      grouped_trait_result[:all_traits].map { |t| t.resource }.compact.sort { |a, b| a.name <=> b.name }.uniq :
      Resource.where(id: @page.page_node.trait_resource_ids).order(:name)

    setup_viz
    set_noindex_if_needed(@page)

    respond_to do |format|
      format.html do
        if request.xhr?
          render layout: false
        else
          render
        end
      end

      format.js {}
    end
  end

  def maps
    @page = PageDecorator.decorate(Page.find(params[:page_id]))
    set_noindex_if_needed(@page)
    @page_title = t("page_titles.pages.maps", page_name: @page.name)
    # NOTE: sorry, no, you cannot choose the page size for maps.
    @media_page_size = 18
    @media = @page.maps.by_page(params[:page]).per(@media_page_size)
    @media_count = @media.length
    @subclass = "map"
    @subclass_id = Medium.subclasses[:map_image]
    @gbif_node = Resource.gbif ? @page.nodes.where(resource: Resource.gbif)&.first : nil
    return render(status: :not_found) unless @page # 404
    respond_to do |format|
      format.html {}
      format.js {}
    end
  end

  def media
    @page = PageDecorator.decorate(Page.find(params[:page_id]))
    set_noindex_if_needed(@page)
    @page_title = t("page_titles.pages.media", page_name: @page.name)
    return render(status: :not_found) unless @page # 404
    get_media
    respond_to do |format|
      format.html do
        if request.xhr?
          render :layout => false
        else
          render
        end
      end
    end
  end

  def articles
    get_articles
    @page_title = t("page_titles.pages.articles", page_name: @page.name)
    set_noindex_if_needed(@page)
    respond_to do |format|
      format.html do
        if request.xhr?
          render :layout => false
        else
          render
        end
      end
    end
  end

  def classifications
    @page = Page.where(id: params[:page_id]).includes(:preferred_vernaculars, nodes: [:children, :page],
      native_node: [:children, node_ancestors: :ancestor]).first
    return render(status: :not_found) unless @page # 404
    respond_to do |format|
      format.html {}
      format.js {}
    end
  end

  def names
    @page = PageDecorator.decorate(
      Page.includes(
        :preferred_vernaculars,
        :native_node,
        { vernaculars: :language }
      ).find(params[:page_id])
    )
    @page_title = t("page_titles.pages.names", page_name: @page.name)
    set_noindex_if_needed(@page)

    respond_to do |format|
      format.html {}
      format.js {}
    end
  end

  def literature_and_references
    # NOTE: I'm not sure the preloading here works because of polymorphism.
    @page = Page.where(id: params[:page_id]).includes(referents: :parent).first
    return render(status: :not_found) unless @page # 404
    respond_to do |format|
      format.html {}
      format.js {}
    end
  end

  def breadcrumbs
    @page = Page.where(id: params[:page_id]).includes(:preferred_vernaculars,
      :nodes, native_node: :children).first
    return render(status: :not_found) unless @page # 404
    respond_to do |format|
      format.js {}
    end
  end

  def batch_lookup
    # TODO: implement
    @lines = []
    render layout: "application"
  end

  def batch_lookup_results
    @lines = params[:query].strip.split("\n")[0, 1000].collect(&:strip)

    @tsv_path = batch_lookup_pages_path(query: params[:query], format: "csv")
    @results_by_line = {}
    searches = @lines.collect do |line|
      search = Page.search(line, {
        fields: ['preferred_scientific_names'],
        match: :phrase,
        limit: 1,
        execute: false
      })
      @results_by_line[line] = search
      search
    end
    Searchkick.multi_search(searches)

    respond_to do |format|
      format.csv do
        tsv_data = CSV.generate(col_sep: "\t") do |tsv|
          tsv << BATCH_LOOKUP_COLS.keys.collect do |key|
            I18n.t("pages.batch_lookup.#{key}")
          end
          @lines.each do |line|
            results = @results_by_line[line]
            result = results.any? ? results.first : nil
            url = result ? page_url(result) : nil
            tsv << BATCH_LOOKUP_COLS.each.collect { |_, lam| lam[line, result, url] }
          end
        end
        send_data tsv_data, filename: "batch_page_lookup.tsv"
      end

      format.html do
        render "batch_lookup", layout: "application"
      end
    end
  end


  def wordcloud_test
    render layout: "application"
  end

private

  def handle_page_redirects
    # HACK: HAAAAACKY  HACK, this was a single exception Jen called out. We really want to handle redirected pages more
    # elegantly than this. I suggest we build a page_redirects table.
    if PageRedirect.exists?(id: params[:id])
      redirect_to_id = PageRedirect.where(id: params[:id]).pluck(:redirect_to_id).first
      redirect_to(controller: :pages, action: params[:action], id: redirect_to_id, status: :moved_permanently)
    elsif PageRedirect.exists?(id: params[:page_id])
      redirect_to_id = PageRedirect.where(id: params[:page_id]).pluck(:redirect_to_id).first
      redirect_to(controller: :pages, action: params[:action], page_id: redirect_to_id, status: :moved_permanently)
    end
  end

  def no_cache_json
    # Prevents the back button from returning raw JSON
    if request.xhr?
      response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
      response.headers["Pragma"] = "no-cache"
      response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
    end
  end

  def set_media_page_size
    @media_page_size = 24
  end

  def get_media
    if @page.media_count > 1000
      # Too many. Just use ALL of them for filtering:
      @license_groups = LicenseGroup.all
      @subclasses = Medium.regular_subclass_keys
      # List of resources, as of Jul 2018 (query takes about 32 seconds), that HAVE images, i.e.:
      # a = Medium.where(subclass: 0).select('resource_id').uniq('resource_id').pluck(:resource_id).sort
      # a.delete(0) ; puts a.join(',')
      resource_ids = [2,4,8,9,10,11,12,14,46,53,181,395,410,416,417,418,420,459,461,462,463,464,465,468,469,470,474,475,
        481,486,493,494,495,496,507,508]
      @resources = Resource.where(id: resource_ids).select('id, name').sort_by { |r| r.name.downcase }
    else
      @license_groups = LicenseGroup
        .joins(:licenses)
        .where('licenses.id': @page.regular_media.pluck(:license_id).uniq)
        .distinct
      @subclasses = @page.regular_media.pluck(:subclass).uniq
      @resources = Resource.where(id: @page.regular_media.pluck(:resource_id).uniq).select('id, name').sort
    end

    if is_admin?
      page_media = @page.media.not_maps.includes(:hidden_medium)
    else
      page_media = @page.regular_media
    end

    media = page_media.includes(:license, :resource, page_contents: {
      page: %i[native_node preferred_vernaculars] }).where(['page_contents.source_page_id = ?',
      @page.id]).references(:page_contents)

    if params[:license_group]
      @license_group = LicenseGroup.find_by_key!(params[:license_group])
      media = media.joins("JOIN license_groups_licenses ON license_groups_licenses.license_id = "\
        "media.license_id").joins("JOIN license_groups ON license_groups_licenses.license_group_id = "\
        "license_groups.id").where("license_groups.id": @license_group.all_ids_for_filter)
    end
    if params[:subclass]
      @subclass = params[:subclass]
      media = media.where(subclass: Medium.subclasses[@subclass])
    end
    if params[:resource_id]
      @resource_id = params[:resource_id].to_i
      media = media.where(['page_contents.resource_id = ?', @resource_id])
      @resource = Resource.find(@resource_id)
    end

    @media_count = media.count
    # Just adding the || 30 in here for safety's sake:
    @media = media.by_page(params[:page]).per(@media_page_size || 30).without_count
  end

  def get_articles
    @page = PageDecorator.decorate(Page.find(params[:page_id]))
    resource_id = params[:resource_id]
    @resource = resource_id.nil? ? nil : Resource.find(resource_id)
    brief_summary_article_ids = @page.articles
      .joins("INNER JOIN content_sections ON content_sections.content_id = articles.id AND content_sections.content_type = 'Article'")
      .where("content_sections.section_id = ?", Section.brief_summary.id).pluck("articles.id")
    @articles = @page.articles
                  .includes(:license, :resource, :language, :sections)
                  .where(['page_contents.source_page_id = ?', @page.id])
                  .references(:page_contents, :resources)
    articles_with_resource = resource_id.nil? ?
      @articles :
      @articles.where({ resource_id: resource_id })

    @locale_codes = Locale.joins(:languages)
      .where("languages.id IN (?)", articles_with_resource.pluck(:language_id).uniq)
      .distinct
      .order(:code)
      .pluck(:code)

    @locale_code = params[:locale_code]
    if @locale_code.nil?
      # Only default the language for the initial page view, where no filters are set.
      # Expect XHR requests to have the language set explicitly.
      if @resource.nil? && @locale_codes.include?(Locale.current.code)
        @locale_code = Locale.current.code
      else
        @locale_code = ALL_LOCALE_CODE
      end
    end

    locale_where =
      if @locale_code == ALL_LOCALE_CODE
        nil
      elsif @locale_code == Locale.current.code
        "articles.language_id IS NULL OR locales.code = ?"
      else
        "locales.code = ?"
      end

    # references is needed to force a LEFT OUTER JOIN here because of the string where condition (not a hash)
    @articles = locale_where ?
      @articles.includes(language: :locale).where(locale_where, @locale_code).references(:locales) :
      @articles

    @resources = Resource
      .where(id: @articles.pluck(:resource_id).uniq)
      .order(:name)

    @articles = @articles.where({ resource_id: resource_id }) if !resource_id.nil?
    orders = brief_summary_article_ids.any? ? ["articles.id IN (#{brief_summary_article_ids.join(",")}) DESC"] : []
    orders += [
      "resources.name",
      "articles.name IS NULL",
      "articles.name"
    ]
    @articles = @articles.unscope(:order).order(orders.join(", "))
    @all_locale_code = ALL_LOCALE_CODE
  end

  def setup_viz
    @show_wordcloud = false
    @show_trophic_web = false
    return if @selected_predicate.nil?

    if (
      WORDCLOUD_PREDICATES.include?(@selected_predicate) &&
      @page.native_node.rank &&
      Rank.treat_as[@page.native_node.rank.treat_as] >= Rank.treat_as[:r_species]
    )
      setup_wordcloud
    elsif (
      TROPHIC_WEB_PREDICATES.include?(@selected_predicate)
    )
      setup_trophic_web
    end
  end

  def setup_trophic_web
    @trophic_web_data = @page.pred_prey_comp_data(breadcrumb_type)
    @show_trophic_web = @trophic_web_data[:nodes].length > 1
    @trophic_web_translations = {
      predator: I18n.t("pages.trophic_web.predator"),
      prey: I18n.t("pages.trophic_web.prey"),
      competitor: I18n.t("pages.trophic_web.competitor"),
    }
  end

  def species_page?
    @page.native_node.rank &&
    Rank.treat_as[@page.native_node.rank.treat_as] >= Rank.treat_as[:r_species]
  end

  def setup_wordcloud
    wordcloud = Wordcloud.new(@page, TermNode.find_by_alias('habitat'))

    if wordcloud.length > MIN_CLOUD_WORDS
      @wordcloud_words = wordcloud.to_json
      @show_wordcloud = true
    end
  end

  def set_noindex_if_needed(page)
    if !page.has_data?
      response.headers['X-Robots-Tag'] = "noindex"
    end
  end

  def setup_habitat_bar_chart
    return if !@page.native_node.any_landmark? || HABITAT_CHART_BLACKLIST_IDS.include?(@page.id)

    query = TermQuery.new({
      clade: @page,
      result_type: :taxa,
      filters_attributes: [{
        predicate_id: EolTerms.alias_hash('habitat')['eol_id']
      }]
    })

    @show_habitat_chart = TraitBank::Stats.check_query_valid_for_counts(query).valid?
    @habitat_chart_query = query
  end
end
