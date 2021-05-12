class TermQuery < ApplicationRecord
  has_many :filters,
    :class_name => "TermQueryFilter",
    :dependent => :destroy,
    :inverse_of => :term_query
  validates_associated :filters
  has_many :user_downloads, dependent: :destroy
  has_many :gbif_downloads, dependent: :destroy
  belongs_to :clade, :class_name => "Page", optional: true
  validates_presence_of :result_type
  validate :validation
  validates_uniqueness_of :digest, unless: Proc.new { |q| q.digest.nil? }

  enum :result_type => { :record => 0, :taxa => 1 }

  accepts_nested_attributes_for :filters

  def self.from_short_params(short_params)
    tq = self.new(
      clade_id: short_params[:c], 
      result_type: short_params[:r]
    )

    tq.filters = short_params[:f]&.keys&.sort&.map do |k|
      TermQueryFilter.from_short_params(short_params[:f][k])
    end || []

    tq
  end

  def to_short_params
    params = {
      r: result_type,
      f: filters.map.with_index { |f, i| [i, f.to_short_params] }.to_h
    }

    if clade
      params[:c] = clade.id
    end

    params
  end

  def predicate_filters
    filters.select { |f| f.predicate? }
  end

  def object_term_filters
    filters.select { |f| f.object_term? }
  end

  def numeric_filters
    filters.select { |f| f.numeric? }
  end

  def range_filters
    filters.select { |f| f.range? }
  end

  def to_s
    attrs = []
    attrs << "clade_id: #{clade_id}" if clade_id
    attrs << "filters_attributes: [#{filters.map(&:to_s).join(', ')}]"
    attrs << "result_type: #{result_type}"
    "&&TermQuery.new(#{attrs.join(',')}) "
  end

  def to_cache_key
    parts = ["term_query"]
    parts << "clade_#{clade_id}" if clade_id
    parts << filters.map(&:to_cache_key).join('/') unless filters.empty?
    parts << "type_#{result_type}"
    parts.join('/')
  end

  # NOTE: this method is never called; it's used in a console.
  def run(options = {})
    options.reverse_merge(per: 10, page: 1, result_type: :record) # Smaller number for console testing.
    TraitBank::Search.term_search(self, options)[:data]
  end

  def to_params
    {
      result_type: result_type,
      clade_id: clade&.id,
      filters_attributes: filters.collect { |f| f.to_params }
    }
  end

  def remove_really_blank_filters
    self.filters = self.filters.reject { |f| f.really_blank? }
  end

  def add_filter_if_none
    self.filters.build if filters.empty?
  end

  def deep_dup
    copy = dup
    copy.filters = self.filters.collect { |f| f.dup }
    copy.reset_page_count_sorted_filters
    copy
  end

  # You MUST call this method if you want a digest saved along with the record. At the time of writing, this was only used by UserDownloads, and adding callbacks/validations messed with trait search.
  def build_digest
    Digest::MD5.hexdigest(self.to_cache_key)
  end

  def refresh_digest
    self.digest = build_digest
  end

  def clade_node
    if clade
      @clade_node ||= PageNode.find(clade.id)
    else
      nil
    end
  end

  class << self
    def find_saved(new_query)
      digest = new_query.build_digest
      TermQuery.find_by_digest(digest)
    end

    def find_or_save!(new_query)
      new_query.refresh_digest
      query = TermQuery.find_by_digest(new_query.digest)

      if query.nil?
        new_query.save!
        query = new_query
      end

      query
    end

    def expected_params
      [
        :clade_id,
        :result_type,
        :filters_attributes => [
          :predicate_id,
          :root_predicate_id,
          :object_term_id,
          :obj_clade_id,
          :op,
          :num_val1,
          :num_val2,
          :units_term_id,
          :sex_term_id,
          :lifestage_term_id,
          :statistical_method_term_id,
          :resource_id,
          :show_extra_fields,
          :predicate_child_selects_attributes => [
            :type,
            :parent_term_id,
            :selected_term_id
          ],
          :object_term_child_selects_attributes => [
            :type,
            :parent_term_id,
            :selected_term_id
          ]
        ]
      ]
    end

    def expected_short_params
        [
          :c,
          :r,
          :f => TermQueryFilter.expected_short_params
        ]
    end
  end

  def page_count_sorted_filters
    @page_count_sorted_filters ||= filters.sort { |a, b| a.min_distinct_page_count <=> b.min_distinct_page_count }
  end

  def reset_page_count_sorted_filters # needed for deep_dup
    @page_count_sorted_filters = nil
  end

  def valid_ignoring_blank_filters?
    copy = self.deep_dup
    copy.remove_really_blank_filters
    copy.valid?
  end

  private
  def validation
    if filters.empty?
      if taxa? && clade.nil?
        errors.add(:base, I18n.t("term_query.validations.empty_filters_error_taxa"))
      elsif record?
        add_filter_if_none
        filters.first.valid? # To trigger error on field as well. This is scary (side-effects in validation??) but convenient.
        errors.add(:base, I18n.t("term_query.validations.empty_filters_error_record"))
      end
    end
  end
end
