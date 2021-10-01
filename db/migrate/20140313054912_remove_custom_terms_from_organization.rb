class RemoveCustomTermsFromOrganization< ActiveRecord::Migration[4.2]
  def up
    remove_column :programs, :mentor_name
    remove_column :programs, :mentee_name
    remove_column :programs, :admin_name
    remove_column :programs, :program_term
    remove_column :programs, :mentoring_connection_name
    remove_column :programs, :article_name
    remove_column :programs, :resources_name
  end

  def down
  end
end