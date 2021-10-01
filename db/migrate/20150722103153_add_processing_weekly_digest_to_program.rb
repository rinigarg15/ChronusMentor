class AddProcessingWeeklyDigestToProgram< ActiveRecord::Migration[4.2]
  def up
    add_column :programs, :processing_weekly_digest, :boolean, default: false
    Program.update_all(processing_weekly_digest: false)
  end

  def down
    remove_column :programs, :processing_weekly_digest
  end
end
