module Common::RakeModule::AuthConfigManager

  def self.fetch_auth_config(organization, auth_type)
    auth_config = organization.auth_configs.find_by(auth_type: auth_type)
    raise "Organization doesn't contain AuthConfig of '#{auth_type}' type!" if auth_config.blank?
    auth_config
  end

  def self.set_attributes_and_options_for_auth_config(auth_config, attributes, config)
    if attributes.present?
      attributes = eval(attributes)
      attributes.each do |attribute, value|
        value = AttachmentUtils.get_remote_data(value) if attribute.to_sym == :logo
        auth_config.send("#{attribute}=", value)
      end
    end
    if config.present?
      options = auth_config.get_options
      options.merge!(eval(config))
      auth_config.set_options!(options)
    else
      auth_config.save!
    end
  end
end