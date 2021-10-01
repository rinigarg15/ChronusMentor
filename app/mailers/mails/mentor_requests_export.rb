class MentorRequestsExport < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'wio5lqz6', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ADMINISTRATION_EMAILS,
    :title        => Proc.new{|program| "email_translations.mentor_requests_export.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.mentor_requests_export.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.mentor_requests_export.subject_v2".translate},
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{|program| program.only_career_based_ongoing_mentoring_enabled? && (program.matching_by_mentee_and_admin? || program.matching_by_mentee_alone?)},
    :campaign_id  => CampaignConstants::MENTOR_REQUESTS_EXPORT_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 5
  }

  def mentor_requests_export(admin, file_name, data)
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
