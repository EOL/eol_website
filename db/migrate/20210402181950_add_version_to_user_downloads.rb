class AddVersionToUserDownloads < ActiveRecord::Migration[5.2]
  def change
    add_column :user_downloads, :version, :integer
  end
end
