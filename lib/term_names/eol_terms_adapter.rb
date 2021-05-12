class TermNames::EolTermsAdapter
  EXCLUDE_URI_PATTERN = /.*(geonames)|(wikidata).*/
  EXCLUDE_PROPERTIES = [
    'is_hidden_from_select',
    'is_hidden_from_overview',
    'is_hidden_from_glossary'
  ]

  def self.name
    'eol_terms'
  end

  def initialize(options)
    @names = []
    @defns = []

    puts "WARNING: Using EolTermsAdapter. Remember to paste the contents of the resulting files to config/locales/en.yml and config/locales/qqq.yml, then delete them before committing"
  end

  def skip_uri_query?
    true
  end

  def include_default_locale?
    true
  end

  def skip_definitions?
    true
  end

  def preload(uris, locales)
    all_terms = EolTerms.list(true)

    all_terms.each do |term|
      next if EXCLUDE_URI_PATTERN.match(term['uri'])
      next if EXCLUDE_PROPERTIES.find { |prop| term[prop] }

      @names << TermNames::Result.new(term['uri'], term['name'])
      @defns << TermNames::Result.new(term['uri'], term['definition'])
    end
  end

  def names_for_locale(locale)
    if locale.to_sym == :en
      @names
    else
      []
    end
  end

  def defns_for_locale(locale)
    if locale.to_sym == :en
      @defns
    else
      []
    end
  end
end

