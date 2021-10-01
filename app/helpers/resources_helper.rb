module ResourcesHelper
  MAX_LENGTH_ROLE_NAME = 20
  MAX_LENGTH_PROGRAM_NAME = 40
  MAX_PROGRAMS_TO_SHOW = 2

  def get_shared_programs_text(resource)
    programs = resource.programs
    if programs.size == 0
      return "feature.resources.content.shared_with_program".translate(count: 0, program: _program)
    else
      visible_labels = []
      hidden_labels = []
      visible_programs = (programs.size <= (MAX_PROGRAMS_TO_SHOW + 1)) ? programs[0..-1] : programs[0..(MAX_PROGRAMS_TO_SHOW - 1)]
      visible_programs.each { |program| visible_labels << { content: program.name, label_class: "label-default" } }
      visible_content = labels_container(visible_labels, tag: :span, class: "m-r-xxs")

      if programs.size > (MAX_PROGRAMS_TO_SHOW + 1)
        remaining_programs = programs[MAX_PROGRAMS_TO_SHOW..-1]
        remaining_programs.each { |program| hidden_labels << { content: program.name, label_class: "label-default" } }
        hidden_content = link_to("+ #{'feature.resources.content.n_other_programs'.translate(count: remaining_programs.size, programs: _programs, program: _program)}",
          "javascript:void(0)", onclick: %Q[jQuery(this).hide(); jQuery('.cjs_more_programs_#{resource.id}').show();], class: "label label-default")
        hidden_content += labels_container(hidden_labels, tag: :span, class: "hide cjs_more_programs_#{resource.id}")
      end
 
      return content_tag(:span, "feature.resources.content.shared_with_v1".translate, class: "m-r-xs") + visible_content + hidden_content
    end
  end

  def generate_role_names(program_role_names_map, resource_roles)
    role_labels = []
    resource_roles.each { |role| role_labels << { content: program_role_names_map[role], label_class: "label-default" } }
    labels_container(role_labels, tag: :span)
  end

  def can_access_resource?(resource)
    resource.is_organization? && !@current_organization.standalone?
  end

  def get_button_rating_class(resource, rating_type, member)
    return "btn-white" if !resource.rated_by_user?(member)
    rating = resource.find_user_rating(member).rating.to_s 
    rating == rating_type ? "btn-success" : "btn-white"
  end
end