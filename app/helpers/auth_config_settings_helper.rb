module AuthConfigSettingsHelper

  def get_auth_config_section_title(section)
    if section == AuthConfigSetting::Section::DEFAULT
      "feature.login_management.header.default_logins".translate
    else
      "feature.login_management.header.custom_logins".translate
    end
  end

  def get_auth_config_section_header(section)
    header_title = get_auth_config_section_title(section)
    customize_label = append_text_to_icon("fa fa-pencil", "manage_strings.program.header.Customize".translate)

    content = content_tag(:h5, header_title, class: "no-padding font-600")
    content << link_to(customize_label, auth_config_settings_path(section: section), class: "m-l btn btn-primary btn-outline btn-xs")
  end
end