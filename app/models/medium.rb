# TODO: unmodified URL is probably not required; it's currently unused. ...Maybe delete it? Maybe use it. Not sure.
class Medium < ApplicationRecord
  include Content
  include Content::Attributed

  # Yes, we store this in two places. First, we log who set the icon when:
  has_many :page_icons, inverse_of: :medium
  # And then we denormlize the latest so we can query it efficiently:
  has_many :pages, inverse_of: :medium
  has_many :collected_pages_media, inverse_of: :medium
  has_many :collected_pages, through: :collected_pages_media
  has_many :collections, through: :collected_pages

  has_one :image_info, inverse_of: :image
  has_one :hidden_medium

  # NOTE: these enums MUST be kept in sync with the harvester codebase! Be careful. Sorry for the conflation.
  enum subclass: %i[image video sound map_image js_map]
  enum format: %i[jpg youtube flash vimeo mp3 ogg wav mp4 ogv mov svg webm]

  scope :images, -> { where(subclass: subclasses[:image]) }
  scope :maps, -> { where(subclass: subclasses[:map_image]) }
  scope :videos, -> { where(subclass: subclasses[:video]) }
  scope :sounds, -> { where(subclass: subclasses[:sound]) }
  scope :not_maps, -> { where.not(subclass: subclasses[:map_image]) }
  scope :regular, -> { not_maps.joins("LEFT JOIN hidden_media ON hidden_media.medium_id = media.id").where("hidden_media.id IS NULL") }

  # NOTE: No, there is NOT a counter_culture here for pages, as this object does NOT reference pages itself.

  # NOTE: this is temp code, for use ONCE. If you're reading this, i've probably already run it and you can
  # probably already delete it.
  class << self
    def fix_wikimedia_attributes(start_row = 1)
      DataFile.dbg('STARTING')
      resource = Resource.find_by_name('Wikimedia Commons')
      # :identifier, :term_name, :agent_role, :term_homepage
      agents_file = Rails.root.join('public', 'data', 'wikimedia', 'agent.tab')
      # :subtype, :access_uri, :usage_terms, :owner, :agent_id
      media_file = Rails.root.join('public', 'data', 'wikimedia', 'media_resource.tab')
      @agents = DataFile.to_hash(agents_file, :identifier)
      @media = DataFile.to_hash(media_file, :access_uri)
      logger = ActiveSupport::TaggedLogging.new(Logger.new("public/data/wikimedia/missing.log"))
      @roles = {}
      Role.all.each { |role| @roles[role.name.downcase] = role.id }
      @licenses = {}
      License.all.each { |lic| @licenses[lic.source_url.downcase] = lic.id }
      DataFile.dbg('Looping through media...')
      total_media = @media.keys.size
      last_row = 0
      begin
        @media.keys.each_with_index do |access_uri, i|
          next if i < start_row
          last_row = i+1
          pct = (last_row / total_media.to_f * 1000).ceil / 10.0
          DataFile.dbg(".. now on medium [#{i+1}](#{access_uri.gsub(')', '%29')})/#{total_media} (#{pct}% complete)") if i == start_row || (i % 25).zero?
          row = @media[access_uri]
          agents = []
          unless row[:agent_id].blank?
            row[:agent_id].split(/;\s*/).each do |agent_id|
              if @agents.has_key?(agent_id)
                agents << @agents[agent_id].merge(identifier: agent_id)
              else
                DataFile.dbg("Missing agent #{agent_id}, leaving agents blank for #{access_uri}")
              end
            end
          end
          medium = Medium.where(resource_id: resource.id, source_url: access_uri)
          if medium.empty?
            next
          end
          medium = medium.first
          unless row[:subtype].blank?
            # The ONLY value we have in there (as of this writing) is "map"
            medium.subclass = :map_image
          end
          medium.attributions.delete_all
          agents.each do |agent|
            # :identifier, :term_name, :agent_role, :term_homepage
            role_id = if @roles.has_key?(agent[:agent_role])
                        @roles[agent[:agent_role]]
                      else
                        DataFile.dbg("Unknown agent role: #{agent[:agent_role]}; using 'contributor'.")
                        @roles['contributor']
                      end
            if agent[:term_homepage] && agent[:term_homepage].length > 512
              logger.tagged("Agent URL too long: #{agent[:term_homepage]}") { logger.warn(access_uri) }
              next
            end
            attribution = Attribution.create(content_id: medium.id, content_type: 'Medium', role_id: role_id,
              value: agent[:term_name], url: agent[:term_homepage], resource_id: resource.id,
              content_resource_fk: agent[:identifier])
            medium.attributions << attribution
          end
          medium.owner = row[:owner]
          if row[:usage_terms]
            if @licenses.has_key?(row[:usage_terms])
              medium.license_id = @licenses[row[:usage_terms]]
            else
              DataFile.dbg("Unknown license: #{row[:usage_terms]} skipping...")
            end
          end
          medium.save
        end
      rescue => e
        DataFile.dbg("** ERROR! Ended on row #{last_row}: #{e}")
        sleep(10)
        start_row = last_row
        DataFile.dbg("** Resuming with start_row #{start_row}: #{e}")
        retry
      end
    end

    def regular_subclass_keys
      self.subclasses.keys.reject do |k|
        k == "map" || k == "js_map"
      end.sort
    end
  end

  def fix_source_pages
    source_page = Page.find(page_id)
    ancestry = source_page.ancestors.map(&:page_id) << page_id
    new_pages = ancestry - page_contents.map(&:page_id)
    bad_pages = page_contents.map(&:page_id) - ancestry
    page_contents.where(page_id: bad_pages).delete_all
    new_pages.each do |page_id|
      position = PageContent.where(page_id: page_id).maximum(:position) + 1
      begin
        PageContent.create(content: self, page_id: page_id, position: position, resource_id: resource_id,
          source_page_id: page_id, trust: :trusted)
      rescue ActiveRecord::RecordNotUnique
        # Ignore.
      end
    end
  end

  def source_pages
    if page_contents.loaded? && page_contents.first&.association(:page)&.loaded?
      page_contents.select { |pc| pc.source_page_id == page_id }.map(&:page)
    else
      page_contents.includes(page: %i[native_node preferred_vernaculars]).sources.map(&:page)
    end
  end

  # TODO: we will have our own media server with more intelligent names:
  # Image-only methods
  def original_size_url
    check_is_image
    orig = Rails.configuration.x.image_path[:original]
    ext = Rails.configuration.x.image_path[:ext]
    base_url + "#{orig}#{ext}"
  end

  def large_size_url
    check_is_image
    base_url + format_image_size(580, 360)
  end

  def medium_icon_url
    check_is_image
    base_url + format_image_size(130, 130)
  end
  alias_method :icon, :medium_icon_url

  def medium_size_url
    check_is_image
    base_url + format_image_size(260, 190)
  end

  def small_size_url
    check_is_image
    base_url + format_image_size(98, 68)
  end

  def small_icon_url
    check_is_image
    base_url + format_image_size(88, 88)
  end

  # Drat. :S
  def name(_language = nil)
    self[:name]
  end

  def url_with_format
    if invalid_format_video?
      source_url
    else
      "#{base_url}.#{format}"
    end
  end

  def sound_url
    # TODO:
    '#'
  end

  def video_url
    # TODO:
    '#'
  end

  def format_image_size(w, h)
    join = Rails.configuration.x.image_path[:join]
    by = Rails.configuration.x.image_path[:by]
    ext = Rails.configuration.x.image_path[:ext]
    "#{join}#{w}#{by}#{h}#{ext}"
  end

  def vitals
    [name, "#{license.name} #{owner.html_safe}"]
  end

  def extra_search_data
    {
      :subclass => subclass
    }
  end

  def embedded_video?
    video? && (youtube? || vimeo?)
  end

  def invalid_format_video?
    video? && jpg?
  end

  def real_format
    # bandaid for incorrect format assigned by harvest
    if invalid_format_video?
      :ogv # so far, we've seen this problem with flv and ogg. We can't display the former, so this won't break them any more than they already are.
    else
      format
    end
  end

  def embed_url
    raise "only supported for embedded video types" unless embedded_video?

    if youtube?
      "https://www.youtube.com/embed/#{unmodified_url}?enablejsapi=1"
    end
  end

  def hidden?
    hidden_medium.present?
  end

  def media_type
    if mp3?
      'audio/mpeg'
    elsif ogg?
      'audio/ogg'
    elsif wav?
      'audio/wav'
    elsif mp4?
      'video/mp4'
    elsif ogv? || invalid_format_video? # bandaid for harvesting issue
      'video/ogg'
    elsif mov?
      'video/quicktime'
    elsif svg?
      'image/svg+xml'
    elsif webm?
      'video/webm'
    else
      'image/jpeg'
    end
  end

  private
    def check_is_image
      raise "method may only be called when Medium subclass is image or map" unless image? || map_image?
    end
end
