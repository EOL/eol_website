class ApiHierarchyEntriesController < LegacyApiController
  def index
    set_default_params
    get_entry
    if @entry.empty?
      return raise ActionController::RoutingError.new('Not Found')
    end
    respond_to do |format|
      format.json { render json: @entry }
      format.xml { render xml: @entry.to_xml }
    end
  end

  private

  def set_default_params
    params[:common_names] = true unless params.has_key?(:common_names)
    params[:synonyms] = true unless params.has_key?(:synonyms)
    params[:language] ||= 'en'
  end

  def get_entry
    @entry = {}
    entry = Node.where(id: params[:id]).
         includes(:resource, :rank,
           node_ancestors: { ancestor: :rank },
           children: :rank,
           vernaculars: :language,
           scientific_names: :taxonomic_status,
           references: :referent).first
    return if entry.nil?
    @entry[:entry] = entry
    @entry[:sourceIdentifier] = entry.resource_pk
    @entry[:taxonID] = entry.id
    @entry[:parentNameUsageID] = entry.parent_id
    @entry[:taxonConceptID] = entry.page_id
    @entry[:scientificName] = entry.scientific_name
    @entry[:taxonRank] = entry.rank&.name
    @entry[:source] = page_url(entry.page)

    @entry[:nameAccordingTo] = [entry.resource.name] # Yes, in an array.

    if params[:common_names]
      @entry[:vernacularNames] = []
      entry.vernaculars.each do |name|
        name_hash = {}
        name_hash['vernacularName'] = name.string
        name_hash['language'] = name.language&.locale&.code
        name_hash['id'] = name.id
        @entry[:vernacularNames] << name_hash unless params[:language] && params[:language] != name_hash['language']
      end
    end

    @entry[:synonyms] = []
    if params[:synonyms]
      entry.scientific_names.each do |synonym|
        synonym_hash = {}
        synonym_hash['parentNameUsageID'] = entry.id
        synonym_hash['scientificName'] = synonym.verbatim
        synonym_hash['taxonomicStatus'] = synonym.taxonomic_status&.name || 'synonym'
        synonym_hash['id'] = synonym.id
        @entry[:synonyms] << synonym_hash
      end
    end

    @entry[:ancestors] = []
    entry.ancestors.compact.each do |ancestor|
      next if ancestor.id == entry.id
      ancestor_hash = {}
      ancestor_hash['sourceIdentifier'] = ancestor.resource_pk
      ancestor_hash['taxonID'] = ancestor.id
      ancestor_hash['parentNameUsageID'] = ancestor.parent_id
      ancestor_hash['taxonConceptID'] = ancestor.page_id
      ancestor_hash['scientificName'] = ancestor.scientific_name
      ancestor_hash['taxonRank'] = ancestor.rank&.name
      ancestor_hash['source'] = page_url(ancestor.page_id)
      @entry[:ancestors] << ancestor_hash
    end

    @entry[:children] = []
    entry.children.compact.each do |child|
      child_hash = {}
      child_hash['sourceIdentifier'] = child.resource_pk
      child_hash['taxonID'] = child.id
      child_hash['parentNameUsageID'] = child.parent_id
      child_hash['taxonConceptID'] = child.page_id
      child_hash['scientificName'] = child.scientific_name
      child_hash['taxonRank'] = child.rank&.name
      child_hash['source'] = page_url(child.page_id)
      @entry[:children] << child_hash
    end
    return @entry

  end
end
