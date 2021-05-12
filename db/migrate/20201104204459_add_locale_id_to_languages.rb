class AddLocaleIdToLanguages < ActiveRecord::Migration[5.2]
  def change
    add_column :languages, :locale_id, :integer
    add_index :languages, :locale_id
  end
end
