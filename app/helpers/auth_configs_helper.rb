module AuthConfigsHelper

  def get_auth_config_actions(auth_config)
    actions = []
    btn_class = "btn btn-white btn-xs m-b-xs pull-right m-l-xs"

    actions <<
      if auth_config.enabled?
        if auth_config.can_be_disabled?
          get_auth_config_disable_action(auth_config, btn_class)
        elsif auth_config.can_be_deleted?
          get_auth_config_delete_action(auth_config, btn_class)
        end
      else
        get_auth_config_enable_action(auth_config, btn_class)
      end

    if auth_config.indigenous? && super_console?
      actions << get_auth_config_password_policy_action(auth_config, btn_class)
    elsif auth_config.custom?
      actions << get_auth_config_configure_action(auth_config, btn_class) if super_console?
      actions << get_auth_config_customize_action(auth_config, btn_class)
    end
    actions.compact!
    actions
  end

  def get_auth_config_link_mobile_class(auth_config)
    (auth_config.remote_login? && !auth_config.use_browsertab_in_mobile?) ? "cjs_external_link" : ""
  end

  def get_auth_config_button(auth_config, modal_id)
    logo_url = auth_config.logo_url
    btn_class = "btn #{get_auth_config_button_class(auth_config)}"
    url, url_options =
      if modal_id.present?
        ["javascript:void(0)", { data: { target: "##{modal_id}", toggle: "modal" } } ]
      else
        [login_path(auth_config_id: auth_config.id), { class: get_auth_config_link_mobile_class(auth_config) } ]
      end

    link_to url, url_options do
      content_tag(:div, class: "btn-group") do
        concat content_tag(:div, image_tag(logo_url, size: "28x28"), class: "#{btn_class} cui-login-btn-icon") if logo_url.present?
        concat content_tag(:div, h(auth_config.title), class: "#{btn_class} cui-login-btn-label#{'-only' if logo_url.blank?}")
      end
    end
  end

  def render_login_id_field(auth_config, login_id)
    label = auth_config.indigenous? ? "display_string.Email".translate : "display_string.Username".translate
    field_type = "email" if auth_config.indigenous?
    field_id = auth_config.indigenous? ? "email" : "email_#{auth_config.id}"

    left_options = { type: "addon", class: "p-r-sm gray-bg", content: get_icon_content("fa fa-user m-r-0") }
    input_html_options = { id: field_id, class: "form-control", placeholder: label }
    input_html_options.merge!(type: field_type) if field_type.present?

    construct_input_group(left_options, {}, input_group_class: "clearfix m-b") do
      concat label_tag("email", label, class: "sr-only", for: field_id)
      concat text_field_tag("email", login_id, input_html_options)
    end
  end

  def render_password_field(auth_config)
    left_options = { type: "addon", class: "gray-bg", content: content_tag(:big, get_icon_content("fa fa-key m-r-0")) }
    field_id = auth_config.indigenous? ? "password" : "password_#{auth_config.id}"

    construct_input_group(left_options, {}, input_group_class: "clearfix") do
      concat label_tag("password", "display_string.Password".translate, class: "sr-only", for: field_id)
      concat password_field_tag("password", nil, class: "form-control", id: field_id, autocomplete: :off, placeholder: "display_string.Password".translate)
    end
  end

  private

  def get_auth_config_disable_action(auth_config, btn_class)
    label = content_tag(:span, append_text_to_icon("fa fa-ban", "display_string.Disable".translate), class: "text-danger")
    confirm_text = "feature.login_management.content.disable_confirmation".translate(title: h(auth_config.title))
    link_to(label, toggle_auth_config_path(auth_config), method: :patch, data: { confirm: confirm_text }, class: btn_class)
  end

  def get_auth_config_delete_action(auth_config, btn_class)
    label = content_tag(:span, append_text_to_icon("fa fa-trash", "display_string.Delete".translate), class: "text-danger")
    confirm_text = "#{'feature.login_management.content.delete_confirmation'.translate(title: h(auth_config.title))} #{'display_string.do_you_want_to_continue'.translate}"
    link_to(label, auth_config_path(auth_config), method: :delete, data: { confirm: confirm_text }, class: btn_class)
  end

  def get_auth_config_enable_action(auth_config, btn_class)
    label = content_tag(:span, append_text_to_icon("fa fa-check", "display_string.Enable".translate), class: "text-navy")
    confirm_text = "feature.login_management.content.enable_confirmation".translate(title: h(auth_config.title))
    link_to(label, toggle_auth_config_path(auth_config, enable: true), method: :patch, data: { confirm: confirm_text }, class: btn_class)
  end

  def get_auth_config_configure_action(auth_config, btn_class)
    label = append_text_to_icon("fa fa-cog", "display_string.Configure".translate)
    if auth_config.saml_auth?
      url = saml_auth_config_saml_sso_path(tab: SamlAuthConfigController::SamlHeaders::UPLOAD_IDP_METADATA)
      link_to(label, url, class: btn_class)
    end
  end

  def get_auth_config_password_policy_action(auth_config, btn_class)
    label = append_text_to_icon("fa fa-lock", "feature.login_management.action.password_policy".translate)
    link_to(label, edit_password_policy_auth_config_path(auth_config), class: btn_class)
  end

  def get_auth_config_customize_action(auth_config, btn_class)
    label = append_text_to_icon("fa fa-pencil", "manage_strings.program.header.Customize".translate)
    link_to(label, edit_auth_config_path(auth_config), class: btn_class)
  end

  def get_auth_config_button_class(auth_config)
    if auth_config.linkedin_oauth?
      "cui-btn-linkedin"
    elsif auth_config.google_oauth?
      "cui-btn-google"
    else
      "btn-primary"
    end
  end
end