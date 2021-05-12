class UserDownload < ApplicationRecord
  belongs_to :user, inverse_of: :user_downloads
  belongs_to :term_query
  has_one :download_error, class_name: "UserDownload::Error", dependent: :destroy # Weird exceptions in delayed_job when this was set to just "error".
  validates_presence_of :user_id
  validates_presence_of :count
  validates_presence_of :term_query
  validates_presence_of :search_url

  after_destroy :delete_file

  accepts_nested_attributes_for :term_query

  enum status: { created: 0, completed: 1, failed: 2 }
  enum duplication: { original: 0, duplicate: 1 }

  scope :pending, -> do
    where("created_at >= ?", EXPIRATION_TIME.ago)
      .where(status: :created)
  end

  scope :for_user_display, -> do
    where("(created_at >= ? AND status != ?) OR status = ?", EXPIRATION_TIME.ago, UserDownload.statuses[:completed], UserDownload.statuses[:completed])
  end

  EXPIRATION_TIME = 30.days
  VERSION = 1 # IMPORTANT: Increment this when making changes where you don't want older downloads to be reused

  class << self
    # TODO: this should be set up in a regular task.
    def self.expire_old
      where(expired_at: nil).where("created_at < ?", EXPIRATION_TIME.ago).
        update_all(expired_at: Time.now)
    end

    # ADMIN method (not called in code) to clear out jobs both in the DB and in Delayed::Job
    def all_clear
      pending.delete_all
      Delayed::Job.where(queue: :download).delete_all
    end
    alias_method :all_clear!, :all_clear

    def create_and_run_if_needed!(ud_attributes, new_query, options)
      download = UserDownload.new(ud_attributes.merge(version: VERSION))
      query = TermQuery.find_or_save!(new_query)
      download.term_query = query

      existing_download = !options[:force_new] && query.user_downloads
        .where(status: :completed, expired_at: nil, duplication: :original)
        .where("created_at >= ?", EXPIRATION_TIME.ago)
        .where(version: VERSION)
        .order("created_at DESC")&.first

      if existing_download
        download.filename = existing_download.filename
        download.status = :completed
        download.duplication = :duplicate
        download.completed_at = Time.now
      else
        download.duplication = :original
      end

      download.save!

      if !download.completed?
        download.background_build_with_delay
      end

      download
    end

    def user_has_pending_for_query?(user, term_query)
      existing_query = TermQuery.find_saved(term_query)
      existing_query&.user_downloads&.where(user: user, status: :created)&.any? || false
    end
  end

  # NOTE: for timing reasons, this does NOT #save the current model, you should do that yourself.
  def mark_as_failed(message, backtrace)
    self.transaction do
      self.status = :failed
      self.completed_at = Time.now # Yes, this is duplicated from #background_build, but it's safer to do so.
      build_download_error({message: message, backtrace: backtrace})
    end
  end

  def processing?
    self.processing_since.present?
  end

private
  def background_build
    begin
      Delayed::Worker.logger.warn("Begin background build of #{count} rows for #{term_query} -> #{search_url}")
      self.update(processing_since: Time.current)
      downloader = TraitBank::DataDownload.new(term_query, count, search_url)
      self.filename = downloader.background_build
      self.status = :completed
    rescue => e
      Delayed::Worker.logger.error("!! ERROR in background_build for User Download #{id}")
      Rails.logger.error("!! ERROR in background_build for User Download #{id}")
      Rails.logger.error("!! #{e.message}")
      Delayed::Worker.logger.error("!! #{e.message}")
      Rails.logger.error("!! #{e.backtrace.join('->')}")
      Delayed::Worker.logger.error("!! #{e.backtrace.join('->')}")
      mark_as_failed(e.message, e.backtrace.join("\n"))
      raise e
    ensure
      self.completed_at = Time.now
      save! # NOTE: this could fail and we lose everything.
      Delayed::Worker.logger.warn("End background build of #{count} rows for #{term_query} -> #{search_url}")
    end
  end
  handle_asynchronously :background_build, :queue => "download"

  def delete_file
    if self.completed? && !self.filename.blank? && self.original?
      path = TraitBank::DataDownload.path.join(self.filename)
      begin
        File.delete(path)
      rescue => e
        Rails.logger.error("Failed to delete user download file #{path}", e)
      end
    end
  end
end
