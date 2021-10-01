require_relative './../../test_helper.rb'

class QaAnswersHelperTest < ActionView::TestCase
  include FlagsHelper

  def test_get_actions_for_qa_answer
    self.expects(:current_program).at_least(0).returns(programs(:albers))
    qa_answer = qa_answers(:for_question_what)
    assert_equal users(:f_student), qa_answer.user

    delete_action = {:label=>"<i class=\"fa fa-trash fa-fw m-r-xs\"></i>Delete", :url=>"/qa_questions/#{qa_answer.qa_question_id}/qa_answers/#{qa_answer.id}.js", :method=>:delete, :data=>{:confirm=>"Are you sure you want to delete this answer?", :remote=>true}}
    flag_action = {:label=>"<i class=\"fa fa-flag  fa-fw m-r-xs\"></i><span class=\"\">Report Content</span>", :js=>"jQueryShowQtip('#centered_content', 600, '/flags/new?content_id=#{qa_answer.id}&content_type=QaAnswer', '', {draggable: true , modal: true});", :class=>"cjs_grey_flag "}

    @current_user = users(:f_student) # answerer
    assert_equal [delete_action], get_actions_for_qa_answer(qa_answer)

    @current_user = users(:f_mentor) # non-admin user
    assert_equal [flag_action], get_actions_for_qa_answer(qa_answer)

    @current_user = users(:f_admin) # admin
    assert_equal [flag_action, delete_action], get_actions_for_qa_answer(qa_answer)
  end

  def test_qa_answer_html_id
    qa_answer = qa_answers(:for_question_what)
    assert_equal "qa_answer_#{qa_answer.id}", qa_answer_html_id(qa_answer)
  end

  def test_get_like_button_container
    qa_answer = qa_answers(:for_question_what)
    assert_equal users(:f_student), qa_answer.user
    qa_answer.update_attribute(:score, 1)
    qa_answer.toggle_helpful!(users(:f_mentor))
    assert qa_answer.helpful?(users(:f_mentor))

    @current_user = users(:f_mentor)
    content = get_like_button_container(qa_answer)
    assert_match /a class=\"btn.*btn-primary\".*data-replace-content=\".*fa fa-thumbs-up.*1/, content
    assert_match /i class=\"fa fa-thumbs-up.*2/, content
    assert_match /data-url=\"\/qa_questions\/#{qa_answer.qa_question_id}\/qa_answers\/#{qa_answer.id}\/helpful.js\"/, content
  end

  def test_get_toggle_contents_for_like_following_button
    contents = get_toggle_contents_for_like_following_button(1, true, label_key: "feature.question_answers.content.n_like", label_icon: "fa fa-thumbs-up")
    assert_match /i class=\"fa fa-thumbs-up.*1.*Like/, contents[:active]
    assert_no_match(/0/, contents[:inactive])
    assert_match /i class=\"fa fa-thumbs-up.*Like/, contents[:inactive]

    contents = get_toggle_contents_for_like_following_button(0, false, label_key: "feature.question_answers.content.n_like", label_icon: "fa fa-thumbs-up")
    assert_match /i class=\"fa fa-thumbs-up.*1.*Like/, contents[:active]
    assert_no_match(/0/, contents[:inactive])
    assert_match /i class=\"fa fa-thumbs-up.*Like/, contents[:inactive]

    contents = get_toggle_contents_for_like_following_button(0, false, show_zero: true, label_key: "feature.question_answers.content.n_like", label_icon: "fa fa-thumbs-up")
    assert_match(/0/, contents[:inactive])
  end
end