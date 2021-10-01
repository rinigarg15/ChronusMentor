class MembershipRequestNotAccepted < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '60iqcv2c', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::APPLY_TO_JOIN,
    :title        => Proc.new{|program| "email_translations.membership_request_not_accepted.title_v1".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.membership_request_not_accepted.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.membership_request_not_accepted.subject_v1".translate},
    :campaign_id  => CampaignConstants::MEMBERSHIP_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.role_names_allowing_membership_request.present? || program.membership_requests.pending.present? },
    :campaign_id_2  => CampaignConstants::MEMBERSHIP_REQUEST_NOT_ACCEPTED_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 8
  }

  def membership_request_not_accepted(membership_request)
    # We're sending the mail to the requestor
    @recipients = membership_request.email
    @membership_request = membership_request
    @member = membership_request.member
    @admin = membership_request.admin
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@membership_request.program)
    set_username(@member)
    @membership_request.user.present? ? setup_email(@membership_request.user, {:from => :admin}) : setup_email(nil, {:email => @recipients, :from => :admin})
    super
  end


  register_tags do
    tag :message_from_admin, :description => Proc.new{'email_translations.membership_request_not_accepted.tags.message_from_admin.description'.translate(:program => @_program_string)}, :example => Proc.new{'email_translations.membership_request_not_accepted.tags.message_from_admin.example'.translate} do
      wrap_and_break(@membership_request.response_text)
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.membership_request_not_accepted.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@program, url_params: { subdomain: @organization.subdomain, root: @program.root }, only_url: true)
    end

    tag :message_from_admin_as_quote, :description => Proc.new{'email_translations.membership_request_not_accepted.tags.message_from_admin_as_quote.description'.translate(:program => @_program_string)}, :example => Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.membership_request_not_accepted.tags.message_from_admin.example'.translate, :name => 'feature.email.tags.mentor_name.example'.translate)} do
      word_wrap(@membership_request.response_text.present? ? 'feature.email.tags.message_from_user_v3_html'.translate(:message => @membership_request.response_text, :name => @admin.name) : "").html_safe
    end
  end

  self.register!

end
