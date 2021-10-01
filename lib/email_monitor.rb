class EmailMonitor

  MONITORING_EMAIL_ID = "apollo_email_monitor+sendmail@chronus.com"
  PAGERDUTY_EMAIL_ID = "email-monitoring@apollo.pagerduty.com"
  FROM_EMAIL_ID = "no-reply@chronus.com"
  EMAIL_SUBJECT = Proc.new { |env, unique_identifier| "[#{env}] Email Monitoring via DJ unique_identifier: #{unique_identifier}"}
  RETRY_INTERVAL_IN_SECONDS = 4
  RETRY_TIMES = 5
  DEFAULT_WAIT_TIME = 15.minutes

  attr_accessor :unique_identifier

  def initialize
    # random integer appended to handle cases such as two production servers with same env variable may send out mails with same time stamp.
    self.unique_identifier = get_unique_identifier
  end

  def send_email
    return unless email_monitoring_enabled?

    send_test_email
    delay(run_at: DEFAULT_WAIT_TIME.from_now).verify_email
  end

  def verify_email
    counter = 0

    begin
      counter += 1
      check_email
    rescue Net::IMAP::NoResponseError, Net::IMAP::BadResponseError, Net::IMAP::ByeResponseError => e
      if counter <= RETRY_TIMES
        puts "Exception name: #{e.class}"
        puts "Exception raised: #{e.message} at #{Time.now}"
        sleep retry_interval_in_seconds
        retry
      else
        puts "Exception raised exceeded retry times: #{e.message} at #{Time.now}"
        raise e.message
      end
    end
  end

  private

  def email_monitoring_enabled?
    defined?(EMAIL_MONITOR_ORG_URL)
  end

  def get_unique_identifier
    [Time.now.getutc.to_s.gsub(' ', '-'), rand(36**8).to_s(36)].join("_")
  end

  def send_test_email
    mail = ChronusMailer.email_monitor_mail(nil, MONITORING_EMAIL_ID, get_program_id)
    mail.subject = EMAIL_SUBJECT[Rails.env, self.unique_identifier]
    mail.deliver_now
  end

  def get_program_id
    org_uri = URI.parse(EMAIL_MONITOR_ORG_URL)
    subdomain, domain =  /(.*)\.(.*\..*)/.match(org_uri.host)[1..-1] if org_uri.host
    Program::Domain.get_organization(domain, subdomain).programs.first.id
  end

  def check_email
    gmail = Gmail.new(MONITORING_EMAIL_ID, ENV['EMAIL_MONITORING_PASSWORD'])
    sent_emails = gmail.inbox.emails(:unread, from: EmailMonitor::FROM_EMAIL_ID, subject: EmailMonitor::EMAIL_SUBJECT[Rails.env, self.unique_identifier])
    notify_failure(gmail) unless sent_emails.count == 1
  end

  def notify_failure(gmail)
    identifier = self.unique_identifier

    gmail.deliver do
      to ["production", "generalelectric", "veteransadmin", "productioneu", "nch"].include?(Rails.env) ? PAGERDUTY_EMAIL_ID : APP_CONFIG[:monit_mailing_list]
      subject "#{Rails.env} EMAIL MONIT ALERT: Emails not being delivered! #{identifier}"
    end
  end

  def retry_interval_in_seconds
    RETRY_INTERVAL_IN_SECONDS
  end
end