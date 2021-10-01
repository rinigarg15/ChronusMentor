module ThreeSixty::CompetenciesHelper
  def display_three_sixty_competency_description(competency)
    tooltip("competency_heading_title_#{competency.id}", competency.description) if competency.description.present?
  end

  def three_sixty_competency_heading_for_listing(competency, show_actions)
    content = content_tag(:big, get_safe_string + competency.title + display_three_sixty_competency_description(competency), :class => "font-bold", :id => "competency_heading_title_#{competency.id}")
    if show_actions
      content += content_tag(:div,:class => "pull-right") do
        link_to(get_icon_content("m-t-xxs text-default fa fa-pencil m-r-sm") + set_screen_reader_only_content("display_string.Edit".translate), "#", :id => "edit_competency_link_#{competency.id}", :data => { :url=> edit_three_sixty_competency_path(competency), :size => 600 }, :class => "remote-popup-link m-t-xxs") +
        link_to(get_icon_content("m-t-xxs text-default fa fa-trash") + set_screen_reader_only_content("display_string.Delete".translate), three_sixty_competency_path(competency), :remote => true, :method => :delete, :class => "m-t-xxs", data: {:confirm => "feature.three_sixty.competency.delete_warning".translate})
      end
    end

    content_tag(:div, :id => "competency_heading_for_listing_#{competency.id}") do
      content
    end
  end

  def add_new_three_sixty_competency_questions(competency)
    content_tag(:div, :class => "m-t well well-sm", :id => "add_new_three_sixty_competency_container_#{competency.id}") do
      display_three_sixty_question_new_inline(competency.questions.new, competency)
    end
  end

  def display_three_sixty_question_new_inline(question, competency, for_new=true)
    content = get_safe_string
    url = for_new ? three_sixty_questions_path(:format => :js) : three_sixty_question_path(question, :format => :js)
    method = for_new ? :post : :patch
    style = for_new ? "display:none" : ""
    simple_form_for question, :url => url, :method => method, :remote => true, :html => { :class => "no-margin-bottom cjs_new_three_sixty_object cui_three_sixty_inline_question", :id => "new_three_sixty_question_#{competency.id}_#{question.id}"} do |f|
      content_tag(:div, :class => "clearfix") do
        content += content_tag(:div, :class => "col-md-7") do
          content_tag(:label, "title", :for => "three_sixty_question_title_#{competency.id}_#{question.id}", class: "sr-only") +
          f.input(:title, :as => :string, :input_html => {:id => "three_sixty_question_title_#{competency.id}_#{question.id}", :class => "col-md-12 form-control", :placeholder => "feature.three_sixty.question.add".translate}, :label => false)
        end
        content += content_tag(:div, :class => "col-md-2") do
          content_tag(:label, "type", :for => "three_sixty_question_type_#{competency.id}_#{question.id}", class: "sr-only") +
          f.select("question_type", options_for_select([[ThreeSixty::Question.question_type_as_string(ThreeSixty::Question::Type::RATING), ThreeSixty::Question::Type::RATING], [ThreeSixty::Question.question_type_as_string(ThreeSixty::Question::Type::TEXT), ThreeSixty::Question::Type::TEXT]], :selected => question.question_type), {}, :class => 'form-control form-control', :disabled => !for_new, :id => "three_sixty_question_type_#{competency.id}_#{question.id}")
        end
        content += content_tag(:div, :class => "col-md-3") do
          f.submit("display_string.Save".translate, :class => 'btn btn-primary pull-right', :disable_with => "display_string.Please_Wait".translate)
        end
        content += f.hidden_field :three_sixty_competency_id, value: competency.id, id: nil
        content
      end
    end
  end
end
