class AddFeedbackSurveySchedule< ActiveRecord::Migration[4.2]
  def change
    add_column :calendar_settings, :feedback_survey_delay_time_bound, :integer, :default => CalendarSetting::DEFAULT_FEEDBACK_DELAY_TIME_BOUND
    add_column :calendar_settings, :feedback_survey_delay_not_time_bound, :integer, :default => CalendarSetting::DEFAULT_FEEDBACK_DELAY_NOT_TIME_BOUND
  end
end
