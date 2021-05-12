class Resource < ApplicationRecord
  searchkick text_start: ["name"], batch_size: 250

  belongs_to :partner, inverse_of: :resources
  belongs_to :dataset_license, class_name: 'License', optional: true

  has_many :nodes, inverse_of: :resource
  has_many :scientific_names, inverse_of: :resource
  has_many :import_logs, inverse_of: :resource
  has_many :media, inverse_of: :resource
  has_many :articles, inverse_of: :resource
  has_many :links, inverse_of: :resource
  has_many :vernaculars, inverse_of: :resource
  has_many :referents, inverse_of: :resource
  has_many :term_query_filters

  before_destroy :destroy_callback

  scope :browsable, -> { where(is_browsable: true) }
  scope :classification, -> { where(classification: true) }

  def dwh?
    id == Resource.native.id
  end

  class << self
    # NOTE: if you change this, you MUST call .update_dwh_from (see below) once it's in place!
    def native
      Rails.cache.fetch('resources/dynamic_hierarchy_1_1') do
        Resource.where(abbr: 'dvdtg').first_or_create do |r|
          r.name = 'EOL Dynamic Hierarchy 1.1'
          r.partner = Partner.native
          r.description = ''
          r.abbr = 'dvdtg'
          r.is_browsable = true
          r.has_duplicate_nodes = false
          r.nodes_count = 650000
        end
      end
    end

    def update_native_nodes
      count = 0
      Searchkick.disable_callbacks
      Searchkick.timeout = 500
      batch_size = 64 # This may actually be too large? 128 was failing frequently. :|
      Node.joins(:page).where(['nodes.resource_id = ? AND pages.native_node_id != nodes.id', Resource.native.id]).
        select('nodes.id, nodes.page_id').
        find_in_batches(batch_size: 10_000) do |batch|
          node_map = {}
          batch.each { |node| node_map[node.page_id] = node.id }
          page_group = []
          log("#{batch.size} nodes id > #{batch.first.id}")
          STDOUT.flush
          # NOTE: native_node_id is NOT indexed, so this is not speedy:
          Page.where(id: batch.map(&:page_id)).includes(:native_node).find_each do |page|
            next if page.native_node&.resource_id == Resource.native.id
            count += 1
            page_group << page.id
            page.update_attribute :native_node_id, node_map[page.id]
            log("Updated #{count}. Last: #{node_map[page.id]}") if (count % 1000).zero?
            STDOUT.flush
          end
          begin
            page_group.in_groups_of(batch_size, false) do |group|
              Searchkick::BulkReindexJob.perform_now(class_name: 'Page', record_ids: group)
            end
          rescue Faraday::TimeoutError => e
            batch_size /= 2
            raise e if batch_size <= 2
            retry
          end
        end
      log('#update_native_nodes Done.')
      Searchkick.enable_callbacks
    end

    # Required to read the IUCN status
    def iucn
      Rails.cache.fetch('resources/iucn') do
        Resource.where(abbr: 'IUCN-SD').first_or_create do |r|
          r.name = 'IUCN Structured Data'
          r.partner = Partner.native
          r.description = 'TBD'
          r.abbr = 'IUCN-SD'
          r.is_browsable = true
          r.has_duplicate_nodes = false
        end
      end
    end

    # Other conservation status providers
    def cosewic
      Rails.cache.fetch('resources/cosewic') do
        Resource.find_by_abbr("COSEWIC")
      end
    end

    def cites
      Rails.cache.fetch('resources/cites') do
        Resource.find_by_abbr("cites_taxa_tar_g")
      end
    end

    # Required to find the "best" Extinction Status: TODO: update the name when
    # we actually have the darn resource.
    def extinction_status
      Rails.cache.fetch("resources/extinction_status") do
        Resource.where(name: "Extinction Status").first_or_create do |r|
          r.name = "Extinction Status"
          r.partner = Partner.native
          r.description = "TBD"
          r.is_browsable = true
          r.has_duplicate_nodes = false
        end
      end
    end

    # Required to find the "best" Extinction Status:
    def paleo_db
      Rails.cache.fetch('resources/paleo_db') do
        Resource.where(abbr: 'pbdb').first_or_create do |r|
          r.name = 'The Paleobiology Database'
          r.partner = Partner.native
          r.description = 'TBD'
          r.abbr = 'pbdb'
          r.is_browsable = true
          r.has_duplicate_nodes = false
        end
      end
    end

    # Required for GBIF link on data search page. Does NOT create the resource if it doesn't exist.
    def gbif
      Rails.cache.fetch('resources/gbif') do
        Resource.find_by(abbr: 'gbif_classificat')
      end
    end

    # NOTE: This order is deterministic and conflated with HarvDB's app/models/publisher.rb ... if you change one, you
    # must change the other.
    def trait_headers
      %i[eol_pk page_id scientific_name resource_pk predicate sex lifestage statistical_method source
         object_page_id target_scientific_name value_uri literal measurement units]
    end

    # NOTE: This order is deterministic and conflated with HarvDB's app/models/publisher.rb ... if you change one, you
    # must change the other.
    def meta_headers
      %i[eol_pk trait_eol_pk predicate literal measurement value_uri units sex lifestage
        statistical_method source]
    end

    def for_traits(traits)
      resources = self.where(id: traits.map { |t| t[:resource_id] }.compact.uniq)
      # A little magic to index an array as a hash:
      Hash[ *resources.map { |r| [ r.id, r ] }.flatten ]
    end
  end

  def unlock
    import_logs.running.update_all(failed_at: Time.now)
  end

  def path
    @path ||= abbr.gsub(/\s+/, '_')
  end

  def create_log
    new_log = ImportLog.create(resource_id: id, status: "currently running")
    import_logs << new_log
    new_log
  end

  def destroy_callback
    remove_content
    import_logs.destroy_all
  end

  def remove_content
    # Traits:
    count = TraitBank::Queries.count_supplier_nodes_by_resource_nocache(id)
    if count.zero?
      log("No graph nodes, skipping.")
    else
      log("Removing #{count} graph nodes")
      TraitBank::Admin.remove_for_resource(self)
    end
    # Node ancestors
    nuke(NodeAncestor)
    # Node identifiers
    nuke(Identifier)
    # content_sections
    [Medium, Article, Link].each do |klass|
      all_pages = klass.where(resource_id: id).pluck(:page_id)
      field = "#{klass.name.pluralize.downcase}_count"
      all_pages.in_groups_of(2000, false) do |pages|
        Page.where(id: pages).update_all("#{field} = #{field} - 1")
        klass.where(resource_id: id).select("id").find_in_batches do |group|
          ContentSection.where(["content_type = ? and content_id IN (?)", klass.name, group.map(&:id)]).delete_all
          if klass == Medium
            # TODO: really, we should make note of these pages and "fix" their icons, now (unless the page itself is being
            # deleted):
            PageIcon.where(["medium_id IN (?)", group]).delete_all
          end
        end
      end
    end
    # javascripts
    nuke(Javascript)
    # locations
    nuke(Location)
    # Bibliographic Citations
    nuke(BibliographicCitation)
    # references, referents
    nuke(Reference)
    nuke(Referent)
    fix_missing_page_contents(delete: true)
    # TODO: Update these counts on affected pages:
      # t.integer  "maps_count",             limit: 4,   default: 0,     null: false
      # t.integer  "data_count",             limit: 4,   default: 0,     null: false
      # t.integer  "vernaculars_count",      limit: 4,   default: 0,     null: false
      # t.integer  "scientific_names_count", limit: 4,   default: 0,     null: false
      # t.integer  "referents_count",        limit: 4,   default: 0,     null: false
      # t.integer  "species_count",          limit: 4,   default: 0,     null: false

    # Media, image_info
    nuke(ImageInfo)
    nuke(Medium)
    # Articles
    nuke(Article)
    # Links
    nuke(Link)
    # occurrence_maps
    nuke(OccurrenceMap)
    # Scientific Names
    nuke(ScientificName)
    # Vernaculars
    nuke(Vernacular)
    # Attributions
    nuke(Attribution)
    # Update page node counts
    # Get list of affected pages
    log("Updating page node counts...")
    pages = Node.where(resource_id: id).pluck(:page_id)
    pages.in_groups_of(5000, false) do |group|
      Page.where(id: group).update_all("nodes_count = nodes_count - 1")
    end
    nuke(Node)
    # You should run something like #fix_native_nodes (q.v.), but it's slow, and not terribly important if you are just
    # about to re-load the resource, so it's the responsibility of the caller to do it if desired.
  end

  def log(message)
    @log ||= Publishing::PubLog.new(self, use_existing_log: true)
    @log.log(message, cat: :infos)
  end

  def nuke(klass)
    total_count = klass.where(resource_id: id).count
    log("++ NUKE: #{klass} (#{total_count})")
    count = if total_count < 250_000
      log("++ Calling delete_all on #{total_count} instances...")
      STDOUT.flush
      klass.where(resource_id: id).delete_all
    else
      log("++ Batch removal of #{total_count} instances...")
      batch_size = 10_000
      times = 0
      max_times = (total_count / batch_size) * 2 # No floating point math here, sloppiness okay.
      begin
        log("Batch #{times}...")
        STDOUT.flush
        klass.connection.execute("DELETE FROM `#{klass.table_name}` WHERE resource_id = #{id} LIMIT #{batch_size}")
        times += 1
        sleep(0.5) # Being (moderately) nice.
      end while klass.where(resource_id: id).count.positive? && times < max_times
      raise "Failed to delete all of the #{klass} instances! Tried #{times}x#{batch_size} times." if
        klass.where(resource_id: id).count.positive?
      total_count
    end
    log("Removed #{count} #{klass.name.humanize.pluralize}")
    STDOUT.flush
  rescue => e # reports as Mysql2::Error but that doesn't catch it. :S
    log("There was an error, retrying: #{e.message}")
    STDOUT.flush
    sleep(2)
    ActiveRecord::Base.connection.reconnect!
    retry rescue "UNABLE TO REMOVE #{klass.name.humanize.pluralize}: timed out"
  end

  def clear_import_logs
    import_logs.each do |log|
      log_name = log.created_at.strftime('%Y-%m-%d %H:%M')
      last_event = log.import_events.last
      if last_event
        old_events = log.import_events.where(['created_at < ?', last_event.created_at - 60])
        unless old_events.count.zero?
          old_events.destroy_all
          log("Removed events older than the last minute for log on #{log_name}.")
        end
      else
        log.destroy
        log("Removed empty log from #{log_name}")
      end
    end
  end

  def fix_native_nodes
    node_ids = Node.where(resource_id: id).pluck(:id)
    node_ids.in_groups_of(1000, false) do |group|
      Page.fix_missing_native_nodes(Page.where(native_node_id: group))
    end
  end

  # This is kinda cool... and faster than fix_counter_culture_counts
  def fix_missing_page_contents(options = {})
    delete = options.key?(:delete) ? options[:delete] : false
    [Medium, Article, Link].each { |type| fix_missing_page_contents_by_type(type, options.merge(delete: delete)) }
  end

  # TODO: this should be extracted and generalized so that a resource_id is options (thus allowing ALL contents to be
  # fixed). TODO: I think the pluck at the beginning will need to be MANUALLY segmented, as it takes too long
  # (285749.5ms on last go).
  def fix_missing_page_contents_by_type(type, options = {})
    delete = options.key?(:delete) ? options[:delete] : false
    page_counts = {}
    type_table = type.table_name
    first_content_id = type.where(resource_id: id).first&.id
    last_content_id = type.where(resource_id: id).last&.id
    contents = PageContent.where(content_type: type.name, resource_id: id).
                           where(["content_id >= ? AND content_id <= ?", first_content_id, last_content_id])
    contents = contents.where(options[:clause]) if options[:clause]
    if delete
      contents.joins(
        %Q{LEFT JOIN #{type_table} ON (page_contents.content_id = #{type_table}.id)}
      ).where("#{type_table}.id IS NULL")
    else
      PageContent
    end
    # .where('page_contents.id > 31617148').pluck(:page_id)
    contents.pluck(:page_id).each { |pid| page_counts[pid] ||= 0 ; page_counts[pid] += 1 }
    by_count = {}
    page_counts.each { |pid, count| by_count[count] ||= [] ; by_count[count] << pid }
    contents.delete_all if delete
    by_count.each do |count, pages|
      pages.in_groups_of(5_000, false) do |group|
        pages = Page.where(id: group)
        type_field = "#{type.table_name}_count"
        update =
          if delete
            "page_contents_count = IF(page_contents_count > #{count}, (page_contents_count - #{count}),0), "\
              "#{type_field} = IF(#{type_field} > #{count}, (#{type_field} - #{count}),0)"
          else
            "page_contents_count = page_contents_count + #{count}, #{type_field} = #{type_field} + #{count}"
          end
        pages.update_all(update)
      end
    end
  end

  def fix_missing_base_urls
    %w[base_url unmodified_url].each do |field|
      all = Medium.where(resource_id: id).where("#{field} LIKE 'data%'").select("id, #{field}")
      all.find_in_batches do |batch|
        Medium.where(id: batch.map(&:id)).update_all("#{field} = CONCAT('https://repo.eol.org/', #{field})")
      end
    end
  end

  # The name of this method is based on the SYMPTOM. The underlying cause is that native nodes are *wrong* because of
  # previous publishes of this resource leaving "zombie" pages with old node ids, and new publishes recognizing that the
  # page already HAS a native_node_id and thus leaving it alone.
  def fix_no_names
    nodes.pluck(:page_id).in_groups_of(1280, false) do |page_ids|
      # This loop is slow. I don't mind terribly much, this is just a fix. It took about 12 seconds on a resource with
      # only 700 nodes. You have been warned!
      Page.where(id: page_ids).
           joins('LEFT JOIN nodes ON nodes.id = pages.native_node_id').
           where('nodes.id IS NULL').
           each do |page|
             nn_id = Node.where(resource_id: id, page_id: page.id).pluck(:id)&.first
             next if nn_id.nil?
             page.update_attribute(:native_node_id, nn_id)
           end
    end
  end

  # Goes and asks the Harvesting site for information on how to move the nodes between pages...
  def move_nodes
    Node::Mover.by_resource(self)
  end

  def slurp_traits
    TraitBank::Slurp.load_csvs(self)
  end

  # Note this does NOT include metadata!
  def trait_count
    TraitBank::Admin.query(%{MATCH (trait:Trait)-[:supplier]->(:Resource { resource_id: #{id} }) RETURN COUNT(trait)})['data'].first.first
  end

  def traits_file
    Rails.public_path.join('data', "traits_#{id}.csv")
  end

  def meta_traits_file
    Rails.public_path.join('data', "meta_traits_#{id}.csv")
  end

  def remove_traits_files
    File.unlink(traits_file) if File.exist?(traits_file)
    File.unlink(meta_traits_file) if File.exist?(meta_traits_file)
  end

  def self.autocomplete(query, options = {})
    search(query, options.reverse_merge({
      fields: ['name'],
      match: :text_start,
      limit: 10,
      load: false,
      misspellings: false,
      highlight: { tag: "<mark>", encoder: "html" }
    }))
  end
end
