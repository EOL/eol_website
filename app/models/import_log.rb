class ImportLog < ApplicationRecord
  belongs_to :resource
  has_many :import_events, inverse_of: :import_log

  scope :successful, -> { where("completed_at IS NOT NULL") }
  scope :running, -> { where("completed_at IS NULL AND failed_at IS NULL") }

  class << self
    def all_clear!
      now = Time.now
      where(completed_at: nil, failed_at: nil).update_all(completed_at: now, failed_at: now)
      where(status: 'currently running').update_all(status: 'stopped')
      ImportRun.where(completed_at: nil).update_all(completed_at: now)
    end

    def already_running?
      undo = 'rake publish:clear if you are SURE these are in an acceptable state.'
      if ImportRun.where(completed_at: nil).any?
        return("A Publishing run appears to be active. #{undo}")
      end
      logging = ImportLog.where(completed_at: nil, failed_at: nil).includes(:resource)
      if logging.any?
        info = "Currently publishing: "
        info += logging.map do |log|
          if log.resource
            info += "ImportLog##{log.id}: #{log.resource.name} (Resource##{log.resource_id})"
          else
            info += "ImportLog##{log.id}: Missing Resource##{log.resource_id})"
          end
        end.join(' ; ')
        return info
      end
      false
    end
  end

  def log(body, options = nil)
    options ||= {}
    cat = options[:cat] || :starts
    chop_into_text_chunks(body).each do |chunk|
      import_events << ImportEvent.create(import_log: self, cat: cat, body: chunk)
    end
  end

  def chop_into_text_chunks(str)
    chunks = []
    while str.size > 65_500
      chunks << str[0..65_500]
      str = str[65_500..-1]
    end
    chunks << str
    chunks
  end

  def complete
    update_attribute(:completed_at, Time.now) unless destroyed?
    update_attribute(:status, 'completed') unless destroyed?
    resource.touch # Ensure that we see the resource as having changed
    log('Complete', cat: :ends)
  end

  def fail_on_error(e)
    if e.backtrace
      e.backtrace.reverse.each_with_index do |trace, i|
        break if trace =~ /\/bundler/
        break if i > 9 # Too much info, man!
        if i > 2
          # TODO: Add other filters here...
          next unless trace =~ /eol_website/
        end
        trace.gsub!(/^.*\/gems\//, 'gem:') # Remove ruby version stuff...
        trace.gsub!(/^.*\/ruby\//, 'ruby:') # Remove ruby version stuff...
        trace.gsub!(/^.*\/eol_website\//, './') # Remove website path..
        log(trace, cat: :errors)
      end
    end
    log(e.message.gsub(/#<(\w+):0x[0-9a-f]+>/, '\\1'), cat: :errors) # I don't need the memory information for models
    update_attribute(:failed_at, Time.now)
    update_attribute(:status, e.message[0..250])
  end
end
