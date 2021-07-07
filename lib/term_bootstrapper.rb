# frozen_string_literal: true

# This is meant to be "one-time-use-only" code to generate a "bootstrap" for the eol_terms gem, by
# reading all of the terms we have in neo4j and writing a YML file with all of that info in it.
#
# > TermBootstrapper.new.create('/app/public/data/terms.yml') # For example...
# Done.
# Wrote 3617 term hashes to `/app/public/data/terms.yml` (7637890-21 lines).
# => nil
#
# And now you can download it from e.g. http://eol.org/data/terms.yml or http://beta.eol.org/data/terms.yml
#
# For testing purposes, remember that
#
# http://eol.org/schema/terms/extant is a parent of http://eol.org/schema/terms/conservationDependent
# http://www.geonames.org/4099753 should have two:
# https://www.fws.gov/southeast/ and http://eol.org/schema/terms/South_central_US
# http://eol.org/schema/terms/bodyMassDry should also have two parents.
#
# And
#
# http://purl.obolibrary.org/obo/GO_0040011 is the synonym of http://www.owl-ontologies.com/unnamed.owl#Locomotion
class TermBootstrapper
  # NOTE: This must be updated if you intend to pick up new fields from EolTerms
  RECOGNIZED_FIELDS = %w[
    alias
    attribution
    definition
    eol_id
    is_hidden_from_select
    is_hidden_from_overview
    is_hidden_from_glossary
    is_text_only
    parent_uris
    units_term_uri
    name
    synonym_of_uri
    type
    uri
    is_symmetrical_association
    inverse_of_uri
    exclusive_to_clade_id
    incompatible_with_clade_id
  ]

  def initialize
  end

  def create(filename = nil)
    @filename = filename
    create_yaml
    report
  end

  # NOTE: this clears cache! It *must*, because there could be deltas that haven't been captured yet. BE AWARE!
  def load
    Rails.cache.clear
    # This raises an exception if it finds any. You will have to deal with it yourself!
    check_for_case_duplicates
    reset_comparisons
    compare_with_gem
    create_terms
    update_terms
    delete_terms
    puts "Done. Terms loaded."
  end

  def raw_terms_from_neo4j
    return @raw_terms_from_neo4j unless @raw_terms_from_neo4j.nil?
    @raw_terms_from_neo4j = []
    page = 0
    while data = TraitBank::Term.full_glossary(page += 1, 1000, include_hidden: true)
      break if data.empty?
      @raw_terms_from_neo4j << data # Uses less memory than #+=
    end
    @raw_terms_from_neo4j.flatten! # Beacuse we used #<<
  end

  def check_for_case_duplicates
    seen = {}
    raw_terms_from_neo4j.each do |term|
      raise("DUPLICATE URI (case is different): #{term[:uri]} vs #{seen[term[:uri].downcase]}") if
        seen.key?(term[:uri].downcase)
      seen[term[:uri].downcase] = term[:uri]
    end
  end

  def terms_from_neo4j
    return @terms_from_neo4j unless @terms_from_neo4j.nil?
    @terms_from_neo4j = []
    raw_terms_from_neo4j.each do |term|
      term = TraitBank::Term.yamlize_keys(term)
      next unless term['uri'] =~ /^htt/ # Most basic check for URI-ish-ness. Should be fine for our purposes.
      # NOTE: .add_yml_fields is VERY SLOW and accounts for about 90% of the time of the whole #create method. S'okay.
      @terms_from_neo4j << TraitBank::Term.add_yml_fields(term)
    end
    @terms_from_neo4j
  end

  # NOTE: not used in the codebase. This is for debugging purposes.
  def term_from_neo4j_by_uri
    return @term_from_neo4j_by_uri if @term_from_neo4j_by_uri
    @term_from_neo4j_by_uri = {}
    terms_from_neo4j.each { |term| @term_from_neo4j_by_uri[term['uri']] = term }
    @term_from_neo4j_by_uri
  end

  def create_yaml
    File.open(@filename, 'w') do |file|
      file.write "# This file was automatically generated from the eol_website codebase using TermBootstrapper.\n"
      file.write "# COMPILED: #{Time.now.strftime('%F %T')}\n"
      file.write "# You MAY edit this file as you see fit. You may remove this message if you care to.\n\n"
      file.write({ 'terms' => terms_from_neo4j }.to_yaml)
    end
  end

  def report
    puts "Done."
    lines = `wc #{@filename} | awk '{print $1;}'`.chomp
    puts "Wrote #{terms_from_neo4j.size} term hashes to `#{@filename}` (#{lines} lines)."
  end

  def reset_comparisons
    @new_terms = []
    @update_terms = []
    @uris_to_delete = []
  end

  def compare_with_gem
    seen_uris = {}
    terms_from_neo4j.each do |term_from_neo4j|
      # Nothing we can do about these. They *should* be removed... but that's not the job of this class.
      next if term_from_neo4j['uri'].nil?
      seen_uris[term_from_neo4j['uri'].downcase] = true
      unless term_from_gem_by_uri.key?(term_from_neo4j['uri'])
        @uris_to_delete << term_from_neo4j['uri']
        next
      end
      term_from_gem = term_from_gem_by_uri[term_from_neo4j['uri']]
      unless equivalent_terms(term_from_gem, term_from_neo4j)
        puts "** Needs update: #{term_from_gem['uri']}"
        term_from_gem.keys.sort.each do |k|
          puts "key #{k}: gem: '#{term_from_gem[k]}' vs neo4j: '#{term_from_neo4j[k]}'" unless term_from_gem[k].to_s == term_from_neo4j[k].to_s
        end
        @update_terms << term_from_gem
      end
    end
    term_from_gem_by_uri.each do |uri, term_from_gem|
      @new_terms << term_from_gem unless seen_uris.key?(uri.downcase)
    end
  end

  def equivalent_terms(term_from_gem, term_from_neo4j)
    return true if term_from_gem == term_from_neo4j # simple, fast check
    term_from_gem.keys.each do |key|
      if (
          (key == 'eol_id' && term_from_gem[key] != term_from_neo4j[key]) || # if one has an integer eol_id and the other a string, they aren't equivalent
          term_from_gem[key].to_s != term_from_neo4j[key].to_s 
      )
        # Ignore false-like values compared to false:
        next if term_from_gem[key] == [] && term_from_neo4j[key].blank?
        next if term_from_gem[key] == 'false' && term_from_neo4j[key].blank?
        next if term_from_neo4j[key] == 'false' && term_from_gem[key].blank?
        next if term_from_neo4j[key] == 'false' && term_from_gem[key].blank?
        puts "TERM #{term_from_gem['uri']} does not match on '#{key}':\n"\
             "gem: {#{term_from_gem[key]}}\n"\
             "neo: {#{term_from_neo4j[key]}}"
        return false
      end
    end
    return false if term_from_gem.keys.sort != term_from_neo4j.keys.sort
    true
  end

  def term_from_gem_by_uri
    return @term_from_gem_by_uri unless @term_from_gem_by_uri.nil?
    @term_from_gem_by_uri = {}
    EolTerms.list.each do |gem_term|
      term = {}

      RECOGNIZED_FIELDS.each do |field|
        term[field] = gem_term[field] || ''

        if field =~ /^is_/
          term[field] = false if term[field].blank?
        end
      end

      # Sort the parents, to match results from neo4j:
      term['parent_uris'] = Array(term['parent_uris']).sort
      @term_from_gem_by_uri[term['uri']] = term
    end
    @term_from_gem_by_uri
  end

  def create_terms
    # TODO: Someday, it would be nice to do this by writing a CSV file and reading that. Much faster. But I would prefer to
    # generalize the current Slurp class before attempting it.
    puts "Creating #{@new_terms.size} new terms..."
    @new_terms.each do |term|
      TraitBank::Term.create(term)
    end
  end

  def update_terms
    puts "Updating #{@update_terms.size} terms..."
    @update_terms.each { |term| TraitBank::Term.update(term) }
  end

  def delete_terms
    # First you have to make sure they aren't related to anything. If they are, warn. But, otherwise, it should be safe to
    # delete them.
    puts "Removing #{@uris_to_delete.size} terms..."
    @uris_to_delete.each do |uri|
      next if uri_has_relationships?(uri)
      TraitBank::Term.delete(uri)
    end
  end

  def uri_has_relationships?(uri)
    out_rels = rels_by_direction(uri, :outgoing)
    in_rels = rels_by_direction(uri, :incoming)

    # We don't really care about these.
    out_rels.delete('synonym_of') 
    out_rels.delete('parent_term') 
    out_rels.delete('units_term') 
    out_rels.delete('object_for_predicate')
    in_rels.delete('object_for_predicate')

    if !out_rels.empty?
      if !in_rels.empty?
        puts "WARNING: #{uri} has incoming relationships: #{in_rels.join(',')} AND outgoing relationships: #{out_rels.join(',')}"
        true
      else
        puts "WARNING: #{uri} has outgoing relationships: #{out_rels.join(',')}"
        true
      end
    elsif !in_rels.empty?
      puts "WARNING: #{uri} has incoming relationships: #{in_rels.join(',')}"
      true
    else
      false
    end
  end

  def rels_by_direction(uri, direction = nil)
    relationship = direction == :incoming ? '<-[relationship]-' : '-[relationship]->'
    res = TraitBank.query(%Q{MATCH (term:Term { uri: "#{uri.gsub(/"/, '\"')}"})#{relationship}() RETURN TYPE(relationship)})['data'].first
    arr = Array(res).sort.uniq
    arr
  end
end
