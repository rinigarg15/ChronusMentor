class ProgramReportAlert < ChronusActionMailer::Base
  include Report::MetricsHelper

  @mailer_attributes = {
    :uid          => 'iqwyqeyf', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ADMINISTRATION_EMAILS,
    :title        => Proc.new{|program| "email_translations.report_alert.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.report_alert.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.report_alert.subject_v1".translate},
    :campaign_id  => CampaignConstants::PROGRAM_REPORT_ALERT_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 8,
    :notification_setting => UserNotificationSetting::SettingNames::DIGEST_AND_ALERTS
  }

  def program_report_alert(user, alerts)
    @user = user
    @alerts = alerts
    init_mail
    @alert_links_hash = Hash[@alerts.map{|a| [a.id, get_metric_view_path(a.metric, true, {:domain => @program.organization.domain, :subdomain => @program.organization.subdomain, :root => @program.root, :src => ReportConst::ManagementReport::EmailSource, :alert_id => a.id})]}]
    @object_alerts_hash = @alerts.inject({}) do |object_alerts_hash, alert|
      object_alerts_hash[alert] = [alert]
      object_alerts_hash
    end
    render_mail
  end

  private

  def init_mail
    set_program(@user.program)
    set_username(@user)
    setup_email(@user, {:from => :admin})
    super
  end

  register_tags do
    tag :alert_details, :description => Proc.new{'email_translations.report_alert.tags.alert_details.description'.translate}, :example => Proc.new{'email_translations.report_alert.tags.alert_details.example_v2_html'.translate} do
      render(:partial => '/alert_details', locals: { object_alerts_hash: @object_alerts_hash, alert_links_hash: @alert_links_hash }).html_safe
    end
    tag :alerts_count, :description => Proc.new{'email_translations.report_alert.tags.alerts_count.description'.translate}, :example =>Proc.new{'email_translations.report_alert.alert_count'.translate(:count => 20)} do
      'email_translations.report_alert.dashboard_alert_count'.translate(:count => @alerts.size)
    end
    tag :need, :description => Proc.new{'email_translations.report_alert.tags.need.description'.translate}, :example =>Proc.new{'email_translations.report_alert.need'.translate(:count => 20)} do
      'email_translations.report_alert.need'.translate(:count => @alerts.size)
    end
    tag :program_link, :description => Proc.new{'email_translations.report_alert.tags.program_link.description'.translate}, :example =>Proc.new{'email_translations.report_alert.tags.program_link.example_html'.translate} do
      'email_translations.report_alert.program_link_html'.translate(:link => management_report_url(:subdomain => @program.organization.subdomain, :root => @program.root))
    end
  end
  self.register!
end
