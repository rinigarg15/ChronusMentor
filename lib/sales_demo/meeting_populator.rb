module SalesDemo
  class MeetingPopulator < BasePopulator
    REQUIRED_FIELDS = Meeting.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :meetings)
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        m = Meeting.new.tap do |meeting|
          assign_data(meeting, ref_object)
          meeting.recurrent = false
          meeting = change_start_end_time(meeting)
          meeting.update_schedule
          meeting.group_id = master_populator.referer_hash[:group][ref_object.group_id]
          meeting.program_id = master_populator.referer_hash[:program][ref_object.program_id]
          meeting.owner_id = master_populator.referer_hash[:member][ref_object.owner_id]
          meeting.meeting_request_id = master_populator.referer_hash[:meeting_request][ref_object.meeting_request_id]
        end
        Meeting.import([m], validate: false, timestamps: false)
        referer[ref_object.id] = Meeting.last.id
      end
      master_populator.referer_hash[:meeting] = referer
    end

    private

    def change_start_end_time(meeting)
      start_time = meeting.start_time.to_i + self.master_populator.delta_date
      start_time_delta = start_time%1800
      start_time = start_time + (1800 - start_time_delta)
      meeting.start_time = Time.zone.at(start_time)
      meeting.end_time = meeting.start_time + 30.minutes
      return meeting
    end
  end
end