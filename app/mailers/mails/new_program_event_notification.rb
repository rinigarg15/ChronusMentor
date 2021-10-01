class NewProgramEventNotification < ChronusActionMailer::Base
  include ProgramEventsHelper

  @mailer_attributes = {
    :uid          => '30u91oqu', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::COMMUNITY,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::EVENTS,
    :title        => Proc.new{|program| "email_translations.new_program_event_notification.title_v1".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.new_program_event_notification.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.new_program_event_notification.subject_v2".translate},
    :campaign_id  => CampaignConstants::COMMUNITY_MAIL_ID,
    :feature      => FeatureName::PROGRAM_EVENTS,
    :campaign_id_2  => CampaignConstants::NEW_PROGRAM_EVENT_NOTIFICATION_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 1,
    :other_registered_tags => [:calendar_ics_attachment_tag]
  }

  def new_program_event_notification(user, program_event, options = {})
    @program_event = program_event
    @test_mail = options[:test_mail]
    @email = options[:email]

    @actual_user = user #used in test emails for setting mail ID
    @user = @actual_user.presence || @program_event.user
    @member = @user.member
    if @program_event.start_time.present?
      @event_timings = event_time_for_display(@program_event, @member)
      @event_datetime = event_datetime_for_display_in_email(@program_event, @member)
    end
    @attachment = options[:ics_calendar_attachment] if options[:ics_calendar_attachment].present?
    @description = @program_event.description || ""
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@program_event.program)
    set_username(@actual_user, name: 'feature.email.content.user_name_html'.translate)
    setup_email(@actual_user, from: :admin, email: @email)
    set_program_event_icalendar_body(@program_event, user: @user)
    super
    set_layout_options(show_change_notif_link: !@test_mail)
  end

  register_tags do
    tag :program_event_title, :description => Proc.new{'email_translations.new_program_event_notification.tags.program_event_title.description'.translate}, :example => Proc.new{'email_translations.new_program_event_notification.tags.program_event_title.example'.translate} do
      @program_event.title
    end

    tag :program_event_timings, :description => Proc.new{'email_translations.new_program_event_notification.tags.program_event_timings.description'.translate}, :example => Proc.new{'email_translations.new_program_event_notification.tags.program_event_timings.example'.translate} do
      if @program_event.start_time.present?
        get_time_for_time_zone(@program_event.start_time, @member.get_valid_time_zone, "short".to_sym) + " " + @event_timings
      else
        'email_translations.new_program_event_notification.tags.program_event_timings.event_timings'.translate
      end
    end

    tag :event_time, :description => Proc.new{'email_translations.new_program_event_notification.tags.event_time.description'.translate}, :example => Proc.new{'email_translations.new_program_event_notification.tags.event_time.example'.translate} do
      if @program_event.start_time.present?
        @event_datetime
      else
        'email_translations.new_program_event_notification.tags.program_event_timings.event_timings'.translate
      end
    end

    tag :program_event_location, :description => Proc.new{'email_translations.new_program_event_notification.tags.program_event_location.description'.translate}, :example => Proc.new{'email_translations.new_program_event_notification.tags.program_event_location.example'.translate} do
      @program_event.location.presence || "-"
    end

    tag :program_event_owner_name, :description => Proc.new{'email_translations.new_program_event_notification.tags.program_event_owner_name.description'.translate}, :example => Proc.new{'feature.email.tags.mentor_name.example_with_url'.translate} do
      link_to(@program_event.user.name(:name_only => true), user_url(@program_event.user, subdomain: @program.organization.subdomain, root: @program.root))
    end

    tag :program_event_description, :description => Proc.new{'email_translations.new_program_event_notification.tags.program_event_description.description'.translate}, :example => Proc.new{'email_translations.new_program_event_notification.tags.program_event_description.example_html'.translate} do
      @description ? "<br/><br/>#{@description}<br/><br/>".html_safe : ""
    end

    tag :url_program_event, :description => Proc.new{'email_translations.new_program_event_notification.tags.url_program_event.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      @test_mail ? "http://www.chronus.com" : program_event_url(@program_event, :subdomain => @organization.subdomain)
    end

    tag :url_accept_program_event_invite, :description => Proc.new{'email_translations.new_program_event_notification.tags.url_accept_program_event_invite.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      @test_mail ? "http://www.chronus.com" : update_invite_program_event_url(@program_event, :status => EventInvite::Status::YES, :src => "email", :subdomain => @organization.subdomain)
    end

    tag :url_reject_program_event_invite, :description => Proc.new{'email_translations.new_program_event_notification.tags.url_reject_program_event_invite.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      @test_mail ? "http://www.chronus.com" : update_invite_program_event_url(@program_event, :status => EventInvite::Status::NO, :src => "email", :subdomain => @organization.subdomain)
    end

    tag :url_maybe_program_event_invite, :description => Proc.new{'email_translations.new_program_event_notification.tags.url_maybe_program_event_invite.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      @test_mail ? "http://www.chronus.com" : update_invite_program_event_url(@program_event, :status => EventInvite::Status::MAYBE, :src => "email", :subdomain => @organization.subdomain)
    end

    tag :button_accept_program_event_invite, :description => Proc.new{'email_translations.new_program_event_notification.tags.button_accept_program_event_invite.description'.translate}, :example => Proc.new{ call_to_action_example("email_translations.new_program_event_notification.tags.button_accept_program_event_invite.yes_will_attend".translate, 'button') } do
      url = @test_mail ? "http://www.chronus.com" : update_invite_program_event_url(@program_event, :status => EventInvite::Status::YES, :src => "email", :subdomain => @organization.subdomain)
      call_to_action("email_translations.new_program_event_notification.tags.button_accept_program_event_invite.yes_will_attend".translate, url, 'button')
    end

    tag :button_reject_program_event_invite, :description => Proc.new{'email_translations.new_program_event_notification.tags.button_reject_program_event_invite.description'.translate}, :example => Proc.new{ call_to_action_example("email_translations.new_program_event_notification.tags.button_reject_program_event_invite.no_attend".translate, 'button-grey') } do
      url = @test_mail ? "http://www.chronus.com" : update_invite_program_event_url(@program_event, :status => EventInvite::Status::NO, :src => "email", :subdomain => @organization.subdomain)
      call_to_action("email_translations.new_program_event_notification.tags.button_reject_program_event_invite.no_attend".translate, url, 'button-grey')
    end

    tag :button_maybe_program_event_invite, :description => Proc.new{'email_translations.new_program_event_notification.tags.button_maybe_program_event_invite.description'.translate}, :example => Proc.new{ call_to_action_example("email_translations.new_program_event_notification.tags.button_reject_program_event_invite.no_attend".translate, 'button-grey') } do
      url = @test_mail ? "http://www.chronus.com" : update_invite_program_event_url(@program_event, :status => EventInvite::Status::MAYBE, :src => "email", :subdomain => @organization.subdomain)
      call_to_action("email_translations.new_program_event_notification.tags.button_maybe_program_event_invite.maybe".translate, url, 'button-grey')
    end

    tag :view_event_details_button, :description => Proc.new{'email_translations.new_program_event_notification.tags.view_event_details_button.description'.translate}, :example => Proc.new{ call_to_action_example("email_translations.new_program_event_notification.tags.view_event_details_button.view_event_details".translate) } do
      url = @test_mail ? "http://www.chronus.com" : program_event_url(@program_event, :subdomain => @organization.subdomain)
      call_to_action("email_translations.new_program_event_notification.tags.view_event_details_button.view_event_details".translate, url)
    end
  end

  self.register!

end
