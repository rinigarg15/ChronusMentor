class UpdateMentoringModeToDefault < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      User.where(mentoring_mode: nil).update_all(mentoring_mode: User::MentoringMode::ONE_TIME_AND_ONGOING)
    end
  end

  def down
  end
end
