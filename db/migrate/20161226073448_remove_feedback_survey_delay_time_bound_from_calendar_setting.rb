class RemoveFeedbackSurveyDelayTimeBoundFromCalendarSetting< ActiveRecord::Migration[4.2]
  def change
    remove_column :calendar_settings, :feedback_survey_delay_time_bound, :integer
  end
end
