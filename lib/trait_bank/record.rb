# A TB Record is passed around as a hash. ...Thus these are really just class
# methods which are *passed* a hash. ...I'm not sure I like this and may change
# the code in the future to either extend the hash class itself or to force us
# to pass around Record instances instead of hashes. ..For now, though, this is
# simple enough.
module TraitBank
  module Record
    class << self
      def obj_term_uri(record)
        record.dig(:object_term, :uri)
      end

      def obj_term_name(record)
        record.dig(:object_term, :name)
      end

      def source(record)
        record[:source]
      end

      def resource_id(record)
        record.dig(:resource, :resource_id)
      end

      # These name methods work on TermNodes as well as hashes since the former's attributes can be accessed with []
      def i18n_name_for_locale(record, locale)
        i18n_attr_for_locale(record, :name, locale)
      end

      def i18n_name(record)
        i18n_name_for_locale(record, I18n.locale)
      end

      def i18n_defn(record)
        i18n_attr_for_locale(record, :definition, I18n.locale)
      end

      def i18n_inverse_name(record)
        if record[:is_symmetrical_association]
          name = i18n_name(record)
        else
          name = i18n_attr_for_locale(record, :inverse_name, I18n.locale)

          if name.nil?
            name = I18n.t('term.inverse_name.fallback', term_name: i18n_name(record))
          end
        end

        name
      end

      private
      def i18n_attr_for_locale(record, attr, locale)
        key = Util::TermI18n.uri_to_key(record[:uri], "term.#{attr.to_s}.by_uri")

        if I18n.exists?(key, locale: locale)
          I18n.t(key, locale: locale)
        else
          record[attr]
        end
      end
    end
  end
end
