module EducationsHelper
  def formatted_education_in_listing(education, options = {})
    content_tag(:div) do
      str = get_icon_content("fa fa-graduation-cap")
      str << (options[:highlight] ? fetch_highlighted_answers(education.school_name, options[:common_values]) : content_tag(:strong, education.school_name))
      degree_str = content_tag(:span, education.degree) if education.degree.present?
      major_str = content_tag(:span, fetch_highlighted_answers(education.major, options[:common_values])) if education.major.present?
      date_str = content_tag(:span, education.graduation_year, class: 'text-muted') if education.graduation_year.present?

      if degree_str.present? || major_str.present?
        degree_major_str = safe_join([degree_str.presence, major_str.presence].compact, content_tag(:span, " #{'display_string.in'.translate} ", class: 'text-muted'))
      end

      if degree_major_str.present? || date_str.present?
        str = content_tag(:div) do
          safe_join([str, safe_join([degree_major_str.presence, date_str.presence].compact, vertical_separator)], content_tag(:span, COMMON_SEPARATOR, class: 'text-muted'))
        end
      end

      str
    end
  end

  # Differentiate between new and existing records
  def fields_for_education(question, education, &block)
    if education.new_record?
      fields_for("profile_answers[#{question.id}][new_education_attributes][]", education, &block)
    else
      fields_for("profile_answers[#{question.id}][existing_education_attributes][]", education, &block)
    end
  end

  # A link with value 'name' will be created which will give a new form for education
  def add_education_link(question, name, options = {})
    new_education_content = render(partial: 'educations/new_education', object: Education.new, locals: { question: question, required: options[:required]})
    link_to_function(name, "jQuery('#edu_cur_list_#{question.id}').append(\"#{j(new_education_content)}\");jQuery('.cjs_add_show').show();jQuery('.cjs_question_#{question.id} .cjs_empty_message').hide();", class: "add_icon #{options[:link_class]}")
  end
end
