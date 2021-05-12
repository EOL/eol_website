class ModifyVernacularsFourByteText < ActiveRecord::Migration[5.2]
  def up
    Vernacular.connection.execute(%{
      ALTER TABLE vernaculars CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
      MODIFY `string` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
      MODIFY `remarks` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
      MODIFY `source` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
    })
  end

  def down
    Article.connection.execute(%{
      ALTER TABLE vernaculars CONVERT TO CHARACTER SET utf8 COLLATE utf8_general_ci,
      MODIFY `string` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci,
      MODIFY `remarks` text CHARACTER SET utf8 COLLATE utf8_general_ci,
      MODIFY `source` text CHARACTER SET utf8 COLLATE utf8_general_ci;
    })
  end
end
