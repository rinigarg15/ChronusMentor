class AddMentoringModeForUser< ActiveRecord::Migration[4.2]
  def change
    add_column :users, :mentoring_mode, :integer, :default => User::MentoringMode::ONE_TIME_AND_ONGOING
  end
end
