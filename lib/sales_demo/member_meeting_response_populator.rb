module SalesDemo
  class MemberMeetingResponsePopulator < BasePopulator
    REQUIRED_FIELDS = MemberMeetingResponse.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :member_meeting_responses)
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        mmr = MemberMeetingResponse.new.tap do |member_meeting_response|
          assign_data(member_meeting_response, ref_object)
          member_meeting_response.member_meeting_id = master_populator.referer_hash[:member_meeting][ref_object.member_meeting_id]
          member_meeting_response.meeting_occurrence_time = MemberMeeting.find(member_meeting_response.member_meeting_id).meeting.occurrences.first.start_time
        end
        MemberMeetingResponse.import([mmr], validate: false, timestamps: false)
        referer[ref_object.id] = MemberMeetingResponse.last.id
      end
      master_populator.referer_hash[:member_meeting_response] = referer
    end
  end
end