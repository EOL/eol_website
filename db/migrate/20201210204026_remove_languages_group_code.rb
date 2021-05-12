class RemoveLanguagesGroupCode < ActiveRecord::Migration[5.2]
  def change
    remove_column :languages, :group
  end
end
