module OrganizationLanguagesHelper
  # Set the I18n.locale either from member or cookie
  # TODO Test for helper

  def fetch_availability_status(org_lang)
    if org_lang.nil? || org_lang.disabled?
      "feature.language.manage_page.content.availability_status.None".translate
    elsif org_lang.enabled_for_admin?
      "feature.language.manage_page.content.availability_status.Only_Admins".translate(Admins: _Admins)
    elsif org_lang.enabled_for_all?
      "feature.language.manage_page.content.availability_status.Everyone".translate
    end
  end

  def get_edit_link(org_lang, language)
    org_lang.nil? ? "jQueryShowQtip('#centered_content', 600, '#{new_organization_language_path(:language_id => language.id)}', '', {draggable: true});" :  
                    "jQueryShowQtip('#centered_content', 600, '#{edit_organization_language_path(org_lang)}', '', {draggable: true});"
  end

  def get_enabled_options_array
    [
      ["feature.language.manage_page.content.availability_status.None".translate, OrganizationLanguage::EnabledFor::NONE],
      ["feature.language.manage_page.content.availability_status.Only_Admins".translate(Admins: _Admins), OrganizationLanguage::EnabledFor::ADMIN],
      ["feature.language.manage_page.content.availability_status.Everyone".translate, OrganizationLanguage::EnabledFor::ALL]
    ]
  end

  def get_programs_selector(organization_language, programs_enabled_for_term)
    enabled_program_ids = organization_language.enabled_program_ids
    programs = organization_language.organization.programs.ordered
    scroll_required = programs.size > 6

    content_tag(:div, data: { slim_scroll: scroll_required, slim_scroll_height: 150 }) do +
      choices_wrapper(programs_enabled_for_term) do
        programs.inject(get_safe_string) do |content, program|
          program_id = program.id
          content + content_tag(:label, class: "checkbox") do +
            check_box_tag("organization_language[enabled_program_ids][]", program_id, enabled_program_ids.include?(program_id), id: "enabled_for_program_#{program_id}", class: "multi_select_check_box") +
            content_tag(:span, program.name, class: "multi_select_label")
          end
        end
      end +
      javascript_tag("initialize.setSlimScroll()")
    end
  end

  def get_enabled_programs_details(organization_language)
    return "display_string.None".translate if organization_language.nil? || organization_language.new_record?

    organization = organization_language.organization
    enabled_programs = organization.programs.where(id: organization_language.enabled_program_ids).ordered
    enabled_programs_count = enabled_programs.size

    if enabled_programs_count.zero?
      "display_string.None".translate
    elsif enabled_programs_count == organization.programs_count
      "display_string.All_Programs_v1".translate(Programs: _Programs)
    else
      programs_list_tooltip(organization_language.id, enabled_programs)
    end
  end

  private

  def programs_list_tooltip(organization_language_id, enabled_programs)
    enabled_programs_count = enabled_programs.size
    tooltip_id = "enabled_programs_help_icon_#{organization_language_id}"
    tootltip_text = content_tag(:div) do
      content_tag(:ul, enabled_programs.collect{|program| content_tag('li', program.name, class: "p-t-xxs")}.inject(:+), class: "list-group")
    end

    content_tag(:span, "feature.profile_customization.label.n_programs_v1".translate(count: enabled_programs_count, programs: _Programs, program: _Program), id: tooltip_id, class: "pointer cui-dotted-border-bottom") +
      tooltip(tooltip_id, tootltip_text, true, placement: "bottom")
  end
end