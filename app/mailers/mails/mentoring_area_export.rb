class MentoringAreaExport < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'tnk04sv9', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ADMINISTRATION_EMAILS,
    :title        => Proc.new{|program| "email_translations.mentoring_area_export.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.mentoring_area_export.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.mentoring_area_export.subject_v2".translate},
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :campaign_id  => CampaignConstants::MENTORING_AREA_EXPORT_MAIL_ID,
    :program_settings => Proc.new{ |program| program.ongoing_mentoring_enabled?},
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 6
  }

  def mentoring_area_export(user, group, file_name, data)
    @user = user
    @group = group        
    attachments[file_name] = data
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@user.program)
    set_username(@user)
    setup_email(@user)
    super
  end

  register_tags do
    tag :group_name, :description => Proc.new{|program| 'email_translations.mentoring_area_export.tags.group_name.description_v1'.translate(program.return_custom_term_hash)}, :example => Proc.new{'email_translations.mentoring_area_export.tags.group_name.example'.translate} do
        @group.name
    end
  end

  self.register!

end
