module User::QuickConnectBox
  extend ActiveSupport::Concern
  module QuickConnectBoxHelpers

    def can_render_meetings_for_quick_connect_box?(program=nil)
      return false if !self.can_view_mentors?
      program ||= self.program
      start_time = Time.now.in_time_zone(self.member.get_valid_time_zone)
      program.calendar_enabled? && self.can_view_mentoring_calendar? && !self.is_max_capacity_program_reached?(start_time, self)
    end

    def can_render_mentors_for_connection_in_quick_connect_box?(program=nil)
      return false if (self.connection_limit_as_mentee_reached? || !self.can_view_mentors?)
      program ||= self.program
      program.only_career_based_ongoing_mentoring_enabled? && (program.matching_by_mentee_alone? || program.matching_by_mentee_and_admin_with_preference?) && self.can_send_mentor_request?
    end

    def can_render_quick_connect_box?(program=nil, options={})
      return false if !self.can_view_mentors?
      program ||= self.program
      member = self.member
      upcoming_recurrent_meetings = options[:meetings] || Meeting.upcoming_recurrent_meetings(program.get_accessible_meetings_list(member.meetings.accepted_meetings).includes([{:member_meetings => [:member]}]))
      (self.can_render_mentors_for_connection_in_quick_connect_box? || (self.can_render_meetings_for_quick_connect_box? && !upcoming_recurrent_meetings.nil? && member.get_attending_recurring_meetings(upcoming_recurrent_meetings).empty? && member.not_connected_for?(Meeting::QuickConnect::DEFAULT_NOT_CONNECTED_FOR, program)))
    end
  end
end