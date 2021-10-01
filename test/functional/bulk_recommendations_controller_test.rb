require_relative './../test_helper.rb'

class BulkRecommendationsControllerTest < ActionController::TestCase
  def setup
    super
    programs(:albers).enable_feature(FeatureName::MENTOR_RECOMMENDATION)
  end

  def test_permission_denied_mentor_recommendation_disabled
    programs(:albers).enable_feature(FeatureName::MENTOR_RECOMMENDATION, false)
    current_user_is :f_admin
    assert_permission_denied do
      get :bulk_recommendation
    end
  end

  def test_bulk_recommendation_should_be_admin
    current_user_is :f_mentor
    assert_permission_denied do
      get :bulk_recommendation
    end
  end

  def test_bulk_recommendation
    program = programs(:albers)
    mentor_views = program.admin_views.default.where(default_view: [AbstractView::DefaultType::AVAILABLE_MENTORS, AbstractView::DefaultType::MENTORS, AbstractView::DefaultType::MENTORS_REGISTERED_BUT_NOT_ACTIVE, AbstractView::DefaultType::MENTORS_WITH_LOW_PROFILE_SCORES, AbstractView::DefaultType::MENTORS_IN_DRAFTED_CONNECTIONS, AbstractView::DefaultType::MENTORS_YET_TO_BE_DRAFTED, AbstractView::DefaultType::NEVER_CONNECTED_MENTORS, AbstractView::DefaultType::MENTORS_WITH_PENDING_MENTOR_REQUESTS])
    student_views = program.admin_views.default.where(default_view: [AbstractView::DefaultType::MENTEES, AbstractView::DefaultType::NEVER_CONNECTED_MENTEES, AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES, AbstractView::DefaultType::MENTEES_REGISTERED_BUT_NOT_ACTIVE, AbstractView::DefaultType::MENTEES_WITH_LOW_PROFILE_SCORES, AbstractView::DefaultType::MENTEES_IN_DRAFTED_CONNECTIONS, AbstractView::DefaultType::MENTEES_YET_TO_BE_DRAFTED, AbstractView::DefaultType::MENTEES_WHO_SENT_REQUEST_BUT_NOT_CONNECTED, AbstractView::DefaultType::MENTEES_WHO_HAVENT_SENT_MENTORING_REQUEST])

    current_user_is :f_admin
    get :bulk_recommendation
    assert_response :success
    assert_equal [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], assigns(:admin_view_role_hash).keys
    assert_equal mentor_views[0], assigns(:mentor_view)
    assert_equal student_views[1], assigns(:mentee_view)
    assert_equal mentor_views, assigns(:admin_view_role_hash)[RoleConstants::MENTOR_NAME]
    assert_equal_unordered student_views, assigns(:admin_view_role_hash)[RoleConstants::STUDENT_NAME]
    assert_equal bulk_matches(:bulk_recommendation_1), assigns(:bulk_match)
    assert assigns(:recommend_mentors)
    assert_equal BulkMatch::OrientationType::MENTEE_TO_MENTOR, assigns(:orientation_type)
  end

  def test_bulk_recommendation_xhr_with_existing_bulk_recommendation
    programs(:albers).mentor_recommendations.destroy_all
    current_user_is :f_admin
    bulk_recommendation = bulk_matches(:bulk_recommendation_1)
    mentor_view = bulk_recommendation.mentor_view
    student_view = bulk_recommendation.mentee_view

    s1_id, s2_id = [users(:f_student).id, users(:rahim).id]
    m1_id, m2_id = [users(:f_mentor).id, users(:robert).id]
    set_cache_values(programs(:albers), s1_id, s2_id, m1_id, m2_id)
    @controller.expects(:get_user_ids).at_least(0).with(student_view, false).returns([s1_id, s2_id])
    @controller.expects(:get_user_ids).at_least(0).with(mentor_view, true).returns([m1_id, m2_id])

    get :bulk_recommendation, xhr: true, params: { mentor_view_id: mentor_view.id, mentee_view_id: student_view.id, format: :js}
    assert_response :success

    assert_equal [m1_id, m2_id], assigns(:mentor_user_ids)
    assert_equal [s1_id, s2_id], assigns(:student_user_ids)
    assert_equal [s1_id, s2_id], assigns(:student_mentor_hash).keys
    assert_equal [[[m1_id, 90], [m2_id, 10]], [[m1_id, 57], [m2_id, 26]]], assigns(:student_mentor_hash).values

    assert_equal [[m1_id, m2_id], [m1_id, m2_id]], assigns(:selected_mentors).values
    assert_equal [[[m1_id, 90], [m2_id, 10]], [[m1_id, 57], [m2_id, 26]]], assigns(:suggested_mentors).values
    assert_equal_unordered [users(:f_mentor), users(:robert)], assigns(:mentor_users)
    assert_equal_unordered [users(:f_student), users(:rahim)], assigns(:student_users)
    assert_equal_unordered programs(:albers).groups.active, assigns(:active_groups)
    assert_equal_unordered programs(:albers).groups.drafted, assigns(:drafted_groups)
    assert_equal_unordered programs(:albers).groups.active_or_drafted, assigns(:active_drafted_groups)
    assert_equal_hash( { m1_id => users(:f_mentor).slots_available, m2_id => users(:robert).slots_available }, assigns(:mentor_slot_hash))
    reset_cache_values(programs(:albers), s1_id, s2_id, m1_id, m2_id)
  end

  def test_bulk_recommendation_xhr_without_existing_bulk_recommendation
    program = programs(:albers)
    program.mentor_recommendations.destroy_all
    current_user_is :f_admin
    program.bulk_recommendation.destroy
    mentor_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS)
    student_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTEES)

    s1_id, s2_id = [users(:f_student).id, users(:rahim).id]
    m1_id, m2_id = [users(:f_mentor).id, users(:robert).id]
    set_cache_values(program, s1_id, s2_id, m1_id, m2_id)
    @controller.expects(:get_user_ids).at_least(0).with(student_view, false).returns([s1_id, s2_id])
    @controller.expects(:get_user_ids).at_least(0).with(mentor_view, true).returns([m1_id, m2_id])

    get :bulk_recommendation, xhr: true, params: { mentor_view_id: mentor_view.id, mentee_view_id: student_view.id, format: :js}
    assert_response :success

    assert_equal [m1_id, m2_id], assigns(:mentor_user_ids)
    assert_equal [s1_id, s2_id], assigns(:student_user_ids)
    assert_equal [s1_id, s2_id], assigns(:student_mentor_hash).keys
    assert_equal [[[m1_id, 90], [m2_id, 10]], [[m1_id, 57], [m2_id, 26]]], assigns(:student_mentor_hash).values

    assert_equal [[m1_id], [m1_id]], assigns(:selected_mentors).values
    assert_equal [[[m1_id, 90], [m2_id, 10]], [[m1_id, 57], [m2_id, 26]]], assigns(:suggested_mentors).values
    assert_equal_unordered [users(:f_mentor), users(:robert)], assigns(:mentor_users)
    assert_equal_unordered [users(:f_student), users(:rahim)], assigns(:student_users)
    assert_equal_unordered program.groups.active, assigns(:active_groups)
    assert_equal_unordered program.groups.drafted, assigns(:drafted_groups)
    assert_equal_unordered program.groups.active_or_drafted, assigns(:active_drafted_groups)
    assert_equal_hash( { m1_id => users(:f_mentor).slots_available, m2_id => users(:robert).slots_available }, assigns(:mentor_slot_hash))
    reset_cache_values(program, s1_id, s2_id, m1_id, m2_id)
  end

  def test_refresh_results_permission_denied
    current_user_is :f_mentor
    assert_permission_denied do
      get :refresh_results, xhr: true, params: { format: :js}
    end
  end

  def test_refresh_results
    current_user_is :f_admin

    get :refresh_results, xhr: true, params: { format: :js}
    assert_response :success
    assert_equal bulk_matches(:bulk_recommendation_1), assigns(:bulk_match)
    assert_equal BulkMatch::OrientationType::MENTEE_TO_MENTOR, assigns(:orientation_type)
  end

  def test_fetch_settings
    current_user_is :f_admin

    get :fetch_settings, xhr: true
    assert_response :success
    assert_equal bulk_matches(:bulk_recommendation_1), assigns(:bulk_match)
  end

  def test_update_settings_update_sort_value
    current_user_is :f_admin
    bulk_recommendation = bulk_matches(:bulk_recommendation_1)

    assert_equal true, bulk_recommendation.sort_order
    assert_nil bulk_recommendation.sort_value

    get :update_settings, xhr: true, params: { sort: true, sort_value: "-group_status", sort_order: false}
    assert_response :success
    assert_equal false, bulk_recommendation.reload.sort_order
    assert_equal "-group_status", bulk_recommendation.sort_value
    assert_equal BulkMatch::OrientationType::MENTEE_TO_MENTOR, assigns(:orientation_type)
    assert_equal BulkMatch::OrientationType::MENTEE_TO_MENTOR, assigns(:orientation_type)
  end

  def test_update_settings_update_hiding_options_but_not_request_notes
    current_user_is :f_admin
    bulk_recommendation = bulk_matches(:bulk_recommendation_1)

    assert_false bulk_recommendation.show_drafted
    assert_false bulk_recommendation.show_published
    assert_false bulk_recommendation.request_notes

    get :update_settings, xhr: true, params: { bulk_recommendation: {show_published: true, show_drafted: true, request_notes: true, max_pickable_slots: 2, max_suggestion_count: 2}}
    assert_response :success
    assert bulk_recommendation.reload.show_drafted
    assert bulk_recommendation.show_published
    assert_false bulk_recommendation.request_notes
    assert_equal 2, bulk_recommendation.max_pickable_slots
    assert_equal 2, bulk_recommendation.max_suggestion_count
    assert_false assigns(:refresh_results)
  end

  def test_update_settings_should_refresh_on_decreasing_pickable_slots
    current_user_is :f_admin
    bulk_recommendation = bulk_matches(:bulk_recommendation_1)

    get :update_settings, xhr: true, params: { bulk_recommendation: {show_published: true, show_drafted: true, request_notes: true, max_pickable_slots: 1, max_suggestion_count: 2}}
    assert_response :success
    assert_equal 1, bulk_recommendation.reload.max_pickable_slots
    assert_equal 2, bulk_recommendation.max_suggestion_count
    assert_false bulk_recommendation.request_notes
    assert assigns(:refresh_results)
    assert_equal BulkMatch::OrientationType::MENTEE_TO_MENTOR, assigns(:orientation_type)
  end

  def test_update_settings_should_refresh_on_changing_max_suggestion_count
    current_user_is :f_admin
    bulk_recommendation = bulk_matches(:bulk_recommendation_1)

    get :update_settings, xhr: true, params: { bulk_recommendation: {show_published: true, show_drafted: true, request_notes: true, max_pickable_slots: 2, max_suggestion_count: 3}}
    assert_response :success
    assert_equal 2, bulk_recommendation.reload.max_pickable_slots
    assert_equal 3, bulk_recommendation.max_suggestion_count
    assert_false bulk_recommendation.request_notes
    assert assigns(:refresh_results)
  end

  def test_alter_pickable_slots_permission_denied
    current_user_is :f_mentor
    assert_permission_denied do
      get :alter_pickable_slots, xhr: true, params: { mentor_id: users(:f_mentor).id, student_id: users(:f_student).id}
    end
  end

  def test_alter_pickable_slots
    current_user_is :f_admin

    get :alter_pickable_slots, xhr: true, params: { mentor_id: users(:f_mentor).id, student_id: users(:f_student).id}
    assert_response :success
    assert_equal bulk_matches(:bulk_recommendation_1), assigns(:bulk_match)
    assert_equal users(:f_mentor), assigns(:mentor)
    assert_equal users(:f_student), assigns(:student)
  end

  def test_update_single_bulk_recommendation_draft
    current_user_is :f_admin
    assert_difference "MentorRecommendation.count", 1 do
      assert_difference "RecommendationPreference.count", 2 do
        get :update_bulk_recommendation_pair, xhr: true, params: { mentor_id_list: "3,4", student_id: 2, update_type: BulkRecommendation::UpdateType::DRAFT}
        assert_response :success
      end
    end
    pos = RecommendationPreference.find_by(user_id: 3).position
    pos1 = RecommendationPreference.find_by(user_id: 4).position
    mr = MentorRecommendation.last
    assert_equal MentorRecommendation::Status::DRAFTED, mr.status
    assert_equal 2, mr.recommendation_preferences.count
    assert_equal [1, 2], [pos, pos1]
  end

  def test_update_single_bulk_recommendation_undraft
    current_user_is :f_admin
    create_mentor_recommendation_and_preferences(2, MentorRecommendation::Status::DRAFTED, [3, 4])

    assert_difference "MentorRecommendation.count", -1 do
      assert_difference "RecommendationPreference.count", -2 do
        get :update_bulk_recommendation_pair, xhr: true, params: { mentor_id: "3,4", student_id: 2, update_type: BulkRecommendation::UpdateType::DISCARD}
        assert_response :success
      end
    end
  end

  def test_update_single_bulk_recommendation_discard_publish_recommendation
    current_user_is :f_admin
    create_mentor_recommendation_and_preferences(2, MentorRecommendation::Status::PUBLISHED, [3, 4])

    assert_difference "MentorRecommendation.count", -1 do
      assert_difference "RecommendationPreference.count", -2 do
        get :update_bulk_recommendation_pair, xhr: true, params: { mentor_id: "3,4", student_id: 2, update_type: BulkRecommendation::UpdateType::DISCARD}
        assert_response :success
      end
    end
  end

  def test_update_bulk_recommendations_draft
    current_user_is :f_admin

    assert_difference "MentorRecommendation.count", 2 do
      assert_difference "RecommendationPreference.count", 3 do
        get :bulk_update_bulk_recommendation_pair, xhr: true, params: { update_type: BulkRecommendation::UpdateType::DRAFT, selected_ids: [1, 2], student_mentor_map: {'1' => [4, 3], '2' => [3]}}
        assert_response :success
      end
    end
    pos = RecommendationPreference.where(user_id: 3).pluck(:position)
    pos1 = RecommendationPreference.find_by(user_id: 4).position
    mr = MentorRecommendation.find_by(receiver_id: 1)
    mr1 = MentorRecommendation.find_by(receiver_id: 2)
    assert_equal MentorRecommendation::Status::DRAFTED, mr.status
    assert_equal MentorRecommendation::Status::DRAFTED, mr1.status
    assert_equal 2, mr.recommendation_preferences.count
    assert_equal 1, mr1.recommendation_preferences.count
    assert_equal [2, 1], pos
    assert_equal 1, pos1
  end

  def test_update_bulk_recommendations_undraft
    current_user_is :f_admin

    create_mentor_recommendation_and_preferences(2, MentorRecommendation::Status::DRAFTED, [3, 4])
    create_mentor_recommendation_and_preferences(5, MentorRecommendation::Status::DRAFTED, [4])
    assert_difference "MentorRecommendation.count", -2 do
      assert_difference "RecommendationPreference.count", -3 do
        get :bulk_update_bulk_recommendation_pair, xhr: true, params: { update_type: BulkRecommendation::UpdateType::DISCARD, selected_ids: [2, 5], student_mentor_map: {'2' => [3, 4], '5' => [4]}}
        assert_response :success
      end
    end
  end

  def test_update_bulk_recommendation_publish_new_recommendation
    current_user_is :f_admin

    assert_difference "MentorRecommendation.count", 1 do
      assert_difference "RecommendationPreference.count", 3 do
        get :update_bulk_recommendation_pair, xhr: true, params: { mentor_id_list: "3,4,5", student_id: 2, update_type: BulkRecommendation::UpdateType::PUBLISH}
        assert_response :success
      end
    end
    mr = MentorRecommendation.last
    assert_equal MentorRecommendation::Status::PUBLISHED, mr.status
    assert_equal 3, mr.recommendation_preferences.count
  end

  def test_update_bulk_recommendation_publish_drafted_recommendation
    current_user_is :f_admin

    create_mentor_recommendation_and_preferences(2, MentorRecommendation::Status::DRAFTED, [3, 4])
    mr = MentorRecommendation.last

    assert_equal MentorRecommendation::Status::DRAFTED, mr.status
    assert_equal 2, mr.recommendation_preferences.count
    assert_no_difference ['MentorRecommendation.count', 'RecommendationPreference.count'] do
      get :update_bulk_recommendation_pair, xhr: true, params: { mentor_id_list: "3,4", student_id: 2, update_type: BulkRecommendation::UpdateType::PUBLISH}
      assert_response :success
    end

    mr.reload
    assert_equal MentorRecommendation::Status::PUBLISHED, mr.status
    assert_equal 2, mr.recommendation_preferences.count
  end

  def test_update_bulk_recommendation_publish_request_bulk
    current_user_is :f_admin
    program = programs(:albers)

    mr1 = create_mentor_recommendation_and_preferences(2, MentorRecommendation::Status::DRAFTED, [3, 4])
    mr2 = create_mentor_recommendation_and_preferences(5, MentorRecommendation::Status::DRAFTED, [4])

    assert_equal MentorRecommendation::Status::DRAFTED, mr1.status
    assert_equal MentorRecommendation::Status::DRAFTED, mr2.status
    assert_nil mr1.published_at
    assert_nil mr2.published_at
    assert_equal 2, mr1.recommendation_preferences.count
    assert_equal 1, mr2.recommendation_preferences.count
    MentorRecommendation.expects(:delay).returns(Delayed::Job)
    Delayed::Job.expects(:send_bulk_publish_mails).with(program.id, [2, 5])
    assert_no_difference ['MentorRecommendation.count', 'RecommendationPreference.count'] do
      get :bulk_update_bulk_recommendation_pair, xhr: true, params: { update_type: BulkRecommendation::UpdateType::PUBLISH, selected_ids: [2, 5], student_mentor_map: {'2' => [3, 4], '5' => [4]}}
      assert_response :success
    end

    mr1.reload
    mr2.reload
    assert_equal MentorRecommendation::Status::PUBLISHED, mr1.status
    assert_equal MentorRecommendation::Status::PUBLISHED, mr2.status
    assert_equal 2, mr1.recommendation_preferences.count
    assert_equal 1, mr2.recommendation_preferences.count
    assert_not_nil mr1.published_at
    assert_not_nil mr2.published_at
  end

  def test_draft_recommendation_for_mentee_with_drafted_recommendation_for_mentor_not_in_current_view
    #Draft a new recommendation for a mentee after the recommended mentor leaves bulk recommendation admin view
    current_user_is :f_admin
    program = programs(:albers)
    mentee = users(:f_student)
    mentor_1 = users(:f_mentor_student)
    mentor_2 = users(:ram)

    mr1 = create_mentor_recommendation_and_preferences(mentee.id, MentorRecommendation::Status::DRAFTED, [mentor_1.id])
    # mentor_1.demote_from_role!("mentor", users(:f_admin)) Assume mentor_1 left the mentor view (All mentors)

    assert_no_difference ['MentorRecommendation.count', 'RecommendationPreference.count'] do
      get :update_bulk_recommendation_pair, xhr: true, params: { mentor_id_list: mentor_2.id.to_s, student_id: mentee.id, update_type: BulkRecommendation::UpdateType::DRAFT}
      assert_response :success
    end

    assert_raise ActiveRecord::RecordNotFound do
      mr1.reload
    end
    assert_equal [6], mentee.mentor_recommendation.recommendation_preferences.pluck(:user_id)
  end

  def test_publish_recommendation_for_mentee_with_drafted_recommendation_for_mentor_not_in_current_view
    #Publish a drafted recommendation for a mentee after the recommended mentor leaves bulk recommendation admin view
    current_user_is :f_admin
    program = programs(:albers)
    mentee = users(:f_student)
    mentor_1 = users(:f_mentor_student)
    mentor_2 = users(:ram)

    mr1 = create_mentor_recommendation_and_preferences(mentee.id, MentorRecommendation::Status::DRAFTED, [mentor_1.id, mentor_2.id])
    # mentor_1.demote_from_role!("mentor", users(:f_admin)) Assume mentor_1 left the mentor view (All mentors)
    assert_equal 2, mentee.mentor_recommendation.recommendation_preferences.count

    assert_no_difference 'MentorRecommendation.count' do
      assert_difference 'RecommendationPreference.count', -1 do
        get :update_bulk_recommendation_pair, xhr: true, params: { mentor_id_list: mentor_2.id.to_s, student_id: mentee.id, update_type: BulkRecommendation::UpdateType::PUBLISH}
        assert_response :success
      end
    end
    assert_raise ActiveRecord::RecordNotFound do
      mr1.reload
    end
    mr = mentee.reload.mentor_recommendation
    assert_equal [6], mr.recommendation_preferences.pluck(:user_id)
    assert_not_nil mr.published_at
  end

  private

  def set_cache_values(program, s1_id, s2_id, m1_id, m2_id)
    set_mentor_cache(s1_id, m1_id, 0.6)
    set_mentor_cache(s1_id, m2_id, 0.1)
    set_mentor_cache(s2_id, m1_id, 0.4)
    set_mentor_cache(s2_id, m2_id, 0.2)
    program.match_setting.update_attributes!({min_match_score: 0.1, max_match_score: 0.6})
  end

  def reset_cache_values(program, s1_id, s2_id, m1_id, m2_id)
    set_mentor_cache(s1_id, m1_id, 0.0)
    set_mentor_cache(s1_id, m2_id, 0.0)
    set_mentor_cache(s2_id, m1_id, 0.0)
    set_mentor_cache(s2_id, m2_id, 0.0)
    program.match_setting.update_attributes!({min_match_score: 0.0, max_match_score: 0.0})
  end
end