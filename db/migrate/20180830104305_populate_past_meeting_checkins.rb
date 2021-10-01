class PopulatePastMeetingCheckins < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      program_ids = Program.includes(:enabled_db_features, :disabled_db_features, organization: [:enabled_db_features, :disabled_db_features]).select(&:contract_management_enabled?).collect(&:id)
      meetings = Meeting.where(program_id: program_ids).group_meetings.slot_availability_meetings.past.includes(:program, member_meetings: [:member_meeting_responses, member: {users: :group_checkins}], group: :mentors)
      Meeting.recurrent_meetings(meetings, {get_merged_list: true, get_only_past_meetings: true}).each do |meetings_hash|
        meeting = meetings_hash[:meeting]
        program = meeting.program
        group = meeting.group
        current_occurrence_time = meetings_hash[:current_occurrence_time]
        meeting.member_meetings.each do |member_meeting|
          user = member_meeting.member.users.find{ |u| u.program_id == program.id }
          response = member_meeting.get_response_object(current_occurrence_time)
          next unless user.present? && group.mentors.include?(user) && !(response && response.rejected?) &&  user.group_checkins.find{ |gc| gc.checkin_ref_obj_type == MemberMeeting.to_s && gc.checkin_ref_obj_id == member_meeting.id && gc.date == current_occurrence_time }.blank?
          GroupCheckin.create_meeting_checkin_obj(user, member_meeting, current_occurrence_time, program, meeting)
        end
      end
    end
  end

  def down
    #Do nothing
  end
end
