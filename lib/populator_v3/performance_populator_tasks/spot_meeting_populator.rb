class SpotMeetingPopulator < PopulatorTask

  def patch(options = {})
    return unless @program.engagement_enabled?
    return if @program.project_based?
    return unless @options[:common]["spot_meeting_enabled?"]
    @options[:eligible_mentor] = @program.users.active.includes([:member, :roles]).select{|user| user.is_mentor? && !user.member.will_set_availability_slots?}
    return if @options[:eligible_mentor].size.zero?
    member_ids = @program.users.active.includes([:roles]).select{|user| user.is_student?}.collect(&:member_id)
    meetings_hsh = @program.meetings.where(group_id: nil).select(:owner_id).group_by(&:owner_id)
    process_patch(member_ids, meetings_hsh) 
  end

  def add_spot_meetings(owner_ids, count, options)
    self.class.benchmark_wrapper "Spot Meeting Requests" do
      eligible_mentors = options[:eligible_mentor]
      randomizer = [*1..10]
      program = options[:program]
      meeting_offset = program.calendar_setting.slot_time_in_minutes.minutes
      students = program.users.active.where(:member_id => owner_ids).to_a
      temp_students = students.dup 
      meeting_request = nil
      Meeting.populate(count * students.size, :per_query => 10_000) do |meeting|
        temp_students = students.dup if temp_students.blank?
        meeting_start_time = Time.now.beginning_of_day + randomizer.sample.days + randomizer.sample.hours
        tentative_start_time = meeting_start_time + rand(1..10).days
        start_time = Time.at(rand((tentative_start_time).to_i .. (tentative_start_time + 30.days).to_i))
        student = temp_students.shift
        mentor = eligible_mentors.sample
        meeting.topic = Populator.words(4..8)
        meeting.description = Populator.sentences(2..3)
        meeting.start_time = start_time
        meeting.end_time = meeting.start_time + meeting_offset + 360.days
        meeting.location = Populator.words(5..7)
        meeting.owner_id = student.id
        meeting.active = true
        meeting.calendar_time_available = false
        meeting.program_id = program.id
        meeting.group_id = nil
        meeting.mentee_id = student.member.id
        meeting.created_at = program.created_at..Time.now
        meeting.schedule = create_recurring_meetings(meeting, nil)
        MeetingRequest.populate 1 do |meeting_request|
          meeting_request.program_id = program.id
          meeting_request.status = AbstractRequest::Status.all + [AbstractRequest::Status::NOT_ANSWERED]*2
          meeting_request.sender_id = student.id
          meeting_request.receiver_id = mentor.id
          meeting_request.show_in_profile = false
          meeting_request.type = MeetingRequest.to_s
          meeting.meeting_request_id = meeting_request.id
          meeting_request.created_at = meeting.created_at
        end
        temp_users = [student, mentor]
        temp_member_ids = temp_users.collect(&:member_id)
        MemberMeeting.populate temp_users.size do |member_meeting|
          member_id = temp_member_ids.shift
          member_meeting.member_id = member_id
          member_meeting.meeting_id = meeting.id
          member_meeting.attending = get_member_meeting_status(member_id, meeting, meeting_request)
          member_meeting.reminder_time = meeting.start_time - MemberMeeting::DEFAULT_MEETING_REMINDER_TIME
          member_meeting.reminder_sent = false
          member_meeting.feedback_request_sent = false
          if self.class.lucky?
            member_meeting.feedback_request_sent = true
          end
        end
        self.dot
      end
      self.class.display_populated_count(students.size * count, "Spot Meeting")
    end
  end

  def remove_spot_meetings(owner_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Spot Meeting................" do
      program = options[:program]
      meeting_ids = program.meetings.where(:owner_id => owner_ids).select([:id, :owner_id]).group_by(&:owner_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      program.meetings.where(:id => meeting_ids).destroy_all
      self.class.display_deleted_count(owner_ids.size * count, "Spot Meeting")
    end
  end
end