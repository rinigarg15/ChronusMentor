MailerTag.register_tags(:meeting_request_accepted_tags) do |t|
  t.tag :mentor_profile_picture, description: Proc.new{'feature.email.tags.meeting_request_tags.mentor_profile_picture.description'.translate(mentor: @_mentor_string)}, example: Proc.new{ %Q[<img alt="user name" src="#{UserConstants::DEFAULT_PICTURE[:large]}" style="-ms-interpolation-mode:bicubic;border:0;line-height:100%;text-decoration:none;outline:none;max-width:100% !important;border: none; border-radius: 50%;" title="user name">].try(:html_safe) } do
    user = @meeting_request.mentor
    user_picture_in_email(user, {item_link: member_url(user.member, subdomain: user.program.organization.subdomain, root: user.program.root, src: :mail), no_name: true, size: :large, use_default_picture_if_absent: true, force_default_picture: @sender_visible_to_receiver.blank?}, style: "border: none; border-radius: 50%; margin: 0 auto;", place_image_in_middle: true)
  end

  t.tag :url_mentor, description: Proc.new{'feature.email.tags.meeting_request_tags.url_mentor.description'.translate(mentor: @_mentor_string)}, example: Proc.new{'http://www.chronus.com'} do
    user = @meeting_request.mentor
    user_url(user, subdomain: user.program.organization.subdomain, root: user.program.root)
  end

  t.tag :url_meeting_area_message, description: Proc.new{'feature.email.tags.meeting_request_tags.url_meeting_area_message.description'.translate(meeting: @_meeting_string)}, example: Proc.new{'http://www.chronus.com'} do
    meeting_scraps_url(meeting_id: @meeting.id, current_occurrence_time: @meeting.first_occurrence, subdomain: @meeting.program.organization.subdomain, root: @meeting.program.root, new_scrap: true)
  end
end