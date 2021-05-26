class Rank < ApplicationRecord
  # Obnoxiously, some of these terms are reserved, so ugly r_ to distinguish:
  enum treat_as: [
    :r_domain,
    :r_subdomain,
    :r_infradomain,

    :r_superkingdom,
    :r_kingdom,
    :r_subkingdom,
    :r_infrakingdom,

    # Also division, for botany:
    :r_superphylum,
    :r_phylum,
    :r_subphylum,
    :r_infraphylum,

    :r_superclass,
    :r_class,
    :r_subclass,
    :r_infraclass,

    :r_superorder,
    :r_order,
    :r_suborder,
    :r_infraorder,

    :r_superfamily,
    :r_family,
    :r_subfamily,
    :r_infrafamily,

    :r_tribe,

    :r_supergenus,
    :r_genus,
    :r_subgenus,
    :r_infragenus,

    :r_superspecies,
    :r_species,
    :r_subspecies,
    :r_infraspecies, # Also variety (botany)
    :r_form
  ]

  class << self
    def all_species_ids
      Rails.cache.fetch("ranks/all_species_ids") do
        where(treat_as: Rank.treat_as[:r_species]).pluck(:id)
      end
    end

    # Useful for deciding whether or not it's worth showing an icon, among other
    # things.
    def species_or_below
      Rails.cache.fetch("ranks/species_or_below") do
        where(["treat_as IN (?)", [
          Rank.treat_as[:r_superspecies],
          Rank.treat_as[:r_species],
          Rank.treat_as[:r_subspecies],
          Rank.treat_as[:r_infraspecies],
          Rank.treat_as[:r_form]
        ]]).pluck(:id)
      end
    end

    def fill_in_missing_treat_as
      where(treat_as: nil).find_each do |rank|
        guess = guess_treat_as(rank.name)
        rank.update_attribute(:treat_as, guess) if guess
      end
    end

    def guess_treat_as(name)
      return "r_#{name}".to_sym if treat_as.has_key?("r_#{name}".to_sym)
      return :r_infraphylum if name =~ /infradiv/
      return :r_superphylum if name =~ /superdiv/
      return :r_subphylum if name =~ /subdiv/
      return :r_phylum if name =~ /div/
      return :r_infraspecies if name =~ /variety/
      treat_as.keys.sort_by { |k| -k.length }.each do |key|
        key_without_prefix = key.sub(/^r_/, "")
        key_with_abbrs = key_without_prefix.sub(/kingdom/, "k").sub(/species/, "sp").
          sub(/genus/, "g").sub(/family/, "fam").sub(/class/, "c")
        if name =~ /#{key_without_prefix}/
          return key.to_sym
        elsif name =~ /#{key_with_abbrs}/
          return key.to_sym
        end
      end
      nil
    end
  end

  def species_or_below?
    Rank.species_or_below.include?(self.id)
  end

  def i18n_name
    if treat_as
      I18n.t("rank.name.#{treat_as}")
    else
      nil
    end
  end

  def self.family_ids
    @family_ids ||= self.where(treat_as: treat_as[:r_family]).pluck(:id)
  end
end
