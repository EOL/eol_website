class AddTimestampsToDataIntegrityChecks < ActiveRecord::Migration[5.2]
  def change
    change_table :data_integrity_checks do |t|
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end
  end
end
