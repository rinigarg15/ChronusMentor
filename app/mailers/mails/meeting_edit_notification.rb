class MeetingEditNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '2b6zuzvx', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MEETINGS,
    :title        => Proc.new{|program| "email_translations.meeting_edit_notification.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.meeting_edit_notification.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.meeting_edit_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::ENGAGEMENT_MAIL_ID,
    :campaign_id_2  => CampaignConstants::MEETING_EDIT_NOTIFICATION_MAIL_ID,
    :feature      => [FeatureName::CALENDAR, FeatureName::MENTORING_CONNECTION_MEETING],
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :other_registered_tags => [:meeting_tags, :meeting_attachment_tag, :meeting_action_tags, :meeting_member_response_tag, :reply_to_tags, :meeting_rescudule_button_tags],
    :listing_order => 6
  }

  def meeting_edit_notification(user, meeting, ics_attachment, current_occurrence_time = nil, options={})
    @user = user
    @member = user.member
    @meeting_owner = meeting.owner
    @meeting = meeting
    @member_meeting = @meeting.member_meetings.find_by(member_id: @member.id)
    @current_occurrence_time = current_occurrence_time
    @attachment = ics_attachment
    member_responses_hash = options.delete(:member_responses_hash)
    if member_responses_hash.present?
      @response_predefined = true
      @response = member_responses_hash[@member.id]
    end
    @options = options
    @meeting_updating_member = options[:sender]
    init_mail
    render_mail
  end

  private

  def init_mail
    set_username(@member)
    set_sender(@options)
    set_program(@meeting.program)
    set_icalendar_body(@meeting, user: @user)
    @is_reply_enabled = true
    @reply_to = [MAILER_ACCOUNT[:reply_to_address].call(@meeting.get_reply_to_token(@meeting_updating_member.id, @member.id), ReplyViaEmail::MEETING_UPDATE_NOTIFICATION)]
    setup_email(@user, :sender_name => @meeting_updating_member.visible_to?(@member) ? meeting_updater_name : nil, message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
  end

  register_tags do
    tag :meeting_owner_email, :description => Proc.new{'email_translations.meeting_edit_notification.tags.meeting_owner_email.description'.translate}, :example => Proc.new{'john@gmail.com'} do
      @meeting_owner.email
    end

    tag :respond_or_change, :description => Proc.new{'feature.email.tags.meeting_tags.respond_or_change.description'.translate}, :example => Proc.new{'feature.email.tags.meeting_tags.respond_or_change.example'.translate} do
      response_object = @member_meeting.get_response_object(@current_occurrence_time)
      (response_object.accepted? || response_object.rejected?) ? 'feature.email.tags.meeting_tags.respond_or_change.content_change'.translate : 'feature.email.tags.meeting_tags.respond_or_change.content_respond'.translate
    end

    tag :meeting_updater_name, :description => Proc.new{'email_translations.meeting_edit_notification.tags.meeting_updater_name.description'.translate}, :example => Proc.new{'John Smith'} do
      @meeting_updating_member.name(name_only: true)
    end

    tag :update_rsvp, description: Proc.new { "feature.email.tags.meeting_tags.update_rsvp.description".translate },
      example: Proc.new { "feature.email.tags.meeting_tags.update_rsvp.example_v2_html".translate(
        accept_button: ChronusActionMailer::Base.call_to_action_example("display_string.Yes".translate, "button"),
        reject_button: ChronusActionMailer::Base.call_to_action_example("display_string.No".translate, "button-grey")
    ) } do
      if @member_meeting.get_response_object(@current_occurrence_time).not_responded?
        content_tag(:span, "feature.email.tags.meeting_tags.update_rsvp.please_update_response_v1".translate) +
        content_tag(:br) +
        content_tag(:table, class: 'responsive-table', border: '0') do
          content_tag(:tr) do
            return_str  = content_tag(:td, call_to_action("display_string.Yes".translate, update_from_guest_meeting_url(@meeting, subdomain: @organization.subdomain, attending: MemberMeeting::ATTENDING::YES, member_id: @member.id, email: true, all_meetings: true), "button"))
            return_str += content_tag(:td, call_to_action("display_string.No".translate , update_from_guest_meeting_url(@meeting, subdomain: @organization.subdomain, attending: MemberMeeting::ATTENDING::NO , member_id: @member.id, email: true, all_meetings: true), "button-grey"), style: 'padding-left:15px;')
            return_str
          end
        end
      else
        ""
      end
    end
  end
  self.register!
end