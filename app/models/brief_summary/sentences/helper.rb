class BriefSummary
  module Sentences
    class Helper
      def initialize(tagger, view)
        @tagger = tagger
        @view = view
      end

      def add_term_to_fmt(fstr, label, predicate, term, source = nil)
        check_fstr(fstr)

        sprintf(
          fstr,
          @tagger.tag(label, predicate, term, source)
        )
      end

      def add_obj_page_to_fmt(fstr, obj_page)
        check_fstr(fstr)

        page_part = obj_page.nil? ?
          '(page not found)' :
          @view.link_to(obj_page.short_name.html_safe, obj_page)

        sprintf(fstr, page_part)
      end

      def add_trait_val_to_fmt(fstr, trait, options = {})
        raise TypeError, "trait can't be nil" if trait.nil?
        check_fstr(fstr)

        if trait.object_page.present?
          add_obj_page_to_fmt(fstr, trait.object_page)
        elsif trait.predicate.present? && trait.object_term.present?
          name = trait.object_term.name
          name = name.pluralize if options[:pluralize]

          add_term_to_fmt(
            fstr, 
            name,
            trait.predicate, 
            trait.object_term,
            nil
          )
        elsif trait.literal.present?
          sprintf(fstr, trait.literal)
        else
          raise BriefSummary::BadTraitError, "Invalid trait for add_trait_val_to_fmt: #{trait.id}"
        end
      end

      private
      def check_fstr(fstr)
        raise TypeError, "fstr can't be blank" if fstr.blank?
      end
    end
  end
end
