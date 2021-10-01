class MembershipRequestSentNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '67pab4en', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::APPLY_TO_JOIN,
    :title        => Proc.new{|program| "email_translations.membership_request_sent_notification.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.membership_request_sent_notification.description_v4".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.membership_request_sent_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::MEMBERSHIP_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.has_membership_requests? },
    :campaign_id_2  => CampaignConstants::MEMBERSHIP_REQUEST_SENT_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 5
  }

  def membership_request_sent_notification(membership_request)
    @membership_request = membership_request
    @member = membership_request.member
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@membership_request.program)
    set_username(@member)
    setup_email(nil, :email => @membership_request.email)
    super
  end

  self.register!

end
