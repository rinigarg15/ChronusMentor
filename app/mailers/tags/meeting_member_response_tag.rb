MailerTag.register_tags(:meeting_member_response_tag) do |t|
  t.tag :member_response, :description => Proc.new{'feature.email.tags.meeting_tags.member_response.description'.translate}, :example => Proc.new{'feature.email.tags.meeting_tags.member_response.example'.translate} do
    response = @response_predefined ? @response : @member_meeting.get_response_object(@current_occurrence_time).attending
    case response
    when MemberMeeting::ATTENDING::YES
      "app_constant.rsvp_terms.yes_v1".translate
    when MemberMeeting::ATTENDING::NO
      "app_constant.rsvp_terms.no_v1".translate
    else
      "app_constant.rsvp_terms.no_response_v1".translate.to_s + " "+ "display_string.to".translate
    end
  end
end