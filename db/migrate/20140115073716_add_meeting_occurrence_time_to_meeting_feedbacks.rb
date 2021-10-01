class AddMeetingOccurrenceTimeToMeetingFeedbacks< ActiveRecord::Migration[4.2]
  def change
    add_column :meeting_feedbacks, :meeting_occurrence_time, :datetime
  end
end
