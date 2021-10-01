module CustomSqlQuery
  module SelectColumns
    ANSWER_MAP = {
      "users.id" => 0,
      "profile_answers.id" => 1,
      "profile_answers.answer_text" => 2,
      "profile_questions.question_type" => 3,
      "profile_question_translations.question_text" => 4,
      "profile_question_translations.question_info" => 5,
      "locations.lat" => 6,
      "locations.lng" => 7,
      "educations.school_name" => 8,
      "educations.major" => 9,
      "experiences.job_title" => 10,
      "experiences.company" => 11,
      "A_match_configs.mentor_question_id" => 12,
      "A_match_configs.student_question_id" => 13,
      "users.member_id" => 14,
      "question_choice_translations.text" => 15
    }
    ANSWERS_FIELDS = ANSWER_MAP.keys.join(", ")
  end

  INDEX_DATA = Proc.new {|select_columns, program_id, role_name, role_id, options = {}|
    match_config_field = (role_name == RoleConstants::MENTOR_NAME ? 'mentor_question_id' : 'student_question_id')
    sql_query = <<-SQL
      SELECT #{select_columns} FROM `users`
      INNER JOIN `role_references` ON `role_references`.`ref_obj_id` = `users`.`id`
      INNER JOIN `roles` ON `roles`.`id` = `role_references`.`role_id` AND `role_references`.`ref_obj_type` = 'User' AND `roles`.`name` = '#{role_name}'
      LEFT JOIN `profile_answers` ON `profile_answers`.`ref_obj_id` = `users`.`member_id` AND `profile_answers`.`ref_obj_type` = 'Member'
      LEFT JOIN `answer_choices` ON `answer_choices`.`ref_obj_id` = `profile_answers`.`id`
        AND `answer_choices`.`ref_obj_type` = 'ProfileAnswer'
      LEFT JOIN `question_choice_translations` ON `question_choice_translations`.`question_choice_id` = `answer_choices`.`question_choice_id`
          AND `question_choice_translations`.`locale` = '#{I18n.default_locale}'
      LEFT JOIN `profile_questions` ON `profile_questions`.`id` = `profile_answers`.`profile_question_id`
      LEFT JOIN `role_questions` ON `role_questions`.`profile_question_id` = `profile_questions`.`id` AND `role_questions`.`role_id` = #{role_id}
      LEFT JOIN (SELECT `match_configs`.`program_id`, `match_configs`.`id`, `match_configs`.`mentor_question_id`, `match_configs`.`student_question_id` 
        FROM `match_configs` WHERE `match_configs`.`program_id` = #{program_id}
       ) A_match_configs 
        ON (`role_questions`.`id` = `A_match_configs`.#{match_config_field})
      LEFT JOIN `educations` ON `educations`.`profile_answer_id` = `profile_answers`.`id`
      LEFT JOIN `experiences` ON `experiences`.`profile_answer_id` = `profile_answers`.`id`
      LEFT JOIN `locations` ON `locations`.`id` = `profile_answers`.`location_id`
      LEFT JOIN `profile_question_translations` ON `profile_question_translations`.`profile_question_id` = `profile_questions`.`id` AND `profile_question_translations`.`locale` = '#{I18n.default_locale}'
      WHERE `users`.`program_id` = #{program_id} AND `users`.`state` != '#{User::Status::SUSPENDED}'
    SQL
    sql_query << " AND `users`.`id` IN (#{options[:user_ids].join(',')})" if options[:user_ids].present?
    sql_query
  }
end