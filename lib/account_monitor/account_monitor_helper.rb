module AccountMonitor
  module AccountMonitorHelper
    EMAIL_RECIPIENTS = ["monitor+sendmail@chronus.com"]
    PAGERDUTY_RECIPIENTS = ["opseng+sendmail@chronus.com", "account-monitoring@apollo.pagerduty.com"]

    def send_mail(subject, body = "")
      recipients = (defined?(PAGERDUTY_NOTIFICATION) && PAGERDUTY_NOTIFICATION) ? PAGERDUTY_RECIPIENTS : EMAIL_RECIPIENTS
      InternalMailer.notify_account_monitoring_status_if_violated(recipients, subject, body).deliver_now
    end

    def get_whitelisting_criteria
      YAML::load(ERB.new(File.read("#{Rails.root}/config/accounts_monitor.yml")).result)[Rails.env]
    end

    def get_whitelisted_orgs(whitelisted_array)
      whitelisted_orgs_hash = {}
      return whitelisted_orgs_hash if whitelisted_array.blank?
      whitelisted_array.each do |org_ids_with_limits|
        whitelisted_orgs_hash[org_ids_with_limits["org_id"]] = org_ids_with_limits["max_limit"]
      end
      whitelisted_orgs_hash
    end
  end
end