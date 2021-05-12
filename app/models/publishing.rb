class Publishing
  attr_accessor :log, :run, :last_run_at
  attr_reader :pub_log

  def initialize(options)
    @pub_log = Publishing::PubLog.new(nil)
    @log = nil
    @repo = nil
    @page_ids = Set.new
    @last_run_at = options[:last_run_at].to_i if options.key?(:last_run_at)
  end

  def abort_if_already_running
    if (info = ImportLog.already_running?)
      puts info
      raise('ABORTED.')
    end
  end

  def get_import_run
    unless @last_run_at
      # NOTE: I'm allowing a significant amount of leeway, here:
      last_run = ImportRun.completed.order('completed_at DESC').limit(5).last
      # NOTE: We use the CREATED time! We want all new data as of the START of the import. In pracice, this is less than
      # perfect... ideally, we would want a start time for each resource... but this should be adequate for our
      # purposes.
      @last_run_at = ((last_run&.created_at || 10.years.ago) - 1.week).to_i
    end
    @run = ImportRun.create
  end

  def get_resources
    @pub_log.log("Getting updated resources...")
    # If there are only a handful of resources, we've just created the DB and the max created_at is useless.
    path = "resources.json?"
    repo = Publishing::Repository.new(log: @pub_log, since: @last_run_at)
    repo.loop_over_pages(path, "resources") do |resource|
      resource[:repository_id] = resource.delete(:id)
      partner = resource.delete(:partner)
      # NOTE: resources that have no associated partner are PURELY test data in the repository database:
      if partner.nil?
        @pub_log.log("!! WARNING: **SKIPPING** resource #{resource[:name]} (#{resource[:repository_id]}): "\
          "no partner defined!", cat: :warns)
        next
      end
      partner[:repository_id] = partner.delete(:id)
      partner = find_and_update_or_create(Partner, partner)
      resource[:partner_id] = partner.id
      resource.delete(:opendata_url) # XXX: hack to remove unsupported attribute -- not sure how this worked before (mvitale, 11/13/20)
      resource = find_and_update_or_create(Resource, resource)
      @pub_log.log("New/updated resource: #{resource[:name]}")
    end
  end

  def find_and_update_or_create(klass, model)
    if klass.where(repository_id: model[:repository_id]).exists?
      m = klass.find_by_repository_id(model[:repository_id])
      m.update_attributes(model)
      m
    else
      klass.create(model)
    end
  end
end
