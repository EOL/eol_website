COMMON_Q = <<~CYPHER
  MATCH (t:Trait)-[:metadata]->(m:MetaData)-[:predicate]->(mp:Term {uri:"http://purl.org/dc/terms/contributor"})
  WHERE m.literal = "Compiler: Anne E Thessen"
CYPHER

COMP_TERM = "(c:Term { uri: 'https://orcid.org/0000-0002-2908-3327' })"

COUNT_Q = <<~CYPHER
  MATCH (t:Trait)-[:compiler]->#{COMP_TERM}
  RETURN count(DISTINCT t) AS count
CYPHER

LIMIT = 1000
MIGRATE_Q = <<~CYPHER
  #{COMMON_Q}
  WITH t, collect(m) AS ms
  LIMIT 1000
  UNWIND ms AS m
  DETACH DELETE m
  WITH collect(DISTINCT t) AS ts
  MATCH #{COMP_TERM}
  UNWIND ts AS t
  CREATE (t)-[:compiler]->(c)
  RETURN count(t) AS count
CYPHER

before_count = ActiveGraph::Base.query(COUNT_Q).first[:count]
puts "Before migration, there are #{before_count} traits with -[:compiler]->#{COMP_TERM}"

batch_count = LIMIT
migrated_count = 0

while batch_count == LIMIT
  batch_count = ActiveGraph::Base.query(MIGRATE_Q).first[:count]
  migrated_count += batch_count
end

puts "Migrated #{migrated_count} traits"

after_count = ActiveGraph::Base.query(COUNT_Q).first[:count]

puts "There are now #{after_count} traits with -[:compiler]->#{COMP_TERM}"

diff = after_count - before_count
puts "#{after_count} - #{before_count} = #{diff}"

if diff == migrated_count
  puts "Success!"
else
  puts "There should be #{migrated_count} new compiler traits, but there are #{diff}. Did something go wrong?"
end

