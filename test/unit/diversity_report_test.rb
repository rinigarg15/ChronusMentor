require_relative './../test_helper.rb'

class DiversityReportTest < ActiveSupport::TestCase
  def setup
    ret = super
    @organization = programs(:org_primary)
    @admin_view = @organization.admin_views.find_by(default_view: AbstractView::DefaultType::ALL_MEMBERS)
    @profile_question = profile_questions(:single_choice_q)
    @diversity_report = @organization.diversity_reports.new({admin_view: @admin_view, profile_question: @profile_question})
    @start_time = @organization.created_at - 10.days
    @end_time = Time.now + 10.years
    ret
  end

  def test_time_period_type_comparison
    @diversity_report.comparison_type = DiversityReport::ComparisonType::PARTICIPANT
    assert_false @diversity_report.time_period_type_comparison?

    @diversity_report.comparison_type = DiversityReport::ComparisonType::TIME_PERIOD
    assert @diversity_report.time_period_type_comparison?
  end

  def test_participant_type_comparison
    @diversity_report.comparison_type = DiversityReport::ComparisonType::PARTICIPANT
    assert @diversity_report.participant_type_comparison?

    @diversity_report.comparison_type = DiversityReport::ComparisonType::TIME_PERIOD
    assert_false @diversity_report.participant_type_comparison?
  end

  def test_get_info_hash_for_time_period_comparison_and_get_time_period_info_hash
    @diversity_report.comparison_type = DiversityReport::ComparisonType::TIME_PERIOD
    choice1 = question_choices(:single_choice_q_1)
    choice2 = question_choices(:single_choice_q_2)
    choice3 = question_choices(:single_choice_q_3)
    target_hash = {
      segment_1: {
        choices: {
          choice1.id => {count: 0, percentage: 0},
          choice2.id => {count: 0, percentage: 0},
          choice3.id => {count: 0, percentage: 0}
        },
        translate_key: "display_string.Previous_Period",
        answered_members_count: 0
      },
      segment_2: {
        choices: {
          choice1.id => {count: 1, percentage: 50.0},
          choice2.id => {count: 0, percentage: 0},
          choice3.id => {count: 1, percentage: 50.0}
        },
        translate_key: "display_string.Selected_Period",
        answered_members_count: 2
      },
      engagement_diversity: 0
    }
    assert_equal_hash(target_hash, @diversity_report.get_info_hash(@start_time, @end_time))
  end

  def test_get_info_hash_for_participant_comparison_and_get_participant_info_hash
    @diversity_report.comparison_type = DiversityReport::ComparisonType::PARTICIPANT
    choice1 = question_choices(:single_choice_q_1)
    choice2 = question_choices(:single_choice_q_2)
    choice3 = question_choices(:single_choice_q_3)
    @diversity_report.stubs(:get_member_ids_of_active_users_during).returns({participant_member_ids: [members(:f_mentor).id], non_participant_member_ids: [members(:robert).id]})
    target_hash = {
      segment_1: {
        choices: {
          choice1.id => {count: 0, percentage: 0},
          choice2.id => {count: 0, percentage: 0},
          choice3.id => {count: 1, percentage: 100.0}
        },
        translate_key: "display_string.Non_Participants",
        answered_members_count: 1
      },
      segment_2: {
        choices: {
          choice1.id => {count: 1, percentage: 100.0},
          choice2.id => {count: 0, percentage: 0},
          choice3.id => {count: 0, percentage: 0}
        },
        translate_key: "display_string.Participants",
        answered_members_count: 1
      },
      engagement_diversity: 0
    }
    assert_equal_hash(target_hash, @diversity_report.get_info_hash(@start_time, @end_time))
  end

  def test_get_base_values_for_participant_type
    @diversity_report.comparison_type = DiversityReport::ComparisonType::PARTICIPANT
    participant_info = @diversity_report.send(:get_member_ids_of_active_users_during, @start_time, @end_time)
    assert_equal [participant_info[:participant_member_ids], participant_info[:non_participant_member_ids], @diversity_report.profile_question.question_choices.map(&:id)], @diversity_report.send(:get_base_values_for_participant_type, @start_time, @end_time)
  end

  def test_prepare_info_and_local_hsh
    assert_equal [{:segment_1=>{:choices=>{1=>{:count=>0, :percentage=>0}, 2=>{:count=>0, :percentage=>0}}, :translate_key=>"display_string.Non_Participants"}, :segment_2=>{:choices=>{1=>{:count=>0, :percentage=>0}, 2=>{:count=>0, :percentage=>0}}, :translate_key=>"display_string.Participants"}}, {1=>{}, 2=>{}}], @diversity_report.send(:prepare_info_and_local_hsh, [1,2], type: DiversityReport::ComparisonType::PARTICIPANT)
    assert_equal [{:segment_1=>{:choices=>{1=>{:count=>0, :percentage=>0}, 2=>{:count=>0, :percentage=>0}}, :translate_key=>"display_string.Previous_Period"}, :segment_2=>{:choices=>{1=>{:count=>0, :percentage=>0}, 2=>{:count=>0, :percentage=>0}}, :translate_key=>"display_string.Selected_Period"}}, {1=>{}, 2=>{}}], @diversity_report.send(:prepare_info_and_local_hsh, [1,2], type: DiversityReport::ComparisonType::TIME_PERIOD)
  end

  def test_update_local_hsh
    local_hsh = {question_choices(:single_choice_q_1).id => {}}
    answer_choice_versions = @diversity_report.send(:get_answer_choice_versions, member_ids: [members(:f_mentor).id], question_choice_ids: [question_choices(:single_choice_q_1).id], end_time: @end_time)
    @diversity_report.send(:update_local_hsh!, local_hsh, answer_choice_versions)
    assert(members(:f_mentor).answer_choice_versions.where(question_choice_id: question_choices(:single_choice_q_1).id).select(:member_id, :question_choice_id, :event, :created_at).to_a.map(&:attributes) == local_hsh[question_choices(:single_choice_q_1).id][members(:f_mentor).id].map(&:attributes))
  end

  def test_prepare_participant_type_process_values
    assert_equal [[], [], {1=>true, 2=>true}], @diversity_report.send(:prepare_participant_type_process_values, [1,2])
  end

  def test_fillup_additional_info
    assert_equal_hash({:segment_1=>{:choices=>{1=>{:count=>2, :percentage=>20.0}, 2=>{:count=>3, :percentage=>30.0}, 3=>{:count=>5, :percentage=>50.0}}, :answered_members_count=>10}, :segment_2=>{:choices=>{1=>{:count=>8, :percentage=>40.0}, 2=>{:count=>6, :percentage=>30.0}, 3=>{:count=>6, :percentage=>30.0}}, :answered_members_count=>20}}, @diversity_report.send(:fillup_additional_info, {segment_1: {choices: {1 => {count: 2}, 2 => {count: 3}, 3 => {count: 5}}}, segment_2: {choices: {1 => {count: 8}, 2 => {count: 6}, 3 => {count: 6}}}}, 10, 20))
  end

  def test_fillup_participants_type_counts_info
    choice1 = question_choices(:single_choice_q_1)
    local_hsh = {choice1.id => {}}
    answer_choice_versions = @diversity_report.send(:get_answer_choice_versions, member_ids: [members(:f_mentor).id], question_choice_ids: [choice1.id], end_time: @end_time)
    @diversity_report.send(:update_local_hsh!, local_hsh, answer_choice_versions)
    inputs = {
      target_question_choice_ids: [choice1].map(&:id),
      local_hsh: local_hsh,
      particpant_member_ids_hsh: {}
    }
    outputs = {info: {segment_1: {choices: {choice1.id => {count: 0}}}, segment_2: {}}, participant_answered_member_ids: [], non_participant_answered_member_ids: []}
    @diversity_report.send(:fillup_participants_type_counts_info!, @end_time, inputs, outputs)
    assert_equal_hash({:info=>{:segment_1=>{:choices=>{choice1.id=>{:count=>1}}}, :segment_2=>{}}, :participant_answered_member_ids=>[], :non_participant_answered_member_ids=>[members(:f_mentor).id]}, outputs)

    local_hsh = {choice1.id => {}}
    @diversity_report.send(:update_local_hsh!, local_hsh, answer_choice_versions)
    inputs = {
      target_question_choice_ids: [choice1].map(&:id),
      local_hsh: local_hsh,
      particpant_member_ids_hsh: {members(:f_mentor).id => true}
    }
    outputs = {info: {segment_2: {choices: {choice1.id => {count: 0}}}, segment_1: {}}, participant_answered_member_ids: [], non_participant_answered_member_ids: []}
    @diversity_report.send(:fillup_participants_type_counts_info!, @end_time, inputs, outputs)
    assert_equal_hash({:info=>{:segment_2=>{:choices=>{choice1.id=>{:count=>1}}}, :segment_1=>{}}, :participant_answered_member_ids=>[members(:f_mentor).id], :non_participant_answered_member_ids=>[]}, outputs)
  end

  def test_get_previous_time_period
    current_end_time = Time.new(2018, 9, 24, 11, 11, 11)
    current_start_time = current_end_time - 5.days
    previous_start_time, previous_end_time = @diversity_report.send(:get_previous_time_period, current_start_time, current_end_time)
    assert_equal (current_start_time - 6.days).beginning_of_day, previous_start_time
    assert_equal (current_start_time - 1.day).end_of_day, previous_end_time
  end

  def test_get_base_values_for_time_period_type
    choice1 = question_choices(:single_choice_q_1)
    choice2 = question_choices(:single_choice_q_2)
    choice3 = question_choices(:single_choice_q_3)
    @diversity_report.stubs(:get_member_ids_of_active_users_during).returns({participant_member_ids: [1,2,3]})
    assert_equal [[1, 2, 3], [choice1, choice2, choice3].map(&:id)], @diversity_report.send(:get_base_values_for_time_period_type, @start_time, @end_time)
  end

  def test_prepare_time_period_type_process_values
    start_time = Time.new(2018, 9, 24, 11, 11, 11)
    assert_equal [[], [], (start_time- 6.days).beginning_of_day, (start_time - 1.day).end_of_day], @diversity_report.send(:prepare_time_period_type_process_values, start_time, start_time + 5.days)
  end

  def test_update_previous_time_segment
    outputs = {info: {segment_1: {choices: {123 => {count: 4}}}}, previous_time_period_answered_member_ids: [23]}
    @diversity_report.send(:update_previous_time_segment!, outputs, 123, 45)
    assert_equal_hash({:info=>{:segment_1=>{:choices=>{123=>{:count=>5}}}}, :previous_time_period_answered_member_ids=>[23, 45]}, outputs)
  end

  def test_update_current_time_segment
    outputs = {info: {segment_1: {choices: {123 => {count: 4}}}, segment_2: {choices: {1 => {count: 3}, 2 => {count: 4}}}}, previous_time_period_answered_member_ids: [23], current_time_period_answered_member_ids: []}
    @diversity_report.send(:update_current_time_segment!, outputs, 2, 50)
    assert_equal_hash({:info=>{:segment_1=>{:choices=>{123=>{:count=>4}}}, :segment_2=>{:choices=>{1=>{:count=>3}, 2=>{:count=>5}}}}, :previous_time_period_answered_member_ids=>[23], :current_time_period_answered_member_ids=>[50]}, outputs)
  end

  def test_fillup_time_period_type_counts_info
    end_time = (Time.now + 1.year).beginning_of_day
    previous_end_time = (end_time - 2.years).end_of_day
    choice1 = question_choices(:single_choice_q_1)
    local_hsh = {choice1.id => {}}
    answer_choice_versions = @diversity_report.send(:get_answer_choice_versions, member_ids: [members(:f_mentor).id], question_choice_ids: [choice1.id], end_time: @end_time)
    @diversity_report.send(:update_local_hsh!, local_hsh, answer_choice_versions)
    inputs = {target_question_choice_ids: [choice1.id], local_hsh: local_hsh}
    outputs = {:info=>{:segment_1=>{:choices=>{choice1.id=>{:count=>1}}}, :segment_2=>{:choices=>{choice1.id=>{:count=>1}}}}, :previous_time_period_answered_member_ids=>[], :current_time_period_answered_member_ids=>[]}
    @diversity_report.send(:fillup_time_period_type_counts_info!, previous_end_time, end_time, inputs, outputs)
    assert_equal_hash({:info=>{:segment_1=>{:choices=>{choice1.id=>{:count=>1}}}, :segment_2=>{:choices=>{choice1.id=>{:count=>2}}}}, :previous_time_period_answered_member_ids=>[], :current_time_period_answered_member_ids=>[members(:f_mentor).id]}, outputs)
  end

  def test_update_percentages_info
    segment = {answered_members_count: 100, choices: {1 => {count: 10}, 2 => {count: 30}, 3 => {count: 60}}}
    @diversity_report.send(:update_percentages_info!, segment)
    assert_equal_hash({:answered_members_count=>100, :choices=>{1=>{:count=>10, :percentage=>10.0}, 2=>{:count=>30, :percentage=>30.0}, 3=>{:count=>60, :percentage=>60.0}}}, segment)
  end

  def test_get_count_for_sequence_at_time
    t1 = Time.new(2018,1,1)
    t2 = t1 + 1.month
    t3 = t2 + 1.month
    t4 = t3 + 1.month
    t5 = t4 + 1.month
    t6 = t5 + 1.month
    sequence = [
      OpenStruct.new(event: AnswerChoiceVersion::Event::CREATE, created_at: t1), OpenStruct.new(event: AnswerChoiceVersion::Event::DESTROY, created_at: t2),
      OpenStruct.new(event: AnswerChoiceVersion::Event::CREATE, created_at: t3), OpenStruct.new(event: AnswerChoiceVersion::Event::DESTROY, created_at: t4),
      OpenStruct.new(event: AnswerChoiceVersion::Event::CREATE, created_at: t5), OpenStruct.new(event: AnswerChoiceVersion::Event::DESTROY, created_at: t6)
    ]
    assert_equal 0, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t1 - 5.days)
    assert_equal 1, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t1)
    assert_equal 1, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t1 + 5.days)
    assert_equal 0, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t2)
    assert_equal 0, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t2 + 5.days)
    assert_equal 1, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t3)
    assert_equal 1, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t3 + 5.days)
    assert_equal 0, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t4)
    assert_equal 0, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t4 + 5.days)
    assert_equal 1, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t5)
    assert_equal 1, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t5 + 5.days)
    assert_equal 0, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t6)
    assert_equal 0, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t6 + 5.days)

    sequence = [
      OpenStruct.new(event: AnswerChoiceVersion::Event::CREATE, created_at: t1), OpenStruct.new(event: AnswerChoiceVersion::Event::CREATE, created_at: t2),
      OpenStruct.new(event: AnswerChoiceVersion::Event::CREATE, created_at: t3), OpenStruct.new(event: AnswerChoiceVersion::Event::DESTROY, created_at: t4),
      OpenStruct.new(event: AnswerChoiceVersion::Event::DESTROY, created_at: t5), OpenStruct.new(event: AnswerChoiceVersion::Event::DESTROY, created_at: t6)
    ]
    assert_equal 0, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t1 - 5.days)
    assert_equal 1, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t1)
    assert_equal 1, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t1 + 5.days)
    assert_equal 1, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t2)
    assert_equal 1, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t2 + 5.days)
    assert_equal 1, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t3)
    assert_equal 1, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t3 + 5.days)
    assert_equal 0, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t4)
    assert_equal 0, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t4 + 5.days)
    assert_equal 0, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t5)
    assert_equal 0, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t5 + 5.days)
    assert_equal 0, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t6)
    assert_equal 0, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t6 + 5.days)

    sequence = [
      OpenStruct.new(event: AnswerChoiceVersion::Event::DESTROY, created_at: t1), OpenStruct.new(event: AnswerChoiceVersion::Event::DESTROY, created_at: t2),
      OpenStruct.new(event: AnswerChoiceVersion::Event::DESTROY, created_at: t3), OpenStruct.new(event: AnswerChoiceVersion::Event::CREATE, created_at: t4),
      OpenStruct.new(event: AnswerChoiceVersion::Event::CREATE, created_at: t5), OpenStruct.new(event: AnswerChoiceVersion::Event::CREATE, created_at: t6)
    ]
    assert_equal 1, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t1 - 5.days)
    assert_equal 0, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t1)
    assert_equal 0, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t1 + 5.days)
    assert_equal 0, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t2)
    assert_equal 0, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t2 + 5.days)
    assert_equal 0, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t3)
    assert_equal 0, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t3 + 5.days)
    assert_equal 1, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t4)
    assert_equal 1, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t4 + 5.days)
    assert_equal 1, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t5)
    assert_equal 1, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t5 + 5.days)
    assert_equal 1, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t6)
    assert_equal 1, @diversity_report.send(:get_count_for_sequence_at_time, sequence, t6 + 5.days)
  end

  def test_get_count_for_event
    assert_equal 1, @diversity_report.send(:get_count_for_event, AnswerChoiceVersion::Event::CREATE, false)
    assert_equal 0, @diversity_report.send(:get_count_for_event, AnswerChoiceVersion::Event::CREATE, true)
    assert_equal 0, @diversity_report.send(:get_count_for_event, AnswerChoiceVersion::Event::DESTROY, false)
    assert_equal 1, @diversity_report.send(:get_count_for_event, AnswerChoiceVersion::Event::DESTROY, true)
  end

  def test_get_member_ids_of_active_users_during
    active_user_ids = Member.where(id: [1, 2]).map(&:users).flatten.map(&:id)
    User.stubs(:get_ids_of_users_active_between).returns(active_user_ids)
    @diversity_report.admin_view.stubs(:fetch_all_member_ids).returns([1,2,3])
    assert_equal_hash({:participant_member_ids=>[1, 2], :non_participant_member_ids=>[3]}, @diversity_report.send(:get_member_ids_of_active_users_during, @start_time, @end_time))
  end

  def test_get_engagement_diversity
    @diversity_report.stubs(:get_final_answers_by_member_id)
    @diversity_report.stubs(:get_groups_for_engagement_diversity).returns([])
    @diversity_report.stubs(:get_meetings_for_engagement_diversity).returns([])
    assert_nil @diversity_report.send(:get_engagement_diversity, [], [])

    @diversity_report.stubs(:get_final_answers_by_member_id).returns(final_answers_by_member_id)
    @diversity_report.stubs(:get_groups_for_engagement_diversity).returns(groups_for_engagement_diversity)
    @diversity_report.stubs(:get_meetings_for_engagement_diversity).returns(meetings_for_engagement_diversity)
    assert_equal 43, @diversity_report.send(:get_engagement_diversity, [], [])
  end

  private

  def final_answers_by_member_id
    {
      1 => [100, 101],
      2 => [100, 101],
      3 => [100, 102]
    }
  end

  def groups_for_engagement_diversity
    {
      1 => [OpenStruct.new(member_id: 1), OpenStruct.new(member_id: 2)],
      2 => [OpenStruct.new(member_id: 1), OpenStruct.new(member_id: 3)],
      3 => [OpenStruct.new(member_id: 1), OpenStruct.new(member_id: 4)],
      4 => [OpenStruct.new(member_id: 1), OpenStruct.new(member_id: 2), OpenStruct.new(member_id: 3)],
    }
  end

  def meetings_for_engagement_diversity
    {
      1 => [OpenStruct.new(member_id: 1), OpenStruct.new(member_id: 2)],
      2 => [OpenStruct.new(member_id: 1), OpenStruct.new(member_id: 3)],
      3 => [OpenStruct.new(member_id: 1), OpenStruct.new(member_id: 4)]
    }
  end
end