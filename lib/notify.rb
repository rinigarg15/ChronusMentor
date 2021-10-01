class Notify
  WEEKLY_STATUS_JOB_UUID_PREFIX = "51b6fc19-c4b5-4db9-b61b-8d3f3c1e903f"

  def self.facilitation_messages
    includes_list = [:enabled_db_features, :disabled_db_features, organization: :enabled_db_features]

    BlockExecutor.iterate_fail_safe(Program.active.includes(includes_list)) do |program|
      next unless program.mentoring_connections_v2_enabled?

      program.deliver_facilitation_messages_v2
    end
  end

  def self.admins_weekly_status
    job_uuid = "#{WEEKLY_STATUS_JOB_UUID_PREFIX}-#{Date.current.week_of_year}-#{Date.current.year}"

    BlockExecutor.iterate_fail_safe(Program.active) do |program|
      next unless program.should_send_admin_weekly_status?

      precomputed_hash = program.get_admin_weekly_status_hash
      JobLog.compute_with_uuid(program.admin_users.active, job_uuid) do |admin_user|
        ChronusMailer.admin_weekly_status(admin_user, program, precomputed_hash).deliver_now
      end
    end
  end

  def self.admin_weekly_saml_sso_check
    saml_auth_configs = AuthConfig.where(auth_type: "SAMLAuth")
    saml_auth_configs.select do |config|
      config.get_options["authn_signed"]
    end.each do |config|
      cert = OpenSSL::X509::Certificate.new(config.get_options["xmlsec_certificate"])
      if (12.weeks.from_now.utc > cert.not_after)
        InternalMailer.saml_sso_expire(config.organization.name, cert.not_after.strftime('%B %d,%Y')).deliver_now
      end
    end
  end
end
