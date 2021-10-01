require_relative './../../test_helper.rb'

class SetProjectsAndConnectionQuestionAnswersTest < ActiveSupport::TestCase
  include SetProjectsAndConnectionQuestionAnswers

  def test_set_projects_and_connection_question_in_summary_hash
    self.instance_variable_set("@current_user", users(:f_student_pbe))
    User.any_instance.stubs(:available_projects_for_user).returns([[groups(:group_pbe_2), groups(:group_pbe_1), groups(:group_pbe_3), groups(:group_pbe_4)], false])
    self.instance_variable_set("@current_program", programs(:pbe))
    q = Connection::Question.create(:program => programs(:pbe), :question_type => CommonQuestion::Type::STRING, :question_text => "Whats your age?")
    summary_q = Summary.create!(connection_question: q)
    ans = Connection::Answer.create!(
          :question => q,
          :group => groups(:group_pbe_2),
          :answer_text => 'hello')
    set_projects_and_connection_question_in_summary_hash
    assert_equal_hash({groups(:group_pbe_2).id => ans.answer_text}, self.instance_variable_get("@connection_question_answer_in_summary_hash"))
    assert_equal q, self.instance_variable_get("@connection_question")
    assert_equal [groups(:group_pbe_2), groups(:group_pbe_1), groups(:group_pbe_3), groups(:group_pbe_4)], self.instance_variable_get("@projects")
    assert_false self.instance_variable_get("@show_all_projects_option")
  end

  def test_set_projects
    self.instance_variable_set("@current_user", users(:f_student_pbe))
    User.any_instance.stubs(:available_projects_for_user).returns([[groups(:group_pbe_2), groups(:group_pbe_1), groups(:group_pbe_3), groups(:group_pbe_4)], false])
    set_projects
    assert_equal [groups(:group_pbe_2), groups(:group_pbe_1), groups(:group_pbe_3), groups(:group_pbe_4)], self.instance_variable_get("@projects")
    assert_false self.instance_variable_get("@show_all_projects_option")
  end

  def test_set_projects_with_show_all
    self.instance_variable_set("@current_user", users(:f_student_pbe))
    User.any_instance.stubs(:available_projects_for_user).returns([[groups(:group_pbe_2), groups(:group_pbe_1), groups(:group_pbe_3), groups(:group_pbe_4), groups(:group_pbe), groups(:group_pbe_0)], true])
    set_projects
    assert_equal [groups(:group_pbe_2), groups(:group_pbe_1), groups(:group_pbe_3), groups(:group_pbe_4), groups(:group_pbe)], self.instance_variable_get("@projects")
    assert self.instance_variable_get("@show_all_projects_option")
  end

  def test_set_connection_question_and_answers_hash_empty_hash
    self.instance_variable_set("@current_program", programs(:pbe))
    self.instance_variable_set("@projects", [groups(:group_pbe_2), groups(:group_pbe_1), groups(:group_pbe_3), groups(:group_pbe_4)])
    q = Connection::Question.create(:program => programs(:pbe), :question_type => CommonQuestion::Type::STRING, :question_text => "Whats your age?")
    summary_q = Summary.create!(connection_question: q)

    set_connection_question_and_answers_hash
    assert_equal_hash({}, self.instance_variable_get("@connection_question_answer_in_summary_hash"))
    assert_equal q, self.instance_variable_get("@connection_question")
  end 

  def test_set_connection_question_and_answers_hash
    self.instance_variable_set("@current_program", programs(:pbe))
    self.instance_variable_set("@projects", [groups(:group_pbe_2), groups(:group_pbe_1), groups(:group_pbe_3), groups(:group_pbe_4)])
    q = Connection::Question.create(:program => programs(:pbe), :question_type => CommonQuestion::Type::STRING, :question_text => "Whats your age?")
    summary_q = Summary.create!(connection_question: q)
    ans = Connection::Answer.create!(
          :question => q,
          :group => groups(:group_pbe_2),
          :answer_text => 'hello')

    set_connection_question_and_answers_hash
    assert_equal_hash({groups(:group_pbe_2).id => ans.answer_text}, self.instance_variable_get("@connection_question_answer_in_summary_hash"))
    assert_equal q, self.instance_variable_get("@connection_question")
  end 
end