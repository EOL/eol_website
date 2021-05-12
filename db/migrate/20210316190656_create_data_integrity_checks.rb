class CreateDataIntegrityChecks < ActiveRecord::Migration[5.2]
  def change
    create_table :data_integrity_checks do |t|
      t.integer :type
      t.integer :status
      t.text :message
      t.datetime :started_at
      t.datetime :completed_at
    end
  end
end
