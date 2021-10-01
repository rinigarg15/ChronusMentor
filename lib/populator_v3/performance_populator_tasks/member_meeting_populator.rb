class MemberMeetingPopulator < PopulatorTask
  def patch(options = {})
    return unless @options[:common]["flash_type"]
    meeting_ids = @program.meetings.pluck(:id)
    member_meetings_hsh = get_children_hash(nil, @options[:args]["model"] || @node, @foreign_key, meeting_ids)
    process_patch(meeting_ids, member_meetings_hsh)
  end

  def add_member_meetings(meeting_ids, member_meetings_count, options = {})
    raise "unexpected count" unless member_meetings_count == 2
    self.class.benchmark_wrapper "MemberMeeting" do
      if meeting_ids.present?
        attending_value_in_ratio = [MemberMeeting::ATTENDING::NO]
        22.times { attending_value_in_ratio << MemberMeeting::ATTENDING::YES }
        6.times { attending_value_in_ratio << MemberMeeting::ATTENDING::NO_RESPONSE }
        attending_value_in_ratio.shuffle!
        meetings = Meeting.where(id: meeting_ids).includes(:meeting_request)
        meeting_index = 0
        meetings_size = meetings.size
        program = meetings[0].program
        user_id_to_member_id_map = program.users.pluck(:id, :member_id).to_h
        for_owner = true
        MemberMeeting.populate (meetings_size * member_meetings_count) do |member_meeting|
          meeting = meetings[meeting_index]
          meeting_index = (meeting_index + 1) % meetings_size unless for_owner
          for_owner = if for_owner
            member_meeting.member_id = meeting.owner_id
            false
          else
            tmp_id = user_id_to_member_id_map[meeting.meeting_request.receiver_id]
            member_meeting.member_id = (tmp_id != meeting.owner_id ? tmp_id : user_id_to_member_id_map[meeting.meeting_request.sender_id])
            true
          end
          member_meeting.meeting_id = meeting.id
          member_meeting.attending = attending_value_in_ratio.sample
          member_meeting.created_at = meeting.created_at
          member_meeting.updated_at = member_meeting.created_at
          member_meeting.reminder_time = member_meeting.updated_at
          member_meeting.reminder_sent = true
          member_meeting.feedback_request_sent_time = member_meeting.updated_at
          member_meeting.feedback_request_sent = true
        end
      end
      self.class.display_populated_count(meetings_size * member_meetings_count, "MemberMeeting")
    end
  end

  def remove_member_meetings(meeting_ids, member_meetings_count, options = {})
    self.class.benchmark_wrapper "Removing MemberMeeting" do
      member_meeting_ids = MemberMeeting.where(meeting_id: meeting_ids).select("meeting_id, id").group_by(&:meeting_id).map{|a| a[1].last(member_meetings_count)}.flatten.collect(&:id).compact.uniq
      count = MemberMeeting.where(id: member_meeting_ids).destroy_all.size
      self.class.display_deleted_count(count, "MemberMeeting")
    end
  end
end