module ThreeSixty::SurveysHelper
  def three_sixty_survey_show_view_bar_content(content, bg_class)
    content_tag(:div, :class => "parallelogram text-center #{bg_class}") do
      content_tag(:p, content)
    end
  end

  def label_hash_without_links
    return {
      ThreeSixty::Survey::View::SETTINGS => "feature.three_sixty.survey.top_bar.survey_settings".translate.capitalize,
      ThreeSixty::Survey::View::QUESTIONS => "feature.three_sixty.survey.top_bar.define_questions".translate.capitalize,
      ThreeSixty::Survey::View::PREVIEW => "feature.three_sixty.survey.top_bar.preview".translate.capitalize,
      ThreeSixty::Survey::View::ASSESSEES => "feature.three_sixty.survey.top_bar.choose_participants_v1".translate.capitalize
    }
  end

  def label_hash_with_links(survey)
    return {
      ThreeSixty::Survey::View::SETTINGS => edit_three_sixty_survey_path(survey),
      ThreeSixty::Survey::View::QUESTIONS => add_questions_three_sixty_survey_path(survey),
      ThreeSixty::Survey::View::PREVIEW => preview_three_sixty_survey_path(survey),
      ThreeSixty::Survey::View::ASSESSEES => add_assessees_three_sixty_survey_path(survey)
    }
  end

  def set_three_sixty_survey_show_url(survey_view, survey)
    case survey_view
    when ThreeSixty::Survey::View::SETTINGS
      if survey.persisted?
        return label_hash_with_links(survey)[survey_view]
      else
        return "javascript:void(0)"
      end
    when ThreeSixty::Survey::View::QUESTIONS
      if survey.persisted? && survey.not_expired? && survey.reviewer_groups.excluding_self_type.present?
        return label_hash_with_links(survey)[survey_view]
      else
        return "javascript:void(0)"
      end
    when ThreeSixty::Survey::View::ASSESSEES, ThreeSixty::Survey::View::PREVIEW
      if survey.persisted? &&  survey.not_expired? && survey.reviewer_groups.excluding_self_type.present? && survey.questions.present?
        return label_hash_with_links(survey)[survey_view]
      else
        return "javascript:void(0)"
      end
    end
  end

  def three_sixty_survey_get_view_bar_tabs(view, survey)
    tabs = ActiveSupport::OrderedHash.new

    ThreeSixty::Survey::View.all.each do |survey_view|
      bg_class = "disabled"
      link_url = set_three_sixty_survey_show_url(survey_view, survey)

      if survey_view <= view || link_url != "javascript:void(0)"
        bg_class = ""
      end

      tabs[survey_view] = {
        :label => label_hash_without_links[survey_view],
        :url => link_url,
        :class => bg_class
      }
    end

    return tabs
  end

  def three_sixty_survey_show_view_bar(view, survey)
    wizard_headers(three_sixty_survey_get_view_bar_tabs(view, survey), view) do
      yield
    end
  end

  def three_sixty_survey_reviewer_group_options(survey_reviewer_groups)
    options = []
    survey_reviewer_groups.each do |survey_reviewer_group|
      reviewer_group = survey_reviewer_group.reviewer_group
      options << [reviewer_group.name, survey_reviewer_group.id] unless reviewer_group.is_for_self?
    end
    return options
  end

  def three_sixty_name_and_email(name, email)
    "#{name} <#{email}>"
  end

  def three_sixty_name_email_and_reviewer_group(name, email, reviewer_group)
    three_sixty_name_and_email(name, email) + ", #{reviewer_group}"
  end

  def three_sixty_survey_rating_instruction(assessee, is_for_self)
    content_tag(:div, :class => "well clearfix") do
      content_tag(:div, :class => "col-md-6") do
        "feature.three_sixty.survey.scale_instruction".translate(:name_or_yourself => is_for_self ? "feature.three_sixty.survey.yourself".translate : assessee.name, :name_or_you => is_for_self ? "feature.three_sixty.survey.you".translate : assessee.name)
      end +
      content_tag(:div, :class => "col-md-6") do
        render(:partial => "three_sixty/survey/rating_instruction")
      end
    end
  end

  def three_sixty_survey_answer_field(survey_question, survey_answer, question)
    case question.question_type
    when ThreeSixty::Question::Type::RATING
      three_sixty_survey_rating_answer_field(survey_question, survey_answer)
    when ThreeSixty::Question::Type::TEXT
      three_sixty_survey_text_answer_field(survey_question, survey_answer)
    end
  end

  def three_sixty_survey_rating_answer_field(survey_question, survey_answer)
    content = get_safe_string
    (1..5).each do |value|
      content +=  content_tag(:label, :for => "three_sixty_survey_question_#{survey_question.id}_#{value}", :class => "col-xs-20 btn btn-white three-sixty-survey-from-rating #{survey_answer.try(:answer_value) == value ? "active" : ""}") do
        radio_button_tag("three_sixty_survey_answers[#{survey_question.id}]", value, survey_answer.try(:answer_value) == value, :id => "three_sixty_survey_question_#{survey_question.id}_#{value}", :class => (survey_answer.try(:answer_value) == value) ? "cjs_three_sixty_input_checked" : "") +
        content_tag(:span, value)
      end
    end
    content_tag(:div, :class => "three-sixty-survey-from btn-group col-xs-12 no-padding", "data-toggle" => "buttons") do
      content
    end
  end

  def three_sixty_survey_text_answer_field(survey_question, survey_answer)
    content_tag(:div, :class => "three-sixty-survey-from") do
      text_area_tag("three_sixty_survey_answers[#{survey_question.id}]", survey_answer.try(:answer_text), :id => "three_sixty_survey_question_#{survey_question.id}", class: "form-control") +
      content_tag(:label, survey_question.question.title, :for => "three_sixty_survey_question_#{survey_question.id}", class: "sr-only")
    end
  end

  def three_sixty_survey_assessees_sorting_and_pagination(sort_param, sort_order, published = true)
    if published
      columns = ["participant", "title", "issued", "expires", "responses"]
    else
      columns = ["title", "participants", "created"]
    end
    header_th = get_safe_string
    class_name = "cjs_sortable_element"
    columns.each do |column|
      header_td = {}
      if column != "participants" && column !="responses"
        key = "#{column}"
        order = sort_param == key ? sort_order : "both"
        sort_options = {
          :class => "sort_#{order} pointer #{class_name}",
          :id => "sort_by_#{key}",
          :data => {
            :sort_param => key,
            :url => dashboard_three_sixty_surveys_path(:format => :js),
            :published => published
          }
        }
        header_td.merge!(sort_options)
      end
      if published
        header_th += content_tag(:th,  "feature.three_sixty.dashboard.assessees.#{column}".translate, header_td)
      else
        header_th += content_tag(:th,  "feature.three_sixty.dashboard.surveys.#{column}".translate, header_td)
      end

    end
    header_th
  end

  def three_sixty_survey_download_link(survey, survey_assessee)
     survey_response_count = survey_assessee.reviewers.select{ |r| r.answered? }.size
     if survey_response_count > 0
        link_to(get_icon_content("fa fa-download") + "feature.three_sixty.dashboard.assessees.download".translate,  survey_report_three_sixty_survey_assessee_path(survey, survey_assessee, { :format => :pdf }),  :method => :get, :class => "pull-right btn btn-xs btn-white")
     else
        content_tag(:div, :class => 'pull-right text-muted btn btn-xs btn-white') do
          get_icon_content("fa fa-download") + "feature.three_sixty.dashboard.assessees.download".translate
        end
     end
  end

  def three_sixty_survey_assessee_heading(survey_assessee)
    assessee = survey_assessee.assessee
    content_tag(:span, get_icon_content('fa fa-user'), :class => "pull-left cui-three-sixty-icon") +
    content_tag(:span, :class => "text-center m-r-xs") do
      link_to_user(assessee, :content_text => assessee.name(:name_only => true), :class => "text-default")
    end +
    content_tag(:span, :class => "m-r-xs m-t-xxs pull-right") do
      link_to(get_icon_content("text-default fa fa-trash m-t-xxs") + set_screen_reader_only_content("display_string.Delete".translate), three_sixty_survey_assessee_path(survey_assessee.survey, survey_assessee), :remote => true, :method => :delete, :class => "", data: { :confirm => "feature.three_sixty.assessee.delete_warning_v1".translate} )
    end
  end

  def three_sixty_survey_assessee_heading_show(survey, survey_assessee)
    assessee = survey_assessee.assessee
    content_tag(:span, get_icon_content('fa fa-user'), :class => "pull-left cui-three-sixty-icon") +
    content_tag(:span, :class => "pull-left") do
      link_to_user(assessee, :content_text => assessee.name(:name_only => true), :class => "text-default")
    end +
    content_tag(:div, :class => "pull-right m-t-n-xs") do
      content_tag(:span, :class => "cjs_three_sixty_actions") do
        link_to(get_icon_content("fa fa-trash") + "display_string.Delete".translate, destroy_published_three_sixty_survey_assessee_path(survey, survey_assessee, { :view => ThreeSixty::Survey::SURVEY_SHOW }), :remote => true, :method => :delete, data: {:confirm => "feature.three_sixty.assessee.delete_published_warning".translate}, :class => "btn btn-white btn-xs")
      end +
      content_tag(:span, :class => "cjs_three_sixty_actions") do
        link_to(get_icon_content("fa fa-plus") + "feature.three_sixty.reviewer.add_reviewers".translate, add_reviewers_three_sixty_survey_assessee_path(survey, survey_assessee, :view => ThreeSixty::Survey::SURVEY_SHOW), :class => "btn btn-white btn-xs") if survey.only_admin_can_add_reviewers? && survey.not_expired?
      end +
      content_tag(:span, :class => "") do
        three_sixty_survey_download_link(survey, survey_assessee)
      end
    end
  end

  def three_sixty_survey_reviewer_heading(survey_assessee)
    content_tag(:div, :class => "clearfix m-b-xs") do
      content_tag(:span, get_icon_content("fa fa-user") + "feature.three_sixty.reviewer.reviewers".translate, :class => "no-margins pull-left font-bold") +
      content_tag(:span, "(#{"feature.three_sixty.survey.n_answered_reviewers_out_of_total_reviewers".translate(:count => survey_assessee.reviewers.select{ |r| r.answered? }.size, :total_count => survey_assessee.reviewers.size)})", :class => "small pull-left text-muted m-t-xxs m-l-sm")
    end
  end

end
