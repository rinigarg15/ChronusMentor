class ChangeAttendingDataTypeInMemberMeetings< ActiveRecord::Migration[4.2]
  def up
  	change_column :member_meetings, :attending, :integer, :default => MemberMeeting::ATTENDING::NO_RESPONSE
  end

  def down
  end
end
