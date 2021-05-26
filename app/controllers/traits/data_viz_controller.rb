require "set"

module Traits
  class DataVizController < ApplicationController
    before_action :set_1d_about_text, only: [:bar, :hist]
    before_action :set_query

    layout "traits/data_viz"

    BAR_CHART_LIMIT = 15

    CountVizResult = Struct.new(:label, :query, :count, :noclick) do
      def noclick?
        noclick
      end
    end

    class HistData
      attr_reader :buckets, :max_bi, :bw, :min, :max_count, :units_term

      class Bucket
        attr_reader :index, :min, :limit, :count, :query, :buckets

        def initialize(raw_index, raw_count, bw, min, query, units_uri)
          @index = raw_index.to_i
          @min = min + bw * @index
          @limit = @min + bw # limit rather than max, since no value in the bucket ever reaches this limit -- it's an asymptote
          @count = raw_count.to_i

          @query = query.deep_dup
          qf = @query.filters.first
          qf.num_val1 = @min
          qf.num_val2 = @limit
          qf.units_uri = units_uri
        end

        def to_h
          {
            min: min,
            limit: limit,
            count: count
          }
        end
      end

      # TODO: update to use TermNode rather than TraitBank query methods
      def initialize(tb_result, query)
        cols = tb_result["columns"]
        data = tb_result["data"]
        i_bi = cols.index("bi")
        i_bw = cols.index("bw")
        i_count = cols.index("c")
        i_min = cols.index("min")
        units_uri = query.filters.first.units_term&.uri || TraitBank::Term.units_for_term(query.filters.first.predicate.uri)

        raise TypeError, 'failed to get a units term for query' if units_uri.nil?

        @units_term = TraitBank::Term.term_record(units_uri)

        @max_bi = data.last[i_bi].to_i
        @bw = self.class.to_d_or_i(data.first[i_bw])
        @min = self.class.to_d_or_i(data.first[i_min])

        @max_count = 0

        result_stack = data.collect do |d|
          @max_count = d[i_count] if d[i_count] > @max_count
          Bucket.new(d[i_bi], d[i_count], @bw, @min, query, @units_term[:uri])
        end.reverse
        
        cur_bucket = result_stack.pop

        @buckets = (0..@max_bi).collect do |i|
          if cur_bucket.index == i
            prev_bucket = cur_bucket
            cur_bucket = result_stack.pop
            prev_bucket
          else
            Bucket.new(i, 0, @bw, @min, query, @units_term[:uri])
          end
        end
      end

      def length
        @buckets.length
      end

      class << self
        def to_d_or_i(str_val)
          d = str_val.to_d
          (d % 1).zero? ? d.to_i : d
        end
      end
    end

    def bar
      result = TraitBank::Stats.obj_counts(@query, BAR_CHART_LIMIT)
      @data = result.collect { |r| obj_count_result_from_row(@query, r) }
      render_common
    end

    def taxon_summary 
      @data = Traits::DataViz::TaxonSummary.new(@query)
      @about_text_key = 'about_this_chart_tooltip_taxon_summary'
      render_with_status(@data.child_node_count > 1)
    end

    def hist
      counts = TraitBank::Search.term_search(@query, { count: true })
      result = TraitBank::Stats.histogram(@query, counts.primary_for_query(@query))
      @data = HistData.new(result, @query)
      render_common
    end

    def sankey
      counts = TraitBank::Search.term_search(@query, { count: true })
      @sankey = Traits::DataViz::Sankey.create_from_query(@query, counts.primary_for_query(@query))
      set_sankey_about_text
      render_with_status(@sankey.multiple_paths?)
    end

    def assoc
      @data = AssocViz.new(@query, helpers, breadcrumb_type)
      @about_text_key = 'about_this_chart_tooltip_assoc'
      render_with_status(@data.should_display?)
    end

    private
    def render_common(options = {})
      render_with_status(@data.length > 1, options)
    end

    def render_with_status(any_data, options = {})
      status = any_data ? :ok : :no_content
      options[:status] = status
      render options
    end
      
    def obj_count_result_from_row(query, row)
      name = TraitBank::Record.i18n_name(row[:obj]).html_safe
      noclick = query.filters.first.object_term&.id == row[:obj][:eol_id]

      CountVizResult.new(
        name,
        TermQuery.new({
          clade_id: query.clade_id,
          result_type: query.result_type,
          filters_attributes: [{
            predicate_id: query.filters.first.predicate&.id,
            object_term_id: row[:obj][:eol_id] 
          }]
        }),
        row[:count],
        noclick
      )
    end

    def term_query_params
      params.require(:tq).permit(TermQuery.expected_short_params)
    end

    def set_1d_about_text
      @about_text_key = "about_this_chart_tooltip_1d"
    end

    def set_sankey_about_text
      @about_text_key = if @query.filters.length > 2
        "about_this_chart_tooltip_sankey_3+" 
      else
        "about_this_chart_tooltip_sankey_2d"
      end
    end

    def set_query
      @query = TermQuery.from_short_params(term_query_params)
    end
  end
end

