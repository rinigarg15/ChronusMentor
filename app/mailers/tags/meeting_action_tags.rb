MailerTag.register_tags(:meeting_action_tags) do |t|
  t.tag :url_reject_meeting_invite, :description => Proc.new{'feature.email.tags.meeting_tags.url_reject_meeting_invite.description'.translate}, :example => Proc.new{"http://www.chronus.com"} do
    update_from_guest_meeting_url(@meeting, :subdomain => @organization.subdomain, :attending => MemberMeeting::ATTENDING::NO, :member_id => @member.id, :email => true, :all_meetings => true)
  end

  t.tag :reject_invitation_button, :description => Proc.new{'feature.email.tags.meeting_tags.reject_invitation_button.description'.translate}, :example => Proc.new{ ChronusActionMailer::Base.call_to_action_example('feature.email.tags.meeting_tags.reject_invitation_button.reject_text'.translate) } do
    call_to_action('feature.email.tags.meeting_tags.reject_invitation_button.reject_text'.translate, update_from_guest_meeting_url(@meeting, :subdomain => @organization.subdomain, :attending => MemberMeeting::ATTENDING::NO, :member_id => @member.id, :email => true, :all_meetings => true), "button-grey")
  end

  t.tag :url_accept_meeting_invite, :description => Proc.new{'feature.email.tags.meeting_tags.url_accept_meeting_invite.description'.translate}, :example => Proc.new{"http://www.chronus.com"} do
    update_from_guest_meeting_url(@meeting, :subdomain => @organization.subdomain, :attending => MemberMeeting::ATTENDING::YES, :member_id => @member.id, :email => true, :all_meetings => true)
  end

  t.tag :accept_invitation_button, :description => Proc.new{'feature.email.tags.meeting_tags.accept_invitation_button.description'.translate}, :example => Proc.new{ ChronusActionMailer::Base.call_to_action_example('feature.email.tags.meeting_tags.accept_invitation_button.accept_text'.translate) } do
    call_to_action('feature.email.tags.meeting_tags.accept_invitation_button.accept_text'.translate, update_from_guest_meeting_url(@meeting, :subdomain => @organization.subdomain, :attending => MemberMeeting::ATTENDING::YES, :member_id => @member.id, :email => true, :all_meetings => true), "button")
  end
end