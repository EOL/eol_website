module DataIntegrityCheck::ZeroCountCheck
  # including classes must implement query and build_count_message methods
 
  def run
    params = respond_to?(:query_params, true) ? query_params : {}
    result = ActiveGraph::Base.query(query, params).to_a.first
    count = result[:count]
    status = count == 0 ? :passed : :failed
    message = build_count_message(count)

    DataIntegrityCheck::Result.new(status, message)
  end
end
