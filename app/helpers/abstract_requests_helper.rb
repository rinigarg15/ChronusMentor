module AbstractRequestsHelper
  def collapsible_filter_view_field_filter(filter_field, filter, options)
    entity = options.delete(:entity) || "mentor_request"
    capture do
      profile_filter_wrapper('display_string.View'.translate, false, false, true) do
        concat radio_button_filter("feature.#{entity}.content.filter.requests_to_me_v2".translate, filter_field, AbstractRequest::Filter::TO_ME, :filter, options) if filter[:to_me]
        concat radio_button_filter("feature.#{entity}.content.filter.requests_by_me_v2".translate, filter_field, AbstractRequest::Filter::BY_ME, :filter, options) if filter[:by_me]
        concat radio_button_filter("feature.#{entity}.content.filter.requests_all_v1".translate, filter_field, AbstractRequest::Filter::ALL, :filter, options) if filter[:all]
      end
    end
  end

  def get_rejection_reason_collection(request_id)
    return [["feature.meeting_request.content.closing_reason_no_match_v1".translate(mentee: _mentee), AbstractRequest::Rejection_type::MATCHING], ["feature.meeting_request.content.closing_reason_limit_reached".translate(mentees: _mentees), AbstractRequest::Rejection_type::REACHED_LIMIT], ["feature.meeting_request.content.closing_reason_busy_v1".translate(mentee: _mentee), AbstractRequest::Rejection_type::BUSY], ["feature.meeting_request.content.closing_reason_other_v1".translate, AbstractRequest::Rejection_type::OTHERS]]
  end
end