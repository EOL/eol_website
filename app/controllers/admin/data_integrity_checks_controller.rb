class Admin::DataIntegrityChecksController < AdminController
  def index
    @checks = DataIntegrityCheck.all_most_recent
  end

  def show
    @type = params.require(:id)
    @limit = 20
    @checks = DataIntegrityCheck.where(type: @type).order('created_at DESC').limit(@limit).map do |record|
      { type: @type, record: record }
    end
  end

  def run_all
    DataIntegrityCheck.run_all
    redirect_to action: "index"
  end

  def run
    type = params.require(:type)
    message = DataIntegrityCheck.run(type) ? 'created' : 'already pending'
    flash[:notice]  = message
    redirect_to action: "index"
  end

  def detailed_report
    @type = params.require(:type)
    @report = DataIntegrityCheck.detailed_report(@type)
  end
end
