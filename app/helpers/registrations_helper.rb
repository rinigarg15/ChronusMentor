module RegistrationsHelper

  def csv_hint_text
    template_link = "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/files/Profile_Import_CSV_Template/profile_fields_template.csv"
    spec_link = "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/files/Profile_Import_CSV_Template/profile_fields_csv_spec.txt"
    hints = []
    hints << "registration_page.content.provide_csv_file".translate
    hints << "registration_page.content.use_template_for_csv_html".translate(template: link_to("display_string.this_template".translate, template_link, target: "_blank"))
    hints << "registration_page.content.please_read_specification_html".translate(specification: link_to("display_string.format_specification".translate, spec_link, target: "_blank"))
    hints << "registration_page.content.dont_include_name_and_email".translate
    raw(hints.join(" "))
  end

  def get_heading_for_signup_page(program_invitation, password)
    if program_invitation.present?
      if program_invitation.assign_type?
        invite_role_names = program_invitation.formatted_role_names.blank? ? "" : "#{'display_string.as'.translate} #{program_invitation.formatted_role_names(articleize: true)}"
        "registration_page.title.welcome_with_roles".translate(current_program_name: current_program.name, invite_role_names: " #{invite_role_names}")
      else
        "registration_page.title.welcome_general".translate(current_program_name: current_program.name)
      end
    elsif password.present?
      "feature.member.content.welcome_terms_v4".translate(member_name: password.member.name(name_only: true))
    end
  end

  def get_title_for_signup_form(auth_config, join_now_page = false)
    if auth_config.present? && !logged_in_organization?
      title =
        if auth_config.indigenous? && !join_now_page
          "display_string.Password".translate
        else
          auth_config.title
        end
      "feature.user.header.sign_up_with".translate(title: title)
    else
      "display_string.sign_up".translate
    end
  end

  def get_url_and_method_for_signup_form(program_invitation, password)
    if program_invitation.present?
      [registrations_url(invite_code: program_invitation.code), :post]
    elsif password.present?
      [registration_url(password.member, reset_code: password.reset_code), :patch]
    end
  end
end