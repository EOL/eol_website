class RemoveGeographicContextFromPages < ActiveRecord::Migration[5.2]
  def change
    remove_column :pages, :geographic_context
  end
end
