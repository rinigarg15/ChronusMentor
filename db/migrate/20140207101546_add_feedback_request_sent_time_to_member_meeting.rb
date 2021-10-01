class AddFeedbackRequestSentTimeToMemberMeeting< ActiveRecord::Migration[4.2]
  def change
    add_column :member_meetings, :feedback_request_sent_time, :datetime
	  
    ActiveRecord::Base.transaction do
      MemberMeeting.select([:id, :feedback_request_sent_time, :feedback_request_sent, :meeting_id]).includes(:meeting).find_each do |mm|
        feedback_request_sent_time = mm.meeting.start_time if mm.meeting.present? && mm.feedback_request_sent
        mm.update_column(:feedback_request_sent_time, feedback_request_sent_time) if feedback_request_sent_time.present?
      end
    end
  end
end
