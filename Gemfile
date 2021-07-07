source 'https://rubygems.org'

# The REALLY basic stuff stays at the top:

gem 'rails', '5.2.4.4'
# Use mysql2 as the database for Active Record
gem 'mysql2', '0.5.3'

# Fixes a licensing issue with Rails:
gem 'mimemagic', '0.3.10'

# "Internal" EOL gems:
gem 'eol_terms', '>= 0.9.16', git: 'https://github.com/EOL/eol_terms.git', branch: 'main'

# Asset-related gems next:
gem 'webpacker', '~> 5.x'

# SASS
# Sass is end-of-life. Update to sassc gem: https://github.com/sass/sassc-ruby#readme
gem 'sass-rails'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.10.2' # NOTE: as of Jan 2021, there is a 2.11, we should try swtiching next month.
# Use jquery as the JavaScript library TODO ... I don't think we do, anymore?
gem 'jquery-rails', '~> 4.4'
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 2.0', group: :doc
# javascript code from rails TODO: I don't think we want this, but could be wrong.
# See https://github.com/rails/execjs#readme for more supported runtimes
gem 'therubyracer', '~> 0.12'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '~> 4.2'

# NOTE: required to avoid weird error caused by the existence of .coffee files in node_modules
#gem 'coffee-rails'

# Use Unicorn as the app server. Not *strictly* required, but handy for development... and what we use in production
# anyway.
gem 'unicorn', '~> 5.8'
gem 'unicorn-worker-killer', '~> 0.4' # NOTE: there's now a unicorn-worker-killer-2 which we should switch to.

# Pagination with kaminari. It's out of order because the methods it uses need
# to be defined first for other classes to recognize them:
gem 'kaminari', '~> 1.2.1'

# All other non-environment-specific gems come next.
#
# ALPHABETICALLY, PLEASE.
#
# ...and with a comment above each gem (or block of related gems) explaining what it's for. Let's keep this
# maintainable!

# To aid in reindexing ElasticSearch. See also connection_pool; also requires redis.
# gem 'activejob-traffic_control', '>= 0.1.3'
# For bulk inserts:
gem 'activerecord-import', '~> 1.0'
# Acts As List simplifies ordered lists of models:
gem 'acts_as_list', '~> 1.0'
# Faster startup:
gem 'bootsnap', '~> 1.7', require: false
# To aid in reindexing ElasticSearch. See also activejob-traffic_control; also requires redis.
# gem 'connection_pool', '~> 2.2'
# Counter Culture handled cached counts of things (which we use ALL OVER):
gem 'counter_culture', '~> 2.7'
# Cron jobs:
gem 'crono', '~> 1.1'
# Run background jobs:
gem 'daemons', '~> 1.3'
# Memcached (not for development):
gem 'dalli', '~> 2.7'
# Background jobs (to be run by daemons, q.v.):
gem 'delayed_job', '~> 4.1'
gem 'delayed_job_active_record', '~> 4.1'
# Devise handles authentication and some authorization:
gem 'devise', '~> 4.7'
gem 'devise-i18n-views', '~> 0.3'
gem 'devise-encryptable', '~> 0.2'
# Discourse handles comments and chat:
gem 'discourse_api', '~> 0.40'
# Model decoration
gem 'draper', '~> 4.0'
# Icons
# TODO: update font-awesome (or remove if unused) since refinery is gone
# font-awesome-sass 4.7 is seriously behind; 5.12 is the latest, but our version of refinerycms-wymeditor requires < 5
gem 'font-awesome-sass', '~> 4.7'
# This is used to locally have a copy of OpenSans. IF YOU STOP USING OPENSANS, YOU SHOULD REMOVE THIS GEM!
gem 'font-kit-rails', '~> 1.2'
# url helpers in JS
gem 'js-routes', '1.4.9'
# jwt is used for JSON Web Token (JWT) standard API handshakes. ...This WAS included in Omniauth, which we removed.
gem 'jwt', '~> 2.2' # Note the gem is ruby-jwt
# Because ERB is just plain silly compared to Haml:
gem 'haml-rails', '~> 2.0'
# HTTP client
gem 'http', '~> 4.4'
# QUIET PLEASE MAKE IT STOP! This helps us cull some of the noise in the logs:
gem 'lograge', '~> 0.11'
# Site monitoring for staging and production:
gem 'newrelic_rpm' # NOT specifying a version for this one; it should NOT Interrupt normal use! Latest is best.
# Speed up JSON, including for ElasticSearch:
gem 'oj', '~> 3.11'
# Debugging:
gem 'pry-rails' # NOT specifying a version for this; latest is best.
# Authorization:
gem 'pundit', '~> 2.1'
# Turing test:
gem 'recaptcha', '~> 5.6', require: 'recaptcha/rails'
# Zip file support
gem 'rubyzip', '~> 2.2'
# ElasticSearch via SearchKick:
gem 'searchkick', '~> 4.4' # Needs to stay in sync (ish) with the elasticsearch gem.
# Searchkick uses sidekiq for job processing (really, anything BUT Delayed::Job, apparently), so I've installed it:
gem 'sidekiq'
gem 'elasticsearch', '~> 6' # Needs to stay in sync with the version of ES that we're using
# Simplify Forms:
# KEEPING client_side_validations OUT OF ORDER, since they are tightly bound to simple_form;
# these are ONLY used on the user page, in the user_helper's validate: true clause...
gem 'simple_form', '~> 5.0'
gem 'client_side_validations', '~> 16.2'
gem 'client_side_validations-simple_form', '~> 9.2'
# Speed up ElasticSearch ... but also good if you want to do web requests, see https://github.com/typhoeus/typhoeus
gem 'typhoeus', '~> 1.4'

# OGM (object graph mapper for Neo4J). Added for use with searchkick.
gem 'activegraph', '~> 10.0' # For example, see https://rubygems.org/gems/activegraph/versions for the latest versions
gem 'neo4j-ruby-driver', git: 'https://github.com/EOL/neo4j-ruby-driver.git', branch: '1.7'

#Sitemap
gem 'sitemap_generator', '~> 6.1'

# url slug support
gem 'friendly_id', '~> 5.4'

# translations in JS
gem 'i18n-js', '~> 3.8'

# CORS middleware
gem 'rack-cors'

# JSON schema-based validation
gem 'json_schemer'

group :development, :test do
  gem 'active_record_query_trace', '~> 1'
  # Security analysis:
  gem 'brakeman', '~> 5', :require => false
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', '~> 11'
  # Coveralls tracks our spec coverage:
  gem 'coveralls', '~> 0', require: false
  # Rails told me to add this to my development group. I don't know why, but I'm ... listening.
  gem 'listen', '~> 3'
  # Rubocop... which technically you want on your *system*, but ...
  gem 'rubocop', '0.93.1' # Being very specific because this is a PITA to update even a tiny bit!
  gem 'rubocop-performance', '1.9.2'
  gem 'rubocop-rails', '2.9.1'
  # Simplecov, oddly, to add configuration for Coveralls.
  gem 'simplecov', '~> 0'
  gem 'solargraph', '~> 0'
end

group :development do
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', '~> 3'

  # Spring speeds up development by keeping your application running in the background.
  # Read more: https://github.com/rails/spring
  gem 'spring', '~> 2'

  # I removed "mailcatcher" the docs (https://mailcatcher.me/) actually say as much: DON'T include it. Just install it
  # if you want to use it and ... uh... use it.

  # For benchmarking queries:
  gem 'meta_request', '~> 0'
end

group :test do
  gem 'rspec-rails', '~> 3'
  gem 'better_errors', '~> 2'
  gem 'capybara', '3'
  gem 'factory_girl', '~> 4'
  gem 'faker', '~> 2'
  gem 'rack_session_access', '~> 0'
  gem 'shoulda-matchers', '~> 4'
end
