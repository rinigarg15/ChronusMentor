class AddDefaultTopicForMeeting< ActiveRecord::Migration[4.2]
  def change
    MeetingObserver.without_callback(:after_update) do
      Meeting.where(topic: nil).find_each do |meeting|
        topic = meeting.attendees.collect(&:last_name).to_sentence
        meeting.update_column(:topic, topic)
      end
    end
  end
end 