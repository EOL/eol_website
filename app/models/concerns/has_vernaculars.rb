module HasVernaculars
  extend ActiveSupport::Concern

  class_methods do
    def set_vernacular_fk_field(field_name)
      @vernacular_fk_field = field_name
    end

    def vernacular_fk_field
      @vernacular_fk_field
    end
  end

  def vernacular(options = {})
    vernacular_fk_field = self.class.vernacular_fk_field
    raise TypeError.new("must call set_vernacular_fk_field (e.g., :page_id from Page) first") if !vernacular_fk_field

    locale = options[:locale] || Locale.current
    fallbacks = options.fetch(:fallbacks, true)
    languages = locale.languages

    name = if preferred_vernaculars.loaded?
      Language.first_matching_record(languages, preferred_vernaculars)
    else
      if vernaculars.loaded?
        Language.all_matching_records(languages, vernaculars).find { |v| v.is_preferred? }
      else
        # I don't trust the associations. :|
        Vernacular.where(vernacular_fk_field => id, :language => languages).preferred.first
      end
    end

    if name.nil? && fallbacks
      locale.fallbacks.each do |l|
        fallback_name = vernacular(locale: l, fallbacks: false)
        return fallback_name if fallback_name
      end
    end
    
    name
  end
end
