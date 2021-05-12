class TermNodesController < ApplicationController
  def show
    term_node = TermNode.find(params[:id].to_i)

    url = if term_node.known_type?
      param = if term_node.predicate?
        :predicate_id
      elsif term_node.object_term?
        :object_term_id
      end

      term_search_results_path(tq: TermQuery.new({
        result_type: :record,
        filters: [
          TermQueryFilter.new(param => term_node.id)
        ]
      }).to_short_params)
    else
      term_node.uri
    end

    redirect_to url, status: 302
  end
end
