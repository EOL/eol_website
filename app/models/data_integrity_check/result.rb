class DataIntegrityCheck::Result
  STATUSES = [:passed, :failed, :warned]

  attr_accessor :status, :message

  def initialize(status, message)
    raise TypeError, "invalid status: #{status}" unless STATUSES.include?(status)

    @status = status
    @message = message
  end

  def to_s
    "DataIntegrityCheck::Result[#{status}: #{message}]"
  end
end
