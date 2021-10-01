class ChangePageTranslations< ActiveRecord::Migration[4.2]
  def change
    change_column :page_translations, :content, :text, :limit => 2147483647
  end
end
