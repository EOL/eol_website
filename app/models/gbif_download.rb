require 'net/http'
require 'uri'

class GbifDownload < ApplicationRecord
  belongs_to :user
  belongs_to :term_query
  validates_presence_of :user_id, :term_query_id
  validate :validate_taxa_query

  before_create :set_status_to_created

  enum status: { 
    created: 0, 
    processing: 1, 
    succeeded: 2, 
    failed: 3, 
    expired: 4 
  }

  PAGE_LIMIT = 100_000
  GBIF_CREATE_URI = URI("https://api.gbif.org/v1/occurrence/download/request?occurrence_status=present")
  GBIF_USERNAME = Rails.application.config.x.gbif_credentials[:username]
  GBIF_PASSWORD = Rails.application.config.x.gbif_credentials[:password]

  class << self
    def gbif_request_data(ids)
      {
        creator: GBIF_USERNAME,
        sendNotification: false,
        format: "SIMPLE_CSV",
        predicate: {
          type: "in",
          key: "TAXON_KEY",
          values: ids
        }
      }
    end

    def enabled_for_user?(user)
      user&.admin? || false
    end
  end

  def background_build
    begin
      Delayed::Worker.logger.info("Begin background GBIF job #{id} for #{term_query}")
      self.update(
        processing_since: Time.current,
        status: :processing
      )
      run
    rescue => e
      Delayed::Worker.logger.error("Error in background_build for GbifDownload")
      Delayed::Worker.logger.error(e.message)
      Delayed::Worker.logger.error(e.backtrace.join("\n"))
      self.status = :failed
      raise e
    ensure
      self.completed_at = Time.now

      if !save
        Delayed::Worker.logger.error("!!!Failed final save of GbifDownload #{id}")
      end

      Delayed::Worker.logger.info("End of background GBIF job #{id}")
    end
  end
  handle_asynchronously :background_build, queue: "download"

  private
  def run
    check_gbif_creds

    page_ids = TraitBank::Search.term_search(term_query, {
      page: 1,
      per: PAGE_LIMIT,
      id_only: true
    })[:data]
    gbif_pks = []
    
    page_ids.in_groups_of(10_000, false) do |page_ids|
      gbif_pks += Node.where(resource: Resource.gbif.id, page_id: page_ids).pluck(:resource_pk).collect { |pk| integer_or_nil pk }
    end
    gbif_pks.compact!

    req = Net::HTTP::Post.new(GBIF_CREATE_URI, "Content-Type" => "application/json")
    req.body = self.class.gbif_request_data(gbif_pks).to_json
    req.basic_auth GBIF_USERNAME, GBIF_PASSWORD

    response = Net::HTTP.start(GBIF_CREATE_URI.hostname, GBIF_CREATE_URI.port, use_ssl: true) do |http|
      http.request(req)
    end

    self.response_code = response.code

    if response.is_a? Net::HTTPCreated
      self.result_url = response["location"]
      self.status = :succeeded
    else
      self.error_response = response.body  
      self.status = :failed
    end

    self.save!
  end

  def validate_taxa_query
    if !term_query.taxa?
      errors.add(:term_query, "must have result_type == :taxa")
    end
  end

  def set_status_to_created
    self.status = :created
  end

  def check_gbif_creds
    raise "GBIF username not set in secrets.yml" if GBIF_USERNAME.blank?
    raise "GBIF password not set in secrets.yml" if GBIF_PASSWORD.blank?
  end

  def integer_or_nil(str)
    Integer(str) rescue nil
  end
end
