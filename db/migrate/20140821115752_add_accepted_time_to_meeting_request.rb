class AddAcceptedTimeToMeetingRequest< ActiveRecord::Migration[4.2]
  def change
    add_column :mentor_requests, :accepted_at, :datetime, :default => nil
    MentorRequest.reset_column_information
    MeetingRequest.accepted.find_each{|mr| mr.update_attribute(:accepted_at, mr.updated_at)}
  end
end
