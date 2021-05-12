module DataAssociations
  extend ActiveSupport::Concern

  def build_page_associations(page)
    build_associations_from_ids(page.association_page_ids)
  end


  def build_associations(data)
    ids = data.map { |t| t[:object_page_id] }.compact.sort.uniq
    build_associations_from_ids(ids)
  end

  private
  def build_associations_from_ids(ids)
    pages = Page.where(id: ids).
      includes(:medium, :preferred_vernaculars, native_node: [:rank])
    pages.collect { |p| [p.id, p] }.to_h
  end
end
