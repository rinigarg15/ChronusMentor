class MeetingRequestReport
  module CSV
    BATCH_SIZE = 1000
    RESPONSE_TEXT_HEADER_FOR_STATE = { AbstractRequest::Status::CLOSED => "feature.meeting_request.label.reason_for_closure", AbstractRequest::Status::REJECTED => "feature.meeting_request.label.reason_for_decline" }
    class << self
      def export_to_stream(stream, meeting_requests, status, requesting_member)
        status = AbstractRequest::Status::STRING_TO_STATE[status]
        meeting_request_headers = meeting_request_report_headers(status)
        include_response_text = include_request_response_text?(status)
        stream << ::CSV::Row.new(meeting_request_headers, meeting_request_headers).to_s
        meeting_requests_meeting_hash = Meeting.unscoped.where(meeting_request_id: meeting_requests.pluck(:id)).map { |meeting| [meeting.meeting_request_id, meeting] }.to_h
        meeting_requests.includes(get_includes_list).find_each(batch_size: BATCH_SIZE) do |meeting_request|
          student = meeting_request.student
          mentor = meeting_request.mentor
          meeting = meeting_requests_meeting_hash[meeting_request.id]
          meeting_request.get_meeting_proposed_slots[0].each do |proposed_slot|
            csv_array = get_default_columns(meeting, meeting_request, mentor, student) + get_slot_details(proposed_slot, meeting, meeting_request, requesting_member)
            csv_array << meeting_request.response_text if include_response_text
            stream << ::CSV::Row.new(meeting_request_headers, csv_array).to_s
          end
        end
      end

      def meeting_request_report_headers(status)
        headers = [
          "feature.meetings.form.request_id".translate,
          "feature.meeting_request.label.sender".translate,
          "feature.meeting_request.label.sender_email".translate,
          "feature.meeting_request.label.recipient".translate,
          "feature.meeting_request.label.recipient_email".translate,
          "feature.meetings.form.topic".translate,
          "feature.meetings.form.description".translate,
          "feature.meetings.form.proposed_time".translate,
          "feature.meetings.form.location".translate,
          "feature.meeting_request.content.sent".translate
        ]
        return headers unless include_request_response_text?(status)
        headers + [RESPONSE_TEXT_HEADER_FOR_STATE[status].translate]
      end

      def proposed_time_string(proposed_slot, meeting, member)
        return "" if !meeting.calendar_time_available? && proposed_slot.is_a?(Meeting)
        format_time_string(proposed_slot.start_time, member) + " (#{meeting.formatted_duration})"
      end

      def format_time_string(time_object, member)
        DateTime.localize(time_object.in_time_zone(member.get_valid_time_zone), format: :full_display_with_zone)
      end

      private

      def include_request_response_text?(status)
        RESPONSE_TEXT_HEADER_FOR_STATE[status].present?
      end

      def get_includes_list
        [:meeting_proposed_slots, student: [:member, :roles], mentor: [:member, :roles]]
      end

      def get_default_columns(meeting, meeting_request, mentor, student)
        [
          meeting_request.id,
          student.name(name_only: true),
          student.email,
          mentor.name(name_only: true),
          mentor.email,
          meeting.topic,
          meeting.description.to_s
        ]
      end

      def get_slot_details(proposed_slot, meeting, meeting_request, requesting_member)
        [
          proposed_time_string(proposed_slot, meeting, requesting_member),
          proposed_slot.location.to_s,
          format_time_string(meeting_request.created_at, requesting_member)
        ]
      end
    end
  end
end