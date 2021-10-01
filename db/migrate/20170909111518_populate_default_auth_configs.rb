class PopulateDefaultAuthConfigs< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      attr_value_map_for_default_auths = AuthConfig.attr_value_map_for_default_auths
      Organization.all.includes(auth_configs: :translations).each do |organization|
        auth_configs = organization.auth_configs
        attr_value_map_for_default_auths.each do |attr_value_map|
          auth_config = auth_configs.find do |auth_config|
            attr_value_map.all? { |attr, value| auth_config[attr] == value }
          end
          organization.auth_configs.create!(attr_value_map.merge(enabled: false)) if auth_config.blank?
        end
      end
    end
  end

  def down
  end
end