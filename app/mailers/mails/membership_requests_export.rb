class MembershipRequestsExport < ChronusActionMailer::Base
  @mailer_attributes = {
    :uid          => 'c5a4hgod', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ADMINISTRATION_EMAILS,
    :title        => Proc.new{|program| "email_translations.membership_requests_export.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.membership_requests_export.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.membership_requests_export.subject".translate},
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.role_names_allowing_membership_request.present? || program.membership_requests.pending.present? },
    :campaign_id  => CampaignConstants::MEMBERSHIP_REQUESTS_EXPORT_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 7
  }

  def membership_requests_export(admin, file_name, data)
    @admin = admin
    attachments[file_name] = data
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@admin.program)
    set_username(@admin)
    setup_email(@admin)
    super
  end

  self.register!

end
