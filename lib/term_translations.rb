require "util/term_i18n"
require "fileutils"

class TermTranslations
  ADAPTERS = [TermNames::GeonamesAdapter, TermNames::WikidataAdapter, TermNames::EolTermsAdapter]
  ADAPTERS_BY_NAME = ADAPTERS.collect { |a| [a.name, a] }.to_h
  LOCALE_FILE_DIR = Rails.application.root.join("config", "locales", "terms")
  TERM_LIMIT = 1500 # XXX: arbitrary limit based on Jen's estimates. Revisit as necessary.

  class << self
    def refresh(adapter_name, options={})
      if adapter_name
        user_adapter_class = ADAPTERS_BY_NAME[adapter_name]
        raise TypeError.new("Invalid provider name: #{adapter_name}") unless user_adapter_class
        adapters = [user_adapter_class]
      else
        adapters = ADAPTERS
      end

      adapters.each do |adapter_class|
        adapter = adapter_class.new(options)
        if adapter.respond_to?(:skip_uri_query?) && adapter.skip_uri_query?
          puts "Skipping uri query"
          uris = []
        else
          puts "Querying uris for adapter #{adapter_class.name}"
          uris = self.term_uris_for_adapter(adapter)
          puts "Got #{uris.length} results"
        end

        puts "Preloading..."
        adapter.preload(uris, I18n.available_locales)
        puts "Done preloading"
        locales = I18n.available_locales
        locales.reject! { |l| l == I18n.default_locale } unless adapter.respond_to?(:include_default_locale?) && adapter.include_default_locale?
        
        locales.each do |locale|
          write_locale_results(locale, adapter)
        end
      end

      puts "Done! Inspect the results, then commit them if everything looks good."
    end

    def term_uris_for_adapter(adapter)
      q = "MATCH (t:Term)\n"\
        "WHERE t.uri =~ '#{adapter.uri_regexp}'\n"\
        "RETURN t.uri\n"\
        "LIMIT #{TERM_LIMIT}"
      result = TraitBank.query(q)
      result["data"].collect { |r| r[0] }
    end

    def term_uris_for_geonames
      puts term_uris_for_adapter(TermNames::GeonamesAdapter)
    end

    def backup_file(file_path, bak_path)
      if File.exist?(file_path)
        puts "Copying existing file #{file_path} to #{bak_path}"
        FileUtils.cp(file_path, bak_path)
      end
    end

    private
    def write_locale_results(locale, adapter)
      puts "Processing results for locale #{locale}"

      names = adapter.names_for_locale(locale)
      defns = adapter.respond_to?(:defns_for_locale) ? adapter.defns_for_locale(locale) : []

      if names.empty? && defns.empty?
        puts "No results found for locale #{locale}. Not writing locale file."
        return
      end

      file_name = "#{adapter.class.name.downcase}.#{locale}.yml"
      bak_name = "#{adapter.class.name.downcase}.#{locale}.yml.bak"
      file_path = LOCALE_FILE_DIR.join(file_name)
      bak_path = LOCALE_FILE_DIR.join(bak_name)

      self.backup_file(file_path, bak_path)

      name_entries = results_to_entries(names)
      defn_entries = results_to_entries(defns)

      yaml_hash = {}
      yaml_hash["name"] = { "by_uri" => name_entries } if name_entries.any?
      yaml_hash["definition"] = { "by_uri" => defn_entries } if defn_entries.any? unless adapter.respond_to?(:skip_definitions?) && adapter.skip_definitions? # we still need the definitions for the qqq file, but don't write them to the en file

      puts "Writing results for locale #{locale} to #{file_path}"
      write_yaml(locale, file_path, yaml_hash)

      if locale == I18n.default_locale
        write_qqq(adapter.class, name_entries, defn_entries)
      end
    end

    def results_to_entries(results)
      entries = []

      results.each do |result|
        next if result.value.blank? # don't write blank definitions etc.

        entries << [Util::TermI18n.uri_to_key(result.uri), result.value]
      end

      entries.to_h
    end

    def write_yaml(locale, path, hash)
      File.open(path, "w") do |file|
        file.write({
          locale.to_s => {
            "term": hash
          } 
        }.to_yaml)
      end
    end

    def write_qqq(adapter_class, name_entries, defn_entries)
      path = LOCALE_FILE_DIR.join("#{adapter_class.name.downcase}.qqq.yml")

      entries = name_entries.keys.collect do |uri|
        if defn_entries[uri].present?
          [Util::TermI18n.uri_to_key(uri), defn_entries[uri]]
        else
          nil
        end
      end.compact.to_h

      if entries.any?
        puts "writing definitions to qqq file"
        write_yaml("qqq", path, { "name" => { "by_uri" => entries } })
      end
    end
  end
end

