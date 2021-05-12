require "http"

class TermNames::WikidataAdapter
  include TermNames::ResponseCheck

  # Example uris:
  # "https://www.wikidata.org/entity/Q764"
  # "https://www.wikidata.org/wiki/Q7075151" 
  ID_CAPTURE_REGEX = /https?:\/\/www\.wikidata\.org\/[^\/]+\/(?<id>Q\d+)/
  BASE_URL = "http://www.wikidata.org/wiki/Special:EntityData/"

  def self.name
    "wikidata"
  end

  def initialize(options)
    @name_storage = TermNames::NameStorage.new
    @defn_storage = TermNames::NameStorage.new
  end

  def uri_regexp
    "https?:\/\/www\.wikidata\.org\/.*"
  end

  def preload(uris, locales)
    uris.each do |uri|
      id = (matches = uri.match(ID_CAPTURE_REGEX)) ? matches[:id] : nil
      next if id.nil?

      url = BASE_URL + id + ".json"
      response = HTTP.follow.get(url)
      next if !check_response(response)
      entity = response.parse.dig("entities", id)
      store_locale_values("labels", @name_storage, entity, uri, locales)
      store_locale_values("descriptions", @defn_storage, entity, uri, locales)
    end

    sleep 1 # throttle api calls
  end

  def names_for_locale(locale)
    @name_storage.names_for_locale(locale)
  end

  def defns_for_locale(locale)
    @defn_storage.names_for_locale(locale)
  end

  private
  def store_locale_values(key, storage, entity, uri, locales)
    by_locale = entity&.[](key)

    if by_locale
      locales.each do |locale|
        val = by_locale.dig(locale.to_s, "value")
        next if val.nil?
        storage.set_value_for_locale(locale, uri, val)
      end
    else
      puts "WARN: failed to retrieve #{key} for #{uri} -- continuing"
    end
  end
end

