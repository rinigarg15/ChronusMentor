require_relative './../../../test_helper.rb'
class ThreeSixty::SurveysHelperTest < ActionView::TestCase
  def test_three_sixty_survey_show_view_bar_content
    html_content = to_html(three_sixty_survey_show_view_bar_content("some text", "some-class"))
    assert_select html_content, "div.parallelogram.some-class" do
      assert_select "p", :text => "some text"
    end
  end

  def test_three_sixty_survey_get_view_bar_tabs
    org = programs(:org_primary)
    survey = org.three_sixty_surveys.new
    assert_nil survey.id

    survey_view = ThreeSixty::Survey::View::SETTINGS
    tabs = {0 => {
      :label => label_hash_without_links[ThreeSixty::Survey::View::SETTINGS],
      :url => "javascript:void(0)",
      :class => ""
    },1 => {
      :label => label_hash_without_links[ThreeSixty::Survey::View::QUESTIONS],
      :url => "javascript:void(0)",
      :class => "disabled"
    },2 => {
      :label => label_hash_without_links[ThreeSixty::Survey::View::PREVIEW],
      :url => "javascript:void(0)",
      :class => "disabled"
    },3 => {
      :label => label_hash_without_links[ThreeSixty::Survey::View::ASSESSEES],
      :url => "javascript:void(0)",
      :class => "disabled"
    }}
    assert_equal tabs, three_sixty_survey_get_view_bar_tabs(survey_view, survey)


    survey_view = ThreeSixty::Survey::View::PREVIEW
    tabs = {0 => {
      :label => label_hash_without_links[ThreeSixty::Survey::View::SETTINGS],
      :url => "javascript:void(0)",
      :class => ""
    },1 => {
      :label => label_hash_without_links[ThreeSixty::Survey::View::QUESTIONS],
      :url => "javascript:void(0)",
      :class => ""
    },2 => {
      :label => label_hash_without_links[ThreeSixty::Survey::View::PREVIEW],
      :url => "javascript:void(0)",
      :class => ""
    },3 => {
      :label => label_hash_without_links[ThreeSixty::Survey::View::ASSESSEES],
      :url => "javascript:void(0)",
      :class => "disabled"
    }}
    assert_equal tabs, three_sixty_survey_get_view_bar_tabs(survey_view, survey)

    survey = three_sixty_surveys(:survey_2)
    assert_equal "drafted", survey.state
    survey.competencies.destroy_all
    assert_false survey.competencies.present?
    survey_view = ThreeSixty::Survey::View::SETTINGS
    tabs = {0 => {
      :label => label_hash_without_links[ThreeSixty::Survey::View::SETTINGS],
      :url => edit_three_sixty_survey_path(survey),
      :class => ""
    },1 => {
      :label => label_hash_without_links[ThreeSixty::Survey::View::QUESTIONS],
      :url => "javascript:void(0)",
      :class => "disabled"
    },2 => {
      :label => label_hash_without_links[ThreeSixty::Survey::View::PREVIEW],
      :url => "javascript:void(0)",
      :class => "disabled"
    },3 => {
      :label => label_hash_without_links[ThreeSixty::Survey::View::ASSESSEES],
      :url => "javascript:void(0)",
      :class => "disabled"
    }}
    assert_equal tabs, three_sixty_survey_get_view_bar_tabs(survey_view, survey)


    survey = three_sixty_surveys(:survey_1)
    assert_equal "drafted", survey.state
    assert_not_nil survey.competencies
    survey_view = ThreeSixty::Survey::View::PREVIEW
    tabs = {0 => {
      :label => label_hash_without_links[ThreeSixty::Survey::View::SETTINGS],
      :url => edit_three_sixty_survey_path(survey),
      :class => ""
    },1 => {
      :label => label_hash_without_links[ThreeSixty::Survey::View::QUESTIONS],
      :url => add_questions_three_sixty_survey_path(survey),
      :class => ""
    },2 => {
      :label => label_hash_without_links[ThreeSixty::Survey::View::PREVIEW],
      :url => preview_three_sixty_survey_path(survey),
      :class => ""
    },3 => {
      :label => label_hash_without_links[ThreeSixty::Survey::View::ASSESSEES],
      :url => add_assessees_three_sixty_survey_path(survey),
      :class => ""
    }}
    assert_equal tabs, three_sixty_survey_get_view_bar_tabs(survey_view, survey)
  end

  def test_three_sixty_survey_show_view_bar
    org = programs(:org_primary)
    survey = org.three_sixty_surveys.new
    assert_nil survey.id

    assert_match  /ul.*nav.*nav-tabs/, three_sixty_survey_show_view_bar(ThreeSixty::Survey::View::SETTINGS, survey){ content_tag(:span, "")}
  end

  def test_set_three_sixty_survey_show_label_with_link
    survey = three_sixty_surveys(:survey_2)
    assert_equal "drafted", survey.state
    assert_not_nil survey.competencies
    survey.update_attribute(:expiry_date, 2.days.from_now)
    content = set_three_sixty_survey_show_url(ThreeSixty::Survey::View::SETTINGS, survey)
    url = edit_three_sixty_survey_path(survey)
    assert_equal url, content

    content = set_three_sixty_survey_show_url(ThreeSixty::Survey::View::QUESTIONS, survey)
    url = add_questions_three_sixty_survey_path(survey)
    assert_equal url, content

    content = set_three_sixty_survey_show_url(ThreeSixty::Survey::View::PREVIEW, survey)
    url = preview_three_sixty_survey_path(survey)
    assert_equal url, content

    content = set_three_sixty_survey_show_url(ThreeSixty::Survey::View::ASSESSEES, survey)
    url = add_assessees_three_sixty_survey_path(survey)
    assert_equal url, content

    survey.update_attribute(:expiry_date, 2.days.ago)
    content = set_three_sixty_survey_show_url(ThreeSixty::Survey::View::QUESTIONS, survey)
    assert_equal "javascript:void(0)", content

    survey.update_attribute(:expiry_date, 2.days.from_now)
    survey.reviewer_groups.excluding_self_type.destroy_all

    content = set_three_sixty_survey_show_url(ThreeSixty::Survey::View::QUESTIONS, survey)
    url = add_assessees_three_sixty_survey_path(survey)
    assert_equal "javascript:void(0)", content

    content = set_three_sixty_survey_show_url(ThreeSixty::Survey::View::PREVIEW, survey)
    assert_equal "javascript:void(0)", content
  end

  def test_set_three_sixty_survey_show_label_without_link
    org = programs(:org_primary)
    assert_match "feature.three_sixty.survey.top_bar.survey_settings".translate.capitalize, label_hash_without_links[ThreeSixty::Survey::View::SETTINGS]
    assert_match "feature.three_sixty.survey.top_bar.define_questions".translate.capitalize, label_hash_without_links[ThreeSixty::Survey::View::QUESTIONS]
    assert_match "feature.three_sixty.survey.top_bar.preview".translate.capitalize, label_hash_without_links[ThreeSixty::Survey::View::PREVIEW]
    assert_match "feature.three_sixty.survey.top_bar.choose_participants_v1".translate.capitalize, label_hash_without_links[ThreeSixty::Survey::View::ASSESSEES]
  end

  def test_three_sixty_survey_reviewer_group_options
    assert three_sixty_survey_reviewer_group_options([]).empty?
    options = three_sixty_survey_reviewer_group_options(three_sixty_surveys(:survey_1).survey_reviewer_groups)
    assert_equal 3, options.size
    assert_equal ["Peer", 2], options.first
  end

  def test_three_sixty_name_and_email
    assert_equal "some <text>", three_sixty_name_and_email("some", "text")
  end

  def test_three_sixty_name_email_and_reviewer_group
    self.stubs(:three_sixty_name_and_email).at_least(1).returns("some text")
    assert_equal "some text, c", three_sixty_name_email_and_reviewer_group("a", "b", "c")
  end

  def test_three_sixty_survey_rating_instruction
    self.stubs(:render).with(:partial => "three_sixty/survey/rating_instruction").at_least(1)
    html_content = three_sixty_survey_rating_instruction(members(:f_student), true)
    set_response_text(html_content)
    assert_select "div.well.clearfix" do
      assert_select "div.col-md-6", :text => "Based on the following scale, please assess yourself on the competencies below. This will help identify and prioritize where you should seek to develop", :count => 1
    end

    self.stubs(:render).with(:partial => "three_sixty/survey/rating_instruction").at_least(1)
    html_content = three_sixty_survey_rating_instruction(members(:f_student), false)
    set_response_text(html_content)
    assert_select "div.well.clearfix" do
      assert_select "div.col-md-6", :text => "Based on the following scale, please assess student example on the competencies below. This will help identify and prioritize where student example should seek to develop", :count => 1
    end
  end

  def test_three_sixty_survey_answer_field
    self.stubs(:three_sixty_survey_rating_answer_field).at_least(1).returns("rating type")
    self.stubs(:three_sixty_survey_text_answer_field).at_least(1).returns("text type")
    assert_equal "rating type", three_sixty_survey_answer_field(nil, nil, three_sixty_questions(:leadership_1))
    assert_equal "text type", three_sixty_survey_answer_field(nil, nil, three_sixty_questions(:team_work_1))
  end

  def test_three_sixty_survey_rating_answer_field
    html_content = to_html(three_sixty_survey_rating_answer_field(three_sixty_survey_questions(:three_sixty_survey_questions_1), nil))
    assert_select html_content, "div.three-sixty-survey-from" do
      assert_select "input[type=radio]", :count => 5
      assert_select "label.three-sixty-survey-from-rating", :count => 5
      assert_select "input[type=radio][value='1']"
      assert_no_select "input[type=radio][checked=checked]"
    end

    html_content = to_html(three_sixty_survey_rating_answer_field(three_sixty_survey_questions(:three_sixty_survey_questions_1), three_sixty_survey_answers(:answer_1)))
    assert_select html_content, "div.three-sixty-survey-from" do
      assert_select "input[type=radio]", :count => 5
      assert_select "label.three-sixty-survey-from-rating", :count => 5
      assert_select "input[type=radio][value='5'][checked=checked]"
    end
  end

  def test_three_sixty_survey_text_answer_field
    html_content = to_html(three_sixty_survey_text_answer_field(three_sixty_survey_questions(:three_sixty_survey_questions_1), three_sixty_survey_answers(:answer_2)))
    assert_select html_content, "div.three-sixty-survey-from" do
      assert_select "textarea#three_sixty_survey_question_1", :text => three_sixty_survey_answers(:answer_2).answer_text, :count => 1
      assert_select "label", :count => 1
    end
  end

  def test_three_sixty_survey_download_link
    # if response count is > 0
    survey_assessee = three_sixty_survey_assessees(:three_sixty_survey_assessees_1)
    survey = survey_assessee.survey
    html_content = to_html(three_sixty_survey_download_link(survey, survey_assessee))

    assert_match /href=.*survey_report.pdf.*/, html_content.to_s

    # if response count is 0
    survey_assessee = three_sixty_survey_assessees(:three_sixty_survey_assessees_2)
    survey = survey_assessee.survey
    html_content = to_html(three_sixty_survey_download_link(survey, survey_assessee))

    assert_no_match /href=.*survey_report.pdf.*/, html_content.to_s
  end

  def test_three_sixty_survey_assessee_heading_show
    survey_assessee = three_sixty_survey_assessees(:three_sixty_survey_assessees_1)
    survey = survey_assessee.survey
    self.stubs(:three_sixty_survey_download_link).with(survey, survey_assessee).at_least(3).returns("The Download Link Stub")
    html_content_1 = to_html(three_sixty_survey_assessee_heading_show(survey, survey_assessee))

    assert survey.not_expired?
    assert_false survey.only_admin_can_add_reviewers?

    assert_select html_content_1, "span.cui-three-sixty-icon"
    assert_select html_content_1, "span" do
      assert_select "a[href=?]", member_path(survey_assessee.assessee), :text => survey_assessee.assessee.name(:name_only => true)
    end
    assert_select html_content_1, "span.cjs_three_sixty_actions" do
      assert_select "a[href=?]", destroy_published_three_sixty_survey_assessee_path(survey, survey_assessee, {:view => ThreeSixty::Survey::SURVEY_SHOW})
    end
    assert_select html_content_1, "span.cjs_three_sixty_actions" do
      assert_select "a[href=?]", add_reviewers_three_sixty_survey_assessee_path(survey, survey_assessee, :view => ThreeSixty::Survey::SURVEY_SHOW), :text => "Add Reviewers", :count => 0
    end
    assert_select html_content_1, "span", :text => "The Download Link Stub"

    survey.update_attribute(:reviewers_addition_type, ThreeSixty::Survey::ReviewersAdditionType::ADMIN_ONLY)
    html_content_2 = to_html(three_sixty_survey_assessee_heading_show(survey.reload, survey_assessee))
    assert_select html_content_2, "span.cjs_three_sixty_actions" do
      assert_select "a[href=?]", add_reviewers_three_sixty_survey_assessee_path(survey, survey_assessee, :view => ThreeSixty::Survey::SURVEY_SHOW), :text => "Add Reviewers", :count => 1
    end

    survey.update_attribute(:expiry_date, 3.days.ago.to_date)
    html_content_3 = to_html(three_sixty_survey_assessee_heading_show(survey.reload, survey_assessee))
    assert_select html_content_3, "span.cjs_three_sixty_actions" do
      assert_select "a[href=?]", add_reviewers_three_sixty_survey_assessee_path(survey, survey_assessee, :view => ThreeSixty::Survey::SURVEY_SHOW), :text => "Add Reviewers", :count => 0
    end
  end
end
