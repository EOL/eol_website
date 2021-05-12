require "set"

class TermQueryFilterConverter
  class << self
    def run
      TermQueryFilter.find_in_batches do |batch|
        puts "processing batch of filters"

        term_uris = Set.new

        batch.each do |filter|
          uris = [
            filter.pred_uri,
            filter.obj_uri,
            filter.units_uri,
            filter.sex_uri,
            filter.lifestage_uri,
            filter.statistical_method_uri 
          ].reject { |uri| uri.blank? }

          term_uris.merge(uris)
        end

        puts "fetching terms"
        terms = TermNode.where(uri: term_uris.to_a)
        terms_by_uri = terms.map { |t| [t.uri, t] }.to_h
        warn_missing_terms(term_uris, terms_by_uri)

        puts "updating filters"
        batch.each do |filter|
          filter.predicate_id = terms_by_uri[filter.pred_uri]&.id if filter.pred_uri.present?
          filter.object_term_id = terms_by_uri[filter.obj_uri]&.id if filter.obj_uri.present?
          filter.units_term_id = terms_by_uri[filter.units_uri]&.id if filter.units_uri.present?
          filter.sex_term_id = terms_by_uri[filter.sex_uri]&.id if filter.sex_uri.present?
          filter.lifestage_term_id = terms_by_uri[filter.lifestage_uri]&.id if filter.lifestage_uri.present?
          filter.statistical_method_term_id = terms_by_uri[filter.statistical_method_uri]&.id if filter.statistical_method_uri.present?

          puts "failed to update filter #{filter.id}: #{filter} (#{filter.errors.full_messages}). Consider manually deleting." unless filter.save
        end
      end

      puts "done!"
    end

    private

    def warn_missing_terms(term_uris, terms_by_uri)
      term_uris.each do |uri|
        if !terms_by_uri.include?(uri)
          puts "WARNING: missing Term for #{uri}"
        end
      end
    end
  end
end
