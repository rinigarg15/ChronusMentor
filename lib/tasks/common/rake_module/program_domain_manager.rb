module Common::RakeModule::ProgramDomainManager

  def self.fetch_program_domain(domain, subdomain)
    program_domain = Program::Domain.find_by(domain: domain, subdomain: subdomain)
    raise "Invalid Domain and Subdomain!" if program_domain.blank?
    program_domain
  end

  def self.make_default(program_domain)
    return if program_domain.is_default?

    organization = program_domain.organization
    existing_default_program_domain = organization.default_program_domain
    if existing_default_program_domain.present?
      existing_default_program_domain.update_column(:is_default, false)
    end
    program_domain.is_default = true
    program_domain.save!

    messages = ["Run Domain Updater!"]
    messages << "Update the SAML config at both SP and IDP ends!" if organization.has_saml_auth?
    Common::RakeModule::Utils.print_alert_messages(messages)
  end
end