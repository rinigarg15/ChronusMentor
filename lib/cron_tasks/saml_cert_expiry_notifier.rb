# To notify the expiration of SP certificate of any SAML config with request signatures enabled
module CronTasks
  class SamlCertExpiryNotifier
    include Delayed::RecurringJob

    def perform
      Notify.admin_weekly_saml_sso_check
    end
  end
end