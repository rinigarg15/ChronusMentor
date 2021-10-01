module MeetingMentorSuggest
  include UserSearch
  def generate_mentor_suggest_hash(program, user_ids, interval, viewing_user, options = {})
    available_slots = generate_slots_or_meeting_preference_per_mentor(program, user_ids, viewing_user, interval, options[:items_size], options[:mentors_score], from_weekly_updates: options[:from_weekly_updates], skip_explicit_preferences: options[:skip_explicit_preferences], quick_connect: options[:quick_connect])
    return prepare_suggest_hash(available_slots, options[:items_size], options[:reject], options[:reject_zero_score_mentors])
  end

  def generate_slots_or_meeting_preference_per_mentor(program, user_ids_array, user, interval, items_size, match_scores = nil, options={})
    return [] unless user_ids_array.any?
    available_slots = []
    # Ideally should be for_each, but that will fire the query again - decreases memory footprint at cost of increased time
    # If using for_each - remove mentor_users cache in UserController#send_weekly_updates_to_users
    if program.has_general_availability?
      set_desired_variables(program, user)
      get_indexed_users({}, items_size, from_weekly_updates: options[:from_weekly_updates], only_flash_users: true, applicable_user_ids: user_ids_array, skip_explicit_preferences: options[:skip_explicit_preferences], quick_connect: options[:quick_connect])
      @users.each do |user|
        next unless user_ids_array.include?(user.id)
        available_slots << {:member => user.member, :new_meeting_params => {:score => @match_results.present? ? @match_results[user.id] : nil}}
      end
      return available_slots
    else
      includes_options = [[:user_setting, member: [:mentoring_slots], roles: :permissions], program: :calendar_setting]
      User.where(id: user_ids_array).includes(includes_options).each do |mentor|
        if mentor != user && mentor.ask_to_set_availability? && mentor.opting_for_one_time_mentoring?(program)
          score = match_scores.present? ? match_scores[mentor.id] : nil
          available_slots << mentor.member.get_next_available_slots(program, interval, user, nil, nil, :score => score, :load_member => true, :mentor_user => mentor).first
        end
      end
      return MentoringSlot.sort_slots!(available_slots.compact)
    end
  end

  def prepare_suggest_hash(available_slots, mentors_size, filter_match = true, reject_zero_score_mentors)
    return [] unless available_slots.present?
    slots = reject_slots_less_than(available_slots, Meeting::QuickConnect::MATCH_SCORE_THRESHOLD, reject_zero_score_mentors) if filter_match
    slots ||= available_slots
    available_mentors = []
    slots[0..(mentors_size - 1)].each do |slot|
      available_mentors_details = { :member => slot[:member], :score => slot[:new_meeting_params][:score]}
      available_mentors_details.merge!(:availability => {:start => slot[:start].to_time, :end => slot[:end].to_time}) if slot[:start] && slot[:end]
      available_mentors << available_mentors_details
    end
    available_mentors
  end

  def reject_slots_less_than(slots, match_score, reject_zero_score_mentors)
    if reject_zero_score_mentors.present?
      slots.reject do |slot|
        slot[:new_meeting_params][:score].to_i == 0
      end
    else
      slots.reject do |slot|
        slot[:new_meeting_params][:score].to_i < match_score
      end
    end
  end

  def can_notify_availability?(user)
    current_time = Time.now.utc
    user.ask_to_set_availability? && !user.member.has_availability_between?(user.program, current_time.beginning_of_day, (current_time + Meeting::Interval::QUARTER.days).end_of_day)
  end

  def can_suggest_mentors?(user)
    user.can_view_mentoring_calendar? && user.member.get_attending_recurring_meetings(Meeting.upcoming_recurrent_meetings(user.member.meetings.of_program(user.program))).empty?
  end

  def set_desired_variables(program, user)
    @current_program = program
    @current_organization = program.organization
    @current_user = user
  end  
end