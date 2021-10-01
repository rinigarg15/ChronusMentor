class AddEligibilityMessageColumnForRoles< ActiveRecord::Migration[4.2]
  include MigrationHelpers

  def up
    add_translation_column(Role, :eligibility_message, "text")
  end

  def down
    remove_column :role_translations, :eligibility_message
  end
end