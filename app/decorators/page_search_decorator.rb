class PageSearchDecorator < SearchResultDecorator
  decorates :page
  delegate :icon

  def type
    :pages
  end

  def fa_icon
    "picture-o"
  end

  def title
    if object.name != object.scientific_name
      I18n.t("search.full_name", vernacular: object.name, scientific: object.scientific_name)
    else
      object.scientific_name
    end
  end

  def content
    if object.try(:search_highlights)&.any?
      search_highlights = object.search_highlights.values.map do |highlight|
        "\"#{highlight}\""
      end.to_sentence

      I18n.t("search.matched_text", text: search_highlights)
    else
      ""
    end
  end

  def page_id
    object.id
  end

  def native_node
    object&.native_node
  end

  def top_resources
    [
      ["media", object.media_count],
      ["data", TraitBank::Queries.count_by_page(object.id)],
      ["articles", object.articles_count],
    ].select { |x| x[1] > 0 }
  end

  def hierarchy
    h.summary_hierarchy(object, false)
  end

  def total_results
    object.response["hits"]["total"]
  end

private
#  def family_ancestor_name
#    ancestors = object.native_node.try(:ancestors)
#
#    return nil unless ancestors
#
#    ancestor = ancestors.detect do |a|
#      Rank.guess_treat_as(a.rank.name) === :r_family
#    end
#    ancestor ? ancestor.name : nil
#  end
end
