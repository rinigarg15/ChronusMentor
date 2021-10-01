jbuilder_responder(json, local_assigns) do
  json.programs do
    json.array! @programs do |program|
      json.id program.id
      json.name program.name
      json.description program.description
      json.root program.root
      
      setting = program.contact_admin_setting
      if setting.present?
        json.contact_admin do
          json.label setting.label_name
          json.url setting.contact_url
          json.instruction setting.content
        end
      end
    end
  end

  json.auth_configs do
    json.array! @auth_configs do |auth_config|
      json.extract! auth_config, :id, :title, :auth_type
      json.is_external !(auth_config.auth_type == AuthConfig::Type::CHRONUS || auth_config.auth_type == AuthConfig::Type::LDAP)
    end
  end

  json.sso_base_url @sso_base_url
end