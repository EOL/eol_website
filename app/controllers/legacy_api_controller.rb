class LegacyApiController < ApplicationController
  before_action :authenticate_token

protected

  def authenticate_token
    authenticate_with_http_token do |token, options|
      @user = User.find_by_api_key(token)
    end
  end

  def add_details_to_data_object(object_hash, object)
    object_hash[:created]                = object.created_at if object.created_at
    object_hash[:modified]               = object.updated_at if object.updated_at
    object_hash[:title]                  = object.name if object.respond_to?(:name) && !object.name.blank?
    object_hash[:title]                  = object.title if object.respond_to?(:title) && !object.title.blank?
    object_hash[:license]                = object.license.source_url if object.license
    object_hash[:license_id]             = object.license.id if object.license
    object_hash[:language]               = object.language&.locale&.code if object.language&.locale
    object_hash[:rights]                 = object.rights_statement if object.rights_statement
    object_hash[:rightsHolder]           = object.owner if object.owner
    object_hash[:bibliographicCitation]  = object.bibliographic_citation.body if object.bibliographic_citation
    if object.respond_to?(:source_page_url)
      object_hash[:source]                 = object.source_page_url if object.source_page_url
      object_hash[:mediaURL]               = object.source_url if object.source_url
    else
      object_hash[:source]                 = object.source_url if object.source_url
    end
    object_hash[:description]            = object.description if object.description
    if object.respond_to?(:image?)
      if object.image?
        object_hash[:eolMediaURL]          = object.original_size_url
        object_hash[:eolThumbnailURL]      = object.small_size_url
      elsif object.video?
        object_hash[:eolMediaURL]          = object.video_url if object.video_url || object.video_url == object.object_url
      elsif object.sound?
        object_hash[:eolMediaURL]          = object.sound_url if object.sound_url || object.sound_url == object.object_url
      end
    end

    # TODO: locations.
    # object_hash[:location]               = object.location unless object.location.blank?
    # unless object.latitude == 0 && object.longitude == 0 && object.altitude == 0
    #   object_hash[:latitude] = object.latitude unless object.latitude == 0
    #   object_hash[:longitude] = object.longitude unless object.longitude == 0
    #   object_hash[:altitude] = object.altitude unless object.altitude == 0
    # end

    object_hash[:agents] = []

    object.attributions.each do |agent|
      object_hash[:agents] << {
        full_name: agent.value,
        homepage: agent.url,
        role: agent.role&.name
      }
    end
    if object.resource
      object_hash[:agents] << {
        'full_name' => object.resource.name,
        'homepage'  => object.resource.url,
        'role'      => 'provider'
      }
    end
    object_hash.delete(:agents) if object_hash[:agents].empty?

    object_hash[:references] = object.references.flat_map(&:referent).map(&:body)
    object_hash.delete(:references) if object_hash[:references].empty?
    object_hash # no real need to return this, but hey.
  end

  def add_taxonomy_to_page(object_hash, page)
    object_hash[:taxonConcepts] =
      page.nodes.map do |node|
        node_hash = {
          identifier: node.id,
          scientificName: node.preferred_scientific_name&.verbatim,
          name: node.preferred_scientific_name&.verbatim,
          nameAccordingTo: node.resource&.name,
          canonicalForm: node.canonical,
          sourceIdentifier: node.resource_pk
        }
        node_hash[:taxonRank] = node.rank.name if node.rank
        node_hash
      end
    object_hash
  end
end
