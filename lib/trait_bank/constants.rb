module TraitBank
  module Constants
    TRAIT_RELS = ":trait|inferred_trait"
    GROUP_META_VALUE_URIS = Set.new([
      EolTerms.alias_uri('stops_at')
    ])

    EXEMPLAR_URI = "https://eol.org/schema/terms/exemplary"
    PRIMARY_EXEMPLAR_URI = "https://eol.org/schema/terms/primary"
    EXEMPLAR_MATCH = "(trait)-[:metadata]->(exemplar: MetaData), (exemplar)-[:predicate]->(:Term { uri: '#{EXEMPLAR_URI}' }), (exemplar)-[:object_term]->(exemplar_value:Term)"
    EXEMPLAR_ORDER = "exemplar_value IS NOT NULL DESC, exemplar_value.uri = '#{PRIMARY_EXEMPLAR_URI}' DESC"
    PARENT_TERMS = ':parent_term|synonym_of*0..'
  end
end
