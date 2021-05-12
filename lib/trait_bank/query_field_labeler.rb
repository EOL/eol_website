class TraitBank::QueryFieldLabeler
  attr_reader :label, :type, :index

  class << self
    def create_from_field(field, index)
      self.new(nil, field.type, index)
    end
  end

  def initialize(override_label, type, index)
    @label = override_label || type.to_s + index.to_s
    @type = type
    @index = index 
  end

  def gathered_label
    @gathered_label ||= "gathered_#{label}"
  end

  def gathered_list_label
    @list_label ||= "#{gathered_label}s"
  end

  def tgt_label
    @tgt_label ||= "tgt_#{type}#{index}"
  end
end
