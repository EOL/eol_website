class OrderedFallbackLocale < ApplicationRecord
  belongs_to :locale
  belongs_to :fallback_locale, class_name: 'Locale'

  validates_presence_of :locale_id
  validates :fallback_locale_id, presence: true, uniqueness: { scope: [:locale_id] }
  validates :position, presence: true, uniqueness: { scope: [:locale_id] }

  YML_PATH = Rails.application.root.join('db', 'seed_data', 'fallback_locales.yml')

  class << self
    def rebuild
      puts "loading #{YML_PATH}"
      data = YAML.load_file(YML_PATH)

      puts "building fallback locales"

      self.transaction do 
        puts 'removing existing FallbackLocales (safely in a transaction)'

        self.destroy_all 

        puts 'rebuilding FallbackLocales'

        data.each do |locale_code, fallback_codes|
          puts "building fallbacks #{locale_code} -> #{fallback_codes}"

          locale = Locale.get_or_create!(locale_code)

          fallback_codes.each_with_index do |fallback_code, i|
            fallback_locale = Locale.get_or_create!(fallback_code)
            self.create!(locale: locale, fallback_locale: fallback_locale, position: i)
          end
        end
      end

      puts 'done'
    end
  end
end

