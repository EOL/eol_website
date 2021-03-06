class MoveUrisToTraitBank < ActiveRecord::Migration[4.2]
def up
    if TraitBank.ping
      TraitBank::Admin.create_constraints
      ActiveRecord::Base.connection.select_all("SELECT * FROM uris").each do |hash|
        hash.delete("id") # We don't actually want this stored; it's meaningless.
        # NOTE: we didn't give our URIs categories, at the time of this
        # migration, so they are ignored!
        #
        # Term: { *uri, *name, *section_ids(csv), definition, comment,
        #         attribution, is_hidden_from_overview, is_hidden_from_glossary }
        TraitBank::Term.create(hash.symbolize_keys)
        TraitBank.connection.execute_query(
          "MATCH (trait:Trait), (term:Term { uri: '#{hash["uri"]}' }) "\
          "WHERE trait.predicate = term.uri "\
          "CREATE (trait)-[pred:predicate]->(term) "\
          "REMOVE trait.predicate "\
          "RETURN pred"
        )
        TraitBank.connection.execute_query(
          "MATCH (trait:Trait), (term:Term { uri: '#{hash["uri"]}' }) "\
          "WHERE trait.term = term.uri "\
          "CREATE (trait)-[pred:object_term]->(term) "\
          "REMOVE trait.term "\
          "RETURN pred"
        )
        TraitBank.connection.execute_query(
          "MATCH (trait:Trait), (term:Term { uri: '#{hash["uri"]}' }) "\
          "WHERE trait.units = term.uri "\
          "CREATE (trait)-[pred:units_term]->(term) "\
          "REMOVE trait.units "\
          "RETURN pred"
        )
        # NOTE: at the time of this writing, there was no metadata. If there were,
        # we would have to apply all three of those transforms to trait:MetaTrait
        # as well. No need, now, though.
      end
    else
      puts "WARNING: neo4j was not found. Skipping the neo4j migration. This "\
        "will break things, if you have data that needs conversion. If you "\
        "needed this, you should re-run this migration with neo4j running."
    end
    drop_table(:uris)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
