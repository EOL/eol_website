Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.ignore_actions = ['PagesController#ping', 'ApiPingController#index', 'HomePageController#index']
  config.cache_classes = true
  cache_addr = Rails.application.secrets.cache_url
  config.cache_store = :mem_cache_store, cache_addr, { namespace: "EOL", compress: true }
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_dispatch.default_headers = { 'X-Frame-Options' => 'ALLOWALL' }
  config.action_controller.perform_caching = true
  config.action_mailer.default_url_options = Rails.application.secrets.host.symbolize_keys
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = Rails.application.secrets.smtp.symbolize_keys
  config.active_support.deprecation = :log
  config.active_record.migration_error = :page_load
  
  config.log_level = :info

  config.assets.debug = false
  config.assets.digest = true
  config.assets.raise_runtime_errors = true

  config.after_initialize do
    ActiveRecord::Base.logger = Rails.logger.clone
    ActiveRecord::Base.logger.level = Logger::INFO
  end
end

# NOTE: it does seem a *little* silly to me to move all of the secrets to the configuration, but I think that makes
# sense, because it allows people to bypass Secrets and use custom configs with their own environments, if need-be.
Rails.configuration.repository_url = Rails.application.secrets.repository[:url]
Rails.configuration.eol_web_url = Rails.application.secrets.host[:url]
Rails.configuration.x.image_path = Rails.application.secrets.image_path
Rails.configuration.traitbank_url = Rails.application.secrets.traitbank_url
