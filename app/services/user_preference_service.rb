class UserPreferenceService
  include UserListingExtensions

  module RequestType
    MEETING = "meeting"
    GROUP = "group"
  end

  attr_reader :user, :request_type, :program

  def self.get_favorite_user_ids_for(user)
    user.favorite_preferences.pluck(:preference_marked_user_id)
  end

  def self.get_ignored_user_ids_for(user)
    user.ignore_preferences.pluck(:preference_marked_user_id)
  end

  def initialize(user, options={})
    @user = user
    @request_type = options[:request_type]
    @program = @user.program
  end

  def get_favorite_preferences_hash
    return Hash[user.favorite_preferences.map{|p| [p.preference_marked_user_id, p.id]}]
  end

  def get_ignore_preferences_hash
    return Hash[user.ignore_preferences.map{|p| [p.preference_marked_user_id, p.id]}]
  end

  def find_available_favorite_users
    favorite_user_ids = user.valid_favorite_users.pluck(:id) 
    favorite_user_ids -= user.ignored_users.pluck(:id) if program.skip_and_favorite_profiles_enabled?
    allowed_favorite_mentor_ids = MentorRecommendationsService.reject_mentors_connected_to_mentee(user, program, favorite_user_ids)
    allowed_favorite_mentor_ids.present? ? available_favorites_based_on_request_type(allowed_favorite_mentor_ids) : []
  end

  private

  def available_favorites_based_on_request_type(allowed_favorite_mentor_ids)
    request_type == RequestType::GROUP ? available_favorites_for_groups(allowed_favorite_mentor_ids) : available_favorites_for_meetings(allowed_favorite_mentor_ids)
  end

  def available_favorites_for_groups(allowed_favorite_mentor_ids)
    mentors_ids_with_slots = get_mentors_with_slots!(program, allowed_favorite_mentor_ids).keys
    availability_of_user_id_hsh = User.get_availability_slots_for(mentors_ids_with_slots)
    favorite_user_ids = availability_of_user_id_hsh.collect {|k,v| k if v != 0}.compact
    program.users.find(favorite_user_ids)
  end

  def available_favorites_for_meetings(allowed_favorite_mentor_ids)
    member = user.member
    start_time = Time.now.in_time_zone(member.get_valid_time_zone)
    return [] if user.is_max_capacity_program_reached?(start_time, user)
    
    interval = Meeting::Interval::MONTH
    availability_of_user_id_hsh = user.generate_mentor_suggest_hash(program, allowed_favorite_mentor_ids, interval, user, {items_size: MentorRecommendationsService::TOP_N_MENTORS_THRESHOLD})
    member_ids = (availability_of_user_id_hsh||[]).collect{|hash| hash[:member].id}
    return program.users.where(member_id: member_ids)
  end
end