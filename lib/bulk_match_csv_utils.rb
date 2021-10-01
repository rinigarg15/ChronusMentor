module BulkMatchCsvUtils

  def generate_csv_for_all_pairs_mentee_to_mentor(csv, students_hash, mentors_hash, options = {})
    students_hash.each do |student_id, student_match_data|
      student = options[:students][student_id]
      export_mentee_mentor_data(csv, student, student_match_data, mentors_hash, options)
    end
  end

  def generate_csv_for_all_pairs_mentor_to_mentee(csv, mentors_hash, options = {})
    mentors_hash.each do |mentor_id, mentor_match_data|
      mentor = options[:mentors][mentor_id]
      export_mentor_mentee_data(csv, mentor, mentor_match_data, options)
    end
  end

  def export_mentor_mentee_data(csv, mentor, mentor_match_data, options = {})
    if mentor_match_data[:selected_students].present?
      mentor_match_data[:selected_students].each_with_index do |student_id, preference|
        student = options[:students][student_id]
        match_score = options[:student_mentor_map][mentor.id][student.id]
        export_data(csv, mentor, student, mentor_match_data, options.merge({match_score: match_score, preference: preference, users_match_data: mentor_match_data}))
      end
    else
      populate_csv(csv, mentor.name(name_only: true), nil, nil, get_options(nil, mentor_match_data, mentor, mentor_match_data, options))
    end
  end

  def export_mentee_mentor_data(csv, student, student_match_data, mentors_match_data, options = {})
    if student_match_data[:selected_mentors].present?
      student_match_data[:selected_mentors].each_with_index do |mentor_id, preference|
        mentor = options[:mentors][mentor_id]
        match_score = options[:student_mentor_map][student.id][mentor.id]        
        export_data(csv, mentor, student, student_match_data, options.merge({match_score: match_score, preference: preference, users_match_data: mentors_match_data}))
      end
    else
      populate_csv(csv, nil, student.name(name_only: true), nil, get_options(student, student_match_data, nil, mentors_match_data, options))
    end
  end

  def export_data(csv, mentor, student, match_data, options={})
    group = options[:groups][match_data[:group_id]]
    populate_csv_options = get_options(student, match_data, mentor, options[:users_match_data], options.merge({group: group}))
    populate_csv(csv, mentor.name(name_only: true), student.name(name_only: true), options[:match_score], populate_csv_options)
  end

  def get_options(student, student_match_data, mentor, mentors_match_data, options = {})
    result_hash = {status: student_match_data[:group_status], bulk_recommendation_flag: options[:bulk_recommendation_flag], answers: populate_match_config_details(mentor, student, options[:mentor_profile_ques_ids], options[:student_profile_ques_ids])}
    return result_hash if mentor.blank?

    result_hash.merge!({preference: (options[:preference] + 1), recommended_count: mentors_match_data[mentor.id][:recommended_count]}) if options[:bulk_recommendation_flag].present?
    result_hash.merge!(get_group_result_hash(options))

    set_results_hash_with_connections_and_pickable_slots(mentor, mentors_match_data, result_hash)
  end

  def get_group_result_hash(options)
    group = options[:group]
    group.present? ? {drafted_date: DateTime.localize(group.created_at, format: :default_dashed), notes: group.notes, published_at: DateTime.localize(group.published_at, format: :default_dashed)} : {}
  end

  def set_results_hash_with_connections_and_pickable_slots(mentor, mentors_match_data, result_hash)
    result_hash.merge!(ongoing_connections_count: (mentors_match_data.present? && !mentor_to_mentee? ? mentors_match_data[mentor.id][:connections_count] : mentor.groups.active.count))
    result_hash.merge!({pickable_slots: mentors_match_data[:pickable_slots]}) if mentor_to_mentee?
    result_hash
  end

  def populate_csv(csv, mentor_name, mentee_name, match_score, options = {})
    names_and_match_score = [mentee_name, mentor_name, match_score]
    options[:bulk_recommendation_flag] ? populate_csv_for_bulk_recommendation(csv, names_and_match_score, options) : populate_csv_for_bulk_match(csv, names_and_match_score, options)
  end

  def populate_csv_for_bulk_match(csv, names_and_match_score, options)
    if mentor_to_mentee?
      names_and_match_score[0], names_and_match_score[1] = names_and_match_score[1], names_and_match_score[0]
      names_and_match_score << options[:pickable_slots]
    end
    csv << (names_and_match_score + [options[:status], options[:drafted_date], options[:notes], options[:published_at], options[:ongoing_connections_count]] + options[:answers].to_a)
  end

  def populate_csv_for_bulk_recommendation(csv, names_and_match_score, options)
    preference = [options[:preference]]
    recommended_count = [options[:recommended_count]]
    csv << (names_and_match_score + preference + [options[:status], options[:ongoing_connections_count]] + recommended_count + options[:answers].to_a)
  end

  def populate_match_config_details(mentor, student, mentor_profile_ques_ids, student_profile_ques_ids)
    mentor_answers = mentor.present? ? mentor.member.profile_answers.index_by(&:profile_question_id) : {}
    student_answers = student.present? ? student.member.profile_answers.index_by(&:profile_question_id) : {}
    answers = []

    mentor_profile_ques_ids.each_with_index do |mentor_ques, i|
      answers << AbstractBulkMatch::MATCH_CONFIG_SEPARATOR
      answers << get_globalized_answer(student_answers, student_profile_ques_ids[i])
      answers << get_globalized_answer(mentor_answers, mentor_ques)
    end
    answers
  end

  def populate_csv_header(csv, program, options = {})
    header, mentor_profile_ques_ids, student_profile_ques_ids = populate_match_config_header(program)
    csv << (get_name_and_match_score_header(program) + get_preference_header(options[:bulk_recommendation_flag]) +  get_other_headers(program, options[:bulk_recommendation_flag]) + get_recommendations_count_header(options[:bulk_recommendation_flag]) + header)
    return [mentor_profile_ques_ids, student_profile_ques_ids]
  end

  def get_name_and_match_score_header(program)
    headers = ["feature.bulk_match.content.mentee_name".translate(Mentee: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).term), 
      "feature.bulk_match.content.mentor_name".translate(Mentor: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term),
      "feature.bulk_match.content.match_percent".translate
    ]
    if mentor_to_mentee?
      headers[0], headers[1] = headers[1], headers[0]
      headers << "feature.bulk_match.label.available_slots".translate
    end
    headers
  end

  def get_preference_header(bulk_recommendation_flag)
    bulk_recommendation_flag ? ["feature.bulk_match.content.preference".translate] : []
  end

  def get_other_headers(program, bulk_recommendation_flag)
    headers = ["feature.connection.header.status.Status".translate]
    unless bulk_recommendation_flag
      headers << "feature.bulk_match.content.drafted_date".translate
      headers << "feature.bulk_match.content.note_added".translate
      headers << "feature.bulk_match.content.published_date".translate
    end
    headers << "feature.bulk_match.content.ongoing_connections_of_role".translate(role: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term_downcase, mentoring_connections: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term_downcase)     
  end

  def get_recommendations_count_header(bulk_recommendation_flag)
    bulk_recommendation_flag ? ["feature.bulk_match.content.recommended_count".translate] : []
  end

  def populate_match_config_header(program)
    match_configs, role_questions, mentor_text, mentee_text = get_match_config_info(program)
    header = []
    mentor_profile_ques_ids = []
    student_profile_ques_ids = []
    match_configs.each do |match_config|
      header << AbstractBulkMatch::MATCH_CONFIG_SEPARATOR

      student_ques = role_questions[match_config.student_question_id].profile_question
      header, student_profile_ques_ids = set_header_and_profile_ques_ids(student_ques, header, student_profile_ques_ids, mentee_text)

      mentor_ques = role_questions[match_config.mentor_question_id].profile_question
      header, mentor_profile_ques_ids = set_header_and_profile_ques_ids(mentor_ques, header, mentor_profile_ques_ids, mentor_text)
    end
    return [header, mentor_profile_ques_ids, student_profile_ques_ids]
  end

  def set_header_and_profile_ques_ids(role_ques, header, profile_ques_ids, text)
    header << text + role_ques.question_text
    profile_ques_ids << role_ques.id
    return [header, profile_ques_ids]
  end

  def get_match_config_info(program)
    match_configs = program.match_configs.select('mentor_question_id, student_question_id')
    role_questions = program.role_questions.includes(:profile_question).select('role_questions.id, profile_question_id').index_by(&:id)
    mentor_text = "feature.bulk_match.content.mentors_answer".translate(Mentor: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term)
    mentee_text = "feature.bulk_match.content.mentees_answer".translate(Mentee: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).term)
    return [match_configs, role_questions, mentor_text, mentee_text]
  end
end
