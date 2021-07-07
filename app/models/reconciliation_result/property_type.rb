class ReconciliationResult
  PropertyType = Struct.new(:id) do
    self::ANCESTOR = self.new('ancestor')
    self::RANK = self.new('rank')
    self::ALL = [
      self::ANCESTOR,
      self::RANK
    ]

    def name
      I18n.t("reconciliation.property.name.#{id}")
    end

    def description
      I18n.t("reconciliation.property.description.#{id}")
    end
  end
end
