require "set"

# Different groups of 'growth habit' trait values are treated differently in BriefSummary. 
# This class provides functionality for classifying a growth habit trait by matching its object term
# against the uris in these groups.
class PageDecorator
  class BriefSummary
    class GrowthHabitGroup
      class << self 
        MATCHER = PageDecorator::BriefSummary::ObjUriGroupMatcher.new({
          type: :species_of_x, 
          uris: [
            EolTerms.alias_uri('tree'),
            EolTerms.alias_uri('shrub')
          ]
        }, {
          type: :species_of_lifecycle_x,
          uris: [
            "http://purl.obolibrary.org/obo/FLOPO_0900036",
            "http://purl.obolibrary.org/obo/FLOPO_0022142",
            "https://www.wikidata.org/entity/Q190903"
          ]
        }, {
          type: :species_of_x_a1,
          uris: [
            "http://eol.org/schema/terms/lichenous",
            "https://www.wikidata.org/entity/Q757163",
            "http://eol.org/schema/terms/semi-woody"
          ]
        }, {
          type: :is_an_x, 
          uris: [
            "http://eol.org/schema/terms/obligateClimber",
            "http://eol.org/schema/terms/facultativeClimber",
            "http://purl.obolibrary.org/obo/FLOPO_0900035",
            "https://www.wikidata.org/entity/Q14079",
            "http://www.wikidata.org/entity/Q189939"
          ]
        }, {
          type: :has_an_x_growth_form,
          uris: [
            "http://eol.org/schema/terms/crustose",
            "http://eol.org/schema/terms/squamulose",
            "http://eol.org/schema/terms/fructose",
            "http://eol.org/schema/terms/self-supportingGrowthForm",
            "http://eol.org/schema/terms/foliose",
            "http://purl.obolibrary.org/obo/PATO_0002389",
          ]
        },)

        def match_all(traits)
          MATCHER.match_all(traits)
        end
      end
    end
  end
end

