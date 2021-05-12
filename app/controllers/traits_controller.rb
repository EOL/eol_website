class TraitsController < ApplicationController
  include DataAssociations

  helper :data

  before_action :no_main_container, only: [:search, :search_results, :search_form, :show]
  before_action :build_query, only: [:create_search, :search_results, :search_form]
  before_action :set_title, only: [:search, :search_results]

  PER_PAGE = 50
  GBIF_LINK_LIMIT = PER_PAGE
  GBIF_DOWNLOAD_LIMIT = 100_000
  GBIF_BASE_URL = "https://www.gbif.org/occurrence/map"
  VIEW_TYPES = Set.new(%w(list gallery))

  DataViz = Struct.new(:type, :data)

  def search
    @query = TermQuery.new(:result_type => :taxa)
    @query.filters.build
  end

  # The search form POSTs here and is redirected to a clean, short shareable url
  def create_search
    @query.remove_really_blank_filters
    redirect_to term_search_results_path(tq: @query.to_short_params), status: 302
  end

  def search_results
    @query.remove_really_blank_filters

    return redirect_to term_search_results_path(tq: @query.to_short_params), status: 301 if params[:term_query] # short params version is canonical

    set_view_type

    respond_to do |fmt|
      fmt.html do
        if @query.valid?
          Rails.logger.warn @query.to_s
          search_common
        else
          @query.add_filter_if_none
          render "search"
        end
      end

      fmt.csv do
        if !current_user
          redirect_to new_user_session_path
        else
          if @query.valid?
            url = term_search_results_url(:tq => @query.to_short_params)
            if UserDownload.user_has_pending_for_query?(current_user, @query)
              flash[:notice] = t("user_download.have_pending", url: user_path(current_user))
              redirect_to url
            else
              data = TraitBank::DataDownload.term_search(@query, current_user.id, url)

              if data.is_a?(UserDownload)
                flash[:notice] = t("user_download.created", url: user_path(current_user))
                redirect_to url
              else
                send_data data
              end
            end
          else
            redirect_to url
          end
        end
      end
    end
  end

  def search_form
    render :layout => false
  end

  # obsolete route, 301
  def show
    # See TermsHelper#term_records_path
    redirect_path = helpers.term_records_path(params)
    redirect_to redirect_path, status: 301
  end

  private
  def tq_params
    params.require(:term_query).permit(TermQuery.expected_params)
  end

  def short_tq_params
    params.require(:tq).permit(TermQuery.expected_short_params)
  end

  def build_query
    @query = params[:tq].present? ? TermQuery.from_short_params(short_tq_params) : TermQuery.new(tq_params)
    @query.filters[params[:show_extra_fields].to_i].show_extra_fields = true if params[:show_extra_fields]
    @query.filters[params[:hide_extra_fields].to_i].clear_extra_fields if params[:hide_extra_fields]
    @query.filters.delete @query.filters[params[:remove_filter].to_i] if params[:remove_filter]
    @query.filters.build(:op => :is_any) if params[:add_filter]
  end

  def search_common
    @page = params[:page]&.to_i || 1
    @per_page = PER_PAGE
    Rails.logger.warn "&&TS Running search:"
    @search = TraitSearch.new(@query)
      .per_page(@per_page)
      .page(@page)
  
    build_gbif_url(@query, @search)
    data_viz_type(@query, @search)
    render "search"
  end

  def set_title
    @page_title = t("page_titles.traits.search")
  end

  def build_gbif_url(query, search)
    if query.taxa? && search.count > 0 && Resource.gbif
      if search.count <= GBIF_LINK_LIMIT
        gbif_params = search.grouped_data.collect do |trait|
          pk = trait.page.nodes.find_by(resource_id: Resource.gbif.id)&.resource_pk
          pk ? "taxon_key=#{pk}" : nil
        end.compact

        if gbif_params.any?
          @gbif_url = "#{GBIF_BASE_URL}?#{gbif_params.join("&")}&occurrence_status=present"
        end
      elsif search.count <= GBIF_DOWNLOAD_LIMIT && GbifDownload.enabled_for_user?(current_user)
        @create_gbif_download_url = gbif_downloads_create_path(term_query: query.to_params)
      end
    end
  end

  def data_viz_type(query, search)
    valid_for_taxon_summary = TraitBank::Stats.check_search_valid_for_taxon_summary(search).valid

    if TraitBank::Stats.check_query_valid_for_assoc(query).valid
      @data_viz_type = :assoc
    elsif TraitBank::Stats.check_query_valid_for_counts(query).valid
      @data_viz_type = :bar
    elsif TraitBank::Stats.check_query_valid_for_histogram(query, search.count).valid
      @data_viz_type = :hist
    elsif TraitBank::Stats.check_query_valid_for_sankey(query).valid
      @data_viz_type = :sankey
    elsif valid_for_taxon_summary
      @data_viz_type = :taxon_summary
    end

    @fallback_data_viz_type = @data_viz_type != :taxon_summary && valid_for_taxon_summary ?
      :taxon_summary :
      nil
  end

  def set_view_type
    if params[:view].present? && VIEW_TYPES.include?(params[:view])
      @view_type = params[:view]
      session["ts_view_type"] = @view_type
    else
      @view_type = session["ts_view_type"] || "list"
    end
  end

  private

  def build_query_for_display(tb_res)
    query = tb_res[:raw_query].gsub(/^\ +/, '') # get rid of leading whitespace

    tb_res[:params].each do |k, v|
      val = v.is_a?(String) ? "\"#{v}\"" : v
      query = query.gsub("$#{k}", val.to_s)
    end

    @raw_query = query
  end
end
