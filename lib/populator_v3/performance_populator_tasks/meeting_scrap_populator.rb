class MeetingScrapPopulator < PopulatorTask
  def patch(options = {})
    return unless @options[:common]["flash_type"]
    meeting_ids = @program.meetings.pluck(:id)
    meeting_scraps_hsh = Scrap.where(ref_obj_id: meeting_ids, ref_obj_type: Meeting.name).pluck(:ref_obj_id).group_by{|x|x}
    process_patch(meeting_ids, meeting_scraps_hsh)
  end

  def add_meeting_scraps(meeting_ids, meeting_scraps_count, options = {})
    self.class.benchmark_wrapper "MeetingScrap" do
      if meeting_ids.present?
        meetings = Meeting.where(id: meeting_ids).includes(:meeting_request)
        meeting_index = 0
        meeting_scrap_index = 0
        meetings_size = meetings.size
        program = meetings[0].program
        user_id_to_member_id_map = program.users.pluck(:id, :member_id).to_h
        for_owner = true
        Scrap.populate (meetings_size * meeting_scraps_count) do |meeting_scrap|
          meeting = meetings[meeting_index]
          meeting_index = (meeting_index + 1) % meetings_size if (meeting_scrap_index % meeting_scraps_count) == (meeting_scraps_count - 1)
          meeting_scrap_index += 1
          meeting_scrap.program_id = program.id
          meeting_scrap.sender_id = (meeting_scrap_index.even? ? meeting.owner_id : user_id_to_member_id_map[meeting.meeting_request.receiver_id])
          meeting_scrap.subject = Populator.words(2..5)
          meeting_scrap.content = Populator.sentences(4..8)
          meeting_scrap.created_at = meeting.created_at + 1.day
          meeting_scrap.updated_at = meeting_scrap.created_at
          meeting_scrap.type = Scrap.name
          meeting_scrap.auto_email = false
          meeting_scrap.posted_via_email = false
          meeting_scrap.ref_obj_id = meeting.id
          meeting_scrap.ref_obj_type = Meeting.name
          meeting_scrap.root_id = meeting_scrap.id
          Scraps::Receiver.populate 1 do |scrap_receiver|
            scrap_receiver.member_id = (meeting_scrap_index.odd? ? meeting.owner_id : user_id_to_member_id_map[meeting.meeting_request.receiver_id])
            scrap_receiver.message_id = meeting_scrap.id
            scrap_receiver.status = [AbstractMessageReceiver::Status::UNREAD, AbstractMessageReceiver::Status::READ].sample
            scrap_receiver.api_token = "scraps-api-token-#{rand(36**36).to_s(36)}"
            scrap_receiver.message_root_id = meeting_scrap.id
          end
        end
        Scrap.update_all("root_id = id")
      end
      self.class.display_populated_count(meeting_ids.size * meeting_scraps_count, "MeetingScrap")
    end
  end

  def remove_meeting_scraps(meeting_ids, meeting_scraps_count, options = {})
    self.class.benchmark_wrapper "Removing MeetingScrap" do
      meeting_scrap_ids = Scrap.where(ref_obj_id: meeting_ids, ref_obj_type: Meeting.name).select("ref_obj_id, id").group_by(&:ref_obj_id).map{|a| a[1].last(meeting_scraps_count)}.flatten.collect(&:id).compact.uniq
      count = Scrap.where(id: meeting_scrap_ids).destroy_all.size
      self.class.display_deleted_count(count, "MeetingScrap")
    end
  end
end