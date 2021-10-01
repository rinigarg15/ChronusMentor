module SalesDemo
  class OrganizationPopulator < BasePopulator
    REQUIRED_FIELDS = Organization.attribute_names.map(&:to_sym) - Organization::PROGRAM_ATTRIBUTES - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    attr_accessor :object

    def initialize(master_populator)
      self.reference = convert_to_objects(master_populator.parse_file(:organizations)).first
      self.master_populator = master_populator
    end

    def copy_data
      organization = Organization.new
      assign_data(organization, self.reference)
      organization.name = master_populator.organization_name
      organization.created_for_sales_demo = true
      organization.account_name = "#{master_populator.organization_name} (subdomain: #{master_populator.subdomain}) Account (created on #{Time.now.utc.to_s})"
      organization.save_without_timestamping!
      self.object = organization
      populate_subdomain
      organization.browser_warning = self.master_populator.handle_ck_editor_import(self.reference.browser_warning, organization)
      organization.privacy_policy = self.master_populator.handle_ck_editor_import(self.reference.privacy_policy, organization)
      organization.agreement = self.master_populator.handle_ck_editor_import(self.reference.agreement, organization)
      organization.save!
      master_populator.referer_hash[:organization] = {self.reference.id => organization.id}
    end

    def populate_subdomain
      pdomain = self.object.program_domains.new
      pdomain.subdomain = master_populator.subdomain
      pdomain.domain = DEFAULT_DOMAIN_NAME
      pdomain.save!
    end

  end
end
