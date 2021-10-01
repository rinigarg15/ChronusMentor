class MeetingProposedSlotPopulator < PopulatorTask
  def patch(options = {})
    return unless @options[:common]["flash_type"]
    meeting_request_ids = @program.meeting_requests.pluck(:id)
    meeting_proposed_slots_hsh = get_children_hash(nil, @options[:args]["model"] || @node, @foreign_key, meeting_request_ids)
    process_patch(meeting_request_ids, meeting_proposed_slots_hsh)
  end

  def add_meeting_proposed_slots(meeting_request_ids, meeting_proposed_slots_count, options = {})
    self.class.benchmark_wrapper "MeetingProposedSlot" do
      if meeting_request_ids.present?
        locations = Location.all
        meeting_requests = MeetingRequest.find(meeting_request_ids)
        meeting_requests_index = 0
        meeting_requests_size = meeting_requests.size
        program = meeting_requests[0].program
        slot_time = program.calendar_setting.slot_time_in_minutes.zero? ? 1.hour : program.calendar_setting.slot_time_in_minutes.minutes
        MeetingProposedSlot.populate (meeting_request_ids.size * meeting_proposed_slots_count) do |meeting_proposed_slot|
          meeting_request = meeting_requests[meeting_requests_index]
          meeting_proposed_slot.meeting_request_id = meeting_request.id
          meeting_proposed_slot.start_time = rand((meeting_request.updated_at + 1.day)..(meeting_request.updated_at + 1.month)).round_to_next({timezone: 'utc'})
          meeting_proposed_slot.end_time = meeting_proposed_slot.start_time + slot_time
          meeting_proposed_slot.location = locations.sample.full_address
          # meeting_proposed_slot.state # not needed for now
          meeting_proposed_slot.proposer_id = meeting_request.sender_id
          meeting_proposed_slot.created_at = meeting_request.updated_at
          meeting_proposed_slot.updated_at = meeting_proposed_slot.created_at
          meeting_requests_index = (meeting_requests_index + 1) % meeting_requests_size
        end
      end
      self.class.display_populated_count(meeting_request_ids.size * meeting_proposed_slots_count, "MeetingProposedSlot")
    end
  end

  def remove_meeting_proposed_slots(meeting_request_ids, meeting_proposed_slots_count, options = {})
    self.class.benchmark_wrapper "Removing MeetingProposedSlot" do
      meeting_proposed_slot_ids = MeetingProposedSlot.where(meeting_request_id: meeting_request_ids).select("meeting_request_id, id").group_by(&:meeting_request_id).map{|a| a[1].last(meeting_proposed_slots_count)}.flatten.collect(&:id).compact.uniq
      MeetingProposedSlot.where(id: meeting_proposed_slot_ids).destroy_all
      self.class.display_deleted_count(meeting_request_ids.size * meeting_proposed_slots_count, "MeetingProposedSlot")
    end
  end
end