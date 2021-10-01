class AddPublishedToPages< ActiveRecord::Migration[4.2]
  def change
    add_column :pages, :published, :boolean, default: true
  end
end
