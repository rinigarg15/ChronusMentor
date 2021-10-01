class AddFlagForTermsAndConditions< ActiveRecord::Migration[4.2]
  def up
    add_column :programs, :display_custom_terms_only, :boolean, default: false
  end

  def down
    remove_column :programs, :display_custom_terms_only
  end
end
