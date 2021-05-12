class TermNames::StaticDataAdapter
  FILE_NAMES = %w(all_terms)
  FILE_DIR = Rails.application.root.join("lib", "term_names", "static_data")
  FILE_PATHS = FILE_NAMES.collect do |name|
    FILE_DIR.join("#{name}.json")
  end

  def self.name
    "static_data"
  end

  def initialize(options)
    if options[:data_file]
      puts "using data file #{options[:data_file]}"
      @file_paths = [FILE_DIR.join(options[:data_file])]
    else
      puts "using all data files"
      @file_paths = FILE_PATHS
    end

    puts "WARNING: Using StaticDataAdapter. Remember to paste the contents of the resulting files to config/locales/en.yml and config/locales/qqq.yml, then delete them before committing"
  end

  def skip_uri_query?
    true
  end

  def include_default_locale?
    true
  end

  def preload(uris, locales)
    @names = []
    @defns = []


    @file_paths.each do |path|
      File.open(path) do |file|
        term_json = JSON.parse(file.read)

        term_json["data"].each do |record|
          @names << TermNames::Result.new(record[0], record[1])
          @defns << TermNames::Result.new(record[0], record[2].tr("\n", " "))
        end
      end
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
