class CreateMemberMeetingResponses< ActiveRecord::Migration[4.2]
  def change
    create_table :member_meeting_responses do |t|
      t.datetime :meeting_occurrence_time
      t.belongs_to :member_meeting
      t.integer :attending, :default => MemberMeeting::ATTENDING::NO_RESPONSE
      t.timestamps null: false
    end
    add_index :member_meeting_responses, :member_meeting_id
    add_index :member_meeting_responses, :meeting_occurrence_time
  end
end
