MailerTag.register_tags(:meeting_request_created_tags) do |t|
  t.tag :mentee_profile_picture, description: Proc.new{'feature.email.tags.meeting_request_tags.mentee_profile_picture.description'.translate(mentee: @_mentee_string)}, example: Proc.new{ %Q[<img alt="user name" src="#{UserConstants::DEFAULT_PICTURE[:large]}" style="-ms-interpolation-mode:bicubic;border:0;line-height:100%;text-decoration:none;outline:none;max-width:100% !important;border: none; border-radius: 50%;" title="user name">].try(:html_safe) } do
    user = @meeting_request.student
    user_picture_in_email(user, {item_link: member_url(user.member, subdomain: user.program.organization.subdomain, root: user.program.root, src: :mail), no_name: true, size: :large, use_default_picture_if_absent: true, force_default_picture: @sender_visible_to_receiver.blank?}, style: "border: none; border-radius: 50%; margin: 0 auto;", place_image_in_middle: true)
  end

  t.tag :meeting_topic_link, description: Proc.new{'feature.email.tags.meeting_request_tags.meeting_topic_link.description'.translate}, example: Proc.new{'feature.email.tags.meeting_request_tags.meeting_topic_link.example_html'.translate} do
    link_to @meeting.topic, meeting_requests_url(subdomain: @program.organization.subdomain, root: @program.root, email_meeting_request_id: @meeting_request.id, email_action: MeetingRequestsController::EmailAction::SHOW, src: EngagementIndex::Src::AccessFlashMeetingArea::EMAIL)
  end

  t.tag :meeting_proposed_times, description: Proc.new{'feature.email.tags.meeting_request_tags.meeting_proposed_times.description'.translate(meeting: @_meeting_string)}, example: Proc.new{'feature.email.tags.meeting_request_tags.meeting_proposed_times.example_v1_html'.translate} do
    render(partial: '/meeting_proposed_times', locals: {member: @member, meeting_request: @meeting_request, user: @receiver})
  end

end