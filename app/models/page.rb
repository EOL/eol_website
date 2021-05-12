class Page < ApplicationRecord
  include Autocomplete
  include HasVernaculars
  include Page::Traits

  set_vernacular_fk_field(:page_id)

  BASE_AUTOCOMPLETE_WEIGHT = 100
  @text_search_fields = %w[preferred_scientific_names dh_scientific_names scientific_name synonyms preferred_vernacular_strings vernacular_strings providers]

  autocompletes "autocomplete_names"

  # NOTE: default batch_size is 1000
  searchkick_args = { word_start: @text_search_fields, text_start: @text_search_fields, batch_size: 2000,
    merge_mappings: true, mappings: { properties: autocomplete_searchkick_properties } }
  searchkick_args[:callbacks] = :queue if Searchkick.redis
  searchkick searchkick_args

  belongs_to :native_node, class_name: "Node", optional: true
  belongs_to :moved_to_page, class_name: "Page", optional: true
  belongs_to :medium, inverse_of: :pages, optional: true

  has_many :nodes, inverse_of: :page
  has_many :collected_pages, inverse_of: :page
  has_many :vernaculars, inverse_of: :page
  has_many :preferred_vernaculars, -> { preferred }, class_name: "Vernacular"
  has_many :scientific_names, inverse_of: :page
  has_many :synonyms, -> { synonym }, class_name: "ScientificName"
  has_many :preferred_scientific_names, -> { preferred },
    class_name: "ScientificName"
  has_many :resources, through: :nodes
  has_many :vernacular_preferences, inverse_of: :page

  # NOTE: this is too complicated, I think: it's not working as expected when preloading. (Perhaps due to the scope.)
  has_many :page_icons, inverse_of: :page
  has_one :dh_node, -> { dh }, class_name: "Node"

  has_many :page_contents, -> { visible.not_untrusted.order(:position) }
  has_many :articles, through: :page_contents, source: :content, source_type: "Article"
  has_many :media, through: :page_contents, source: :content, source_type: "Medium"
  has_many :regular_media, -> { regular }, through: :page_contents, source: :content, source_type: "Medium"
  has_many :links, through: :page_contents, source: :content, source_type: "Link"

  has_many :all_page_contents, -> { order(:position) }, class_name: "PageContent"

  has_one :occurrence_map, inverse_of: :page

  has_and_belongs_to_many :referents

  has_many :home_page_feed_items

  has_one :desc_info

  # NOTE: you cannot preload the node ancestors; it needs to call the method
  # from the module. NOTE: not loading media, because for large pages, that's a
  # long query, and we only want one page. Besides, it's loaded in a separate
  # instance variable...
  scope :preloaded, -> do
    includes(:preferred_vernaculars, :medium, :occurrence_map,
      referents: :references, native_node: [:rank, { node_ancestors: :ancestor }],
      articles: [:license, :sections, :bibliographic_citation,
        :location, :resource, attributions: :role])
  end

  scope :with_hierarchy, -> do
    with_hierarchy_no_media.includes(:medium)
  end

  scope :with_hierarchy_no_media, -> do
    includes(:preferred_vernaculars,
      native_node: [:scientific_names, { node_ancestors: { ancestor: {
        page: [:preferred_vernaculars, { native_node: :scientific_names }]
      } } }])
  end

  scope :search_import, -> { includes(:scientific_names, :preferred_scientific_names, :vernaculars, dh_node: [:scientific_names], native_node: [:scientific_names]) }

  scope :missing_native_node, -> { joins('LEFT JOIN nodes ON (pages.native_node_id = nodes.id)').where('nodes.id IS NULL') }

  scope :with_scientific_name, -> { includes(native_node: [:scientific_names]) }
  scope :with_name, -> { with_scientific_name.includes(:preferred_vernaculars) }

  KEY_DATA_LIMIT = 12
  METAZOA_ID = 1

  class << self
    # Occasionally you'll see "NO NAME" for some page IDs (in searches, associations, collections, and so on), and this
    # can be caused by the native_node_id being set to a node that no longer exists. You should try and track down the
    # source of that problem, but this code can be used to (slowly) fix the problem, where it's possible to do so:
    def fix_all_missing_native_nodes
      log_healing(">> fix_all_missing_native_nodes")
      start = 1 # Don't bother checking minimum, this is always 1.
      upper = maximum(:id)
      batch_size = 10_000
      while start < upper
        log_healing(">> fix_missing_native_nodes(start = #{start})")
        fix_missing_native_nodes(where("pages.id >= #{start} AND pages.id < #{start + batch_size}"))
        start += batch_size
      end
      log_healing("<< DONE: fix_all_missing_native_nodes")
    end

    def fix_missing_native_nodes(scope)
      pages = scope.joins('LEFT JOIN nodes ON (pages.native_node_id = nodes.id)').where('nodes.id IS NULL')
      pages.includes(:nodes).find_each do |page|
        if page.nodes.empty?
          # NOTE: This DOES destroy pages! ...But only if it's reasonably sure they have no content:
          if PageContent.exists?(page_id: page.id) || ScientificName.exists?(page_id: page.id)
            log_healing("!! RETAINED nodeless page #{page.id} because it had content (or a name). "\
                        "You should investigate")
          else
            log_healing("!! DESTROYED page #{page.id}")
            page.destroy
          end
        else
          correct_id = page.nodes.first.id
          log_healing("healed page #{page.id} (node #{page.native_node_id} -> #{correct_id})")
          page.update_attribute(:native_node_id, correct_id)
        end
      end
    end

    def page_healing_log
      @page_healing_log ||= Logger.new("#{Rails.root}/log/page_healing.log")
    end

    def log_healing(msg)
      page_healing_log.info("[#{Time.now.localtime.strftime('%F %T')}] #{msg}")
    end

    # TODO: abstract this to allow updates of the other count fields.
    # NOTE: This isn't as hairy as it looks. Currently (July 2018) takes under 10 minutes.
    def fix_media_counts
      pids = PageContent.connection.execute('select DISTINCT(page_id) from page_contents where content_type = "Medium"')
      pids.each do |page_id|
        count = PageContent.where(page_id: page_id, content_type: 'Medium').count
        # NOTE: Skipping loading any models; this just calls the DB, even though it looks weird to "update_all" one row.
        Page.where(id: page_id).update_all(media_count: count)
      end
    end

    # NOTE: you prrrrrrobaby want to fix_media_counts before you call this.
    def fix_missing_icons
      fix_zombie_icons
      pages = []
      Page.where(medium_id: nil).where('media_count > 0').find_each do |page|
        # There's no NICE way to include the media, so this, yes, will make a query for every page. We don't run this
        # method often enough to warrant speeding it up.
        page.medium_id = page.media.first&.id
        pages << page
        if pages.size > 999 # FLUSH!
          Page.import!(pages, on_duplicate_key_update: [:medium_id])
          pages = []
        end
      end
      Page.import!(pages, on_duplicate_key_update: [:medium_id]) unless pages.empty?
    end

    def fix_zombie_icons
      # NOTE: this is less than stellar efficiency, since it loads the batches into memory but doesn't need them. But
      # this isn't important enough code to explode it to the verbose, efficient verison:
      Page.where('medium_id IS NOT NULL').eager_load(:medium).merge(Medium.where(id: nil)).find_in_batches do |batch|
        Page.where(id: batch.map(&:id)).update_all(medium_id: nil)
      end
    end

    def fix_low_position_exmplars
      PageContent.media.where(position: 1).joins(:page).
        where('`pages`.`medium_id` != `page_contents`.`content_id`').includes(:page).find_each do |pc|
          pc.move_to_top
        end
    end

    def remove_if_nodeless
      # Delete pages that no longer have nodes
      Page.find_in_batches(batch_size: 10_000) do |group|
        group_ids = group.map(&:id)
        have_ids = Node.where(page_id: group_ids).pluck(:page_id)
        bad_pages = group_ids - have_ids
        next if bad_pages.empty?
        # TODO: PagesReferent
        [PageIcon, ScientificName, SearchSuggestion, Vernacular, CollectedPage, Collecting, OccurrenceMap,
         PageContent].each do |klass|
          klass.where(page_id: bad_pages).delete_all
        end
        Page.where(id: bad_pages).delete_all
      end
    end

    def warm_autocomplete
      ('a'..'z').each do |first_letter|
        autocomplete(first_letter)
        ('a'..'z').each do |second_letter|
          autocomplete("#{first_letter}#{second_letter}")
          ('a'..'z').each do |third_letter|
            autocomplete("#{first_letter}#{second_letter}#{third_letter}")
          end
        end
      end
    end

  end

  # NOTE: we DON'T store :name becuse it will necessarily already be in one of
  # the other fields.
  def search_data
    verns = vernacular_strings.uniq
    pref_verns = preferred_vernacular_strings
    sci_name = ActionView::Base.full_sanitizer.sanitize(scientific_name)
    {
      id: id,
      # NOTE: this requires that richness has been calculated. Too expensive to do it here:
      scientific_name: sci_name,
      preferred_scientific_names: preferred_scientific_strings,
      synonyms: synonyms,
      preferred_vernacular_strings: pref_verns,
      dh_scientific_names: dh_scientific_names,
      vernacular_strings: verns,
    }.merge(autocomplete_names_per_locale)
  end


  def safe_native_node
    return native_node if native_node
    return nil if nodes.empty?
    update_attribute(:native_node_id, nodes.first.id)
    return nodes.first
  end

  def specificity
    return 0 if dh_scientific_names.nil? || dh_scientific_names.empty?
    sum = dh_scientific_names&.map do |name|
      case name.split.size
      when 1 # Genera or higher
        1000
      when 2 # Species
        100
      when 3
        10
      else
        1
      end
    end
    sum ||= 0
    sum.inject { |sum, el| sum + el }.to_f / dh_scientific_names.size
  end

  def synonyms
    if scientific_names.loaded?
      scientific_names.select { |n| !n.is_preferred? }.map { |n| n.canonical_form }
    else
      scientific_names.synonym.map { |n| n.canonical_form }
    end
  end

  def resource_pks
    nodes.map(&:resource_pk)
  end

  def resource_preferred_vernacular_strings(locale)
    result = if vernaculars.loaded?
      Language.all_matching_records(Language.for_locale(locale), vernaculars).select { |v| v.is_preferred_by_resource? }
    else
      vernaculars.preferred_by_resource.where(language: Language.for_locale(locale))
    end

    result.map { |v| v.string }
  end

  def preferred_vernacular_strings
    if vernaculars.loaded?
      vernaculars.select { |v| v.is_preferred? }.map { |v| v.string }
    else
      vernaculars.preferred.map { |v| v.string }
    end
  end

  def preferred_vernacular_strings_for_locale(locale)
    langs = Language.for_locale(locale)

    result = if preferred_vernaculars.loaded?
      Language.all_matching_records(langs, preferred_vernaculars)
    elsif vernaculars.loaded?
      Language.all_matching_records(langs, vernaculars).find_all { |v| v.is_preferred? }
    else
      vernaculars.preferred.where(language: langs)
    end

    result.collect { |v| v.string }
  end

  def preferred_scientific_strings
    preferred_scientific_names.map { |n| n.italicized }.uniq.map { |n| ActionView::Base.full_sanitizer.sanitize(n) }
  end

  def vernacular_strings
    if vernaculars.loaded?
      vernaculars.select { |v| !v.is_preferred? }.map { |v| v.string }
    else
      vernaculars.nonpreferred.map { |v| v.string }
    end
  end

  def dh_scientific_names
    names = dh_node&.scientific_names&.map { |n| n.canonical_form }&.uniq
    names&.map { |n| ActionView::Base.full_sanitizer.sanitize(n) }
  end

  def providers
    resources.flat_map do |r|
      [r.name, r.partner.name, r.partner.short_name]
    end.uniq
  end

  def ancestors
    return [] if native_node.nil?
    native_node.ancestors
  end

  def node_ancestors
    return Node.none if native_node.nil?
    native_node.node_ancestors
  end

  def ancestry_ids
    # NOTE: compact is in there to catch rare cases where a node doesn't have a page_id (this can be caused by missing
    # data)
    return [id] unless native_node
    if native_node.unordered_ancestors&.loaded?
      native_node.unordered_ancestors.map(&:page_id).compact + [id]
    else
      Array(native_node&.unordered_ancestors&.pluck(:page_id)).compact + [id]
    end
  end

  def descendant_species
    return species_count unless species_count.nil?
    count_species
  end

  def count_species
    return 0 # TODO. This was possible before, when we used the tree gem, but I got rid of it, so... hard.
  end

  def content_types_count
    PageContent.unscoped.where(page_id: id, is_hidden: false)
      .where.not(trust: PageContent.trusts[:untrusted]).group(:content_type).count.keys.size
  end

  def sections_count
    return(sections.size) if articles.loaded?
    ids = PageContent.where(page_id: id, is_hidden: false, content_type: 'Article')
      .where.not(trust: PageContent.trusts[:untrusted]).pluck(:id)
    ContentSection.where(content_id: ids, content_type: 'Article').group(:section_id).count.keys.count
  end

  # MEDIA METHODS

  def sorted_articles
    return @articles if @articles
    @articles = if page_contents.loaded?
      page_contents.select { |pc| pc.content_type == "Article" }.map(&:content)
    else
      articles
    end
    @articles =
      @articles.sort_by do |a|
        a.first_section.try(:position) || 1000
      end
    @duplicate_articles = {}
    @articles.select { |a| a.sections.size > 1 }.each do |article|
      # NOTE: don't try to use a #delete here, it calls the Rails #delete!
      article.sections.each do |section|
        next if section == article.first_section
        @duplicate_articles[section] ||= []
        @duplicate_articles[section] << article
      end
    end
    @articles
  end

  def duplicate_articles
    sorted_articles unless @duplicate_articles
    @duplicate_articles
  end

  def article
    sorted_articles.first
  end

  def toc
    return @toc if @toc
    secs = sorted_articles.flat_map(&:sections).uniq
    @toc = if secs.empty?
      []
    else
      # Each section may have one (and ONLY one) parent, so we need to load
      # those, too...
      parent_ids = secs.map(&:parent_id).uniq
      parent_ids.delete(0)
      sec_ids = secs.map(&:id)
      parent_ids.delete_if { |pid| sec_ids.include?(pid) }
      parents = Section.where(id: parent_ids)
      secs.sort_by { |s| s.position }
      toc = []
      last_section = nil
      last_parent = nil
      # NOTE: UUUUUUGHHHHH! This is SOOO UGLY!  ...Can we do this a better way?
      sorted_articles.each do |a|
        this_section = a.first_section
        if this_section.nil? || this_section == last_section
          # DO nothing.
        else
          last_section = this_section
          if this_section.parent
            if last_parent == this_section.parent
              toc.last[this_section.parent] << this_section
            else
              last_parent = this_section.parent
              toc << {this_section.parent => [this_section]}
            end
          else
            last_parent = nil
            toc << this_section
          end
        end
      end
      toc
    end
  end

  # Without touching the DB, if you have the media preloaded:
  def _media_count
    page_contents.select { |pc| pc.content_type == "Medium" }.size
  end

  def icon
    medium && medium.image? && medium.medium_icon_url
  end

  def occurrence_map?
    occurrence_map
  end

  def map?
    occurrence_map? || map_count > 0
  end

  def maps
    media.where(subclass: Medium.subclasses[:map_image])
  end

  def map_count
    maps.count
  end

  def sections
    @sections = articles.flat_map { |a| a.sections }.uniq
  end

  # NAMES METHODS

  def name(locale = nil)
    vernacular(locale: locale)&.string || scientific_name
  end

  def short_name_notags(locale = nil)
    vernacular(locale: locale)&.string || canonical_notags
  end

  def short_name(locale = nil)
    vernacular(locale: locale)&.string || canonical
  end

  def canonical_notags
    @canonical_notags ||= ActionController::Base.helpers.strip_tags(canonical)
  end

  def names_count
    # NOTE: there are no "synonyms!" Those are a flavor of scientific name.
    @names_count ||= vernaculars_count + scientific_names_count
  end

  # TODO: this is duplicated with node; fix. Can't (easily) use clever associations here because of language. TODO:
  # Aaaaaactually, we really need to use GROUPS, not language IDs. (Or, at least, both, to make it efficient.) Switch to
  # that. Yeeesh.

  def scientific_name
    native_node&.italicized || native_node&.scientific_name || "NO NAME!"
  end

  def canonical
    native_node.try(:canonical) || "NO NAME!"
  end

  def rank
    native_node.try(:rank)
  end

  def vernacular_or_canonical(locale = nil)
    vernacular(locale: locale)&.string&.titlecase || canonical
  end

  # TRAITS METHODS

  def key_data
    tb_result = TraitBank::Page.key_data_pks(self, KEY_DATA_LIMIT)
    traits_by_id = Trait.for_eol_pks(tb_result.map { |row| row[:trait_pk] })
      .map { |t| [t.id, t] }
      .to_h

    tb_result.map do |row| 
      trait = traits_by_id[row[:trait_pk]]

      [
        row[:predicate],
        trait
      ]
    end.to_h
  end

  def has_data?
    data_count > 0
  end

  def data_count
    TraitBank::Queries.count_by_page(id)
  end

  def predicate_count
    TraitBank::Queries.predicate_count_by_page(id)
  end

  # NOTE: This page size is "huge" because we don't want pagination for data.
  # ...Mainly because it gets complicated quickly. Data rows can be in multiple
  # TOC items, and we want to be able to show all of the data in a single TOC
  # item. ...which I suppose we could manage by passing in a section id.
  # ...Hmmmn. We could. But we haven't been asked to, I'm going to hold off for
  # now. (NOTE: If we do that, we're going to need another method to pull in the
  # full TOC.)
  def data(page = 1, per = 2000)
    return @data[0..per] if @data
    data = TraitBank::Queries.by_page(id, page, per)
    @data_toc_needs_other = false
    @data_toc = data.flat_map do |t|
      next if t[:predicate][:section_ids].nil? # Usu. test data...
      secs = t[:predicate][:section_ids].split(",")
      @data_toc_needs_other = true if secs.empty?
      secs.map(&:to_i)
    end.uniq
    @data_toc = Section.where(id: @data_toc) unless @data_toc.empty?
    @data_loaded = true
    @data = data
  end

  def object_data
    @object_data = TraitBank::Page.object_traits_by_page(id) unless @object_data
    @object_data
  end
  
  def association_page_ids
    TraitBank::Page.association_page_ids(id)
  end

  def redlist_status
    # TODO
  end

  def should_show_icon?
    return nil unless native_node
    # WAS: Rank.species_or_below.include?(native_node.rank_id) ||
    # HACK: This one weird trick ... saves us in a lot of cases!
    @should_show_icon ||= (native_node.scientific_name =~ /<i/)
  end

  def glossary
    @glossary ||= Rails.cache.fetch("/pages/#{id}/glossary", expires_in: 1.day) do
      TraitBank::Term.page_glossary(id)
    end
  end

  def clear
    clear_caches
    recount
    iucn_status = nil
    has_checked_marine = nil
    has_checked_extinct = nil
    # TODO: (for now) score_richness
    instance_variables.each do |v|
      # Skip Rails variables:
      next if [
        :@attributes, :@aggregation_cache, :@association_cache, :@readonly,
        :@destroyed, :@marked_for_destruction, :@destroyed_by_association,
        :@new_record, :@txn, :@_start_transaction_state, :@transaction_state,
        :@reflects_state, :@original_raw_attributes
      ].include?(v)
      remove_instance_variable(v)
    end
    medium_id = media.first&.id
    save # NOTE: this calls "reindex" so no need to do that here.
    # TODO: we should also re-index all of the page_contents by checking direct
    # relationships to this page and its children. (I think this is better than
    # descendants; if you want to do an entire tree, that should be another
    # process; this reindex should just check that it's honoring the
    # relationships it has direct influence on.) We may also want to check node
    # relationships, but I'm not sure that's necessary. It's also possible there
    # will be other denormalized relationships to re-build here.
  end

  # NOTE: if you add caches IN THIS CLASS, then add them here:
  def clear_caches
    [
      "/pages/#{id}/glossary",
      "trait_bank/by_page/#{id}",
      "trait_bank/key_data/#{id}/v3/limit_#{KEY_DATA_LIMIT}"
    ].each do |cache|
      Rails.cache.delete(cache)
    end
  end

  def recount
    [ "page_contents", "media", "articles", "links", "maps",
      "nodes", "vernaculars", "scientific_names", "referents"
    ].each do |field|
      update_column("#{field}_count".to_sym, send(field).count)
    end
    count_species
  end

  def data_toc
    return @data_toc if @data_toc
    data
    @data_toc
  end

  def data_toc_needs_other?
    return @data_toc_needs_other if @data_toc_needs_other
    data
    @data_toc_needs_other
  end

  def grouped_data
    @grouped_data ||= data.group_by { |t| t[:predicate][:uri] }
  end

  def grouped_object_data
    @grouped_object_data ||= object_data.group_by { |t| t[:predicate][:uri] }
  end

  def grouped_data_by_obj_uri
    @grouped_data_by_obj ||= data.select do |t|
      t.dig(:object_term, :uri).present?
    end.group_by do |t|
      t[:object_term][:uri]
    end
  end

  def predicates
    @predicates ||= grouped_data.keys.sort do |a,b|
      glossary_names[a] <=> glossary_names[b]
    end.collect do |uri|
      glossary[uri]
    end.compact
  end

  def object_terms
    @object_terms ||= glossary.keys - predicates
  end

  # REFERENCES METHODS

  def literature_and_references_count
    if referents.count != referents_count
      update_attribute(:referents_count, referents.count)
    end
    @literature_and_references_count ||= referents_count
  end

  def richness
    score_richness if self.page_richness.nil?
    page_richness
  end

  def score_richness
    update_attribute(:page_richness, RichnessScore.calculate(self))
  end

  # Nodes methods
  def classification_nodes
    nodes.includes(:resource).where({ resources: { classification: true } })
  end

  def fix_non_image_hero
    return nil if medium.nil?
    return nil if medium.image?
    update_attribute(:medium_id, media.images.first&.id) # Even if it's nil, that's correct.
  end

  # TODO: spec
  # NOTE: this is just used for sorting.
  def glossary_names
    @glossary_names ||= begin
      gn = {}
      glossary.each do |uri, hash|
        term_name = TraitBank::Record.i18n_name(glossary[uri])
        name = term_name ? term_name.downcase : glossary[uri][:uri].downcase.gsub(/^.*\//, "").humanize.downcase
        gn[uri] = name
      end
      gn
    end
  end

  # TROPHIC_WEB_DATA
  # (not sure if this is the right place for this, but here it lives for now)
  def pred_prey_comp_data(breadcrumb_type)
    result = Rails.cache.fetch("pages/#{id}/pred_prey_json/#{I18n.locale}/5", expires: 1.day) do
      if !rank&.r_species? # all nodes must be species, so bail
        { nodes: [], links: [] }
      else
        relationships = TraitBank::Stats.pred_prey_comp_for_page(self)
        handle_pred_prey_comp_relationships(relationships)
      end
    end
    result[:labelKey] = breadcrumb_type == BreadcrumbType.vernacular ? "shortName" : "canonicalName"
    result
  end

  # END TROPHIC WEB DATA

  def sci_names_by_display_status
    scientific_names.includes(:taxonomic_status, :resource, { node: [:rank] }).references(:taxonomic_status)
      .where("taxonomic_statuses.id != ?", TaxonomicStatus.unusable.id)
      .group_by do |n|
        n.display_status
      end
  end

  def animal?
    ancestors.find { |anc| anc.page_id == METAZOA_ID }.present?
  end

  def page_icon
    page_icons.order(created_at: :desc).first
  end

  def gbif_node
    Resource.gbif.present? ?
      nodes.where(resource: Resource.gbif)&.first :
      nil
  end

  def page_node
    PageNode.find(id)
  end

  private
  def first_image_content
    page_contents.find { |pc| pc.content_type == "Medium" && pc.content.is_image? }
  end

  PRED_PREY_LIMIT = 7
  COMP_LIMIT = 10
  def handle_pred_prey_comp_relationships(relationships)
    prey_ids = Set.new
    pred_ids = Set.new
    comp_ids = Set.new

    links = relationships.map do |row|
      if row[:type] == "prey"
        prey_ids.add(row[:target])
      elsif row[:type] == "predator"
        pred_ids.add(row[:source])
      elsif row[:type] == "competitor"
        comp_ids.add(row[:source])
      else
        raise "unrecognized relationship type in result: #{row[:type]}"
      end

      {
        source: row[:source],
        target: row[:target]
      }
    end

    all_ids = Set.new([id])
    all_ids.merge(prey_ids).merge(pred_ids).merge(comp_ids)

    pages = Page.where(id: all_ids.to_a).includes(:native_node).map do |page|
      [page.id, page]
    end.to_h
    node_ids = Set.new

    source_nodes = pages_to_nodes([id], :source, pages, node_ids)

    if source_nodes.empty?
      {
        nodes: [],
        links: []
      }
    else
      build_nodes_links(node_ids, links, pages, source_nodes, pred_ids, prey_ids, comp_ids)
    end
  end

  def build_prey_to_comp_ids(prey_nodes, comp_nodes, links)
    prey_to_comp_ids = {}
    prey_ids = Set.new(prey_nodes.map { |p| p[:id] })
    comp_ids = Set.new(comp_nodes.map { |c| c[:id] })

    links.each do |link|
      source = link[:source]
      target = link[:target]

      if prey_ids.include?(source) && comp_ids.include?(target)
        prey_id = source
        comp_id = target
      elsif prey_ids.include?(target) && comp_ids.include?(source)
        prey_id = target
        comp_id = source
      else
        prey_id = nil
        comp_id = nil
      end

      if prey_id
        comp_ids_for_prey = prey_to_comp_ids[prey_id] || []
        comp_ids_for_prey << comp_id
        prey_to_comp_ids[prey_id] = comp_ids_for_prey
      end
    end

    prey_to_comp_ids
  end

  def build_nodes_links(node_ids, links, pages, source_nodes, pred_ids, prey_ids, comp_ids)
    pred_nodes = pages_to_nodes(pred_ids, :predator, pages, node_ids)
    prey_nodes = pages_to_nodes(prey_ids, :prey, pages, node_ids)
    comp_nodes = pages_to_nodes(comp_ids, :competitor, pages, node_ids)

    prey_to_comp_ids = build_prey_to_comp_ids(prey_nodes, comp_nodes, links)

    keep_prey_nodes = prey_nodes.sort do |a, b|
      a_count = prey_to_comp_ids[a[:id]]&.length || 0
      b_count = prey_to_comp_ids[b[:id]]&.length || 0
      b_count - a_count
    end[0, PRED_PREY_LIMIT]

    keep_comp_ids = Set.new
    keep_prey_nodes.each do |prey|
      keep_comp_ids.merge(prey_to_comp_ids[prey[:id]] || [])
    end
    keep_comp_nodes = comp_nodes.select do |comp|
      keep_comp_ids.include?(comp[:id])
    end[0, COMP_LIMIT]

    keep_pred_nodes = pred_nodes[0, PRED_PREY_LIMIT]

    nodes = source_nodes.concat(keep_pred_nodes).concat(keep_prey_nodes).concat(keep_comp_nodes)
    node_ids = Set.new(nodes.collect { |n| n[:id] })

    links = links.select do |link|
      node_ids.include?(link[:source]) && node_ids.include?(link[:target])
    end

    {
      nodes: nodes,
      links: links
    }
  end

  def pred_prey_comp_node(page, group)
    if page.rank&.r_species? && page.icon
      {
        shortName: page.short_name_notags,
        canonicalName: page.canonical_notags,
        groupDesc: group_desc(group),
        id: page.id,
        group: group,
        icon: page.icon,
        x: 0, # for convenience of the visualization JS
        y: 0
      }
    else
      nil
    end
  end

  def group_desc(group)
    I18n.t("trophic_web.group_descriptions.#{group}", source_name: short_name_notags)
  end

  def pages_to_nodes(page_ids, group, pages, node_ids)
    result = []

    page_ids.each do |id|
      if !node_ids.include?(id)
        node = pred_prey_comp_node(pages[id], group)

        if node
          node_ids.add(node[:id])
          result << node
        end
      end
    end

    result
  end

  def autocomplete_names_per_locale
    I18n.available_locales.collect do |locale|
      names = if dh_scientific_names&.any?
        vernaculars = vernaculars_for_autocomplete(locale)
        vernaculars = vernaculars_for_autocomplete(I18n.default_locale) if vernaculars.empty?
        (vernaculars + dh_scientific_names).uniq(&:downcase).map do |n|
          {
            input: n,
            weight: BASE_AUTOCOMPLETE_WEIGHT - [n.length, BASE_AUTOCOMPLETE_WEIGHT - 1].min # shorter results get greater weight to boost exact matches to the top
          }
        end
      else
        []
      end
      [:"autocomplete_names_#{locale}", names]
    end.to_h
  end

  def vernaculars_for_autocomplete(locale)
    (
      preferred_vernacular_strings_for_locale(locale) +
      resource_preferred_vernacular_strings(locale)
    ).uniq
  end
end
