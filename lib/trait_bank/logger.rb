module TraitBank
  class Logger
    class << self
      LOGGER = Rails.application.config.neo4j.logger

      def log(message)
        LOGGER.info(message)
      end

      def warn(message)
        LOGGER.warn(message)
      end

      def log_error(message)
        LOGGER.error(message)
      end
    end
  end
end
