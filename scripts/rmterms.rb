#!/usr/local/bin/ruby

lines = CSV.read(Rails.root.join('data', 'terms2rm.csv'))

def rels_by_direction(uri, direction = nil)
  relationship = direction == :incoming ? '<-[relationship]-' : '-[relationship]->'
  res = TraitBank.query(%Q{MATCH (term:Term { uri: "#{uri.gsub(/"/, '\"')}"})#{relationship}() RETURN TYPE(relationship)})['data'].first
  arr = Array(res).sort.uniq
  arr
end

deletes = []
puts "=" * 120
lines.each_with_index do |line,index|
  (name, uri, type) = line[0..2]
  # puts "Name: #{name} has a uri of #{uri}"
  term = begin
           TraitBank::Term.term_as_hash(uri)
         rescue ActiveRecord::RecordNotFound
           puts "Term #{uri} (#{name}) was already missing, skipped."
           next
         end
  out_rels = rels_by_direction(uri, :outgoing)
  in_rels = rels_by_direction(uri, :incoming)
  out_rels.delete('synonym_of') # We don't really care about these.
  out_rels.delete('parent_term') # We don't really care about these.
  out_rels.delete('units_term') # We don't really care about these.
  if !out_rels.empty?
    if !in_rels.empty?
      puts "WARNING: #{uri} has incoming relationships: #{in_rels.join(',')} AND outgoing relationships: #{out_rels.join(',')}"
      next
    else
      puts "WARNING: #{uri} has outgoing relationships: #{out_rels.join(',')}"
      next
    end
  elsif !in_rels.empty?
    puts "WARNING: #{uri} has incoming relationships: #{in_rels.join(',')}"
    next
  end
  deletes << %{MATCH (term:Term { uri: "#{uri.gsub(/"/, '\"')}"}) DETACH DELETE term}
end

puts "=" * 120
puts "DELETES:"
deletes.each do |q|
  puts q
  TraitBank.query(q)
end
puts "=" * 120
puts "Done. Deleted #{deletes.size} terms."
