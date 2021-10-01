require_relative './../../test_helper.rb'

class Connection::QuestionTest < ActiveSupport::TestCase

  def test_create_success
    assert_difference "Connection::Question.count" do
      Connection::Question.create(:program => programs(:albers), :question_type => CommonQuestion::Type::STRING, :question_text => "Whats your age?")
    end
  end

  def test_has_answers
    assert_equal [common_answers(:one_connection)], common_questions(:string_connection_q).answers
  end

  def test_has_one_summary_question
    assert_equal summaries(:string_connection_summary_q), common_questions(:string_connection_q).summary
  end

  def test_has_many_group_view_columns
    question = Connection::Question.create(:program => programs(:albers), :question_type => CommonQuestion::Type::STRING, :question_text => "Whats your age?")
    group_view = programs(:albers).group_view
    assert_blank question.group_view_columns

    group_view_column = GroupViewColumn.create!(:group_view => group_view, :connection_question => question, :position => 3, :ref_obj_type => GroupViewColumn::ColumnType::GROUP)

    question = question.reload
    assert_equal [group_view_column], question.group_view_columns
  end

  def test_get_viewable_or_updatable_questions
    program = programs(:albers)
    program.enable_feature(FeatureName::CONNECTION_PROFILE)
    question = Connection::Question.create(:program => program, :question_type => CommonQuestion::Type::STRING, :question_text => "Whats your age?")
    question_a = Connection::Question.create(:program => program, :question_type => CommonQuestion::Type::STRING, :question_text => "Whats your age?", :is_admin_only => true)

    assert       Connection::Question.get_viewable_or_updatable_questions(program, false).include? question
    assert_false Connection::Question.get_viewable_or_updatable_questions(program, false).include? question_a
    assert       Connection::Question.get_viewable_or_updatable_questions(program, true).include? question
    assert       Connection::Question.get_viewable_or_updatable_questions(program, true).include? question_a


    program.enable_feature(FeatureName::CONNECTION_PROFILE, false)
    assert_blank Connection::Question.get_viewable_or_updatable_questions(program, false)
  end

  def test_positioning
    program = programs(:albers)
    existing_questions = program.connection_questions.to_a
    assert_equal (1..4).to_a, existing_questions.collect(&:position)
    new_question = Connection::Question.create(program: program, question_type: CommonQuestion::Type::STRING, question_text: "Albers New Question!?", position: 1)
    assert_equal (2..5).to_a, existing_questions.collect(&:reload).collect(&:position)

    program_2 = programs(:nwen)
    new_question_2 = Connection::Question.create(program: program_2, question_type: CommonQuestion::Type::STRING, question_text: "Nwen New Question!?", position: 1)
    assert_equal 1, new_question_2.position
    assert_equal 1, new_question.reload.position
    assert_equal (2..5).to_a, existing_questions.collect(&:reload).collect(&:position)
  end
end