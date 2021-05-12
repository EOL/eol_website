require_relative 'boot'

require 'rails/all'
require 'active_graph/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module EolWebsite
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.2

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
        # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.default_locale = :en
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]
    config.i18n.available_locales = %i(en mk fi pt-BR fr zh-TW zh-CN pms tr ar el nl)

    # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
    # the I18n.default_locale when a translation cannot be found).
    config.i18n.fallbacks = true

    config.exceptions_app = self.routes
    config.data_glossary_page_size = 250

    # For activenode/ruby-neo4j-driver gems, not neography
    config.neo4j.driver.url = Rails.application.secrets.neo4j_driver_url
    config.neo4j.driver.username = Rails.application.secrets.neo4j_user
    config.neo4j.driver.password = Rails.application.secrets.neo4j_password
    config.neo4j.driver.encryption = false

    # Search for classes in the lib directory
    config.autoload_paths += %W(#{config.root}/lib)
    config.eager_load_paths += %W(#{config.root}/lib) # NOTE: make sure this stays the same as autoload_paths!

    # set x-robots-tag header to noindex for all requests
    config.x.block_crawlers = Rails.application.secrets.block_crawlers || false

    # disallowed prefixes for robots.txt and X-Robots-Tag header
    config.x.robots_disallow_patterns = [
      "/api/",
      "/users/",
      "/resources/*/nodes/",
      "/search/"
    ]

    config.x.geonames_app_id = Rails.application.secrets.geonames_app_id

    # scaffold config
    config.generators do |g|
      g.test_framework nil
      g.scaffold_stylesheet false
      g.javascript_engine :js
    end

    config.active_storage.service = :local
    Rails.application.routes.default_url_options[:host] = Rails.application.secrets.host[:name]

    config.x.gbif_credentials = Rails.application.secrets.gbif_credentials

    # point autocomplete to localized fields
    config.x.autocomplete_i18n_enabled = true
    config.active_job.queue_adapter = :sidekiq

    # neo4j log
    config.neo4j.logger = ActiveSupport::TaggedLogging.new(Logger.new(Rails.root.join('log', 'traitbank.log')))
    config.neo4j.logger.level = Logger::DEBUG
    config.neo4j.logger.formatter = proc do |severity, datetime, progname, msg|
      "#{datetime} [#{severity}]: #{msg}\n"
    end
    config.neo4j.pretty_logged_cypher_queries = true
  end
end
