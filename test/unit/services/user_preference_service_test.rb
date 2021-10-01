require_relative './../../test_helper.rb'

class UserPreferenceServiceTest < ActiveSupport::TestCase

  def test_initialize
    user = users(:f_student)
    ups = UserPreferenceService.new(user)
    assert_equal user, ups.user

    user = users(:f_admin)
    ups = UserPreferenceService.new(user)
    assert_equal user, ups.user
  end

  def test_get_favorite_preferences_hash
    user = users(:f_student)
    ups = UserPreferenceService.new(user)
    assert_equal_hash({users(:f_mentor).id=>abstract_preferences(:favorite_1).id, users(:robert).id=>abstract_preferences(:favorite_3).id}, ups.get_favorite_preferences_hash)

    user = users(:f_admin)
    ups = UserPreferenceService.new(user)
    assert_equal_hash({}, ups.get_favorite_preferences_hash)

    user = users(:f_mentor)
    ups = UserPreferenceService.new(user)
    assert_equal_hash({}, ups.get_favorite_preferences_hash)

    user = users(:mkr_student)
    ups = UserPreferenceService.new(user)
    assert_equal_hash({}, ups.get_favorite_preferences_hash)
  end

  def test_get_ignore_preferences_hash
    user = users(:f_student)
    ups = UserPreferenceService.new(user)
    assert_equal_hash({users(:f_mentor).id=>abstract_preferences(:ignore_1).id, users(:ram).id=>abstract_preferences(:ignore_3).id}, ups.get_ignore_preferences_hash)

    user = users(:f_admin)
    ups = UserPreferenceService.new(user)
    assert_equal_hash({}, ups.get_ignore_preferences_hash)

    user = users(:f_mentor)
    ups = UserPreferenceService.new(user)
    assert_equal_hash({}, ups.get_ignore_preferences_hash)

    user = users(:mkr_student)
    ups = UserPreferenceService.new(user)
    assert_equal_hash({}, ups.get_ignore_preferences_hash)
  end

  def test_find_available_favorite_users
    user = users(:f_student)
    ups = UserPreferenceService.new(user, request_type: UserPreferenceService::RequestType::MEETING)
    
    MentorRecommendationsService.stubs(:reject_mentors_connected_to_mentee).with(user, user.program, [ users(:robert).id]).returns([ users(:robert).id])
    ups.stubs(:available_favorites_based_on_request_type).with([ users(:robert).id]).returns([users(:robert)])
    assert_equal [users(:robert)], ups.send(:find_available_favorite_users)

    ups = UserPreferenceService.new(user, request_type: UserPreferenceService::RequestType::GROUP)
    
    MentorRecommendationsService.stubs(:reject_mentors_connected_to_mentee).with(user, user.program, [ users(:robert).id]).returns([ users(:robert).id])
    ups.stubs(:available_favorites_based_on_request_type).with([ users(:robert).id]).returns([users(:robert)])
    assert_equal [users(:robert)], ups.send(:find_available_favorite_users)
    
    ups = UserPreferenceService.new(user, request_type: UserPreferenceService::RequestType::MEETING)
    
    MentorRecommendationsService.stubs(:reject_mentors_connected_to_mentee).with(user, user.program, [users(:robert).id]).returns([users(:robert).id])
    ups.stubs(:available_favorites_based_on_request_type).with([users(:robert).id]).returns([])
    assert_equal [], ups.send(:find_available_favorite_users)

    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(false)
    MentorRecommendationsService.stubs(:reject_mentors_connected_to_mentee).with(user, user.program, [ users(:robert).id, users(:f_mentor).id]).returns([ users(:robert).id])
    ups.stubs(:available_favorites_based_on_request_type).with([ users(:robert).id]).returns([users(:robert)])
  end

  def test_available_favorites_based_on_request_type
    user = users(:f_student)
    ups = UserPreferenceService.new(user, request_type: UserPreferenceService::RequestType::MEETING)
    ups.stubs(:available_favorites_for_meetings).with([users(:f_mentor).id, users(:robert).id]).returns([users(:f_mentor)])
    assert_equal [users(:f_mentor)], ups.send(:available_favorites_based_on_request_type, [users(:f_mentor).id, users(:robert).id])

    ups = UserPreferenceService.new(user, request_type: UserPreferenceService::RequestType::GROUP)
    ups.stubs(:available_favorites_for_groups).with([users(:f_mentor).id, users(:robert).id]).returns([users(:f_mentor)])
    assert_equal [users(:f_mentor)], ups.send(:available_favorites_based_on_request_type, [users(:f_mentor).id, users(:robert).id])
  end

  def test_available_favorites_for_groups
    user = users(:f_student)
    ups = UserPreferenceService.new(user, request_type: UserPreferenceService::RequestType::MEETING)
    ups.stubs(:get_mentors_with_slots!).with(programs(:albers), [users(:f_mentor).id, users(:robert).id]).returns({users(:f_mentor).id => 2, users(:robert).id => 3})
    User.stubs(:get_availability_slots_for).with([users(:f_mentor).id, users(:robert).id]).returns({users(:f_mentor).id => "2", users(:robert).id => "3"})
    assert_equal [users(:f_mentor), users(:robert)], ups.send(:available_favorites_for_groups, [users(:f_mentor).id, users(:robert).id])

    ups = UserPreferenceService.new(user, request_type: UserPreferenceService::RequestType::GROUP)
    ups.stubs(:get_mentors_with_slots!).with(programs(:albers), [users(:f_mentor).id, users(:robert).id]).returns({users(:f_mentor).id => 2, users(:robert).id => 3})
    User.stubs(:get_availability_slots_for).with([users(:f_mentor).id, users(:robert).id]).returns({users(:f_mentor).id => "2", users(:robert).id => "3"})
    assert_equal [users(:f_mentor), users(:robert)], ups.send(:available_favorites_for_groups, [users(:f_mentor).id, users(:robert).id])
  end

  def test_available_favorites_for_meetings
    user = users(:f_student)
    ups = UserPreferenceService.new(user, request_type: UserPreferenceService::RequestType::MEETING)
    member = user.member
    time_now = Time.now
    Time.stubs(:now).returns(time_now)
    start_time = time_now.in_time_zone(member.get_valid_time_zone)
    user.stubs(:is_max_capacity_program_reached?).with(start_time, user).returns(true)
    assert_equal [], ups.send(:available_favorites_for_meetings, [users(:f_mentor).id, users(:robert).id])

    time_now = Time.now
    Time.stubs(:now).returns(time_now)
    start_time = time_now.in_time_zone(member.get_valid_time_zone)
    user.stubs(:is_max_capacity_program_reached?).with(start_time, user).returns(false)
    user_ids_arr = [users(:f_mentor).id, users(:robert).id]
    user.stubs(:generate_mentor_suggest_hash).with(user.program, user_ids_arr, Meeting::Interval::MONTH, user, {items_size: MentorRecommendationsService::TOP_N_MENTORS_THRESHOLD}).returns([{member: users(:f_mentor).member}, {member: users(:robert).member}])
    assert_equal [users(:f_mentor), users(:robert)], ups.send(:available_favorites_for_meetings, [users(:f_mentor).id, users(:robert).id])

    ups = UserPreferenceService.new(user, request_type: UserPreferenceService::RequestType::GROUP)
    user.stubs(:generate_mentor_suggest_hash).with(user.program, user_ids_arr, Meeting::Interval::MONTH, user, {items_size: MentorRecommendationsService::TOP_N_MENTORS_THRESHOLD}).returns([{member: users(:f_mentor).member}, {member: users(:robert).member}])
    assert_equal [users(:f_mentor), users(:robert)], ups.send(:available_favorites_for_meetings, [users(:f_mentor).id, users(:robert).id])
  end

  def test_get_favorite_user_ids_for
    assert_equal [], UserPreferenceService.get_favorite_user_ids_for(users(:f_admin))
    assert_equal [users(:f_mentor).id, users(:robert).id], UserPreferenceService.get_favorite_user_ids_for(users(:f_student))
    assert_equal [users(:ram).id], UserPreferenceService.get_favorite_user_ids_for(users(:rahim))
  end

  def test_get_ignored_user_ids_for
    assert_equal [], UserPreferenceService.get_ignored_user_ids_for(users(:f_admin))
    assert_equal [users(:f_mentor).id, users(:ram).id], UserPreferenceService.get_ignored_user_ids_for(users(:f_student))
    assert_equal [users(:robert).id], UserPreferenceService.get_ignored_user_ids_for(users(:rahim))
  end
end