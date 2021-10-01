module SalesDemo
  class MeetingRequestPopulator < BasePopulator
    REQUIRED_FIELDS = MeetingRequest.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at, :closed_at, :reminder_sent_time, :accepted_at]

    def initialize(master_populator)
      super(master_populator, :meeting_requests)
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        mr = MeetingRequest.new.tap do |meeting_request|
          assign_data(meeting_request, ref_object)
          meeting_request.group_id = master_populator.referer_hash[:group][ref_object.group_id]
          meeting_request.program_id = master_populator.referer_hash[:program][ref_object.program_id]
          meeting_request.sender_id = master_populator.referer_hash[:user][ref_object.sender_id]
          meeting_request.receiver_id = master_populator.referer_hash[:user][ref_object.receiver_id]
          meeting_request.closed_by_id = master_populator.referer_hash[:user][ref_object.closed_by_id]
        end
        MeetingRequest.import([mr], validate: false, timestamps: false)
        referer[ref_object.id] = MeetingRequest.last.id
      end
      master_populator.referer_hash[:meeting_request] = referer
    end
  end
end