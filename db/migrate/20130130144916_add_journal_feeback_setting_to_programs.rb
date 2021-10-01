class AddJournalFeebackSettingToPrograms< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :allow_private_journals, :boolean, :default => true
    add_column :programs, :allow_connection_feedback, :boolean, :default => true
  end
end
