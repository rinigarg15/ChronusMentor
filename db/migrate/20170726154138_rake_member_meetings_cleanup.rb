class RakeMemberMeetingsCleanup< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      Common::RakeModule::Utils.execute_task do
        MemberMeeting.where.not(meeting_id: Meeting.pluck(:id)).delete_all

        Program.all.each_with_index do |program, index|
          meetings_scope = program.meetings
          program_meeting_ids = meetings_scope.non_group_meetings.pluck(:id)
          program_member_ids = program.all_users.pluck(:member_id)
          group_id_meetings_map = meetings_scope.group_meetings.includes(:member_meetings).group_by(&:group_id)
          group_id_member_id_role_id_map = Group.get_group_id_member_id_role_id_map(group_id_meetings_map.keys)
          MemberMeeting.where(meeting_id: program_meeting_ids).where.not(member_id: program_member_ids).each do |member_meet|
            begin
              member_meet.destroy
            rescue => ex
              Common::RakeModule::Utils.print_error_messages("Error occurred #{ex.message} for Member Meeting id: #{member_meet.id}")
            end
          end
          group_id_meetings_map.each do |group_id, group_meetings|
            group_member_ids = group_id_member_id_role_id_map[group_id].try(:keys)
            group_meetings.each do |group_meeting|
              group_meeting.member_meetings.select { |mm| !mm.member_id.in?(group_member_ids) }.each do |member_meet|
                begin
                  member_meet.destroy
                rescue => ex
                  Common::RakeModule::Utils.print_error_messages("Error occurred #{ex.message} for Member Meeting id: #{member_meet.id}")
                end
              end
            end
          end
          print "." if ((index + 1) % 10 == 0)
        end
      end
    end
  end

  def down
    #Do nothing
  end
end