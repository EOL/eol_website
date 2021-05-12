class RemoveNullConstraintFromLanguagesGroup < ActiveRecord::Migration[5.2]
  def change
    change_column :languages, :group, :string, limit: 12, null: true
  end
end
