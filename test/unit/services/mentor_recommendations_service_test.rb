require_relative './../../test_helper.rb'

class MentorRecommendationsServiceTest < ActiveSupport::TestCase
  def test_initialize
    user = users(:f_admin)
    MentorRecommendationsService.any_instance.stubs(:get_recommendations_type).returns("something").once
    mrs = MentorRecommendationsService.new(user)
    assert_equal user, mrs.mentee
    assert_equal user.program, mrs.program
    assert_equal "something", mrs.recommendations_for
    assert_equal MentorRecommendationsService::DEFAULT_RECOMMENDATIONS_COUNT, mrs.recommendations_count
    assert_false mrs.only_favorite_and_top_matches

    MentorRecommendationsService.any_instance.stubs(:get_recommendations_type).never
    mrs = MentorRecommendationsService.new(user, recommendations_for: "blah", recommendations_count: "seven", only_favorite_and_top_matches: true)
    assert_equal user, mrs.mentee
    assert_equal user.program, mrs.program
    assert_equal "blah", mrs.recommendations_for
    assert_equal "seven", mrs.recommendations_count
    assert mrs.only_favorite_and_top_matches
  end

  def test_get_system_recommendations
    user = users(:f_admin)
    program = user.program
    active_mentor_ids = program.mentor_users.active.pluck(:id)
    mrs = MentorRecommendationsService.new(user)

    mrs.stubs(:get_mentors_with_slots!).with(program, active_mentor_ids).returns({"something" => "value", "nothing" => "other value"})
    mrs.stubs(:get_mentors_list_for_quick_connect_box).with(active_mentor_ids, ["something", "nothing"], nil).returns("results")
    assert_equal "results", mrs.get_system_recommendations
    assert mrs.showing_system_recommendations
  end

  def test_get_explicit_preference_recommendations
    user = users(:f_admin)
    program = user.program
    active_mentor_ids = program.mentor_users.active.pluck(:id)
    mrs = MentorRecommendationsService.new(user)

    mrs.stubs(:get_mentors_with_slots!).with(program, active_mentor_ids).returns({"something" => "value", "nothing" => "other value"})
    mrs.stubs(:get_explicit_preferences_recommended_user_ids).returns(["something"])
    mrs.stubs(:get_mentors_list_for_quick_connect_box).with([], ["something"], ["something"]).returns("results")
    assert_equal "results", mrs.get_explicit_preference_recommendations
    assert mrs.showing_explicit_preference_recommendations
  end

  def test_get_recommendations
    user = users(:rahim)
    program = user.program
    active_mentor_ids = program.mentor_users.active.pluck(:id)
    mrs = MentorRecommendationsService.new(user)

    mrs.expects(:get_mentors_with_slots!).with(program, active_mentor_ids).never
    mrs.expects(:get_system_recommendations).never
    Program.any_instance.stubs(:mentor_recommendation_enabled?).returns(true)

    assert_equal [{member: members(:ram), recommended_for: MentorRecommendationsService::RecommendationsFor::ONGOING, recommendation_preference: recommendation_preferences(:recommendation_preference_1), user: users(:ram)}], mrs.get_recommendations(MentorRecommendationsService::RecommendationCategory::ADMIN_RECOMMENDATIONS)

    user = users(:f_student)
    program = user.program
    active_mentor_ids = program.mentor_users.active.pluck(:id)
    mrs = MentorRecommendationsService.new(user)

    mrs.stubs(:get_mentors_with_slots!).with(program, active_mentor_ids).returns({"something" => "value", "nothing" => "other value"})
    mrs.stubs(:get_mentors_list_for_quick_connect_box).with(active_mentor_ids, ["something", "nothing"], nil).returns("results")

    assert_equal "results", mrs.get_recommendations(MentorRecommendationsService::RecommendationCategory::SYSTEM_RECOMMENDATIONS)

    mrs = MentorRecommendationsService.new(user)
    assert_equal [], mrs.get_recommendations(MentorRecommendationsService::RecommendationCategory::ADMIN_RECOMMENDATIONS)

    assert_equal [], mrs.get_recommendations("")

    mrs.stubs(:get_mentors_with_slots!).with(program, active_mentor_ids).returns({"something" => "value", "nothing" => "other value"})
    mrs.stubs(:get_explicit_preferences_recommended_user_ids).returns([])
    assert_equal [], mrs.get_recommendations(MentorRecommendationsService::RecommendationCategory::EXPLICIT_PREFERENCE_RECOMMENDATIONS)
  end

  def test_get_admin_recommendations
    user = users(:rahim)
    mrs = MentorRecommendationsService.new(user)
    recommendation_preferences = users(:rahim).published_mentor_recommendation.recommendation_preferences
    mrs.instance_variable_set(:@recommendation_preferences, recommendation_preferences)
    mrs.instance_variable_set(:@filtered_recommendation_preference_ids, users(:ram).id)
    assert_equal [{member: members(:ram), recommended_for: MentorRecommendationsService::RecommendationsFor::ONGOING, recommendation_preference: recommendation_preferences(:recommendation_preference_1), user: users(:ram)}], mrs.send(:get_admin_recommendations)
  end

  def test_show_view_favorites_button
    user = users(:rahim)
    mrs = MentorRecommendationsService.new(user)
    mrs.stubs(:showing_system_recommendations).returns(false)
    mrs.stubs(:recommendations_count).returns(2)
    mrs.stubs(:favorite_mentor_recommendations).returns([])
    assert_false mrs.show_view_favorites_button?

    mrs.stubs(:showing_system_recommendations).returns(true)
    assert_false mrs.show_view_favorites_button?

    mrs.stubs(:favorite_mentor_recommendations).returns([1,2])
    assert_false mrs.show_view_favorites_button?

    mrs.stubs(:favorite_mentor_recommendations).returns([1,2,3])
    assert mrs.show_view_favorites_button?

    mrs.stubs(:showing_system_recommendations).returns(false)
    assert_false mrs.show_view_favorites_button?
  end

  def test_filtered_recommendation_preference_user_ids
    user = users(:rahim)
    mrs = MentorRecommendationsService.new(user)
    recommendation_preferences = users(:rahim).published_mentor_recommendation.recommendation_preferences
    mrs.instance_variable_set(:@recommendation_preferences, recommendation_preferences)
    assert_equal [6], mrs.send(:filtered_recommendation_preference_user_ids)

    mrs.stubs(:ignored_user_ids).returns([6, 999])
    assert_equal [], mrs.send(:filtered_recommendation_preference_user_ids)

    mrs.stubs(:ignored_user_ids).returns([])
    User.stubs(:get_availability_slots_for).with([users(:ram).id]).returns({})
    assert_equal [], mrs.send(:filtered_recommendation_preference_user_ids)
  end

  def test_get_recommendations_type
    user = users(:f_admin)
    program = user.program
    mrs = MentorRecommendationsService.new(user)

    assert_equal MentorRecommendationsService::RecommendationsFor::ONGOING, mrs.send(:get_recommendations_type)

    program.stubs(:only_one_time_mentoring_enabled?).returns(true)
    assert_equal MentorRecommendationsService::RecommendationsFor::FLASH, mrs.send(:get_recommendations_type)

    program.stubs(:only_one_time_mentoring_enabled?).returns(false)
    program.stubs(:calendar_enabled?).returns(true)
    assert_equal MentorRecommendationsService::RecommendationsFor::BOTH, mrs.send(:get_recommendations_type)
  end

  def test_get_mentors_list_for_quick_connect_box
    user = users(:f_student)
    program = user.program
    assert user.student_document_available?
    user.stubs(:student_cache_normalized).returns("student_cache_normalized")
    mrs = MentorRecommendationsService.new(user)

    get_mentors_recommendations_for_ongoing = [{member: members(:f_admin), score: "something"}, {member: members(:mentor_0), score: "nothing"}]
    get_mentor_recommendations_for_flash = [{member: members(:f_admin), score: "something"}, {member: members(:f_mentor), score: "everything"}]
    all_active_mentors_hash = program.mentor_users.where(member_id: [members(:f_admin), members(:mentor_0), members(:f_mentor)].collect(&:id)).active.includes([:profile_views, :groups, member: [:accepted_flash_meetings]]).index_by(&:member_id)
    all_active_mentors_hash_f = program.mentor_users.where(member_id: [members(:f_admin), members(:f_mentor)].collect(&:id)).active.includes([:profile_views, :groups, member: [:accepted_flash_meetings]]).index_by(&:member_id)
    all_active_mentors_hash_o = program.mentor_users.where(member_id: [members(:f_admin), members(:mentor_0)].collect(&:id)).active.includes([:profile_views, :groups, member: [:accepted_flash_meetings]]).index_by(&:member_id)
    mrs.stubs(:get_recommendations_for_ongoing_connections?).returns(true)
    mrs.stubs(:get_mentors_recommendations_for_ongoing).with("student_cache_normalized", "mentors_ids_with_slots").returns(get_mentors_recommendations_for_ongoing)
    mrs.stubs(:get_recommendations_for_flash_connections?).returns(true)
    mrs.stubs(:get_mentor_recommendations_for_flash).with("student_cache_normalized", "active_mentor_ids", true).returns(get_mentor_recommendations_for_flash)
    mrs.stubs(:get_combined_mentors_list).with(get_mentor_recommendations_for_flash, get_mentors_recommendations_for_ongoing, all_active_mentors_hash, nil).returns("get_combined_mentors_list")
    assert_equal "get_combined_mentors_list", mrs.send(:get_mentors_list_for_quick_connect_box, "active_mentor_ids", "mentors_ids_with_slots")

    user.stubs(:student_document_available?).returns(false)
    mrs.stubs(:get_recommendations_for_ongoing_connections?).returns(false)
    mrs.stubs(:get_mentors_recommendations_for_ongoing).never
    mrs.stubs(:get_recommendations_for_flash_connections?).returns(true)
    mrs.stubs(:get_mentor_recommendations_for_flash).with({}, "active_mentor_ids", false).returns(get_mentor_recommendations_for_flash)
    mrs.stubs(:get_combined_mentors_list).with(get_mentor_recommendations_for_flash, [], all_active_mentors_hash_f, nil).returns("get_combined_mentors_list1")
    assert_equal "get_combined_mentors_list1", mrs.send(:get_mentors_list_for_quick_connect_box, "active_mentor_ids", "mentors_ids_with_slots")

    mrs.stubs(:get_recommendations_for_ongoing_connections?).returns(true)
    mrs.stubs(:get_mentors_recommendations_for_ongoing).with({}, "mentors_ids_with_slots").returns(get_mentors_recommendations_for_ongoing)
    mrs.stubs(:get_recommendations_for_flash_connections?).returns(false)
    mrs.stubs(:get_mentor_recommendations_for_flash).never
    mrs.stubs(:get_combined_mentors_list).with([], get_mentors_recommendations_for_ongoing, all_active_mentors_hash_o, nil).returns("get_combined_mentors_list2")
    assert_equal "get_combined_mentors_list2", mrs.send(:get_mentors_list_for_quick_connect_box, "active_mentor_ids", "mentors_ids_with_slots")
  end

  def test_get_mentors_recommendations_for_ongoing
    user = users(:f_student)
    mentors_score = {users(:f_admin).id => "f_admin", users(:f_student).id => "f_student", users(:f_mentor).id => "f_mentor"}

    mrs = MentorRecommendationsService.new(user)
    mrs.stubs(:can_recommend_mentors_for_connections?).returns(false)
    assert_nil mrs.send(:get_mentors_recommendations_for_ongoing, mentors_score, "mentors_ids_with_slots")

    mrs.stubs(:can_recommend_mentors_for_connections?).returns(true)
    MentorRecommendationsService.stubs(:reject_mentors_connected_to_mentee).with(user, user.program, "mentors_ids_with_slots").returns("mentors_ids")
    mrs.stubs(:get_top_and_favorite_mentor_ids_for_ongoing_based_on_recommendation).with("mentors_ids", mentors_score).returns([users(:f_admin).id, users(:f_mentor).id])
    result = mrs.send(:get_mentors_recommendations_for_ongoing, mentors_score, "mentors_ids_with_slots")
    assert_equal 2, result.size
    r0, r1 = result

    assert_equal "f_admin", r0[:score]
    assert_equal "f_mentor", r1[:score]

    assert_equal users(:f_admin).id, r0[:user].id
    assert_equal users(:f_mentor).id, r1[:user].id

    assert_equal users(:f_admin).member_id, r0[:member].id
    assert_equal users(:f_mentor).member_id, r1[:member].id
  end

  def test_get_top_and_favorite_mentor_ids_for_ongoing
    user = users(:f_student)
    mrs = MentorRecommendationsService.new(user)

    mrs.stubs(:select_top_mentors_for_connection_recommendations).with(['a', 'b', 'c', 'd'], 'mentors_score').returns(['a', 'b'])
    mrs.stubs(:favourite_user_ids).returns(['a', 'd', 'e'])
    mrs.stubs(:reject_mentors_below_match_threshold).with(['a', 'd'], 'mentors_score').returns(['a', 'd'])
    assert_equal ['a', 'b', 'd'], mrs.send(:get_top_and_favorite_mentor_ids_for_ongoing, ['a', 'b', 'c', 'd'], 'mentors_score')

    mrs.stubs(:reject_mentors_below_match_threshold).with(['a', 'd'], 'mentors_score').returns(['a'])
    assert_equal ['a', 'b'], mrs.send(:get_top_and_favorite_mentor_ids_for_ongoing, ['a', 'b', 'c', 'd'], 'mentors_score')
  end

  def test_reject_mentors_below_match_threshold
    user = users(:f_student)
    mrs = MentorRecommendationsService.new(user)
    mrs.stubs(:showing_system_recommendations).returns(true)
    assert_equal ['b', 'd'], mrs.send(:reject_mentors_below_match_threshold, ['a', 'b', 'c', 'd'], {'a' => 49, 'b' => 50, 'd' => 51})
  end

  def test_get_mentor_recommendations_for_flash
    user = users(:f_student)
    program = user.program
    mentors_score = {users(:f_admin).id => "f_admin", users(:f_student).id => "f_student", users(:f_mentor).id => "f_mentor"}

    mrs = MentorRecommendationsService.new(user)
    user.stubs(:can_render_meetings_for_quick_connect_box?).returns(false)
    assert_nil mrs.send(:get_mentor_recommendations_for_flash, mentors_score, "active_mentor_ids", "document_available")

    user.stubs(:can_render_meetings_for_quick_connect_box?).returns(true)
    MentorRecommendationsService.stubs(:reject_mentors_connected_to_mentee).with(user, program, "active_mentor_ids").returns([users(:f_admin).id, users(:f_mentor).id])
    mrs.stubs(:get_top_and_favorite_mentor_ids_for_flash).with([users(:f_admin).id, users(:f_mentor).id], mentors_score, "document_available").returns("something")
    assert_equal "something", mrs.send(:get_mentor_recommendations_for_flash, mentors_score, "active_mentor_ids", "document_available")
  end

  def test_get_top_and_favorite_mentor_ids_for_flash
    user = users(:f_student)
    program = user.program
    mentors_score = {users(:f_admin).id => "f_admin", users(:f_student).id => "f_student", users(:f_mentor).id => "f_mentor"}
    mrs = MentorRecommendationsService.new(user)
    mrs.stubs(:showing_system_recommendations).returns(true)
    mrs.stubs(:favourite_user_ids).returns([users(:f_admin).id, 999, 1000])
    user.stubs(:generate_mentor_suggest_hash).with(program, [users(:f_student).id, users(:f_mentor).id], Meeting::Interval::MONTH, user, mentors_score: mentors_score, items_size: MentorRecommendationsService::TOP_N_MENTORS_THRESHOLD, reject: "document_available", skip_explicit_preferences: true, reject_zero_score_mentors: nil, quick_connect: true).returns([1, 12345])
    user.stubs(:generate_mentor_suggest_hash).with(program, [users(:f_admin).id], Meeting::Interval::MONTH, user, mentors_score: mentors_score, items_size: MentorRecommendationsService::TOP_N_MENTORS_THRESHOLD, reject: "document_available", skip_explicit_preferences: true, reject_zero_score_mentors: nil, quick_connect: true).returns([98765])
    assert_equal [1, 12345, 98765], mrs.send(:get_top_and_favorite_mentor_ids_for_flash, [users(:f_admin).id, users(:f_student).id, users(:f_mentor).id], mentors_score, "document_available")
  end

  def test_get_recommendations_for_ongoing_connections?
    user = users(:f_student)
    mrs = MentorRecommendationsService.new(user)

    mrs.stubs(:recommendations_for).returns(MentorRecommendationsService::RecommendationsFor::BOTH)
    assert mrs.send(:get_recommendations_for_ongoing_connections?)

    mrs.stubs(:recommendations_for).returns(MentorRecommendationsService::RecommendationsFor::ONGOING)
    assert mrs.send(:get_recommendations_for_ongoing_connections?)

    mrs.stubs(:recommendations_for).returns(MentorRecommendationsService::RecommendationsFor::FLASH)
    assert_false mrs.send(:get_recommendations_for_ongoing_connections?)
  end

  def test_get_recommendations_for_flash_connections?
    user = users(:f_student)
    mrs = MentorRecommendationsService.new(user)

    mrs.stubs(:recommendations_for).returns(MentorRecommendationsService::RecommendationsFor::BOTH)
    assert mrs.send(:get_recommendations_for_flash_connections?)

    mrs.stubs(:recommendations_for).returns(MentorRecommendationsService::RecommendationsFor::ONGOING)
    assert_false mrs.send(:get_recommendations_for_flash_connections?)

    mrs.stubs(:recommendations_for).returns(MentorRecommendationsService::RecommendationsFor::FLASH)
    assert mrs.send(:get_recommendations_for_flash_connections?)
  end

  def test_reject_mentors_connected_to_mentee
    user = users(:student_1)
    mrs = MentorRecommendationsService.new(user)
    MentorRecommendationsService.stubs(:get_flash_mentor_ids_of_mentee).with(user, user.program).returns([users(:mentor_2).id])

    assert_equal [users(:mentor_1).id, users(:robert).id], user.mentors(:all).collect(&:id)
    assert_equal [users(:f_mentor).id, users(:robert).id], user.sent_mentor_requests.pluck(:receiver_id)
    create_meeting_request(mentor: users(:mentor_3), student: user)
    assert_equal [users(:robert).id, users(:mentor_3).id], user.sent_meeting_requests.pluck(:receiver_id)

    assert_equal [users(:f_admin), users(:mentor_0)].collect(&:id), MentorRecommendationsService.send(:reject_mentors_connected_to_mentee, user, user.program, [users(:f_admin), users(:student_1), users(:f_mentor), users(:robert), users(:mentor_0), users(:mentor_1), users(:mentor_2), users(:mentor_3)].collect(&:id))

    create_group(:students => [users(:student_1)], :mentors => [users(:mentor_0)], :program => programs(:albers), :status => Group::Status::DRAFTED, :creator_id => users(:f_admin).id)
    assert_equal [users(:mentor_1).id, users(:robert).id, users(:mentor_0).id], user.mentors(:all).collect(&:id)

    assert_equal [users(:f_admin)].collect(&:id), MentorRecommendationsService.send(:reject_mentors_connected_to_mentee, user, user.program, [users(:f_admin), users(:student_1), users(:f_mentor), users(:robert), users(:mentor_0), users(:mentor_1), users(:mentor_2), users(:mentor_3)].collect(&:id))
  end

  def test_get_flash_mentor_ids_of_mentee
    user = users(:mkr_student)
    mrs = MentorRecommendationsService.new(user)
    assert_equal [users(:f_mentor).id], MentorRecommendationsService.send(:get_flash_mentor_ids_of_mentee, user, user.program)
    options = {members: [members(:mentor_0), members(:mkr_student)], owner_id: members(:mentor_0).id, requesting_mentor: users(:mentor_0), requesting_student: users(:mkr_student), force_non_group_meeting: true}
    create_meeting(options)
    # user.reload
    assert_equal [users(:f_mentor).id, users(:mentor_0).id], MentorRecommendationsService.send(:get_flash_mentor_ids_of_mentee, user, user.program)
  end

  def test_can_recommend_mentors_for_connections
    mentee = users(:mkr_student)
    program = mentee.program
    mrs = MentorRecommendationsService.new(mentee)

    mentee.stubs(:can_render_mentors_for_connection_in_quick_connect_box?).returns(true)
    
    mentee.stubs(:pending_request_limit_reached_for_mentee?).returns(false)
    program.stubs(:allow_mentoring_requests?).returns(true)
    assert mrs.send(:can_recommend_mentors_for_connections?, ["something"])

    assert_false mrs.send(:can_recommend_mentors_for_connections?, [])

    mentee.stubs(:can_render_mentors_for_connection_in_quick_connect_box?).returns(false)
    assert_false mrs.send(:can_recommend_mentors_for_connections?, ["something"])

    mentee.stubs(:can_render_mentors_for_connection_in_quick_connect_box?).returns(true)
    assert mrs.send(:can_recommend_mentors_for_connections?, ["something"])
   
    mentee.stubs(:pending_request_limit_reached_for_mentee?).returns(true)
    assert_false mrs.send(:can_recommend_mentors_for_connections?, ["something"])

    mentee.stubs(:pending_request_limit_reached_for_mentee?).returns(false)
    program.stubs(:allow_mentoring_requests?).returns(false)
    assert_false mrs.send(:can_recommend_mentors_for_connections?, ["something"])

    program.stubs(:allow_mentoring_requests?).returns(true)
    assert mrs.send(:can_recommend_mentors_for_connections?, ["something"])
  end

  def test_select_top_mentors_for_connection_recommendations
    user = users(:mkr_student)
    mrs = MentorRecommendationsService.new(user)
    mentor_ids = (1..20).to_a
    mentors_score = {}
    availability_of_user_id_hsh = {}
    mentor_ids.each {|id| mentors_score[id] = id + 42; availability_of_user_id_hsh[id] = 1 }
    mentors_score[8] = mentors_score[9]
    availability_of_user_id_hsh[8] = 2

    top_mentor_ids = mrs.send(:get_top_mentor_ids_based_on_score, mentor_ids, mentors_score)
    assert_equal_unordered (8..20).to_a, top_mentor_ids

    availability_of_top_user_id_hsh = availability_of_user_id_hsh.select{|k, v| top_mentor_ids.include?(k) }
    User.stubs(:get_availability_slots_for).with(top_mentor_ids).returns(availability_of_top_user_id_hsh)
    assert_equal ((10..20).to_a.reverse + [8] + [9]), mrs.send(:select_top_mentors_for_connection_recommendations, mentor_ids, mentors_score)
  end

  def test_get_combined_mentors_list
    user = users(:mkr_student)
    mrs = MentorRecommendationsService.new(user)
    mentors_for_connection = [{member: members(:f_admin), something: "nothing"}, {member: members(:f_student), nothing: "something"}]
    combined_mentors = {"one" => {recommendation_score: 6, something: 1, is_favorite: true}, "two" => {recommendation_score: 20, something: 2}, "three" => {recommendation_score: -5, something: 3}, "four" => {something: 4, is_favorite: false}, "five" => {recommendation_score: -3, something: 5, is_favorite: false}, "six" => {recommendation_score: -7, something: 6, is_favorite: true}}
    mrs.stubs(:add_mentors_for_meetings_to_combined_list).with({}, "mentors_for_meeting", "mentors_hash").returns("combined_mentors")
    User.stubs(:get_availability_slots_for).with([members(:f_admin), members(:f_student)].collect(&:id)).returns("availability_of_user_id_hsh")
    mrs.stubs(:add_mentors_for_connection_to_combined_list).with("combined_mentors", mentors_for_connection, "availability_of_user_id_hsh", "mentors_hash").returns(combined_mentors)
    mrs.stubs(:recommendations_count).returns(4)
    mrs.stubs(:showing_system_recommendations).returns(true)
    assert_equal [2, 1, 4, 5], mrs.send(:get_combined_mentors_list, "mentors_for_meeting", mentors_for_connection, "mentors_hash").map{|h| h[:something]}
    assert_equal [{recommendation_score: 6, something: 1, is_favorite: true}, {recommendation_score: -7, something: 6, is_favorite: true}], mrs.favorite_mentor_recommendations
  end

  def test_sort_mentor_list_by_recommendation_type
    user = users(:mkr_student)
    mrs = MentorRecommendationsService.new(user)
    mrs.stubs(:showing_system_recommendations).returns(false)
    final_list = [{user: {id: 1}}, {user: {id: 2}}, {user: {id: 3}}]
    sort_order = [2, 3, 1]
    assert_equal sort_order, mrs.send(:sort_mentor_list_by_recommendation_type, final_list, sort_order).collect{|list_item| list_item[:user][:id]}
  end

  def test_add_mentors_for_meetings_to_combined_list
    user = users(:mkr_student)
    mrs = MentorRecommendationsService.new(user)

    assert_equal "something", mrs.send(:add_mentors_for_meetings_to_combined_list, "something", nil, "mentors_hash")

    mentors_hash = {members(:f_admin).id => users(:f_admin), members(:f_student).id => users(:f_student), members(:f_mentor).id => users(:f_mentor)}
    mentors_for_meeting = [{member: members(:f_admin), score: "50", availability: "f_admin availability"}, {member: members(:f_student), score: "60", availability: "f_student availability"}, {member: members(:f_mentor), score: nil, availability: "f_mentor availability"}]
    result = { members(:f_admin).id => {member: members(:f_admin), user: users(:f_admin), max_score: 50, recommendation_score: "r f_admin", availability: "f_admin availability", recommended_for: MentorRecommendationsService::RecommendationsFor::FLASH, is_favorite: true},
                         members(:f_student).id => {member: members(:f_student), user: users(:f_student), max_score: 60, recommendation_score: "r f_student", availability: "f_student availability", recommended_for: MentorRecommendationsService::RecommendationsFor::FLASH, is_favorite: false},
                         members(:f_mentor).id => {member: members(:f_mentor), user: users(:f_mentor), max_score: 0, recommendation_score: "r f_mentor", availability: "f_mentor availability", recommended_for: MentorRecommendationsService::RecommendationsFor::FLASH, is_favorite: false}
                       }
    mrs.stubs(:compute_recommendation_score).with('50', users(:f_admin)).returns("r f_admin")
    mrs.stubs(:compute_recommendation_score).with('60', users(:f_student)).returns("r f_student")
    mrs.stubs(:compute_recommendation_score).with(nil, users(:f_mentor)).returns("r f_mentor")
    mrs.stubs(:favourite_user_ids).returns([users(:f_admin).id, 9999])
    assert_equal result, mrs.send(:add_mentors_for_meetings_to_combined_list, {}, mentors_for_meeting, mentors_hash)
  end

  def test_add_mentors_for_connection_to_combined_list
    user = users(:mkr_student)
    mrs = MentorRecommendationsService.new(user)
    assert_equal "something", mrs.send(:add_mentors_for_connection_to_combined_list, "something", [], "availability_of_user_id_hsh", "mentors_hash")

    mentors_for_connection_ary = [{member: members(:f_admin), score: "50", user: users(:f_admin)}, {member: members(:f_student), score: "60", user: users(:f_student)}, {member: members(:f_mentor), score: nil, user: users(:f_mentor)}]
    availability_of_user_id_hsh = {members(:f_admin).id => "a f_admin", members(:f_student).id => "a f_student", members(:f_mentor).id => "a f_mentor"}
    mentors_hash = {members(:f_admin).id => "m f_admin", members(:f_student).id => "m f_student", members(:f_mentor).id => "m f_mentor"}
    combined_mentors = {members(:f_admin).id => {member: "member", max_score: 20, recommendation_score: "rscore old", availability: "f_admin availability"},
                         members(:f_student).id => {member: "member", max_score: 100, recommendation_score: "rscore old", availability: "f_student availability", recommended_for: "flash old"}}
    result = { members(:f_admin).id => {member: members(:f_admin), max_score: 50, recommendation_score: "r f_admin", availability: "f_admin availability", user: users(:f_admin), slots_availabile_for_mentoring: "a f_admin", recommended_for: MentorRecommendationsService::RecommendationsFor::ONGOING, is_favorite: true},
               members(:f_student).id => {member: members(:f_student), max_score: 100, recommendation_score: "rscore old", availability: "f_student availability", user: users(:f_student), slots_availabile_for_mentoring: "a f_student", recommended_for: "flash old", is_favorite: false},
               members(:f_mentor).id => {member: members(:f_mentor), max_score: 0, recommendation_score: "r f_mentor", user: users(:f_mentor), slots_availabile_for_mentoring: "a f_mentor", recommended_for: MentorRecommendationsService::RecommendationsFor::ONGOING, is_favorite: false} }

    mrs.stubs(:compute_recommendation_score).with('50', "m f_admin").returns("r f_admin")
    mrs.stubs(:compute_recommendation_score).with('60', "m f_student").returns("r f_student").never
    mrs.stubs(:compute_recommendation_score).with(nil, "m f_mentor").returns("r f_mentor")
    mrs.stubs(:favourite_user_ids).returns([users(:f_admin).id, 9999])

    assert_equal_hash result, mrs.send(:add_mentors_for_connection_to_combined_list, combined_mentors, mentors_for_connection_ary, availability_of_user_id_hsh, mentors_hash)
  end

  def test_set_max_score_for_combined_list
    user = users(:mkr_student)
    mrs = MentorRecommendationsService.new(user)

    mentors_hash = {10 => "something"}
    mentor = {score: "30", member: "member"}
    combined_mentors = {10 => {max_score: 40, recommendation_score: "old", recommended_for: "flash"}}
    result1 = {10 => {max_score: 40, recommendation_score: "old", recommended_for: "flash"}}
    mrs.stubs(:compute_recommendation_score).with("30", "something").never
    mrs.send(:set_max_score_for_combined_list, combined_mentors, 10, mentor, mentors_hash)
    assert_equal result1, combined_mentors

    mentor = {score: "50", member: "member"}
    combined_mentors = {10 => {max_score: 40, recommendation_score: "old", recommended_for: "flash"}}
    result2 = {10 => {max_score: 50, recommendation_score: "new", recommended_for: MentorRecommendationsService::RecommendationsFor::ONGOING}}
    mrs.stubs(:compute_recommendation_score).with("50", "something").returns("new")
    mrs.send(:set_max_score_for_combined_list, combined_mentors, 10, mentor, mentors_hash)
    assert_equal result2, combined_mentors
  end

  def test_compute_recommendation_score
    user = users(:mkr_student)
    mentor = users(:f_mentor)
    member = mentor.member
    mrs = MentorRecommendationsService.new(user)

    mrs.stubs(:only_favorite_and_top_matches).returns(true)
    mrs.stubs(:favourite_user_ids).returns([9999])
    assert_equal 2500, mrs.send(:compute_recommendation_score, "2500", users(:f_admin))

    mrs.stubs(:favourite_user_ids).returns([9999, users(:f_admin).id])
    assert_equal 2600, mrs.send(:compute_recommendation_score, "2500", users(:f_admin))    

    mrs.stubs(:only_favorite_and_top_matches).returns(false)
    mrs.stubs(:get_user_profile_views_score).with(mentor).returns(900)
    mrs.stubs(:get_member_terms_and_conditions_score).with(member).returns(80)
    mrs.stubs(:get_user_connections_score).with(mentor, member).returns(1)
    mrs.stubs(:get_favorite_score).with(mentor).returns(2000)
    assert_equal 14982.0, mrs.send(:compute_recommendation_score, "100000", mentor)
  end

  def test_get_favorite_score
    user = users(:mkr_student)
    mentor = users(:f_mentor)
    mrs = MentorRecommendationsService.new(user)
    mrs.stubs(:favourite_user_ids).returns([9999])
    assert_equal 0.0, mrs.send(:get_favorite_score, users(:f_mentor))

    mrs.stubs(:favourite_user_ids).returns([9999, users(:f_mentor).id])
    assert_equal 1.0, mrs.send(:get_favorite_score, users(:f_mentor))
  end

  def test_get_user_profile_views_score
    user = users(:mkr_student)
    mentor = users(:f_mentor)
    mrs = MentorRecommendationsService.new(user)

    assert_equal 0.0, mrs.send(:get_user_profile_views_score, mentor)
    Timecop.travel(4.months.ago)
      ProfileView.create!(user: mentor, viewed_by: users(:f_admin))
    Timecop.return
    assert_equal 0.0, mrs.send(:get_user_profile_views_score, mentor.reload)

    ProfileView.create!(user: mentor, viewed_by: users(:f_admin))
    assert_equal 1.0/3.0, mrs.send(:get_user_profile_views_score, mentor.reload)

    Timecop.travel(1.months.ago)
      ProfileView.create!(user: mentor, viewed_by: users(:f_admin))
    Timecop.return
    assert_equal 2.0/3.0, mrs.send(:get_user_profile_views_score, mentor.reload)

    ProfileView.create!(user: mentor, viewed_by: users(:f_admin))
    assert_equal 1.0, mrs.send(:get_user_profile_views_score, mentor.reload)

    ProfileView.create!(user: mentor, viewed_by: users(:f_admin))
    assert_equal 1.0, mrs.send(:get_user_profile_views_score, mentor.reload)
  end

  def test_get_member_terms_and_conditions_score
    user = users(:mkr_student)
    member = members(:f_mentor)
    mrs = MentorRecommendationsService.new(user)

    member.stubs(:terms_and_conditions_accepted).returns(nil)
    assert_equal 0.0, mrs.send(:get_member_terms_and_conditions_score, member)

    member.stubs(:terms_and_conditions_accepted).returns(31.days.ago)
    assert_equal 0.0, mrs.send(:get_member_terms_and_conditions_score, member)

    member.stubs(:terms_and_conditions_accepted).returns(2.days.ago)
    assert_equal 1.0, mrs.send(:get_member_terms_and_conditions_score, member)
  end

  def test_get_user_connections_score
    user = users(:mkr_student)
    mentor = users(:f_mentor)
    member = members(:f_mentor)
    mrs = MentorRecommendationsService.new(user)

    mentor.stubs(:groups).returns([])
    member.stubs(:accepted_flash_meetings).returns([])
    assert_equal 1.0, mrs.send(:get_user_connections_score, mentor, member)

    mentor.stubs(:groups).returns([1])
    assert_equal 0.0, mrs.send(:get_user_connections_score, mentor, member)

    mentor.stubs(:groups).returns([])
    member.stubs(:accepted_flash_meetings).returns([1])
    assert_equal 0.0, mrs.send(:get_user_connections_score, mentor, member)
  end

  def test_should_show_recommendation_matching_by_mentee_and_admin
    rahim = users(:rahim)
    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(false)
    Program.any_instance.stubs(:matching_by_mentee_and_admin?).returns(true)
    Program.any_instance.stubs(:mentor_recommendation_enabled?).returns(true)
    mrs = MentorRecommendationsService.new(rahim)
    assert mrs.send(:show_recommendation_box?)
  end

  def test_should_not_show_recommendation_unpublished_mentor_recommendation
    rahim = users(:rahim)
    mrs = MentorRecommendationsService.new(rahim)
    Program.any_instance.stubs(:mentor_recommendation_enabled?).returns(true)
    assert mrs.send(:show_recommendation_box?)
    mentor_recommendation = rahim.mentor_recommendation
    mentor_recommendation.status = MentorRecommendation::Status::DRAFTED
    mentor_recommendation.save!
    rahim.reload
    assert_false mrs.send(:show_recommendation_box?)
  end

  def test_should_show_recommendation_matching_by_mentee_and_admin_with_preference1
    rahim = users(:rahim)
    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(false)
    Program.any_instance.stubs(:matching_by_mentee_and_admin_with_preference?).returns(false)
    mrs = MentorRecommendationsService.new(rahim)
    assert_false mrs.send(:show_recommendation_box?)
  end

  def test_should_show_recommendation_matching_by_mentee_and_admin_with_preference2
    rahim = users(:rahim)
    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(false)
    Program.any_instance.stubs(:matching_by_mentee_and_admin_with_preference?).returns(true)
    Program.any_instance.stubs(:mentor_recommendation_enabled?).returns(true)
    mrs = MentorRecommendationsService.new(rahim)
    assert mrs.send(:show_recommendation_box?)
  end

  def test_should_not_show_recommendation_not_matching_by_mentee
    rahim = users(:rahim)
    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(false)
    Program.any_instance.stubs(:matching_by_mentee_and_admin?).returns(false)
    mrs = MentorRecommendationsService.new(rahim)
    assert_false mrs.send(:show_recommendation_box?)
  end

  def test_should_show_recommendation_career_based_ongoing_mentoring
    rahim = users(:rahim)
    Program.any_instance.stubs(:mentor_recommendation_enabled?).returns(true)
    program = rahim.program
    program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    program.save!
    mrs = MentorRecommendationsService.new(rahim)
    assert mrs.send(:show_recommendation_box?)
  end

  def test_should_not_show_recommendation_project_based_mentoring
    Program.any_instance.stubs(:mentor_recommendation_enabled?).returns(true)
    rahim = users(:rahim)
    program = rahim.program
    program.engagement_type = Program::EngagementType::PROJECT_BASED
    program.save!
    mrs = MentorRecommendationsService.new(rahim)
    assert_false mrs.send(:show_recommendation_box?)
  end

  def test_should_not_show_recommendation_career_based_mentoring
    rahim = users(:rahim)
    program = rahim.program
    program.engagement_type = Program::EngagementType::CAREER_BASED
    program.save!
    mrs = MentorRecommendationsService.new(rahim)
    assert_false mrs.send(:show_recommendation_box?)
  end

  def test_should_not_show_recommendation_no_recommendation
    student = users(:f_student)
    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(false)
    Program.any_instance.stubs(:matching_by_mentee_and_admin?).returns(true)
    mrs = MentorRecommendationsService.new(student)
    assert_false mrs.send(:show_recommendation_box?)
  end

  def test_should_not_show_recommendation_not_student
    program = programs(:albers)
    admin = users(:f_admin)
    student = users(:f_student)
    mentor = users(:f_mentor)
    ram = users(:ram)
    robert = users(:robert)
    setup_recommendation(program: program, admin: admin, student: mentor, mentor1: student, mentor2: ram, mentor3: robert)
    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(false)
    Program.any_instance.stubs(:matching_by_mentee_and_admin?).returns(true)
    mrs = MentorRecommendationsService.new(mentor)
    assert_false mrs.send(:show_recommendation_box?)
  end

  def test_should_show_recommendation_student_and_mentor
    program = programs(:albers)
    admin = users(:f_admin)
    student = users(:f_mentor_student)
    mentor = users(:f_mentor)
    ram = users(:ram)
    robert = users(:robert)
    setup_recommendation(program: program, admin: admin, student: student, mentor1: mentor, mentor2: ram, mentor3: robert)
    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(false)
    Program.any_instance.stubs(:matching_by_mentee_and_admin?).returns(true)
    Program.any_instance.stubs(:mentor_recommendation_enabled?).returns(true)
    mrs = MentorRecommendationsService.new(student)
    assert mrs.send(:show_recommendation_box?)
  end

  def test_should_not_show_recommendation_for_student_with_active_group
    program = programs(:albers)
    admin = users(:f_admin)
    student = users(:mkr_student)
    mentor = users(:f_mentor)
    Program.any_instance.stubs(:mentor_recommendation_enabled?).returns(true)
    setup_recommendation(program: program, admin: admin, student: student, mentor1: mentor)
    mrs = MentorRecommendationsService.new(student)
    assert_false mrs.send(:show_recommendation_box?)
  end

  def test_should_not_show_recommendation_connnection_limit_reached
    program = programs(:albers)
    admin = users(:f_admin)
    student = users(:mkr_student)
    mentor = users(:f_mentor)
    ram = users(:ram)
    robert = users(:robert)
    program.update_attribute(:max_connections_for_mentee, student.groups.active.count)
    setup_recommendation(program: program, admin: admin, student: student, mentor1: mentor, mentor2: ram, mentor3: robert)
    mrs = MentorRecommendationsService.new(student)
    assert_false mrs.send(:show_recommendation_box?)
  end

  def test_should_not_show_recommendation_pending_request_limit_reached
    rahim = users(:rahim)
    albers = programs(:albers)
    albers.update_attribute(:max_pending_requests_for_mentee, 1)
    mr = MentorRequest.new
    mr.program_id = albers.id
    mr.sender_id = rahim.id
    mr.receiver_id = users(:f_mentor_student).id
    mr.message = "hihih"
    mr.save
    mrs = MentorRecommendationsService.new(rahim)
    assert_false mrs.send(:show_recommendation_box?)
  end

  def test_should_not_show_recommendation_program_allow_mentoring_request_false
    Program.any_instance.stubs(:mentor_recommendation_enabled?).returns(true)
    rahim = users(:rahim)
    program = rahim.program
    mrs = MentorRecommendationsService.new(rahim)
    assert mrs.send(:show_recommendation_box?)
    program.allow_mentoring_requests = false
    program.save!
    rahim.reload
    assert_false mrs.send(:show_recommendation_box?)
  end

  def test_get_top_and_favorite_mentor_ids_for_ongoing_based_on_recommendation
    rahim = users(:rahim)
    mrs = MentorRecommendationsService.new(rahim)
    mrs.stubs(:get_top_and_favorite_mentor_ids_for_ongoing).with("available_mentors_ids", "mentors_score").returns("system recommendations")
    mrs.stubs(:reject_mentors_with_zero_score_for_preference_recommendations).with("available_mentors_ids", "mentors_score").returns("preference recommendations")
    mrs.stubs(:showing_system_recommendations).returns(false)
    assert_equal "preference recommendations", mrs.send(:get_top_and_favorite_mentor_ids_for_ongoing_based_on_recommendation, "available_mentors_ids", "mentors_score")
    mrs.stubs(:showing_system_recommendations).returns(true)
    assert_equal "system recommendations", mrs.send(:get_top_and_favorite_mentor_ids_for_ongoing_based_on_recommendation, "available_mentors_ids", "mentors_score")
  end

  def test_reject_mentors_with_zero_score_for_preference_recommendations
    rahim = users(:rahim)
    mrs = MentorRecommendationsService.new(rahim)
    assert_equal [1,2], mrs.send(:reject_mentors_with_zero_score_for_preference_recommendations, [1,2,3], {1 => 55, 2 => 90, 3 => 0})
    assert_equal [1,2,3], mrs.send(:reject_mentors_with_zero_score_for_preference_recommendations, [1,2,3], {})
  end

  def favourite_user_ids
    user = users(:mkr_student)
    program = user.program
    mrs = MentorRecommendationsService.new(user)
    program.stubs(:skip_and_favorite_profiles_enabled?).returns(false)
    UserPreferenceService.stubs(:get_favorite_user_ids_for).with(user).never
    assert mrs.send(:favourite_user_ids).empty?

    program.stubs(:skip_and_favorite_profiles_enabled?).returns(true)
    UserPreferenceService.stubs(:get_favorite_user_ids_for).with(user).once.returns("something")
    assert_equal "something", mrs.send(:favourite_user_ids)
  end

  def ignored_user_ids
    user = users(:mkr_student)
    program = user.program
    mrs = MentorRecommendationsService.new(user)
    program.stubs(:skip_and_favorite_profiles_enabled?).returns(false)
    UserPreferenceService.stubs(:get_ignored_user_ids_for).with(user).never
    assert mrs.send(:ignored_user_ids).empty?

    program.stubs(:skip_and_favorite_profiles_enabled?).returns(true)
    UserPreferenceService.stubs(:get_ignored_user_ids_for).with(user).once.returns("something")
    assert_equal "something", mrs.send(:ignored_user_ids)
  end

  def test_get_recommendations_for_mail
    user = users(:mkr_student)
    mrs = MentorRecommendationsService.new(user)
    mrs.stubs(:show_recommendation_box?).returns(false)
    user.stubs(:explicit_preferences_configured?).returns(false)
    mrs.stubs(:get_admin_recommendations).returns("admin_recommendations")
    mrs.stubs(:get_explicit_preference_recommendations).returns("explicit_preference_recommendations")
    mrs.stubs(:get_system_recommendations).returns("system_recommendations")

    assert_equal "system_recommendations", mrs.get_recommendations_for_mail

    mrs.stubs(:show_recommendation_box?).returns(true)
    assert_equal "admin_recommendations", mrs.get_recommendations_for_mail

    user.stubs(:explicit_preferences_configured?).returns(true)
    assert_equal "explicit_preference_recommendations", mrs.get_recommendations_for_mail
  end

  def test_get_explicit_preferences_recommended_user_ids
    user = users(:f_student)
    user.stubs(:explicit_preferences_configured?).returns(true)
    mrs = MentorRecommendationsService.new(user)
    MentorRecommendationsService::IndexedUserService.any_instance.stubs(:user_ids).returns([1])
    assert_equal [1], mrs.get_explicit_preferences_recommended_user_ids
  end

  private

  def setup_recommendation(options)

    #creating recommendation
    m = MentorRecommendation.new
    m.program = options[:program]
    m.sender = options[:admin]
    m.receiver = options[:student]
    m.status = options[:status] || MentorRecommendation::Status::PUBLISHED
    m.save!

    #creating recommendation preferences
    if options[:mentor1].present?
      p1 = m.recommendation_preferences.new
      p1.position = 1
      p1.preferred_user = options[:mentor1]
      p1.save!
    end

    if options[:mentor2].present?
      p2 = m.recommendation_preferences.new
      p2.position = 2
      p2.preferred_user = options[:mentor2]
      p2.save!
    end

    if options[:mentor3].present?
      p3 = m.recommendation_preferences.new
      p3.position = 3
      p3.preferred_user = options[:mentor3]
      p3.save!
    end
  end
end