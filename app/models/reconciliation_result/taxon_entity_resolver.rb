class ReconciliationResult
  class TaxonEntityResolver
    ID_REGEX = /^pages\/(\d+)$/

    attr_accessor :page

    def initialize(entity_hash)
      @page = resolve(entity_hash)
    end

    private
    def resolve(entity_hash)
      return nil unless entity_hash.include?('id')
      
      id_str = entity_hash['id']
      return nil if id_str.blank?

      match = ID_REGEX.match(id_str)
      return unless match

      Page.find_by(id: match[1])
    end
  end
end
