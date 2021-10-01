MailerTag.register_tags(:meeting_request_action_tags) do |t|
  t.tag :url_meeting_request_accept_link, description: Proc.new{'feature.email.tags.meeting_request_tags.url_meeting_request_accept_link_v1'.translate(:meeting => @_meeting_string)}, example: Proc.new{'http://www.chronus.com'} do   
    update_status_meeting_request_url(@meeting_request, subdomain: @organization.subdomain, root: @program.root, secret: @member.calendar_api_key, status: AbstractRequest::Status::ACCEPTED, src: "email")   
  end

  t.tag :url_meeting_request_decline_link, description: Proc.new{'feature.email.tags.meeting_request_tags.url_meeting_request_decline_link_v1'.translate(:meeting => @_meeting_string)}, example: Proc.new{'http://www.chronus.com'} do
    update_status_meeting_request_url(@meeting_request, subdomain: @organization.subdomain, root: @program.root, secret: @member.calendar_api_key, status: AbstractRequest::Status::REJECTED, src: "email")
  end
end
