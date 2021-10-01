class AddMaxCapacityStudentHoursAndMaxCapacityStudentFrequencyToCalendarSetting< ActiveRecord::Migration[4.2]
  def change
    add_column :calendar_settings, :max_capacity_student_hours, :integer
    add_column :calendar_settings, :max_capacity_student_frequency, :integer
  end
end
