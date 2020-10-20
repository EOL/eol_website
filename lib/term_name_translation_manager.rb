require "util/i18n_util"

class TermNameTranslationManager
  class << self
    def rebuild_node_properties
      base_fetch_query = %q(
        MATCH (t:Term) 
        WHERE t.is_hidden_from_select = false
      )

      count_query = %Q(
        #{base_fetch_query}
        RETURN count(t)
      )

      skip = 0
      limit = 1000 
      count = TraitBank.query(count_query)["data"].first.first

      while skip < count
        fetch_query = %Q(
          #{base_fetch_query}
          RETURN t.uri, t.name
          SKIP #{skip}
          LIMIT #{limit}
        )
        puts "fetching terms:\n#{fetch_query}"
        fetch_result = TraitBank.query(fetch_query)["data"].map { |r| { uri: r[0], name: r[1] } }

        fetch_result.each do |term_record|

          property_sets = Util::I18nUtil.non_default_locales.map do |locale|
            "t.#{Util::I18nUtil.term_name_property_for_locale(locale)} = \"#{TraitBank::Record.i18n_name_for_locale(term_record, locale).gsub('"', '\"')}\"" 
          end.join(", ")

          set_query = %Q(
            MATCH (t:Term{ uri: "#{term_record[:uri]}" })
            SET #{property_sets}
          )

          TraitBank.query(set_query)
        end

        skip += limit
      end

      puts "done"
    end
  end
end

