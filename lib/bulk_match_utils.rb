module BulkMatchUtils
  include BulkMatchScoreUtils
  include MatchAdminViewUtils

  MAX_AVAILABLE_SLOTS = 100000

  def get_user_ids(admin_view, is_mentor = true)
    user_ids = admin_view.generate_view("", "",false).to_a
    MatchingDocument.where(:record_id => user_ids, :mentor => is_mentor).pluck(:record_id)
  end

  def compute_bulk_match_results(program, bulk_entry)
    @active_drafted_groups = program.groups.active_or_drafted.includes(:mentors => [:member], :students => [:member])
    @active_groups = program.groups.active.includes(:mentors => [:member], :students => [:member])
    @drafted_groups = program.groups.drafted.includes(:mentors => [:member], :students => [:member])
    compute_mentor_and_student_user_ids(program, bulk_entry)
    compute_bulk_match_data(program, bulk_entry)
  end

  def compute_mentor_and_student_user_ids(program, bulk_entry)
    user_record_hash = program.all_users.active_or_pending.includes(:member, :sent_mentor_offers, :mentoring_groups => [:students]).group_by(&:id)
    @student_user_ids = user_record_hash.keys & get_user_ids(bulk_entry.mentee_view, false)
    @mentor_user_ids = user_record_hash.keys & get_user_ids(bulk_entry.mentor_view, true)
  end

  def compute_bulk_match_data(program, bulk_entry, for_csv=false)
    @student_mentor_hash = Hash.new
    if @student_user_ids.present? && @mentor_user_ids.present?
      @mentor_users = User.where(:id => @mentor_user_ids).includes(:mentoring_groups, :member => [:profile_picture])
      @student_users = User.where(:id => @student_user_ids).includes(:member => [:profile_picture], :studying_groups => [:mentors => [:member]])

      @mentor_slot_hash = User.get_availability_slots_for(@mentor_user_ids)
      @group_or_recommendation_info = fetch_group_or_recommendation_status(program, bulk_entry, @mentor_user_ids, @student_user_ids)
      @pickable_slots, @recommended_count = fetch_mentor_available_pickable_slot_hash(bulk_entry, @mentor_user_ids, @group_or_recommendation_info)
      compute_results_based_on_orientation_type(program, bulk_entry) unless for_csv
    end
  end

  def compute_results_based_on_orientation_type(program, bulk_entry)
    bulk_entry.orientation_type == BulkMatch::OrientationType::MENTEE_TO_MENTOR ? compute_mentee_to_mentor_match_results(program, bulk_entry) : compute_mentor_to_mentee_match_results(program, bulk_entry)
  end

  def compute_mentee_to_mentor_match_results(program, bulk_entry)
    @student_mentor_hash, student_mentor_scores = compute_student_mentor_hash(program, @student_user_ids, @mentor_user_ids)
    @selected_mentors, @suggested_mentors = fetch_selected_suggested_mentors(bulk_entry, @group_or_recommendation_info, @student_mentor_hash, student_mentor_scores, get_args_for_matching(program))
  end

  def compute_mentor_to_mentee_match_results(program, bulk_entry)
    @mentor_student_hash, student_mentor_scores = compute_mentor_student_hash(program, @student_user_ids, @mentor_user_ids)
    @pickable_slots_for_mentees = fetch_pickable_slots_hash_for_students(bulk_entry, @student_user_ids, @group_or_recommendation_info)
    @selected_mentees, @suggested_mentees = fetch_selected_suggested_mentees(@group_or_recommendation_info, @mentor_student_hash, student_mentor_scores, get_args_for_matching(program))
  end

  private

  def fetch_bulk_match_groups(bulk_entry, mentor_user_ids, student_user_ids)
    group_info = Hash.new
    program = bulk_entry.program
    groups = Group.where(bulk_match_id: program.bulk_matches.pluck(:id))
    groups.active_or_drafted.includes([:mentor_memberships, :student_memberships]).each do |group|
      student_id, mentor_id = group.initial_student_mentor_pair
      if(mentor_user_ids.include?(mentor_id) && student_user_ids.include?(student_id))
        set_group_info(group, group_info, bulk_entry.orientation_type, student_id, mentor_id)
      end
    end
    return group_info
  end

  def set_group_info(group, group_info, orientation_type, student_id, mentor_id)
    if orientation_type == BulkMatch::OrientationType::MENTEE_TO_MENTOR
      group_info[student_id] = { group_id: group.id, status: group.status, mentor_list: [mentor_id] }
    else
      group_info[mentor_id] = { group_id: group.id, status: group.status, student_list: [student_id] }
    end
  end

  def fetch_group_or_recommendation_status(program, bulk_entry, mentor_user_ids, student_user_ids)
    if bulk_entry.is_a?(BulkRecommendation)
      fetch_bulk_recommendations_status(program, student_user_ids, mentor_user_ids)
    else
      fetch_bulk_match_groups(bulk_entry, mentor_user_ids, student_user_ids)
    end
  end

  def fetch_bulk_recommendations_status(program, student_user_ids, mentor_user_ids)
    recommendation_info = Hash.new
    program.mentor_recommendations.where(receiver_id: student_user_ids).includes(:recommendation_preferences).each do |mentor_recommendation|
      mentors_in_preference_order = mentor_recommendation.recommendation_preferences.select {|preference| mentor_user_ids.include?(preference.user_id)}.collect(&:user_id)
      if mentors_in_preference_order.present?
        recommendation_info[mentor_recommendation.receiver_id] = {
          status: mentor_recommendation.status,
          mentor_list: mentors_in_preference_order
        }
      end
    end
    return recommendation_info
  end

  def fetch_mentor_available_pickable_slot_hash(bulk_entry, mentor_user_ids, group_or_recommendation_info)
    pickable_slots = Hash.new
    recommend_mentors = bulk_entry.is_a?(BulkRecommendation)
    connections_count = get_connections_count_for_users(mentor_user_ids, bulk_entry, group_or_recommendation_info)
    mentor_user_ids.each do |user_id|
      pickable_slots[user_id] = get_max_pickable_slot(@mentor_slot_hash[user_id], bulk_entry.max_pickable_slots, connections_count[user_id], recommend_mentors, bulk_entry.orientation_type)
    end
    return pickable_slots, connections_count
  end

  def fetch_pickable_slots_hash_for_students(bulk_entry, student_user_ids, group_or_recommendation_info)
    pickable_slots_for_mentees = Hash.new
    connections_count = get_connections_count_for_users(student_user_ids, bulk_entry, group_or_recommendation_info, true)
    student_user_ids.each do |user_id|
      pickable_slots_for_mentees[user_id] = [0, bulk_entry.max_pickable_slots - connections_count[user_id]].max
    end
    return pickable_slots_for_mentees
  end

  def get_connections_count_for_users(user_ids, bulk_entry, group_or_recommendation_info, for_mentees = false)
    connections_count = Hash.new
    user_ids.each do |user_id|
      connections_count[user_id] = 0
    end
    if bulk_entry.orientation_type == BulkMatch::OrientationType::MENTEE_TO_MENTOR || for_mentees
      group_or_recommendation_info.values.each do |status_with_user_list|
        user_list = for_mentees ? status_with_user_list[:student_list] : status_with_user_list[:mentor_list]
        user_list.each do |user_id|
          connections_count[user_id] ||= 0
          connections_count[user_id] = connections_count[user_id] + 1
        end
      end
    else
      group_or_recommendation_info.keys.each do |user_id|
        connections_count[user_id] ||= 0
        connections_count[user_id] = connections_count[user_id] + 1
      end
    end
    connections_count
  end

  def slots_available_for(user, pending_mentor_offers, active_drafted_groups)
    [user.max_connections_limit -
    ((user.mentoring_groups & active_drafted_groups).collect(&:students).flatten.size +
      (user.sent_mentor_offers & pending_mentor_offers).size), 0].max
  end

  def compute_student_mentor_hash(program, student_user_ids, mentor_user_ids)
    student_mentor_hash = get_normalized_student_mentor_score_details(program, student_user_ids, mentor_user_ids)
    student_mentor_hash.each_pair do |key, value|
      student_mentor_hash[key] = value.slice(*mentor_user_ids).sort_by{|ary| User.priority_array_for_match_score_sorting(ary[1], @mentor_slot_hash[ary[0]]) }
    end
    student_mentor_scores = get_sorted_student_mentor_scores(student_mentor_hash)
    return student_mentor_hash, student_mentor_scores
  end

  def get_normalized_student_mentor_score_details(program, student_user_ids, mentor_user_ids)
    min_max_match_score = get_min_max_match_score(program)
    ScoreNormalizer.normalize_for(student_user_ids, mentor_user_ids, min_max_match_score)
  end

  def get_sorted_student_mentor_scores(student_mentor_hash)
    student_mentor_scores = []
    student_mentor_hash.each do |student_id, mentor_id_and_score_list|
      mentor_id_and_score_list.each do |mentor_id, score|
        student_mentor_scores << [student_id, mentor_id, score]
      end
    end
    student_mentor_scores.sort_by{|x| User.priority_array_for_match_score_sorting(x[2], @mentor_slot_hash[x[1]]) << (-x[1]) }
  end

  def compute_mentor_student_hash(program, student_user_ids, mentor_user_ids)
    student_mentor_hash = get_normalized_student_mentor_score_details(program, student_user_ids, mentor_user_ids)
    mentor_student_hash = build_mentor_student_score_hash(student_mentor_hash)
    mentor_student_hash.each_pair do |key, value|
      mentor_student_hash[key] = value.slice(*student_user_ids).sort_by{|ary| ary[1]}.reverse
    end
    student_mentor_scores = get_sorted_student_mentor_scores(student_mentor_hash)
    return mentor_student_hash, student_mentor_scores
  end

  def build_mentor_student_score_hash(student_mentor_hash)
    mentor_student_hash = {}
    student_mentor_original_hash = student_mentor_hash.deep_dup
    student_mentor_original_hash.each do |student_id, mentor_id_and_score_list|
      mentor_id_and_score_list.each do |mentor_id, score|
        mentor_student_hash[mentor_id] ||= {}
        mentor_student_hash[mentor_id][student_id] = score
      end
    end
    return mentor_student_hash
  end

  def get_min_max_match_score(program)
    match_setting = program.match_setting
    [match_setting.min_match_score, match_setting.max_match_score]
  end

  def fetch_selected_suggested_mentors(bulk_entry, group_or_recommendation_info, student_mentor_hash, student_mentor_scores, args_for_matching)
    selected_mentors = Hash.new
    suggested_mentors = Hash.new
    selection_count = bulk_entry.max_suggestion_count || 1
    student_mentor_scores.each do |student_id, mentor_id, score|
      suggested_mentors[student_id] ||= student_mentor_hash[student_id]
      selected_mentors[student_id] ||= []
      if(selection_count - selected_mentors[student_id].length > 0)
        if !group_or_recommendation_info[student_id].present? || selected_mentors[student_id].length == 0
          selected_mentors[student_id] += select_default_mentors(student_id, mentor_id, score, group_or_recommendation_info, args_for_matching)
        end
      end
      selected_mentors[student_id] = selected_mentors[student_id] & suggested_mentors[student_id].collect(&:first)
    end
    return selected_mentors, suggested_mentors
  end

  def fetch_selected_suggested_mentees(group_or_recommendation_info, mentor_student_hash, student_mentor_scores, args_for_matching)
    selected_mentees = Hash.new
    suggested_mentees = Hash.new
    student_mentor_scores.each do |student_id, mentor_id, score|
      suggested_mentees[mentor_id] ||= mentor_student_hash[mentor_id]
      selected_mentees[mentor_id] ||= []
      if selected_mentees[mentor_id].length == 0
        selected_mentees[mentor_id] = select_default_mentee(student_id, mentor_id, score, group_or_recommendation_info, args_for_matching)
      end
    end
    return selected_mentees, suggested_mentees
  end

  def get_max_pickable_slot(slots_available, max_slot_setting, connections_count, recommend_mentors, orientation_type)
    return [0, slots_available].max if orientation_type == BulkMatch::OrientationType::MENTOR_TO_MENTEE
    pickable_slots_in_bulk_match = [0, max_slot_setting-connections_count].max if max_slot_setting.present?
    if recommend_mentors
      pickable_slots = max_slot_setting.present? ? pickable_slots_in_bulk_match : [MAX_AVAILABLE_SLOTS-connections_count,0].max
    else
      pickable_slots = max_slot_setting.present? ? [slots_available, pickable_slots_in_bulk_match].min : slots_available
    end
    return pickable_slots
  end

  def select_default_mentors(student_id, mentor_id, score, group_or_recommendation_info, options = {})
    mentor_id_list = []
    if group_or_recommendation_info[student_id].present?
      mentor_id_list = group_or_recommendation_info[student_id][:mentor_list]
    elsif can_show_mentor_as_default_selection?(student_id, mentor_id, score, options)
      options[:pickable_slots][mentor_id] = options[:pickable_slots][mentor_id] - 1
      options[:recommended_count][mentor_id] = options[:recommended_count][mentor_id] + 1
      mentor_id_list = [mentor_id]
    end
    mentor_id_list
  end

  def select_default_mentee(student_id, mentor_id, score, group_or_recommendation_info, options = {})
    student_list = []
    if group_or_recommendation_info[mentor_id].present?
      student_list = group_or_recommendation_info[mentor_id][:student_list]
    elsif can_show_mentee_as_default_selection?(student_id, mentor_id, score, options)
      options[:pickable_slots_for_mentees][student_id] = options[:pickable_slots_for_mentees][student_id] - 1
      student_list = [student_id]
    end
    student_list
  end

  def can_show_mentee_as_default_selection?(student_id, mentor_id, score, options = {})
    score > 0 && (mentor_id != student_id) && options[:pickable_slots][mentor_id] > 0 && options[:pickable_slots_for_mentees][student_id] > 0
  end

  def can_show_mentor_as_default_selection?(student_id, mentor_id, score, options = {})
    (!options[:consider_mentoring_mode] || !options[:mentors_preferring_one_time_mentoring].include?(mentor_id)) &&score > 0 && (mentor_id != student_id) && options[:pickable_slots][mentor_id] > 0
  end

  def get_args_for_matching(program)
    args_for_matching = {
      consider_mentoring_mode: program.consider_mentoring_mode?,
      mentors_preferring_one_time_mentoring: @mentor_users.where(:mentoring_mode => User::MentoringMode::ONE_TIME).pluck(:id),
      pickable_slots: @pickable_slots,
      recommended_count: @recommended_count,
      pickable_slots_for_mentees: @pickable_slots_for_mentees
    }
    args_for_matching
  end
end