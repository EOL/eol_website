class CreateOrderedFallbackLocales < ActiveRecord::Migration[5.2]
  def change
    create_table :ordered_fallback_locales do |t|
      t.integer :locale_id
      t.integer :fallback_locale_id
      t.integer :position
    end
  end
end
