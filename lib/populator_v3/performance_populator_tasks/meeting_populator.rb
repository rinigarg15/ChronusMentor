class MeetingPopulator < PopulatorTask

  def patch(options = {})
    return unless @options[:common]["flash_type"]

    meeting_request_ids = @program.meeting_requests.pluck(:id)
    meetings_hsh = Meeting.unscoped.where(meeting_request_id: meeting_request_ids).pluck(:meeting_request_id).group_by { |x| x }
    process_patch(meeting_request_ids, meetings_hsh)
  end

  def add_meetings(meeting_request_ids, meetings_count, options = {})
    self.class.benchmark_wrapper "Meeting" do
      meeting_requests = MeetingRequest.where(id: meeting_request_ids)
      if meeting_requests.present?
        meeting_requests_index = 0
        meeting_requests_size = meeting_requests.size
        program = meeting_requests[0].program
        slot_time = program.calendar_setting.slot_time_in_minutes.zero? ? 1.hour : program.calendar_setting.slot_time_in_minutes.minutes
        user_id_to_member_id_map = program.users.pluck(:id, :member_id).to_h

        Meeting.populate (meeting_requests_size * meetings_count) do |meeting|
          meeting_request = meeting_requests[meeting_requests_index]
          meeting_requests_index = (meeting_requests_index + 1) % meeting_requests_size
          meeting.group_id = nil
          meeting.description = Populator.sentences(1..4)
          meeting.topic = Populator.words(3..7)
          meeting.owner_id = user_id_to_member_id_map[meeting_request.sender_id]
          meeting.created_at = meeting_request.created_at
          meeting.updated_at = meeting.created_at
          meeting.program_id = meeting_request.program_id
          meeting.ics_sequence = 0
          meeting.meeting_request_id = meeting_request.id
          meeting.calendar_time_available = options.has_key?(:calendar_time_available) ? options[:calendar_time_available] : (rand(1..7) > 1)

          if meeting.calendar_time_available
            start_time_offset_sample_set = 4.times.map { [rand(1..30).days, 1] } + 2.times.map { [rand(31..60).days, 1] } + 2.times.map { [rand(61..90).days, 1] }
            start_time_offset_sample_set += (2.times.map { [rand(91..120).days, 1] } + 8.times.map { [rand(0..199).days, -1] })
            start_time_offset = start_time_offset_sample_set.sample
            start_time = Time.now + start_time_offset[1] * (start_time_offset[0] + rand(0..23).hours + rand(0..59).minutes)

            meeting_state_sample_set = 2.times.map { Meeting::State::CANCELLED } + 10.times.map { Meeting::State::COMPLETED }
            meeting.state = meeting_state_sample_set.sample if start_time_offset[1] == -1
            meeting.start_time = start_time.round_to_next(timezone: 'utc')
          else
            meeting.start_time = (meeting.created_at + program.calendar_setting.feedback_survey_delay_not_time_bound.days).round_to_next({timezone: 'utc'})
            meeting_state_sample_set = 2.times.map { Meeting::State::CANCELLED } + 10.times.map { Meeting::State::COMPLETED } + 88.times.map { nil }
            meeting.state = meeting_state_sample_set.sample
            meeting.start_time = rand((Time.now - 4.days)..(Time.now - 1.day)).round_to_next(timezone: 'utc') if meeting.state.present?
          end

          meeting.end_time = meeting.start_time + slot_time
          meeting.active = (meeting_request.status == AbstractRequest::Status::ACCEPTED)
          meeting.recurrent = false
          meeting.mentee_id = user_id_to_member_id_map[meeting_request.sender_id]
          tmp_meeting = Meeting.new(meeting.attributes)
          tmp_meeting.update_schedule
          meeting.schedule = tmp_meeting.schedule.to_yaml
        end
      end
      self.class.display_populated_count(meeting_requests_size * meetings_count, "Meeting")
    end
  end

  def remove_meetings(meeting_request_ids, meetings_count, options = {})
    self.class.benchmark_wrapper "Removing Meeting" do
      meeting_ids = Meeting.where(meeting_request_id: meeting_request_ids).select("meeting_request_id, id").group_by(&:meeting_request_id).map{|a| a[1].last(meetings_count)}.flatten.collect(&:id).compact.uniq
      count = Meeting.where(id: meeting_ids).destroy_all.size
      self.class.display_deleted_count(count, "Meeting")
    end
  end
end