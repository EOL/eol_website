# This migration comes from refinery_resources (originally 20100913234709)
class CreateRefinerycmsResourcesSchema < ActiveRecord::Migration[4.2]
  def change
    create_table :refinery_resources do |t|
      t.string   :file_mime_type
      t.string   :file_name
      t.integer  :file_size
      t.string   :file_uid
      t.string   :file_ext

      t.timestamps null: false
    end
  end
end
