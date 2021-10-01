class AddAllowLegalLinksToPrograms< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :allow_legal_links, :boolean, :default => true
  end
end
