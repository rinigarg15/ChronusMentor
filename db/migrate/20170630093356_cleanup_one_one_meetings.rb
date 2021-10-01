class CleanupOneOneMeetings< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      count = 0
      Meeting.non_group_meetings.joins("LEFT OUTER JOIN member_meetings on member_meetings.meeting_id = meetings.id").where("member_meetings.member_id is NULL").each do |meeting|
        meeting.update_column(:active, false)
        count += 1
      end
      puts "Updated #{count} meetings to active false"
    end
  end
end
