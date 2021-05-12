class AddIdFieldsToTermQueryFilters < ActiveRecord::Migration[5.2]
  def change
    change_table(:term_query_filters) do |t|
      t.column :predicate_id, :integer
      t.column :object_term_id, :integer
      t.column :units_term_id, :integer
      t.column :sex_term_id, :integer
      t.column :lifestage_term_id, :integer
      t.column :statistical_method_term_id, :integer
    end
  end
end
