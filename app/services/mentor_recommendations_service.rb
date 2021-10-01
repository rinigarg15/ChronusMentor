class MentorRecommendationsService
  include UserListingExtensions

  DEFAULT_RECOMMENDATIONS_COUNT = 3
  TOP_N_MENTORS_THRESHOLD = 15  

  module RecommendationsFor
    BOTH = "both"
    FLASH = "flash"
    ONGOING = "ongoing"
  end

  module RecommendationCategory
    ADMIN_RECOMMENDATIONS = "admin_recommendations"
    SYSTEM_RECOMMENDATIONS = "system_recommendations"
    EXPLICIT_PREFERENCE_RECOMMENDATIONS = "explicit_preference_recommendations"
  end

  attr_accessor :mentee, :program, :recommendations_for, :recommendations_count, :only_favorite_and_top_matches, :showing_system_recommendations, :favorite_mentor_recommendations, :showing_explicit_preference_recommendations, :recommendation_category, :ignore_mentors

  def initialize(mentee, options={})
    @mentee = mentee
    @program = mentee.program
    @ignore_mentors = []
    @recommendations_for = options[:recommendations_for] || get_recommendations_type
    @recommendations_count = options[:recommendations_count] || DEFAULT_RECOMMENDATIONS_COUNT
    @only_favorite_and_top_matches = options[:only_favorite_and_top_matches] || false
  end

  def get_recommendations(type, ignore_mentors = [])
    @recommendation_category = type
    @ignore_mentors = ignore_mentors
    case type
    when RecommendationCategory::ADMIN_RECOMMENDATIONS
      recommendations = check_and_get_admin_recommendations
    when RecommendationCategory::SYSTEM_RECOMMENDATIONS
      recommendations = get_system_recommendations
    when RecommendationCategory::EXPLICIT_PREFERENCE_RECOMMENDATIONS
      recommendations = check_and_get_explicit_preference_recommendations
      # do nothing
    end
    recommendations || []
  end

  def get_recommendations_for_mail
    recommendations = check_and_get_explicit_preference_recommendations
    recommendations = check_and_get_admin_recommendations if recommendations.blank?
    recommendations = get_system_recommendations if recommendations.blank?
    recommendations || []
  end

  def check_and_get_admin_recommendations
    get_admin_recommendations if show_recommendation_box?
  end

  def check_and_get_explicit_preference_recommendations
    get_explicit_preference_recommendations if mentee.explicit_preferences_configured?
  end

  def get_explicit_preference_recommendations
    @recommendation_category = RecommendationCategory::EXPLICIT_PREFERENCE_RECOMMENDATIONS
    @showing_explicit_preference_recommendations = true
    get_recommended_mentors_list(get_explicit_preferences_recommended_user_ids)
  end

  def get_explicit_preferences_recommended_user_ids
    IndexedUserService.new.get_recommended_user_ids(mentee)
  end

  def get_system_recommendations
    @showing_system_recommendations = true
    get_recommended_mentors_list
  end

  def get_recommended_mentors_list(selected_mentors = nil)
    active_mentor_ids = program.mentor_users.active.pluck(:id) - ignore_mentors
    mentors_ids_with_slots = get_mentors_with_slots!(program, active_mentor_ids).keys - ignore_mentors
    unless selected_mentors.nil?
      active_mentor_ids = active_mentor_ids & selected_mentors
      mentors_ids_with_slots = mentors_ids_with_slots & selected_mentors
    end
    get_mentors_list_for_quick_connect_box(active_mentor_ids, mentors_ids_with_slots, selected_mentors)
  end

  def self.get_class_for_recommended_for(recommended_for)
    recommended_for == RecommendationsFor::FLASH ? AbstractRequest::MEETING_REQUEST : AbstractRequest::MENTOR_REQUEST
  end

  def get_match_info_for(selected_mentors)
    match_info = []
    selected_mentors.each do |mentor_hash|
      mentor_user = mentor_hash[:member].user_in_program(program)
      program_questions_for_user = mentee.get_visibile_match_config_profile_questions_for(mentor_user)
      match_info << mentee.get_match_details_of(mentor_user, program_questions_for_user).collect{|tag| tag[:answers]}.flatten
    end
    match_info
  end

  def show_view_favorites_button?
    (showing_system_recommendations || showing_explicit_preference_recommendations) && favorite_mentor_recommendations.size > recommendations_count
  end

  def self.reject_mentors_connected_to_mentee(mentee, program, all_mentor_ids)
    mentors_of_user_ids = mentee.mentors(:all).collect(&:id)
    users_connected_via_meetings_ids = self.get_flash_mentor_ids_of_mentee(mentee, program)
    mentor_request_user_ids = mentee.sent_mentor_requests.pluck(:receiver_id)
    meeting_request_user_ids = mentee.sent_meeting_requests.pluck(:receiver_id)
    users_ids_to_be_ignored = mentors_of_user_ids + users_connected_via_meetings_ids + mentor_request_user_ids + meeting_request_user_ids + [mentee.id]
    all_mentor_ids - users_ids_to_be_ignored
  end

  class IndexedUserService
    include UserSearch
    attr :user_ids
    def get_recommended_user_ids(mentee)
      @current_program = mentee.program
      @current_user = mentee
      get_indexed_users({quick_connect_recommendations: true})
      user_ids
    end
  end

  private

  def get_recommendations_type
    if program.only_one_time_mentoring_enabled?
      RecommendationsFor::FLASH
    elsif program.ongoing_mentoring_enabled? && program.calendar_enabled?
      RecommendationsFor::BOTH
    else
      RecommendationsFor::ONGOING
    end
  end

  def show_recommendation_box?
    return false unless (mentee.show_recommended_ongoing_mentors? && program.mentor_recommendation_enabled? && mentee.published_mentor_recommendation.present?)
    @recommendation_preferences = mentee.published_mentor_recommendation.recommendation_preferences
    filtered_recommendation_preference_user_ids.present?
  end

  def filtered_recommendation_preference_user_ids
    recommendation_preference_user_ids = @recommendation_preferences.pluck(:user_id)
    mentor_ids = MentorRecommendationsService.reject_mentors_connected_to_mentee(mentee, program, recommendation_preference_user_ids)
    mentor_ids = program.users.active.where(id: mentor_ids).pluck(:id)
    mentor_ids -= ignored_user_ids
    availability_of_user_id_hsh = User.get_availability_slots_for(mentor_ids)
    @filtered_recommendation_preference_ids = availability_of_user_id_hsh.collect {|k,v| k if v != 0}.compact
  end

  def get_admin_recommendations
    recommendations = []
    filtered_recommendation_preferences = @recommendation_preferences.where(user_id: @filtered_recommendation_preference_ids).includes([preferred_user: :member])
    filtered_recommendation_preferences.each do |recommendation_preference|
      recommendations << {member: recommendation_preference.preferred_user.member, recommendation_preference: recommendation_preference, user: recommendation_preference.preferred_user, recommended_for: recommendations_for}
    end
    recommendations
  end

  def get_mentors_list_for_quick_connect_box(active_mentor_ids, mentors_ids_with_slots, sort_order =nil)
    document_available = mentee.student_document_available?
    mentors_score = document_available ? mentee.student_cache_normalized : {}

    mentors_for_connection = get_recommendations_for_ongoing_connections? ? get_mentors_recommendations_for_ongoing(mentors_score, mentors_ids_with_slots) : []
    mentors_for_meeting = get_recommendations_for_flash_connections? ? get_mentor_recommendations_for_flash(mentors_score, active_mentor_ids, document_available) : []
    member_ids = (mentors_for_connection||[]).collect{|hash| hash[:member].id} + (mentors_for_meeting||[]).collect{|hash| hash[:member].id}
    all_active_mentors_hash = program.mentor_users.where(member_id: member_ids).active.includes([:profile_views, :groups, member: [:accepted_flash_meetings]]).index_by(&:member_id)
    get_combined_mentors_list(mentors_for_meeting, mentors_for_connection, all_active_mentors_hash, sort_order)
  end

  def get_mentors_recommendations_for_ongoing(mentors_score, mentors_ids_with_slots)
    if can_recommend_mentors_for_connections?(mentors_ids_with_slots)
      available_mentors_ids = MentorRecommendationsService.reject_mentors_connected_to_mentee(mentee, program, mentors_ids_with_slots)
      top_and_favorite_mentor_ids = get_top_and_favorite_mentor_ids_for_ongoing_based_on_recommendation(available_mentors_ids, mentors_score)
      User.where(id: top_and_favorite_mentor_ids).
           includes([:user_setting, :member => [:mentoring_slots], :roles => :permissions]).
           map{|u| {score: mentors_score[u.id], member: u.member, user: u}}
    end
  end

  def get_top_and_favorite_mentor_ids_for_ongoing_based_on_recommendation(available_mentors_ids, mentors_score)
    showing_system_recommendations ? get_top_and_favorite_mentor_ids_for_ongoing(available_mentors_ids, mentors_score) : reject_mentors_with_zero_score_for_preference_recommendations(available_mentors_ids, mentors_score)
  end

  def get_top_and_favorite_mentor_ids_for_ongoing(available_mentors_ids, mentors_score)
    top_mentor_ids = select_top_mentors_for_connection_recommendations(available_mentors_ids, mentors_score)
    favourite_mentor_ids = reject_mentors_below_match_threshold(available_mentors_ids & favourite_user_ids, mentors_score)
    (top_mentor_ids + favourite_mentor_ids).uniq
  end

  def get_mentor_recommendations_for_flash(mentors_score, active_mentor_ids, document_available)
    if mentee.can_render_meetings_for_quick_connect_box?
      available_mentor_ids = MentorRecommendationsService.reject_mentors_connected_to_mentee(mentee, program, active_mentor_ids)
      get_top_and_favorite_mentor_ids_for_flash(available_mentor_ids, mentors_score, document_available)
    end
  end

  def get_top_and_favorite_mentor_ids_for_flash(available_mentor_ids, mentors_score, document_available)
    interval = Meeting::Interval::MONTH
    reject_zero_score_mentors = showing_system_recommendations ? nil : true
    top_mentors_for_flash = mentee.generate_mentor_suggest_hash(program, available_mentor_ids - favourite_user_ids, interval, mentee, mentors_score: mentors_score, items_size: TOP_N_MENTORS_THRESHOLD, reject: document_available, skip_explicit_preferences: true, reject_zero_score_mentors: reject_zero_score_mentors, quick_connect: true)
    favourite_mentor_ids = available_mentor_ids & favourite_user_ids
    favorite_mentors_for_flash = mentee.generate_mentor_suggest_hash(program, favourite_mentor_ids, interval, mentee, mentors_score: mentors_score, items_size: TOP_N_MENTORS_THRESHOLD, reject: document_available, skip_explicit_preferences: true, reject_zero_score_mentors: reject_zero_score_mentors, quick_connect: true)
    top_mentors_for_flash + favorite_mentors_for_flash
  end

  def get_recommendations_for_ongoing_connections?
    [RecommendationsFor::BOTH, RecommendationsFor::ONGOING].include?(recommendations_for)
  end

  def get_recommendations_for_flash_connections?
    [RecommendationsFor::BOTH, RecommendationsFor::FLASH].include?(recommendations_for)
  end

  def self.get_flash_mentor_ids_of_mentee(mentee, program)
    meetings = program.meetings.non_group_meetings.where(mentee_id: mentee.member_id)
    mentor_member_ids = MemberMeeting.where(meeting_id: meetings.pluck(:id)).pluck(:member_id) - [mentee.member_id]
    program.users.where(member_id: mentor_member_ids).pluck(:id)
  end

  def can_recommend_mentors_for_connections?(mentors_ids_with_slots)
    mentee.can_render_mentors_for_connection_in_quick_connect_box? && !mentee.pending_request_limit_reached_for_mentee? && mentors_ids_with_slots.present? && program.allow_mentoring_requests?
  end

  def select_top_mentors_for_connection_recommendations(mentor_ids, mentors_score)
    mentor_ids = get_top_mentor_ids_based_on_score(mentor_ids, mentors_score)
    availability_of_user_id_hsh = User.get_availability_slots_for(mentor_ids)
    mentor_ids.sort_by{|user_id| User.priority_array_for_match_score_sorting(mentors_score[user_id], availability_of_user_id_hsh[user_id])}.first(TOP_N_MENTORS_THRESHOLD)
  end

  def reject_mentors_below_match_threshold(mentor_ids, mentors_score)
    mentor_ids.reject{|user_id| mentors_score[user_id].to_i < Meeting::QuickConnect::MATCH_SCORE_THRESHOLD}
  end

  def reject_mentors_with_zero_score_for_preference_recommendations(mentor_ids, mentors_score)
    mentors_score.present? ? mentor_ids.reject{|user_id| mentors_score[user_id].to_i == 0} : mentor_ids
  end

  def get_top_mentor_ids_based_on_score(mentor_ids, mentors_score)
    # Sort by Mentor score, reject mentors having score < score of the last TOP_N_MENTORS_THRESHOLD user or < MATCH_SCORE_THRESOLD
    mentor_ids = mentor_ids.sort_by{|user_id| [-1 * mentors_score[user_id].to_i] }
    last_selected_mentor_score = (mentors_score[mentor_ids[TOP_N_MENTORS_THRESHOLD - 1]] || mentors_score.values.last).to_i
    mentor_ids.reject!{|user_id| mentors_score[user_id].to_i < Meeting::QuickConnect::MATCH_SCORE_THRESHOLD || mentors_score[user_id].to_i < last_selected_mentor_score}
    mentor_ids
  end

  def get_combined_mentors_list(mentors_for_meeting, mentors_for_connection, mentors_hash, sort_order = nil)
    combined_mentors = {}
    combined_mentors = add_mentors_for_meetings_to_combined_list(combined_mentors, mentors_for_meeting, mentors_hash)

    mentors_for_connection_ary = Array(mentors_for_connection)
    availability_of_user_id_hsh = User.get_availability_slots_for(mentors_for_connection_ary.map{|hsh| hsh[:member].id })

    combined_mentors = add_mentors_for_connection_to_combined_list(combined_mentors, mentors_for_connection_ary, availability_of_user_id_hsh, mentors_hash)
    final_list = combined_mentors.values
    @favorite_mentor_recommendations = final_list.select{|hsh| hsh[:is_favorite]}
    sort_mentor_list_by_recommendation_type(final_list, sort_order).first(recommendations_count)
  end

  def sort_mentor_list_by_recommendation_type(final_list, sort_order)
    unless showing_system_recommendations
      final_list.sort_by! { |hsh| sort_order.index(hsh[:user][:id]) } if sort_order.present?
    else
      final_list.sort_by! { |hsh| -(hsh[:recommendation_score]||0) }
    end
    final_list
  end

  def add_mentors_for_meetings_to_combined_list(combined_mentors, mentors_for_meeting, mentors_hash)
    users_list = program.users.where(member_id: Array(mentors_for_meeting).collect{|m| m[:member][:id]}).index_by(&:member_id)
    Array(mentors_for_meeting).each do |mentor|
      member_id = mentor[:member].id
      mentor_user = mentors_hash[member_id]
      combined_mentors[member_id] ||= {}
      combined_mentors[member_id][:member] = mentor[:member]
      combined_mentors[member_id][:user] = users_list[mentor[:member][:id]]
      combined_mentors[member_id][:max_score] = mentor[:score].to_i
      combined_mentors[member_id][:recommendation_score] = compute_recommendation_score(mentor[:score], mentor_user)
      combined_mentors[member_id][:availability] = mentor[:availability]
      combined_mentors[member_id][:recommended_for] = MentorRecommendationsService::RecommendationsFor::FLASH
      combined_mentors[member_id][:is_favorite] = is_favorite_mentor?(mentor_user)
    end
    return combined_mentors
  end

  def add_mentors_for_connection_to_combined_list(combined_mentors, mentors_for_connection_ary, availability_of_user_id_hsh, mentors_hash)
    mentors_for_connection_ary.each do |mentor|
      member_id = mentor[:member].id
      combined_mentors[member_id] ||= {}
      combined_mentors[member_id][:member] = mentor[:member]
      combined_mentors[member_id][:user] = mentor[:user]
      combined_mentors[member_id][:slots_availabile_for_mentoring] = availability_of_user_id_hsh[member_id]
      combined_mentors[member_id][:is_favorite] = is_favorite_mentor?(mentor[:user])
      set_max_score_for_combined_list(combined_mentors, member_id, mentor, mentors_hash)
    end
    return combined_mentors
  end

  def set_max_score_for_combined_list(combined_mentors, member_id, mentor, mentors_hash)
    if mentor[:score].to_i >= combined_mentors[member_id][:max_score].to_i
      combined_mentors[member_id][:max_score] = mentor[:score].to_i
      combined_mentors[member_id][:recommendation_score] = compute_recommendation_score(mentor[:score], mentors_hash[member_id])
      combined_mentors[member_id][:recommended_for] = MentorRecommendationsService::RecommendationsFor::ONGOING
    end
  end

  def compute_recommendation_score(match_score, mentor)
    if only_favorite_and_top_matches
      favorite_score = is_favorite_mentor?(mentor) ? 100 : 0
      match_score.to_i + favorite_score
    else
      compute_recommendation_score_for_advanced_matches(match_score, mentor)      
    end
  end

  def compute_recommendation_score_for_advanced_matches(match_score, mentor)
    member = mentor.member
    m_score = match_score.to_f / 100.0
    p_score = get_user_profile_views_score(mentor)
    t_score = get_member_terms_and_conditions_score(member)
    c_score = get_user_connections_score(mentor, member)
    f_score = get_favorite_score(mentor)
    10.0*m_score + p_score + t_score + 2*c_score + 2*f_score
  end

  def get_user_profile_views_score(mentor)
    [1.0, mentor.profile_views.select{|view| view.created_at >= 3.months.ago}.size / 3.0].min
  end

  def get_member_terms_and_conditions_score(member)
    (member.terms_and_conditions_accepted && (member.terms_and_conditions_accepted > 1.month.ago)) ? 1.0 : 0.0
  end

  def get_user_connections_score(mentor, member)
    mentor.groups.size + member.accepted_flash_meetings.size > 0 ? 0.0 : 1.0
  end

  def get_favorite_score(mentor)
    is_favorite_mentor?(mentor) ? 1.0 : 0.0
  end

  def is_favorite_mentor?(mentor)
    favourite_user_ids.include?(mentor.id)
  end

  def favourite_user_ids
    @favourite_user_ids ||= program.skip_and_favorite_profiles_enabled? ? UserPreferenceService.get_favorite_user_ids_for(mentee) : []
  end

  def ignored_user_ids
    @ignored_user_ids ||= program.skip_and_favorite_profiles_enabled? ? UserPreferenceService.get_ignored_user_ids_for(mentee) : []
  end
end