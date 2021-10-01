module ExperiencesHelper
  # Differentiate between new and existing records
  def fields_for_experience(question, experience, &block)
    if experience.new_record?
      fields_for("profile_answers[#{question.id}][new_experience_attributes][]", experience, &block)
    else
      fields_for("profile_answers[#{question.id}][existing_experience_attributes][]", experience, &block)
    end
  end

  # A link with value 'name' will be created which will give a new form for experience
  def add_experience_link(question, name, options = {})
    new_experience_content = render(partial: 'experiences/new_experience', object: Experience.new, locals: { question: question, required: options[:required] })
    link_to_function(name, "jQuery('#exp_cur_list_#{question.id}').append(\"#{j(new_experience_content)}\");jQuery('.cjs_add_show').show();jQuery('.cjs_question_#{question.id} .cjs_empty_message').hide();", class: "add_icon #{options[:link_class]}")
  end

  def formatted_work_experience_in_listing(experience, options = {})
    content_tag(:div, class: 'work_exp') do
      str = get_icon_content("fa fa-suitcase")
      str << (options[:highlight] ? fetch_highlighted_answers(experience.company, options[:common_values], class: "company") : content_tag(:strong, experience.company, class: "company"))
      title_str = content_tag(:span, fetch_highlighted_answers(experience.job_title, options[:common_values]), :class => "title") if experience.job_title.present?

      if experience.dates_present?
        date_start_info = (fetch_workex_month(experience.start_month) + " " + experience.start_year.to_s).strip
        date_end_info = experience.current_job? ? "feature.education_and_experience.label.present".translate : (fetch_workex_month(experience.end_month) + " " + experience.end_year.to_s).strip

        date_str = content_tag(:span, class: 'text-muted work_date') do
          if date_start_info.present? && date_end_info.present?
            "#{date_start_info} - #{date_end_info}"
          else
            date_start_info + date_end_info
          end
        end
      end

      if title_str.present? || date_str.present?
        str = content_tag(:div, class: 'title_and_date') do
          safe_join([str, safe_join([title_str.presence, date_str.presence].compact, vertical_separator)].compact, content_tag(:span, COMMON_SEPARATOR, class: 'text-muted'))
        end
      end

      str
    end
  end

  def fetch_workex_month(month_code)
    "date.abbr_month_names".translate[month_code].to_s
  end
end
