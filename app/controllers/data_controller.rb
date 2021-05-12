class DataController < ApplicationController
  include DataAssociations
  include TraitBank::Constants

  helper :data
  protect_from_forgery

  def show
    @trait = Trait.find(params[:id])
    page_id = params[:page_id]
    @page = page_id.present? ? Page.find(page_id) : @trait.page

    trait_has_page = @page.nil? ||
                     @trait.page == @page || 
                     @trait.object_page == @page || 
                     @trait.query_as(:trait).match('(page:Page)-[:inferred_trait]->(trait)')
                      .where('page.page_id': @page.id)
                      .return('count(*) AS count').first[:count] > 0

    raise ActiveRecord::RecordNotFound unless trait_has_page

    if request.xhr?
      @show_taxon = params[:show_taxon] && params[:show_taxon] == "true"
      render :layout => false
    else
      group_predicate = @trait.query_as(:trait)
        .match('(trait)-[:predicate]->(:Term)-[:synonym_of*0..]->(group_predicate:Term)')
        .where_not('(group_predicate)-[:synonym_of]->(:Term)')
        .proxy_as(TermNode, :group_predicate).first

      redirect_to "#{page_data_path(page_id: @page.id, predicate_id: group_predicate.id)}#trait_id=#{@trait.id}"
    end
  end
end
