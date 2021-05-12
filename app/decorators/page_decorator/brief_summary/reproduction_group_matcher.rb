class PageDecorator
  class BriefSummary
    class ReproductionGroupMatcher
      MATCHER = PageDecorator::BriefSummary::ObjUriGroupMatcher.new({
        type: :v,
        uris: [
          "http://purl.obolibrary.org/obo/GO_0019953",
          "http://purl.obolibrary.org/obo/GO_0019954",
          "http://eol.org/schema/terms/alternatingReproduction",
          "http://eol.org/schema/terms/transverseDivision",
          "https://eol.org/schema/terms/unisexual_flowers",
          "http://eol.org/schema/terms/dwarfMales",
          "http://polytraits.lifewatchgreece.eu/terms/SM_YES",
          EolTerms.alias_uri('parental_care')
        ]
      }, {
        type: :w,
        uris: [
          "http://purl.obolibrary.org/obo/UBERON_0010899",
          "http://purl.obolibrary.org/obo/UBERON_0007197",
          "http://purl.obolibrary.org/obo/UBERON_0010895",
          "http://eol.org/schema/terms/broadcastSpawner",
          "http://eol.org/schema/terms/sacSpawner",
          "http://purl.obolibrary.org/obo/UBERON_3010039",
          "http://purl.obolibrary.org/obo/UBERON_3010042"
        ] 
      }, {
        type: :x,
        uris: [
          "http://polytraits.lifewatchgreece.eu/terms/STRAT_ITER",
          "http://polytraits.lifewatchgreece.eu/terms/STRAT_SEM",
          "http://www.marinespecies.org/traits/Viviparous",
          "http://www.marinespecies.org/traits/Oviparous",
          "http://www.marinespecies.org/traits/Ovoviviparous",
          "https://www.wikidata.org/entity/Q148681",
          "https://eol.org/schema/terms/duodichogamous",
          "https://www.wikidata.org/entity/Q66368485",
          "https://eol.org/schema/terms/andromonoecious",
          "https://eol.org/schema/terms/polygamodioecious",
          "https://www.wikidata.org/entity/Q7226331",
          "http://purl.obolibrary.org/obo/HAO_0000048",
          "https://eol.org/schema/terms/dioicous",
          "https://eol.org/schema/terms/monoicous",
          "http://eol.org/schema/terms/diandry",
          "http://eol.org/schema/terms/monandry"
        ]        
      }, {
        type: :y,
        uris: [
          "http://eol.org/schema/terms/no",
          "http://ncicb.nci.nih.gov/xml/owl/EVS/Thesaurus.owl#C54166"
        ]        
      }, {
        type: :z,
        uris: [
          "http://eol.org/schema/terms/paternalCare",
          "http://eol.org/schema/terms/symbiontInheritance",
          "http://eol.org/schema/terms/occasionalCooperativeBreeding",
          "http://eol.org/schema/terms/parentalCarePair",
          "http://eol.org/schema/terms/CooperativeBreeding",
          "http://eol.org/schema/terms/parentalCareFemale",
          "http://eol.org/schema/terms/socialGroupCare",
          "http://eol.org/schema/terms/parentalCareMale",
          "http://purl.obolibrary.org/obo/CEPH_0000036"
        ]        
      })

      class << self
        def match_all(traits)
          matches = MATCHER.match_all(traits)

          if matches.has_type?(:z) && matches.has_uri?(EolTerms.alias_uri('parental_care'))
            matches.by_uri(EolTerms.alias_uri('parental_care')).each do |match|
              matches.remove(match)
            end
          end

          matches
        end
      end
    end
  end
end
