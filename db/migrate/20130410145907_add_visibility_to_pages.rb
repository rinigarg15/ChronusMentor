class AddVisibilityToPages< ActiveRecord::Migration[4.2]
  def change
    add_column :pages, :visibility, :integer, default: 0
  end
end
