class Serializer
  class << self
    def store_clade_id(id, options = {})
      page = Page.find(id)
      store_clade(page, options)
    end

    def store_clade(page, options = {})
      serializer = new(page, options)
      serializer.store_clade
    end
  end

  def initialize(page, options = {})
    @page = page
    data_dir = Rails.root.join('public', 'data')
    log("Made data dir") if Dir.mkdir(data_dir, 0755) unless Dir.exist?(data_dir)
    raise "Page required" unless @page.is_a?(Page)
    @pages_dir = data_dir.join('pages')
    log("Made pages data dir") if Dir.mkdir(@pages_dir, 0755) unless Dir.exist?(@pages_dir)
    @page_dir = @pages_dir.join(@page.id.to_s)
    log("Made new page data dir #{@page.id}") if Dir.mkdir(@page_dir, 0755) unless Dir.exist?(@page_dir)
    FileUtils.rm_rf Dir.glob("#{@page_dir}/*")
    @filenames = []
    @limit = options[:limit] || 100
    trait_fields = %w(eol_pk page_id scientific_name resource_pk predicate sex lifestage statistical_method source
      object_page_id target_scientific_name value_uri literal measurement units normal_measurement normal_units_uri
      resource_id)
    metadata_fields = %w(eol_pk trait_eol_pk predicate literal measurement value_uri units sex lifestage
      statistical_method source)
    @traits = [trait_fields] # NOTE: that's an array with an array in it.
    @metadata = [metadata_fields] # NOTE: that's an array with an array in it.
    @terms = {} # A hash, to avoid duplicates.
  end

  def filename_for(klass)
    @page_dir.join("#{klass.table_name}.csv")
  end

  # TODO: collections and users ... maybe? Nice for testing...
  # TODO: curations
  # TODO: Resource filter
  def store_clade

# YOU WERE HERE:
    # /usr/local/bundle/gems/mysql2-0.4.9/lib/mysql2/client.rb:120:in `_query': Mysql2::Error: Unknown column 'referents.reference_id' in 'where clause': SELECT  `referents`.`id` FROM `referents` WHERE `referents`.`reference_id` = 0 LIMIT 20000 (ActiveRecord::StatementInvalid)

  # That's the wrong way: the references has a referent_id.

    structure = [
      :occurrence_maps, {
        nodes: [ :identifiers, :node_ancestors, :rank,
                 # NOTE: skipping resources of the names because ... they should be 100% the same as the nodes!
                 { scientific_names: [ :taxonomic_status ],
                   vernaculars: [ :language ],
                   resource: [ :partner ],
                   references_AS_parent: :referents } ],
        page_contents: [{
          media_AS_content: [
            # TODO: :sytlesheet, :javascript, { content_sections: :section }
            :image_info, :license, :language, :bibliographic_citation, :location, # TODO: :attributions,
              { references_AS_parent: :referents, resource: [ :partner ] }
          ],
          articles_AS_content: [
            # TODO: :sytlesheet, :javascript, { content_sections: :section }
            :license, :language, :bibliographic_citation, :location, # TODO: :attributions,
              { references_AS_parent: :referents, resource: [ :partner ] }
          ]
        }]
      }
    ]

    node_ids = @page.native_node.descendants.pluck(:node_id)
    node_ids << @page.native_node_id
    ancestor_page_ids = @page.native_node.ancestors.compact.map(&:page_id)
    page_ids = Node.where(id: node_ids).pluck(:page_id)
    @tables = { Page => page_ids + ancestor_page_ids }
    gather(:pages, ancestor_page_ids, { nodes: [ {scientific_names: [ :taxonomic_status ] }]})
    structure.each { |relationship| gather(:pages, page_ids, relationship) }
    require 'csv'
    @tables.each do |klass, ids|
      next if ids.empty?
      data = []
      fields = klass.column_names
      data << fields
      data += klass.where(id: ids).pluck("`#{fields.join('`,`')}`")
      filename = filename_for(klass)
      CSV.open(filename, 'w') { |csv| data.each { |row| csv << row } }
      @filenames << File.basename(filename)
    end
    write_traits(page_ids)
    full_tgz_path = "#{@pages_dir}/#{@page.id}_data.tgz"
    File.unlink(full_tgz_path) if File.exist?(full_tgz_path)
    `cd #{@pages_dir} && /bin/tar cvzf #{@page.id}_data.tgz #{@page.id}`
    FileUtils.rm_rf(@page_dir)
    log(full_tgz_path)
    full_tgz_path
  end

  def write_traits(page_ids)
    gather_traits(page_ids)
    store_trait_data('traits', @traits)
    store_trait_data('metadata', @metadata)
    store_terms
  end

  def gather_traits(page_ids)
    # Wellllll... surprisingly, grabbing these one page at a time was WAAAAAAY faster than using { IN [ids] }, so:
    page_ids.each do |page_id|
      response = TraitBank::Queries.data_dump_page(page_id)
      next if response.nil?
      next if response['data'].nil? || response['data'].empty?
      @traits += response['data']
      gather_terms(response['data'])
      gather_metadata(response['data'].map(&:first))
    end
  end

  def gather_metadata(keys)
    keys.each do |id|
      meta_response = TraitBank::Queries.data_dump_trait(id)
      next if meta_response.nil?
      next if meta_response['data'].nil? || meta_response['data'].empty?
      @metadata += meta_response['data']
      gather_terms(meta_response['data'])
    end
  end

  def gather_terms(rows)
    rows.flatten.each do |v|
      @terms[v] = true if v && v.is_a?(String) && (v[0..3].downcase == 'http' || v[0..2].downcase == 'doi')
    end
  end

  def store_terms
    # NOTE this is an array of arrays.
    headers = %w(uri name definition type is_hidden_from_select is_hidden_from_glossary is_hidden_from_overview
      ontology_source_url ontology_information_url is_verbatim_only is_text_only section_ids attribution used_for
      comment position)
    terms = [headers]
    @terms.keys.each do |uri|
      response = TraitBank.term(uri)
      next if response.nil? || !response.key?("data")
      row = []
      headers.each { |header| row << response["data"][header] }
      terms << row
    end
    store_trait_data('terms', terms)
  end

  def store_trait_data(name, data)
    file_base_name = "#{name}.csv"
    filename = @page_dir.join(file_base_name)
    CSV.open(filename, 'w') { |csv| data.each { |row| csv << row } }
    log("--> #{data.size} rows written to #{filename}.")
    @filenames << file_base_name
  end

  def gather(source, source_ids, relationship)
    log("GATHER #{source}, (#{source_ids.size} ids), #{relationship.inspect}")
    if relationship.is_a?(Symbol) # e.g. :occurrence_map
      # log(".. SYMBOL")
      gather_relationship_ids(source, source_ids, relationship)
    elsif relationship.is_a?(Array)
      # log(".. ARRAY")
      relationship.each do |specific_relationship|
        gather(source, source_ids, specific_relationship)
      end
    elsif relationship.is_a?(Hash)
      # log(".. HASH")
      relationship.each do |child, descendants|
        # log(".. CHILD: #{child} ; DESC: #{descendants.inspect}")
        children_ids = gather_relationship_ids(source, source_ids, child)
        gather(child, children_ids, descendants)
      end
    else
      raise "I don't understand how to gather #{relationship} (#{relationship.class.name})"
    end
  end

  def gather_relationship_ids(source, source_ids, relationship)
    # log("GATHER_REL_IDS #{source}, (#{source_ids.size} ids), #{relationship.inspect}")
    relationship_class = objectify(relationship)
    relationship_name = strip_name(relationship)
    source_class = objectify(source)
    @tables[relationship_class] ||= []
    new_ids =
      if relationship_name == relationship_name.singularize
        # log("(singular)")
        source_class.where(id: source_ids).limit(@limit).pluck("#{relationship_name.singularize}_id")
      else
        # log("(plural)")
        filter = { "#{source_class.name.underscore.singularize}_id" => source_ids }
        parent_field = nil
        if relationship.to_s =~ /_AS_(\w+)$/
          # log(".. SPECIAL 'AS' HANDLER")
          parent_field = $1
          filter = { "#{parent_field}_id" => source_ids }
        end
        # AUGH! This is hard. Content is polymorphic, so handle the case specially:
        if parent_field == 'content'
          # log(".. SPECIAL CONTENT HANDLER")
          source_class.where(id: source_ids).limit(@limit).pluck('content_id')
        # ...and Referents keep the id in References:
        elsif source_class == Reference
          source_class.where(id: source_ids).limit(@limit).pluck('referent_id')
        else
          # log(".. NORMAL PLURAL")
          relationship_class.where(filter).limit(@limit).pluck(:id)
        end
      end
    new_ids.uniq!
    @tables[relationship_class] += new_ids
    # log(".. FOUND #{new_ids.size} new IDs")
    new_ids
  end

  def objectify(original_name)
    name = strip_name(original_name)
    Object.const_get(name.singularize.classify)
  end

  def strip_name(name)
    name.to_s.sub(/_(FILTER|AS)_\w+$/, '')
  end

  def log(what)
    # TODO: better logging. For now:
    ts = "[#{Time.now.strftime('%H:%M:%S.%3N')}]"
    puts "** #{ts} #{what}"
    Rails.logger.info("#{ts} SERIALIZER: #{what}")
  end
end
