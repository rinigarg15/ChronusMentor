class AddMeetingIdToSurveyAnswer< ActiveRecord::Migration[4.2]
  def change
    add_column :common_answers, :member_meeting_id, :integer
    add_column :common_answers, :meeting_occurrence_time, :datetime
    add_index :common_answers, ["member_meeting_id", "meeting_occurrence_time"], name: "index_common_answers_on_member_meeting_id_and_occurrence_time"
  end
end
