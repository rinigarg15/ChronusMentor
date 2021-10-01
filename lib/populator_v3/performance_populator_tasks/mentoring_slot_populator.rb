class MentoringSlotPopulator < PopulatorTask

  def patch(options = {})
    return unless @program.engagement_enabled?
    return if @program.project_based?
    return unless @program.calendar_setting.allow_mentor_to_configure_availability_slots?
    member_ids = @program.users.active.includes([:roles, :member]).select{|user| user.is_mentor? && user.member.will_set_availability_slots?}.collect(&:member_id)
    @options[:students] = @program.users.active.includes(:roles).select{|user| user.is_student?}
    mentoring_slots_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, member_ids)
    process_patch(member_ids, mentoring_slots_hsh) 
  end

   def add_mentoring_slots(member_ids, count, options = {})
    self.class.benchmark_wrapper "Mentoring Slots" do
      program = options[:program]
      lower_bound = Time.now.beginning_of_day + 8.hours + 10.days
      higher_bound = lower_bound + 100.days
      randomizer = [*1..5]
      mentor = nil
      students = options[:students]
      mentors = program.users.active.where(:member_id => member_ids)
      repeat_options_count = (MentoringSlot::Repeats.all.size - 1)
      repeats_arr = MentoringSlot::Repeats.all + Array.new(repeat_options_count * 9 - 1, MentoringSlot::Repeats::NONE)
      temp_mentors = mentors.dup
      MentoringSlot.populate(member_ids.size * count, :per_query => 10_000) do |slot|
        mentor = temp_mentors.first
        temp_mentors = temp_mentors.rotate
        slot.member_id = mentor.member_id
        slot.start_time = lower_bound..higher_bound
        slot.end_time = slot.start_time + randomizer.sample.hours
        slot.location = Populator.words(5..7)
        slot.repeats = repeats_arr
        slot.repeats_by_month_date = slot.repeats == MentoringSlot::Repeats::MONTHLY
        slot.repeats_on_week = (slot.repeats == MentoringSlot::Repeats::WEEKLY ? slot.start_time.wday : nil)
        if slot.repeats != MentoringSlot::Repeats::MONTHLY
          users = {
            student: students.sample,
            mentor: mentor
          }
          create_meeting(program, users, slot.start_time, 1, non_group_meeting: true, calendar_time_available: false)
        end
        self.dot
      end
      self.class.display_populated_count(member_ids.size * count, "Mentoring Slots")
    end
  end

  def remove_mentoring_slots(member_ids, count, options = {})
    self.class.benchmark_wrapper "Removing mentoring slots................" do
      program = options[:program]
      mentoring_slot_ids = program.mentoring_slots.where(:member_id => member_ids).select("mentoring_slots.id, mentoring_slots.member_id").group_by(&:member_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      program.mentoring_slots.where(:id => mentoring_slot_ids).destroy_all
      self.class.display_deleted_count(member_ids.size * count, "Mentoring Slots")
    end
  end

  def create_meeting(program, users, meeting_start_time, meetings_count, options = {})
    options.reverse_merge!(calendar_time_available: true, non_group_meeting: false)
    meeting_offset = program.calendar_setting.slot_time_in_minutes.minutes
    tentative_start_time = meeting_start_time + 10.days
    meeting_request = nil
    Meeting.populate meetings_count do |meeting|
      start_time = Time.at(rand((tentative_start_time).to_i .. (tentative_start_time + 30.days).to_i))
      meeting.group_id = options[:group_id]
      meeting.topic = Populator.words(4..8)
      meeting.description = Populator.sentences(2..3)
      tentative_start_time = meeting_start_time + 10.days
      meeting.start_time = options[:start_time] || start_time
      meeting.end_time = meeting.start_time + meeting_offset + 360.days
      meeting.location = Populator.words(5..7)
      meeting.owner_id = options[:non_group_meeting] ? users[:student].member_id : users.collect(&:member_id)
      meeting.active = true
      meeting.calendar_time_available = options[:calendar_time_available]
      meeting.program_id = program.id
      meeting.schedule = create_recurring_meetings(meeting, options[:group])
      if options[:non_group_meeting]
        MeetingRequest.populate 1 do |meeting_request|
          meeting_request.program_id = program.id
          meeting_request.status = AbstractRequest::Status.all + [AbstractRequest::Status::NOT_ANSWERED]*2
          meeting_request.sender_id = users[:student].id
          meeting_request.receiver_id = users[:mentor].id
          meeting_request.show_in_profile = false
          meeting_request.type = MeetingRequest.to_s
          meeting.meeting_request_id = meeting_request.id
        end
      elsif options[:recurrent] && options[:group].expiry_time > meeting.start_time
        meeting.recurrent = true
      end
      temp_users = options[:non_group_meeting] ? users.values : users
      temp_member_ids = temp_users.collect(&:member_id)
      MemberMeeting.populate temp_users.size do |member_meeting|
        member_id = temp_member_ids.shift
        member_meeting.member_id = member_id
        member_meeting.meeting_id = meeting.id
        member_meeting.attending = get_member_meeting_status(member_id, meeting, meeting_request)
        member_meeting.reminder_time = meeting.start_time - MemberMeeting::DEFAULT_MEETING_REMINDER_TIME
        member_meeting.reminder_sent = false
        member_meeting.feedback_request_sent = false        
        member_meeting.feedback_request_sent = true if self.class.lucky?
      end
      self.dot
    end
  end
end