require_relative './../test_helper.rb'

class AbstractBulkMatchTest < ActiveSupport::TestCase

  def test_valid_bulk_match_types
    assert_equal [BulkMatch.name, BulkRecommendation.name], AbstractBulkMatch.valid_bulk_match_types
  end

  def test_validations
    abstract_bulk_match = AbstractBulkMatch.new
    assert !abstract_bulk_match.valid?    
    assert_equal(["can't be blank"], abstract_bulk_match.errors[:program])
    assert_equal(["can't be blank"], abstract_bulk_match.errors[:mentor_view])
    assert_equal(["can't be blank"], abstract_bulk_match.errors[:mentee_view])
  end

  def test_uniqueness_validations
    program = programs(:albers)
    bulk_match = bulk_matches(:bulk_match_1)
    duplicate_bulk_match = bulk_match.dup
    assert_false duplicate_bulk_match.valid?
    assert_equal(["has already been taken"], duplicate_bulk_match.errors[:program_id])
    duplicate_bulk_match.orientation_type = BulkMatch::OrientationType::MENTOR_TO_MENTEE
    program.mentor_bulk_match.destroy
    assert duplicate_bulk_match.valid?

    bulk_recommendation = bulk_matches(:bulk_recommendation_1)
    duplicate_bulk_recom = bulk_recommendation.dup
    assert_false duplicate_bulk_recom.valid?
    assert_equal(["has already been taken"], duplicate_bulk_recom.errors[:program_id])
  end

  def test_associations
    program = programs(:albers)

    mentor_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS)
    mentee_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTEES)

    abstract_bulk_match = bulk_matches(:bulk_match_1)
    abstract_bulk_match.update_attributes!(mentor_view_id: mentor_view.id, mentee_view_id: mentee_view.id)

    assert_equal program, abstract_bulk_match.program
    assert_equal mentor_view, abstract_bulk_match.mentor_view
    assert_equal mentee_view, abstract_bulk_match.mentee_view
  end

  def test_get_globalized_answer
    abstract_bulk_match = AbstractBulkMatch.new

    question = profile_questions(:student_multi_choice_q)
    answer = ProfileAnswer.new(:profile_question => question, :ref_obj => members(:f_student))
    answer.answer_value = ["Stand", "Walk"]
    answer.save!

    assert_equal "Stand, Walk", abstract_bulk_match.send(:get_globalized_answer, {question.id => answer}, question.id)

    run_in_another_locale(:'fr-CA') do
      assert_equal "Supporter, Marcher", abstract_bulk_match.send(:get_globalized_answer, {question.id => answer}, question.id)
    end

    answer.answer_value = nil
    answer.save!
    assert_equal "", abstract_bulk_match.send(:get_globalized_answer, {question.id => answer}, question.id)    
  end

  def test_update_bulk_entry
    program = programs(:ceg)
    mentor_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS_WITH_LOW_PROFILE_SCORES)
    mentee_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTEES_WITH_LOW_PROFILE_SCORES)
    bulk_entry = BulkMatch.new(program: program)
    bulk_entry.update_bulk_entry(mentor_view.id, mentee_view.id)
    bulk_entry.reload

    assert_equal program.default_max_connections_limit, bulk_entry.max_pickable_slots
    assert_nil bulk_entry.max_suggestion_count
    assert bulk_entry.request_notes
    assert_equal mentor_view, bulk_entry.mentor_view
    assert_equal mentee_view, bulk_entry.mentee_view

    bulk_entry = BulkMatch.new(program: program, orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE)
    bulk_entry.update_bulk_entry(mentor_view.id, mentee_view.id)
    bulk_entry.reload

    assert_equal 1, bulk_entry.max_pickable_slots
    assert_nil bulk_entry.max_suggestion_count
    assert bulk_entry.request_notes
    assert_equal mentor_view, bulk_entry.mentor_view
    assert_equal mentee_view, bulk_entry.mentee_view

    bulk_entry = BulkRecommendation.new(program: program)
    bulk_entry.update_bulk_entry(mentor_view.id, mentee_view.id)
    bulk_entry.reload

    assert_equal program.default_max_connections_limit, bulk_entry.max_pickable_slots
    assert_equal 1, bulk_entry.max_suggestion_count
    assert_false bulk_entry.request_notes
    assert_equal mentor_view, bulk_entry.mentor_view
    assert_equal mentee_view, bulk_entry.mentee_view

    program = programs(:albers)
    current_mentor_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS)
    current_mentee_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTEES)
    updated_mentor_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS_WITH_LOW_PROFILE_SCORES)
    updated_mentee_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTEES_WITH_LOW_PROFILE_SCORES)

    bulk_entry = bulk_matches(:bulk_match_1)
    assert_equal current_mentor_view, bulk_entry.mentor_view
    assert_equal current_mentee_view, bulk_entry.mentee_view
    bulk_entry.update_bulk_entry(updated_mentor_view.id, updated_mentee_view.id)
    bulk_entry.reload

    assert_equal updated_mentor_view, bulk_entry.mentor_view
    assert_equal updated_mentee_view, bulk_entry.mentee_view

    bulk_entry = bulk_matches(:bulk_match_2)
    assert_equal current_mentor_view, bulk_entry.mentor_view
    assert_equal current_mentee_view, bulk_entry.mentee_view
    bulk_entry.update_bulk_entry(updated_mentor_view.id, updated_mentee_view.id)
    bulk_entry.reload

    assert_equal updated_mentor_view, bulk_entry.mentor_view
    assert_equal updated_mentee_view, bulk_entry.mentee_view
  end

  def test_get_default_pickable_slots
    program = programs(:ceg)
    bulk_entry = BulkMatch.new(program: program)
    default_slots_count = program.default_max_connections_limit
    assert_equal default_slots_count, bulk_entry.get_default_pickable_slots
    bulk_entry = BulkMatch.new(program: program, orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE)
    assert_equal 1, bulk_entry.get_default_pickable_slots
    bulk_entry = BulkRecommendation.new(program: program)
    assert_equal default_slots_count, bulk_entry.get_default_pickable_slots
  end
end