class AddAllowToChooseMentoringMode< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :allow_mentoring_mode_change, :integer, :default => Program::MENTORING_MODE_CONFIG::NON_EDITABLE
  end
end