class AddRsvpChangeSourceToMemberMeetingResponse< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :member_meeting_responses do |m|
        m.add_column :rsvp_change_source, "int(11)"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      m.remove_column :rsvp_change_source
    end
  end
end