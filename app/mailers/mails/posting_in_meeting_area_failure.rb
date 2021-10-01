class PostingInMeetingAreaFailure < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'z16h892i', # rand(36**8).to_s(36)
    :title        => Proc.new{|program| "email_translations.posting_in_meeting_area_failure.title".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.posting_in_meeting_area_failure.description".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.posting_in_meeting_area_failure.subject".translate},
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :feature      => [FeatureName::CALENDAR],
    :campaign_id  => CampaignConstants::ENGAGEMENT_MAIL_ID,
    :campaign_id_2  => CampaignConstants::POSTING_IN_MEETING_AREA_FAILURE_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :donot_list   => true
  }

  def posting_in_meeting_area_failure(user, meeting, old_subject, old_body)
    @meeting = meeting
    @user = user
    @old_subject = old_subject
    @old_content = old_body
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@meeting.program)
    set_username(@user)
    setup_email(@user)
    super
  end

  register_tags do
    tag :subject, :description => Proc.new{'email_translations.posting_in_meeting_area_failure.tags.subject.description'.translate}, :example => Proc.new{'email_translations.posting_in_meeting_area_failure.tags.subject.example'.translate} do
      @old_subject
    end

    tag :content, :description => Proc.new{'email_translations.posting_in_meeting_area_failure.tags.content.description'.translate}, :example => Proc.new{'email_translations.posting_in_meeting_area_failure.tags.content.example'.translate} do
      wrap_and_break(@old_content)
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.posting_in_meeting_area_failure.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@meeting.program, {:only_url => true, :url_params => {:subdomain => @organization.subdomain, :src => 'email'}})
    end
  end

  self.register!

end
