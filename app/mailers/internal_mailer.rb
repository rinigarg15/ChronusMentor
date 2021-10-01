class InternalMailer < ActionMailer::Base
  CSMailingList = ["cs@chronus.com", "cseng@chronus.com"]

  helper UserMailerHelper

  include UserMailerHelper

  def notify_untranslated_strings(untranslated_strings_hash)
    @untranslated_strings_hash = untranslated_strings_hash
    @from = "\"Chronus Admin\" <#{Brand::Defaults::DELIVERY_EMAIL}>"
    @recipients = APP_CONFIG[:monit_mailing_list]
    @subject = "#{Rails.env} - Untranslated String in some locales"
    build_mail
  end

  def notify_unused_keys(unused_keys)
    @unused_keys = unused_keys
    @from = "\"Chronus Admin\" <#{Brand::Defaults::DELIVERY_EMAIL}>"
    @recipients = APP_CONFIG[:monit_mailing_list]
    @subject = "Unused keys present in codebase"
    build_mail
  end

  def notify_corrupted_translations(problematic_keys)
    @problematic_interpolation_keys = problematic_keys[:problematic_interpolation_keys]
    @problematic_html_keys = problematic_keys[:problematic_html_keys]
    @warning_html_keys = problematic_keys[:warning_html_keys]
    count = @problematic_interpolation_keys.count + @problematic_html_keys.count + @warning_html_keys.count

    @from = "\"Chronus Admin\" <#{Brand::Defaults::DELIVERY_EMAIL}>"
    @recipients = APP_CONFIG[:monit_mailing_list]
    @subject = "#{Rails.env} - #{count} incorrect translated strings"
    build_mail
  end

  def data_feed_migration_status_notification_to_chronus(migration_status, is_success = true)
    @from = "\"Chronus Admin\" <#{Brand::Defaults::DELIVERY_EMAIL}>"
    @migration_status = migration_status
    @date = Time.now
    recipients = FEED_MIGRATION_STATUS_NOTIFICATION_CHRONUS_RECIPIENTS
    recipients += FEED_MIGRATION_FAILURE_NOTIFICATION_CHRONUS_RECIPIENTS unless is_success
    @recipients = recipients.join(',')
    @subject = "Customer Feed Migration Status Report"
    build_mail
  end

  def sales_demo_organization_creation_status_notification_to_chronus(creation_success, organization_options)
    @from = "\"Chronus Admin\" <#{Brand::Defaults::DELIVERY_EMAIL}>"
    @creation_success = creation_success
    @organization_name = organization_options[:organization_name]
    @organization_subdomain = organization_options[:organization_subdomain]
    @recipients = SALES_DEMO_ORGANIZATION_CREATION_STATUS_NOTIFICATION_RECIPIENTS.join(',')
    @subject = "Sales Demo Organization Creation Status"
    build_mail
  end

  def notify_dj_status(dj_notifier)
    @dj_notifier = dj_notifier
    @from = "\"Chronus Admin\" <#{Brand::Defaults::DELIVERY_EMAIL}>"
    @recipients = APP_CONFIG[:monit_mailing_list]
    @subject = "#{Rails.env} - Delayed Job - Non Empty Queue"
    build_mail
  end

  def mailgun_failed_summary_notification(permanent_events, all_events)
    @failed_events = permanent_events
    @all_events = all_events
    total_failed_events_count = @failed_events.values.inject(0) { |mem, var| var.count + mem }
    @from = "\"Chronus Admin\" <#{Brand::Defaults::DELIVERY_EMAIL}>"
    @recipients = APP_CONFIG[:monit_mailing_list]
    @subject = "#{Rails.env} - Mailgun Failed Events (#{total_failed_events_count})"
    build_mail
  end

  def saml_sso_expire(organization_name, expire_date)
    @date = Time.now
    @recipients = APP_CONFIG[:monit_mailing_list]
    @subject = "SAML SSO certificate for '#{organization_name}' is about to expire on #{expire_date} EOM"
    @from = "\"Chronus Admin\" <no-reply@chronus.com>"
    build_mail(body: "")
  end

  def notify_multiple_servers(recipients)
    @date = Time.now
    @recipients = recipients.join(',')
    @subject = "Multiple Primary/Collapse servers are running in #{Rails.env}. Please stop the other server for #{Rails.env} <EOM>"
    @from = "\"Chronus Monitor\" <monitor@chronus.com>"
    build_mail(body: "")
  end

  def notify_account_monitoring_status_if_violated(recipients, subject, body = "")
    @date = Time.now
    @recipients = recipients.join(',')
    @subject = "#{Rails.env}: #{subject}"
    @from = "\"Chronus Monitor\" <monitor@chronus.com>"
    build_mail(body: body)
  end

  def deactivate_organization_notification(org_name, org_account_name, org_url)
    @date = Time.now
    @recipients = CSMailingList.join(',')
    name = org_account_name.present? ? org_account_name : org_name
    @subject = "#{name} has been deactivated"
    @from = "\"Chronus Admin\" <no-reply@chronus.com>"
    @org_name = org_name
    @org_account_name = org_account_name
    @org_url = org_url
    build_mail
  end

  def bounced_mail_notification(recipient_email, bounce_reason, campaign_information,member_information)
    @from = "\"Chronus Admin\" <#{Brand::Defaults::DELIVERY_EMAIL}>"
    @recipients = BOUNCED_MAIL_AND_SPAM_NOTIFICATION_RECIPIENTS.join(',')
    @subject = "The email address #{recipient_email} has been added to the bounced list"
    @recipient_email = recipient_email
    @bounce_reason = bounce_reason
    @campaign_information = campaign_information
    @member_information = member_information
    build_mail
  end

  def marked_as_spam_notification(recipient_email, campaign_information,member_information)
    @from = "\"Chronus Admin\" <#{Brand::Defaults::DELIVERY_EMAIL}>"
    @recipients = BOUNCED_MAIL_AND_SPAM_NOTIFICATION_RECIPIENTS.join(',')
    @subject = "User with email address #{recipient_email} has marked our email as spam"
    @recipient_email = recipient_email
    @campaign_information = campaign_information
    @member_information = member_information
    build_mail
  end

  def notify_active_admins(active_admins_csv)
    @from = "\"Chronus Admin\" <#{Brand::Defaults::DELIVERY_EMAIL}>"
    @recipients = ACTIVE_ADMINS_NOTIFICATION_RECIPIENTS.join(',')
    @subject = "#{Rails.env} - Active Admins"
    attachments[File.basename(active_admins_csv)] = File.read(active_admins_csv)
    build_mail
  end

  protected

  def setup_from_subject_and_sent_on(options = {})
    @from = "\"#{@organization.name}\" <#{MAILER_ACCOUNT[:email_address]}>"
    @subject = ""
    @date = Time.now
  end

  def setup_recipient_and_organization(organization, program = nil)
    @organization = organization

    if program
      @program = program
    end

    set_host_name_for_urls(@organization, @program)

    if @program
      @program_link = helpers.link_to(@program.name, program_root_url(:subdomain => @organization.subdomain, :root => @program.root)).html_safe
    elsif @organization
      @program_link = helpers.link_to(@organization.name, root_organization_url(:subdomain => @organization.subdomain)).html_safe
    end
  end

  def helpers
    ActionController::Base.helpers
  end

  def build_mail(options = {})
    mail_options = {to: @recipients, subject: @subject, cc: @cc, from: @from, sender: @from, reply_to: @reply_to, date: @date}
    mail_options.merge!(body: options[:body]) if options.keys.include?(:body)
    mail(mail_options)
  end
end
