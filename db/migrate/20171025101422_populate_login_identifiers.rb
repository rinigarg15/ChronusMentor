class PopulateLoginIdentifiers< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      chronus_auth_id_organization_id = AuthConfig.unscoped.where(auth_type: AuthConfig::Type::CHRONUS).pluck(:id, :organization_id)
      custom_auth_configs = AuthConfig.unscoped.select(:id, :organization_id, :use_email).where.not(auth_type: [AuthConfig::Type::CHRONUS, AuthConfig::Type::OPEN])

      login_identifiers = []
      chronus_auth_id_organization_id.each do |chronus_auth_id, organization_id|
        member_ids = Member.where(organization_id: organization_id).where.not(crypted_password: nil).pluck(:id)
        member_ids.each do |member_id|
          login_identifiers << LoginIdentifier.new(auth_config_id: chronus_auth_id, member_id: member_id)
        end
      end

      custom_auth_configs.each do |custom_auth_config|
        identifier_column = custom_auth_config.use_email? ? :email : :login_name
        member_id_identifier = custom_auth_config.organization.members.where.not(identifier_column => nil).pluck(:id, identifier_column)
        member_id_identifier.each do |member_id, identifier|
          next if identifier.blank?
          login_identifiers << LoginIdentifier.new(auth_config_id: custom_auth_config.id, member_id: member_id, identifier: identifier)
        end
      end
      LoginIdentifier.import login_identifiers, validate: false
    end
  end

  def down
  end
end