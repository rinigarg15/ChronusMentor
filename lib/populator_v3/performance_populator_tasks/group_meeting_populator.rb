class GroupMeetingPopulator < PopulatorTask

  def patch(options = {})
    return unless @program.engagement_enabled?
    group_ids = @program.groups.active.pluck(:id)
    meetings_hsh = @program.meetings.where("group_id is not null").pluck(:group_id).group_by{|x| x}
    process_patch(group_ids, meetings_hsh)
  end

   def add_group_meetings(group_ids, count, options = {})
    self.class.benchmark_wrapper "Group Meeting" do
      program = options[:program]
      meeting_offset = program.calendar_setting.slot_time_in_minutes.minutes
      groups = Group.where(id: group_ids).to_a
      temp_groups = groups * count
      meeting_request = nil
      Meeting.populate(group_ids.size * count, :per_query => 10_000) do |meeting|
        group = temp_groups.shift
        meeting_start_time = group.created_at
        tentative_start_time = meeting_start_time + 10.days
        start_time = Time.at(rand((tentative_start_time).to_i .. (tentative_start_time + 30.days).to_i))
        meeting.group_id = group.id
        meeting.topic = Populator.words(4..8)
        meeting.description = Populator.sentences(2..3)
        meeting.start_time = start_time
        meeting.end_time = meeting.start_time + meeting_offset + 360.days
        meeting.location = Populator.words(5..7)
        meeting.owner_id = group.members.pluck(:member_id)
        meeting.active = true
        meeting.created_at = group.created_at..Time.now
        meeting.calendar_time_available = true
        meeting.program_id = program.id
        meeting.schedule = create_recurring_meetings(meeting, group)
        meeting.recurrent = true if group.expiry_time > meeting.start_time
        temp_users = group.members
        temp_member_ids = temp_users.collect(&:member_id)
        MemberMeeting.populate temp_users.size do |member_meeting|
          member_id = temp_member_ids.shift
          member_meeting.member_id = member_id
          member_meeting.meeting_id = meeting.id
          member_meeting.attending = MemberMeeting::ATTENDING::YES
          member_meeting.reminder_time = meeting.start_time - MemberMeeting::DEFAULT_MEETING_REMINDER_TIME
          member_meeting.reminder_sent = false
          member_meeting.feedback_request_sent = false
          member_meeting.feedback_request_sent = true if self.class.lucky?
          member_meeting.created_at = meeting.created_at
        end
        self.dot
      end
      self.class.display_populated_count(group_ids.size * count, "Group Meetings")
    end
  end

  def remove_group_meetings(group_ids, count, options = {})
    self.class.benchmark_wrapper "Removing group_meetings................" do
      program = options[:program]
      meeting_ids = program.meetings.where(:group_id => group_ids).select([:id, :group_id]).group_by(&:group_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      program.meetings.where(:id => meeting_ids).destroy_all
      self.class.display_deleted_count(group_ids.size * count, "Group Meetings")
    end
  end
end