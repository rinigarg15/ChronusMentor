module BulkMatchScoreUtils
  def get_match_status_for_match_config(student_id, mentor_id, indexed_data, options)
    match_config, student_question, mentor_question = get_common_data_for_matching(options.reverse_merge(program_id: @current_program.id))
    student_index_data, mentor_index_data = get_student_mentor_index_data(student_question, mentor_question, student_id, mentor_id, indexed_data)
    data_fields = []
    Matching::Indexer.process_each_pair!(student_index_data, data_fields, options.slice(:supplementary_matching_pair))
    Matching::Indexer.process_each_pair!(mentor_index_data, data_fields, options.slice(:supplementary_matching_pair))
    get_match_score_and_status(data_fields[1], data_fields[0], match_config)
  end

  def get_indexed_data(role_names, program, options = {})
    role_index_data = {}
    role_names.each do |role_name|
      index_data_query = CustomSqlQuery::INDEX_DATA.call(CustomSqlQuery::SelectColumns::ANSWERS_FIELDS, program.id, role_name, program.get_role(role_name).id, options)
      role_index_data[role_name] = ActiveRecord::Base.connection.execute(index_data_query).to_a.group_by { |data| data[Matching::FIELDS["profile_answers.id"]] }
    end
    role_index_data
  end

  private

  def get_student_mentor_index_data(student_question, mentor_question, student_id, mentor_id, indexed_data)
    student_index_data = construct_data_field_array(student_question, User.find(student_id), RoleConstants::STUDENT_NAME, indexed_data)
    mentor_index_data = construct_data_field_array(mentor_question, User.find(mentor_id), RoleConstants::MENTOR_NAME, indexed_data)
    [Matching::Indexer.get_index_by_answer(student_index_data), Matching::Indexer.get_index_by_answer(mentor_index_data)]
  end

  def get_common_data_for_matching(options)
    match_config = options[:match_config].presence || MatchConfig.new(options.slice(:mentor_question_id, :student_question_id, :program_id, :weight, :threshold, :operator, :matching_type, :matching_details_for_display, :matching_details_for_matching))
    role_questions = RoleQuestion.where(id: [match_config.student_question_id, match_config.mentor_question_id]).index_by(&:id)
    student_question = ProfileQuestion.find(role_questions[match_config.student_question_id].profile_question_id)
    mentor_question = ProfileQuestion.find(role_questions[match_config.mentor_question_id].profile_question_id)
    [match_config, student_question, mentor_question]
  end

  def get_match_score_and_status(mentor_question, student_question, match_config)
    return {} if student_question.blank?
    match_score_or_hash = mentor_question.nil? ? 0.0 : mentor_question.match(student_question, matching_details: match_config.matching_details_for_matching, get_common_data: true)
    if match_score_or_hash.is_a?(Hash)
      match_score = match_score_or_hash[:score]
    else
      match_score = match_score_or_hash
      match_score_or_hash = {score: match_score}
    end
    threshold = match_config.threshold
    not_a_match = threshold.present? && ((MatchConfig::Operator.lt == match_config.operator) ? match_score < threshold : match_score > threshold)
    match_score_or_hash.merge(not_a_match: not_a_match)
  end

  def construct_data_field_array(question, user, role_name, indexed_data)
    profile_answer_id = ProfileAnswer.where(profile_question_id: question.id, ref_obj_id: user.member_id).pluck(:id).first
    return [] unless profile_answer_id
    indexed_data[role_name][profile_answer_id]
  end
end