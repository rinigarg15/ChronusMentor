class OrganizationReportAlert < ChronusActionMailer::Base
  include Report::MetricsHelper

  @mailer_attributes = {
    :uid          => 'o2gxpnyx', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ADMINISTRATION_EMAILS,
    :title        => Proc.new{ "email_translations.organization_report_alert.title".translate },
    :description  => Proc.new{ |organization| "email_translations.organization_report_alert.description".translate(Administrators: organization.admin_custom_term.pluralized_term, programs: organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).pluralized_term_downcase) },
    :subject      => Proc.new{ "email_translations.organization_report_alert.subject".translate },
    :program_settings => Proc.new{ |program| !program.standalone? },
    :campaign_id  => CampaignConstants::ORGANIZATION_REPORT_ALERT_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::ORGANIZATION,
    :listing_order => 12,
    :notification_setting => UserNotificationSetting::SettingNames::DIGEST_AND_ALERTS
  }

  def organization_report_alert(member, program_alerts_hash)
    @member = member
    init_mail
    @alert_links_hash = get_alert_links_hash(program_alerts_hash)
    @program_alerts_hash = program_alerts_hash
    @alerts_count = @program_alerts_hash.values.collect(&:size).sum
    render_mail
  end

  private

  def init_mail
    set_username(@member)
    setup_recipient_and_organization(@member, @member.organization)
    setup_email(@member, { from: :admin })
    super
  end

  register_tags do
    tag :alert_details_consolidated, description: Proc.new{ |program| 'email_translations.organization_report_alert.tags.alert_details_consolidated.description'.translate(programs: program.return_custom_term_hash[:_programs]) }, example: Proc.new{ |_, organization|
        program_2 = organization.programs.last
        'email_translations.organization_report_alert.tags.alert_details_consolidated.example_html'.translate(
          programs: organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).pluralized_term_downcase,
          program_name_1: organization.programs.first.name,
          program_name_2: program_2.name,
          Mentees: program_2.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term,
          Mentoring: program_2.term_for(CustomizedTerm::TermType::MENTORING_TERM).term
        )
      } do
      render(partial: '/alert_details', locals: { object_alerts_hash: @program_alerts_hash, org_level_report: true, alert_links_hash: @alert_links_hash }).html_safe
    end
    tag :alerts_count_consolidated, description: Proc.new{ |program| 'email_translations.organization_report_alert.tags.alerts_count_consolidated.description'.translate(programs: program.return_custom_term_hash[:_programs])}, example: Proc.new{ |_, organization| 'email_translations.organization_report_alert.alerts_count_consolidated'.translate(count: 3, programs_count: "feature.profile_customization.label.n_programs_v1".translate(count: 2, programs: organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).pluralized_term_downcase))} do
      'email_translations.organization_report_alert.alerts_count_consolidated'.translate(count: @alerts_count, programs_count: "feature.profile_customization.label.n_programs_v1".translate(count: @program_alerts_hash.size, program: @_program_string, programs: @_programs_string))
    end
    tag :need, description: Proc.new{'email_translations.report_alert.tags.need.description'.translate}, example: Proc.new{'email_translations.report_alert.need'.translate(count: 4)} do
      'email_translations.report_alert.need'.translate(count: @alerts_count)
    end
  end
  self.register!
end
