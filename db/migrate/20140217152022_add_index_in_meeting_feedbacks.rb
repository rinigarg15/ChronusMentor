class AddIndexInMeetingFeedbacks< ActiveRecord::Migration[4.2]
  def change
    add_index :meeting_feedbacks, :meeting_occurrence_time
  end
end