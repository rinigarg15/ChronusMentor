module SalesDemo
  class MemberMeetingPopulator < BasePopulator
    REQUIRED_FIELDS = MemberMeeting.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at, :reminder_time, :feedback_request_sent_time]

    def initialize(master_populator)
      super(master_populator, :member_meetings)
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        mm = MemberMeeting.new.tap do |member_meeting|
          assign_data(member_meeting, ref_object)
          member_meeting.member_id = master_populator.referer_hash[:member][ref_object.member_id]
          member_meeting.meeting_id = master_populator.referer_hash[:meeting][ref_object.meeting_id]
        end
        MemberMeeting.import([mm], validate: false, timestamps: false)
        referer[ref_object.id] = MemberMeeting.last.id
      end
      master_populator.referer_hash[:member_meeting] = referer
    end
  end
end