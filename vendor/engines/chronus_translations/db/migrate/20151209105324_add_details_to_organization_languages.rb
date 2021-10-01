class AddDetailsToOrganizationLanguages < ActiveRecord::Migration[4.2]

  def change
    add_column :organization_languages, :title, :string
    add_column :organization_languages, :display_title, :string
    add_column :organization_languages, :language_name, :string
  end
end
