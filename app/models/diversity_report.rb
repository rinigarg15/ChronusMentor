class DiversityReport < ActiveRecord::Base
  module ComparisonType
    PARTICIPANT = 0
    TIME_PERIOD = 1

    class << self
      def possible_values
        [PARTICIPANT, TIME_PERIOD]
      end
    end
  end

  belongs_to_organization foreign_key: :organization_id
  belongs_to :admin_view
  belongs_to :profile_question

  validates :organization_id, :admin_view_id, :profile_question_id, presence: true
  validates :comparison_type, inclusion: { in: ComparisonType.possible_values }

  def get_info_hash(start_time, end_time)
    return get_time_period_info_hash(start_time, end_time) if time_period_type_comparison?
    return get_participant_info_hash(start_time, end_time) if participant_type_comparison?
  end

  def time_period_type_comparison?
    comparison_type == ComparisonType::TIME_PERIOD
  end

  def participant_type_comparison?
    comparison_type == ComparisonType::PARTICIPANT
  end

  private

  def get_base_values_for_participant_type(start_time, end_time)
    participant_info = get_member_ids_of_active_users_during(start_time, end_time)
    target_particpant_member_ids = participant_info[:participant_member_ids]
    target_non_particpant_member_ids = participant_info[:non_participant_member_ids]
    target_question_choice_ids = profile_question.question_choices.map(&:id)
    [target_particpant_member_ids, target_non_particpant_member_ids, target_question_choice_ids]
  end

  def prepare_info_and_local_hsh(target_question_choice_ids, options = {})
    info = {segment_1: {choices: {}}, segment_2: {choices: {}}}
    info[:segment_1][:translate_key] = ((options[:type] == ComparisonType::PARTICIPANT) ? "display_string.Non_Participants" : "display_string.Previous_Period")
    info[:segment_2][:translate_key] = ((options[:type] == ComparisonType::PARTICIPANT) ? "display_string.Participants" : "display_string.Selected_Period")
    local_hsh = {}
    target_question_choice_ids.each do |question_choice_id|
      info[:segment_1][:choices][question_choice_id] = {count: 0, percentage: 0}
      info[:segment_2][:choices][question_choice_id] = {count: 0, percentage: 0}
      local_hsh[question_choice_id] = {}
    end
    [info, local_hsh]
  end

  def update_local_hsh!(local_hsh, answer_choice_versions)
    answer_choice_versions.each do |answer_choice_version|
      local_hsh[answer_choice_version.question_choice_id][answer_choice_version.member_id] = [] if local_hsh[answer_choice_version.question_choice_id][answer_choice_version.member_id].nil?
      local_hsh[answer_choice_version.question_choice_id][answer_choice_version.member_id] << answer_choice_version
    end
  end

  def prepare_participant_type_process_values(target_particpant_member_ids)
    non_participant_answered_member_ids = []
    participant_answered_member_ids = []
    particpant_member_ids_hsh = {}
    target_particpant_member_ids.each { |id| particpant_member_ids_hsh[id] = true }
    [non_participant_answered_member_ids, participant_answered_member_ids, particpant_member_ids_hsh]
  end

  def fillup_additional_info(info, segment_1_size, segment_2_size)
    [{key: :segment_1, size: segment_1_size}, {key: :segment_2, size: segment_2_size}].each do |unit|
      info[unit[:key]][:answered_members_count] = unit[:size]
      update_percentages_info!(info[unit[:key]])
    end
    info
  end

  def fillup_participants_type_counts_info!(end_time, inputs, outputs)
    inputs[:target_question_choice_ids].each do |question_choice_id|
      inputs[:local_hsh][question_choice_id].each do |member_id, sequence|
        segment_key = (inputs[:particpant_member_ids_hsh][member_id] ? :segment_2 : :segment_1)
        if get_count_for_sequence_at_time(sequence, end_time) == 1
          outputs[:info][segment_key][:choices][question_choice_id][:count] += 1
          (inputs[:particpant_member_ids_hsh][member_id] ? outputs[:participant_answered_member_ids] : outputs[:non_participant_answered_member_ids]) << member_id
        end
      end
    end
  end

  def get_participant_info_hash(start_time, end_time)
    target_particpant_member_ids, target_non_particpant_member_ids, target_question_choice_ids = get_base_values_for_participant_type(start_time, end_time)
    # non participant is segment_1, participant is segment_2
    info, local_hsh = prepare_info_and_local_hsh(target_question_choice_ids, type: ComparisonType::PARTICIPANT)
    answer_choice_versions = get_answer_choice_versions(member_ids: (target_particpant_member_ids + target_non_particpant_member_ids), question_choice_ids: target_question_choice_ids, end_time: end_time)
    update_local_hsh!(local_hsh, answer_choice_versions)
    non_participant_answered_member_ids, participant_answered_member_ids, particpant_member_ids_hsh = prepare_participant_type_process_values(target_particpant_member_ids)
    info[:engagement_diversity] = get_engagement_diversity(target_particpant_member_ids, answer_choice_versions, start_time: start_time, end_time: end_time)
    fillup_participants_type_counts_info!(end_time, {target_question_choice_ids: target_question_choice_ids, local_hsh: local_hsh, particpant_member_ids_hsh: particpant_member_ids_hsh}, {info: info, participant_answered_member_ids: participant_answered_member_ids, non_participant_answered_member_ids: non_participant_answered_member_ids})
    fillup_additional_info(info, non_participant_answered_member_ids.uniq.size, participant_answered_member_ids.uniq.size)
  end

  def get_previous_time_period(start_time, end_time)
    previous_end_time = start_time.prev_day.end_of_day
    [previous_end_time.beginning_of_day - (end_time.to_date - start_time.to_date).days, previous_end_time]
  end

  def get_base_values_for_time_period_type(start_time, end_time)
    [get_member_ids_of_active_users_during(start_time, end_time)[:participant_member_ids], profile_question.question_choices.map(&:id)]
  end

  def prepare_time_period_type_process_values(start_time, end_time)
    [[], [], *get_previous_time_period(start_time, end_time)]
  end

  def update_previous_time_segment!(outputs, question_choice_id, member_id)
    outputs[:info][:segment_1][:choices][question_choice_id][:count] += 1
    outputs[:previous_time_period_answered_member_ids] << member_id
  end

  def update_current_time_segment!(outputs, question_choice_id, member_id)
    outputs[:info][:segment_2][:choices][question_choice_id][:count] += 1
    outputs[:current_time_period_answered_member_ids] << member_id
  end

  def fillup_time_period_type_counts_info!(previous_end_time, end_time, inputs, outputs)
    inputs[:target_question_choice_ids].each do |question_choice_id|
      inputs[:local_hsh][question_choice_id].each do |member_id, sequence|
        update_previous_time_segment!(outputs, question_choice_id, member_id) if get_count_for_sequence_at_time(sequence, previous_end_time) == 1
        update_current_time_segment!(outputs, question_choice_id, member_id) if get_count_for_sequence_at_time(sequence, end_time) == 1
      end
    end
  end

  def get_time_period_info_hash(start_time, end_time)
    previous_time_period_answered_member_ids, current_time_period_answered_member_ids, previous_start_time, previous_end_time = prepare_time_period_type_process_values(start_time, end_time)
    target_member_ids, target_question_choice_ids = get_base_values_for_time_period_type(previous_start_time, end_time)
    # previous time period is segment_1, current time period is segment_2
    info, local_hsh = prepare_info_and_local_hsh(target_question_choice_ids)
    answer_choice_versions = get_answer_choice_versions(member_ids: target_member_ids, question_choice_ids: target_question_choice_ids, end_time: end_time)
    update_local_hsh!(local_hsh, answer_choice_versions)
    info[:engagement_diversity] = get_engagement_diversity(target_member_ids, answer_choice_versions, start_time: start_time, end_time: end_time)
    fillup_time_period_type_counts_info!(previous_end_time, end_time, {target_question_choice_ids: target_question_choice_ids, local_hsh: local_hsh}, {info: info, previous_time_period_answered_member_ids: previous_time_period_answered_member_ids, current_time_period_answered_member_ids: current_time_period_answered_member_ids})
    fillup_additional_info(info, previous_time_period_answered_member_ids.uniq.size, current_time_period_answered_member_ids.uniq.size)
  end

  def update_percentages_info!(segment)
    total = segment[:answered_members_count]
    segment[:choices].each do |_id, info_hsh|
      info_hsh[:percentage] = (total == 0 ? 0 : ((100.0 * info_hsh[:count]) / total))
    end
  end

  def get_count_for_sequence_at_time(sequence, time_instance)
    return 0 if sequence.blank?

    lo, hi = [0, sequence.size]
    while lo < hi
      mid = (lo + hi)/2
      if time_instance < sequence[mid].created_at
        hi = mid
      else
        lo = mid + 1
      end
    end

    if hi == 0
      get_count_for_event(sequence[hi].event, true)
    else
      get_count_for_event(sequence[hi-1].event, false)
    end
  end

  def get_count_for_event(event, invert)
    count = case event
            when AnswerChoiceVersion::Event::CREATE, AnswerChoiceVersion::Event::UPDATE
              1
            when AnswerChoiceVersion::Event::DESTROY
              0
            end
    count = (count == 0 ? 1 : 0) if invert
    count
  end

  def get_member_ids_of_active_users_during(start_time, end_time)
    # consider only active programs, discussed with PM about the cases and decided
    selected_program_ids = organization.programs.active.map(&:id)
    active_member_ids = organization.users_with_published_profiles_in_date_range_for_organization([start_time, end_time], program_ids: selected_program_ids, role_ids: Role.where(program_id: selected_program_ids).pluck(:id))
    all_member_ids = admin_view.fetch_all_member_ids
    participant_member_ids = all_member_ids & active_member_ids
    {participant_member_ids: participant_member_ids, non_participant_member_ids: (all_member_ids - participant_member_ids)}
  end

  def get_engagement_diversity(member_ids, answer_choice_versions, options = {})
    final_answers_by_member_id = get_final_answers_by_member_id(answer_choice_versions)
    groups = get_groups_for_engagement_diversity(member_ids, options)
    meetings = get_meetings_for_engagement_diversity(member_ids, options)
    return nil if (groups.blank? && meetings.blank?)
    sum = calculate_engagement_diversity(groups, final_answers_by_member_id) + calculate_engagement_diversity(meetings, final_answers_by_member_id)
    (sum.fdiv(groups.size + meetings.size) * 100).round
  end

  def handle_empty_common_choices(question_choice_ids_array)
    (question_choice_ids_array.select(&:present?).size > 1) ? 1 : 0
  end

  def handle_common_choices(question_choice_ids_array, common_choices)
    (question_choice_ids_array.any? {|question_choice_ids| question_choice_ids.size > common_choices.size }) ? 1 : 0
  end

  def get_answer_choice_versions(options = {})
    AnswerChoiceVersion.where(member_id: options[:member_ids], question_choice_id: options[:question_choice_ids]).where("created_at < ?", options[:end_time]).order(:created_at, :id).select(:member_id, :question_choice_id, :event, :created_at)
  end

  def get_final_answers_by_member_id(answer_choice_versions)
    hsh = {}
    hit = {}
    (answer_choice_versions.size - 1).downto(0).each do |i|
      answer_choice = answer_choice_versions[i]
      next if answer_choice_already_hit?(hit, answer_choice)
      init_hit_and_result_hash!(hsh, hit, answer_choice.member_id) if hit[answer_choice.member_id].nil?
      set_hit_and_result_hash!(hsh, hit, answer_choice)
    end
    hsh
  end

  def get_groups_for_engagement_diversity(member_ids, options = {})
    group_ids = organization.connections_in_date_range_for_organization(options.values_at(:start_time, :end_time))
    Connection::Membership.joins(:user).where(users: {member_id: member_ids}, group_id: group_ids).select(:group_id, :member_id).group_by(&:group_id)
  end

  def get_meetings_for_engagement_diversity(member_ids, options = {})
    meeting_ids = Meeting.non_group_meetings.in_programs(organization.program_ids).accepted_meetings.between_time(options.values_at(:start_time, :end_time)).pluck(:id)
    MemberMeeting.where(member_id: member_ids, meeting_id: meeting_ids).select(:meeting_id, :member_id).group_by(&:meeting_id)
  end

  def answer_choice_already_hit?(hit_hash, answer_choice)
    hit_hash[answer_choice.member_id] && hit_hash[answer_choice.member_id][answer_choice.question_choice_id]
  end

  def init_hit_and_result_hash!(result_hash, hit_hash, member_id)
    result_hash[member_id] = []
    hit_hash[member_id] = {}
  end

  def set_hit_and_result_hash!(result_hash, hit_hash, answer_choice)
    result_hash[answer_choice.member_id] << answer_choice.question_choice_id if answer_choice.event == AnswerChoiceVersion::Event::CREATE
    hit_hash[answer_choice.member_id][answer_choice.question_choice_id] = true
  end

  def calculate_engagement_diversity(connections_hash, final_answers_by_member_id)
    sum = 0
    connections_hash.each do |_connection_id, connection_memberships|
      question_choice_ids_array = connection_memberships.collect {|connection_membership| final_answers_by_member_id[connection_membership.member_id].to_a }
      common_choices = question_choice_ids_array.inject(:&)
      sum += common_choices.blank? ? handle_empty_common_choices(question_choice_ids_array) : handle_common_choices(question_choice_ids_array, common_choices)
    end
    sum
  end
end
