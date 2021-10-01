require_relative './../../test_helper.rb'

class BulkMatchUtilsTest < ActiveSupport::TestCase
  include BulkMatchUtils

  def setup
    super
    @s1, @s2 = [users(:f_student), users(:rahim)]
    @s1_id, @s2_id = [users(:f_student).id, users(:rahim).id]
    @m1, @m2 = [users(:f_mentor), users(:robert)]
    @m1_id, @m2_id = [@m1.id, @m2.id]
    programs(:albers).mentor_recommendations.destroy_all
  end

  def test_get_user_ids
    program = programs(:albers)
    admin_view = program.admin_views.default.find_by(default_view: AdminView::DefaultType::ALL_USERS)
    assert_equal_unordered program.mentor_users.active_or_pending.pluck(:id), get_user_ids(admin_view)
    assert_equal_unordered program.mentor_users.active_or_pending.pluck(:id), get_user_ids(admin_view, true)
    assert_equal_unordered program.student_users.active_or_pending.pluck(:id), get_user_ids(admin_view, false)
  end

  def test_compute_matches_for_mentee_to_mentor_view
    init_and_compute_results(BulkMatch.name, 2, 1)

    assert_initializations_and_student_mentor_hash

    # fetch_group_or_recommendation_status
    assert @group_or_recommendation_info.empty?

    # fetch_mentor_available_pickable_slot_hash
    assert_equal_hash({@m1_id => 1, @m2_id => 3}, @mentor_slot_hash)
    assert_equal_hash({@m1_id => 0, @m2_id => 1}, @pickable_slots)
    assert_equal_hash({@m1_id => 1, @m2_id => 1}, @recommended_count)

    # fetch_selected_suggested_mentors
    assert_equal [[@m1_id], [@m2_id]], @selected_mentors.values
    assert_equal [[[@m1_id, 90], [@m2_id, 10]], [[@m1_id, 57], [@m2_id, 26]]], @suggested_mentors.values

    reset_cache_values
  end

  def test_compute_matches_for_mentor_to_mentee_view
    init_and_compute_results(BulkMatch.name, 2, 1, false, BulkMatch::OrientationType::MENTOR_TO_MENTEE)

    assert_initializations_and_mentor_student_hash

    # fetch_group_or_recommendation_status
    assert @group_or_recommendation_info.empty?

    # fetch_mentor_available_pickable_slot_hash
    assert_equal_hash({@m1_id => 1, @m2_id => 3}, @mentor_slot_hash)
    assert_equal_hash({@m1_id => 1, @m2_id => 3}, @pickable_slots)

    # fetch_selected_suggested_mentees
    assert_equal [[@s1_id], [@s2_id]], @selected_mentees.values
    assert_equal [[[@s1_id, 90], [@s2_id, 57]], [[@s2_id, 26], [@s1_id, 10]]], @suggested_mentees.values

    reset_cache_values
  end

  def test_compute_matches_with_drafted_groups
    program = programs(:albers)
    bulk_match = init_and_compute_results(BulkMatch.name, 2, 1, true)
    draft_group = create_group(
      status: Group::Status::DRAFTED,
      student: users(:f_student),
      mentor: @m2,
      bulk_match: bulk_match,
      creator_id: users(:f_admin).id
    )
    reindex_documents(updated: [@m2, users(:f_student)])

    compute_bulk_match_results(program, bulk_match)
    assert_initializations_and_student_mentor_hash

    # fetch_group_or_recommendation_status
    expected_hash = {
      @s1_id => {
        group_id: draft_group.id,
        status: Group::Status::DRAFTED,
        mentor_list: [@m2_id]
      }
    }
    assert_equal_hash(expected_hash, @group_or_recommendation_info)

    # fetch_mentor_available_pickable_slot_hash
    assert_equal_hash( { @m1_id => 1, @m2_id => 2 }, @mentor_slot_hash)
    assert_equal_hash( { @m1_id => 0, @m2_id => 1 }, @pickable_slots)
    assert_equal_hash( { @m1_id => 1, @m2_id => 1 }, @recommended_count)

    # fetch_selected_suggested_mentors
    assert_equal [[@m2_id], [@m1_id]], @selected_mentors.values
    assert_equal [[[@m1_id, 90], [@m2_id, 10]], [[@m1_id, 57], [@m2_id, 26]]], @suggested_mentors.values

    reset_cache_values
  end

  def test_compute_matches_for_mentor_to_mentee_view_with_drafted_groups
    program = programs(:albers)
    bulk_match = init_and_compute_results(BulkMatch.name, 2, 1, true, BulkMatch::OrientationType::MENTOR_TO_MENTEE)
    draft_group = create_group(
      status: Group::Status::DRAFTED,
      student: users(:f_student),
      mentor: @m2,
      bulk_match: bulk_match,
      creator_id: users(:f_admin).id
    )
    reindex_documents(updated: [@m2, users(:f_student)])

    compute_bulk_match_results(program, bulk_match)
    assert_initializations_and_mentor_student_hash

    # fetch_group_or_recommendation_status
    expected_hash = {
      @m2_id => {
        group_id: draft_group.id,
        status: Group::Status::DRAFTED,
        student_list: [@s1_id]
      }
    }
    assert_equal_hash(expected_hash, @group_or_recommendation_info)

    # fetch_mentor_available_pickable_slot_hash
    assert_equal_hash( { @m1_id => 1, @m2_id => 2 }, @mentor_slot_hash)
    assert_equal_hash( { @m1_id => 1, @m2_id => 2 }, @pickable_slots)
    assert_equal_hash( { @s1_id => 0, @s2_id => 2 }, @pickable_slots_for_mentees)

    assert_equal [[@s1_id], [@s1_id]], @selected_mentees.values
    assert_equal [[[@s1_id, 90], [@s2_id, 57]], [[@s2_id, 26], [@s1_id, 10]]], @suggested_mentees.values
    reset_cache_values

    #computing results by reducing the slot limit for mentees
    bulk_match = init_and_compute_results(BulkMatch.name, 1, 1, true, BulkMatch::OrientationType::MENTOR_TO_MENTEE)
    draft_group.destroy
    draft_group = create_group(
      status: Group::Status::DRAFTED,
      student: users(:f_student),
      mentor: @m2,
      bulk_match: bulk_match,
      creator_id: users(:f_admin).id
    )
    reindex_documents(updated: [@m2, users(:f_student)])

    compute_bulk_match_results(program, bulk_match)
    assert_equal_hash( { @m1_id => 1, @m2_id => 2 }, @pickable_slots)
    assert_equal_hash( { @s1_id => 0, @s2_id => 0 }, @pickable_slots_for_mentees)

    assert_equal [[@s2_id], [@s1_id]], @selected_mentees.values
    assert_equal [[[@s1_id, 90], [@s2_id, 57]], [[@s2_id, 26], [@s1_id, 10]]], @suggested_mentees.values
    reset_cache_values
  end

  def test_compute_matches_with_published_groups
    program = programs(:albers)
    bulk_match = init_and_compute_results(BulkMatch.name, 2, 1, true)
    group = create_group(
      student: users(:f_student),
      mentors: [@m1],
      bulk_match: bulk_match,
      creator_id: users(:f_admin).id
    )
    reindex_documents(updated: [@m1, users(:f_student)])

    compute_bulk_match_results(program, bulk_match)
    assert_initializations_and_student_mentor_hash

    # fetch_group_or_recommendation_status
    expected_hash = {
      @s1_id => {
        group_id: group.id,
        status: Group::Status::ACTIVE,
        mentor_list: [@m1_id]
      }
    }
    assert_equal_hash(expected_hash, @group_or_recommendation_info)

    # fetch_mentor_available_pickable_slot_hash
    assert_equal_hash( { @m1_id => 0, @m2_id => 3 }, @mentor_slot_hash)
    assert_equal_hash( { @m1_id => 0, @m2_id => 1 }, @pickable_slots)
    assert_equal_hash( { @m1_id => 1, @m2_id => 1 }, @recommended_count)

    # fetch_selected_suggested_mentors
    assert_equal [[@m1_id], [@m2_id]], @selected_mentors.values
    assert_equal [[[@m1_id, 90], [@m2_id, 10]], [[@m1_id, 57], [@m2_id, 26]]], @suggested_mentors.values

    reset_cache_values
  end

  def test_compute_matches_for_mentor_to_mentee_view_with_published_groups
    program = programs(:albers)
    bulk_match = init_and_compute_results(BulkMatch.name, 2, 1, true, BulkMatch::OrientationType::MENTOR_TO_MENTEE)
    group = create_group(
      student: users(:f_student),
      mentors: [@m1],
      bulk_match: bulk_match,
      creator_id: users(:f_admin).id
    )
    reindex_documents(updated: [@m1, users(:f_student)])

    compute_bulk_match_results(program, bulk_match)
    assert_initializations_and_mentor_student_hash

    # fetch_group_or_recommendation_status
    expected_hash = {
      @m1_id => {
        group_id: group.id,
        status: Group::Status::ACTIVE,
        student_list: [@s1_id]
      }
    }
    assert_equal_hash(expected_hash, @group_or_recommendation_info)

    # fetch_mentor_available_pickable_slot_hash
    assert_equal_hash( { @m1_id => 0, @m2_id => 3 }, @mentor_slot_hash)
    assert_equal_hash( { @m1_id => 0, @m2_id => 3 }, @pickable_slots)
    assert_equal_hash( { @s1_id => 1, @s2_id => 1 }, @pickable_slots_for_mentees)

    assert_equal [[@s1_id], [@s2_id]], @selected_mentees.values
    assert_equal [[[@s1_id, 90], [@s2_id, 57]], [[@s2_id, 26], [@s1_id, 10]]], @suggested_mentees.values

    reset_cache_values
  end

  def test_recommend_mentors
    init_and_compute_results(BulkRecommendation.name, 10)

    assert_initializations_and_student_mentor_hash

    # fetch_group_or_recommendation_status
    assert @group_or_recommendation_info.empty?

    # fetch_mentor_available_pickable_slot_hash
    assert_equal_hash({@m1_id => 1, @m2_id => 3}, @mentor_slot_hash)
    assert_equal_hash({@m1_id => 8, @m2_id => 8}, @pickable_slots)
    assert_equal_hash({@m1_id => 2, @m2_id => 2}, @recommended_count)

    # fetch_selected_suggested_mentors
    assert_equal [[@m1_id, @m2_id], [@m1_id, @m2_id]], @selected_mentors.values
    assert_equal [[[@m1_id, 90], [@m2_id, 10]], [[@m1_id, 57], [@m2_id, 26]]], @suggested_mentors.values

    reset_cache_values
  end

  def test_recommend_mentors_with_max_connections_limit_increased
    @m1.max_connections_limit += 1
    @m1.save!
    reindex_documents(updated: @m1)

    init_and_compute_results(BulkRecommendation.name)

    assert_initializations_and_student_mentor_hash

    # fetch_group_or_recommendation_status
    assert @group_or_recommendation_info.empty?

    # fetch_mentor_available_pickable_slot_hash
    assert_equal_hash({@m1_id => 2, @m2_id => 3}, @mentor_slot_hash)
    assert_equal_hash({@m1_id => 0, @m2_id => 0}, @pickable_slots)
    assert_equal_hash({@m1_id => 2, @m2_id => 2}, @recommended_count)

    # fetch_selected_suggested_mentors
    assert_equal [[@m1_id, @m2_id], [@m1_id, @m2_id]], @selected_mentors.values
    assert_equal [[[@m1_id, 90], [@m2_id, 10]], [[@m1_id, 57], [@m2_id, 26]]], @suggested_mentors.values

    reset_cache_values
  end

  def test_recommend_mentors_with_max_pickable_slots_increased
    init_and_compute_results(BulkRecommendation.name, 3)

    assert_initializations_and_student_mentor_hash

    # fetch_group_or_recommendation_status
    assert @group_or_recommendation_info.empty?

    # fetch_mentor_available_pickable_slot_hash
    assert_equal_hash({@m1_id => 1, @m2_id => 3}, @mentor_slot_hash)
    assert_equal_hash({@m1_id => 1, @m2_id => 1}, @pickable_slots)
    assert_equal_hash({@m1_id => 2, @m2_id => 2}, @recommended_count)

    # fetch_selected_suggested_mentors
    assert_equal [[@m1_id, @m2_id], [@m1_id, @m2_id]], @selected_mentors.values
    assert_equal [[[@m1_id, 90], [@m2_id, 10]], [[@m1_id, 57], [@m2_id, 26]]], @suggested_mentors.values

    reset_cache_values
  end

  def test_recommend_mentors_with_drafted_recommendations
    create_mentor_recommendation_and_preferences(@s1_id, MentorRecommendation::Status::DRAFTED, [@m2_id])

    init_and_compute_results(BulkRecommendation.name, 3)

    assert_initializations_and_student_mentor_hash

    # fetch_group_or_recommendation_status
    expected_hash = {
      @s1_id => {
        :status => MentorRecommendation::Status::DRAFTED,
        :mentor_list => [@m2_id]
      }
    }
    assert_equal_hash(expected_hash, @group_or_recommendation_info)

    # fetch_mentor_available_pickable_slot_hash
    assert_equal_hash({@m1_id => 1, @m2_id => 3}, @mentor_slot_hash)
    assert_equal_hash({@m1_id => 2, @m2_id => 1}, @pickable_slots)
    assert_equal_hash({@m1_id => 1, @m2_id => 2}, @recommended_count)

    # fetch_selected_suggested_mentors
    assert_equal [[@m2_id], [@m1_id, @m2_id]], @selected_mentors.values
    assert_equal [[[@m1_id, 90], [@m2_id, 10]], [[@m1_id, 57], [@m2_id, 26]]], @suggested_mentors.values

    reset_cache_values
  end

  def test_recommend_mentors_with_drafted_recommendations_with_mentor_not_in_current_view
    other_mentor_id = users(:f_mentor_student).id
    create_mentor_recommendation_and_preferences(@s1_id, MentorRecommendation::Status::DRAFTED, [@m2_id, other_mentor_id])

    init_and_compute_results(BulkRecommendation.name, 3)

    assert_initializations_and_student_mentor_hash

    # fetch_group_or_recommendation_status
    expected_hash = {
      @s1_id => {
        :status => MentorRecommendation::Status::DRAFTED,
        :mentor_list => [@m2_id]
      }
    }
    assert_equal_hash(expected_hash, @group_or_recommendation_info)

    # fetch_mentor_available_pickable_slot_hash
    assert_equal_hash({@m1_id => 1, @m2_id => 3}, @mentor_slot_hash)
    assert_equal_hash({@m1_id => 2, @m2_id => 1}, @pickable_slots)
    assert_equal_hash({@m1_id => 1, @m2_id => 2}, @recommended_count)

    # fetch_selected_suggested_mentors
    assert_equal [[@m2_id], [@m1_id, @m2_id]], @selected_mentors.values
    assert_equal [[[@m1_id, 90], [@m2_id, 10]], [[@m1_id, 57], [@m2_id, 26]]], @suggested_mentors.values

    reset_cache_values
  end

  def test_recommend_mentors_with_published_recommendations_with_mentor_not_in_current_view
    other_mentor_id = users(:f_mentor_student).id
    create_mentor_recommendation_and_preferences(@s1_id, MentorRecommendation::Status::PUBLISHED, [@m2_id, other_mentor_id])

    init_and_compute_results(BulkRecommendation.name, 3)

    assert_initializations_and_student_mentor_hash

    # fetch_group_or_recommendation_status
    expected_hash = {
      @s1_id => {
        :status => MentorRecommendation::Status::PUBLISHED,
        :mentor_list => [@m2_id]
      }
    }
    assert_equal_hash(expected_hash, @group_or_recommendation_info)

    # fetch_selected_suggested_mentors
    assert_equal [[@m2_id], [@m1_id, @m2_id]], @selected_mentors.values
    assert_equal [[[@m1_id, 90], [@m2_id, 10]], [[@m1_id, 57], [@m2_id, 26]]], @suggested_mentors.values

    reset_cache_values
  end

  def test_recommend_mentors_with_published_recommendations
    create_mentor_recommendation_and_preferences(@s2_id, MentorRecommendation::Status::PUBLISHED, [@m1_id])

    init_and_compute_results(BulkRecommendation.name, 3)

    assert_initializations_and_student_mentor_hash

    # fetch_group_or_recommendation_status
    expected_hash = {
      @s2_id => {
        :status => MentorRecommendation::Status::PUBLISHED,
        :mentor_list => [@m1_id]
      }
    }
    assert_equal_hash(expected_hash, @group_or_recommendation_info)

    # fetch_mentor_available_pickable_slot_hash
    assert_equal_hash({@m1_id => 1, @m2_id => 3}, @mentor_slot_hash)
    assert_equal_hash({@m1_id => 1, @m2_id => 2}, @pickable_slots)
    assert_equal_hash({@m1_id => 2, @m2_id => 1}, @recommended_count)

    # fetch_selected_suggested_mentors
    assert_equal [[@m1_id, @m2_id], [@m1_id]], @selected_mentors.values
    assert_equal [[[@m1_id, 90], [@m2_id, 10]], [[@m1_id, 57], [@m2_id, 26]]], @suggested_mentors.values

    reset_cache_values
  end

  def test_recommend_mentors_with_max_suggestion_count_changed
    @m1.max_connections_limit += 1
    @m1.save!
    reindex_documents(updated: @m1)

    init_and_compute_results(BulkRecommendation.name, 3, 1)

    assert_initializations_and_student_mentor_hash

    # fetch_group_or_recommendation_status
    assert @group_or_recommendation_info.empty?

    # fetch_mentor_available_pickable_slot_hash
    assert_equal_hash({@m1_id => 2, @m2_id => 3}, @mentor_slot_hash)
    assert_equal_hash({@m1_id => 1, @m2_id => 3}, @pickable_slots)
    assert_equal_hash({@m1_id => 2, @m2_id => 0}, @recommended_count)

    # fetch_selected_suggested_mentors
    assert_equal [[@m1_id], [@m1_id]], @selected_mentors.values
    assert_equal [[[@m1_id, 90], [@m2_id, 10]], [[@m1_id, 57], [@m2_id, 26]]], @suggested_mentors.values

    reset_cache_values
  end

  private

  def assert_initializations_and_student_mentor_hash
    assert_common_match_details
    # compute_student_mentor_hash
    assert_equal [@s1_id, @s2_id], @student_mentor_hash.keys
    assert_equal [[[@m1_id, 90], [@m2_id, 10]], [[@m1_id, 57], [@m2_id, 26]]], @student_mentor_hash.values
  end

  def assert_initializations_and_mentor_student_hash
    assert_common_match_details
    # compute_mentor_student_hash
    assert_equal [@m1_id, @m2_id], @mentor_student_hash.keys
    assert_equal [[[@s1_id, 90], [@s2_id, 57]], [[@s2_id, 26], [@s1_id, 10]]], @mentor_student_hash.values
  end

  def assert_common_match_details
    assert_equal [@m1_id, @m2_id], @mentor_user_ids
    assert_equal [@s1_id, @s2_id], @student_user_ids
    assert_equal_unordered [@m1, @m2], @mentor_users
    assert_equal_unordered [users(:f_student), users(:rahim)], @student_users
    assert_equal_unordered programs(:albers).groups.active, @active_groups
    assert_equal_unordered programs(:albers).groups.drafted, @drafted_groups
  end

  def init_and_compute_results(type, max_pickable_slots = 2, max_suggestion_count = 2, dont_compute = false, orientation_type = BulkMatch::OrientationType::MENTEE_TO_MENTOR)
    AbstractBulkMatch.where(program_id: programs(:albers).id, type: type).destroy_all
    bulk_match = create_bulk_match(type: type, max_pickable_slots: max_pickable_slots, max_suggestion_count: max_suggestion_count, orientation_type: orientation_type)

    mentor_view = bulk_match.mentor_view
    student_view = bulk_match.mentee_view

    set_cache_values

    self.expects(:get_user_ids).at_least(0).with(student_view, false).returns([@s1_id, @s2_id])
    self.expects(:get_user_ids).at_least(0).with(mentor_view, true).returns([@m1_id, @m2_id])

    if dont_compute
      bulk_match
    else
      compute_bulk_match_results(programs(:albers), bulk_match)
    end
  end

  def set_cache_values
    set_mentor_cache(@s1_id, @m1_id, 0.6)
    set_mentor_cache(@s1_id, @m2_id, 0.1)
    set_mentor_cache(@s2_id, @m1_id, 0.4)
    set_mentor_cache(@s2_id, @m2_id, 0.2)
    programs(:albers).match_setting.update_attributes!({min_match_score: 0.1, max_match_score: 0.6})
  end

  def reset_cache_values
    set_mentor_cache(@s1_id, @m1_id, 0.0)
    set_mentor_cache(@s1_id, @m2_id, 0.0)
    set_mentor_cache(@s2_id, @m1_id, 0.0)
    set_mentor_cache(@s2_id, @m2_id, 0.0)
    programs(:albers).match_setting.update_attributes!({min_match_score: 0.0, max_match_score: 0.0})
  end

end