module AppConstantsHelper

  def get_login_expiry_array_display
    login_expiry_array = [["common_text.n_mins".translate(count: 15), 15],
                          ["common_text.n_mins".translate(count: 30), 30],
                          ["common_text.n_mins".translate(count: 45), 45],
                          ["common_text.hour".translate(count: 1), 60],
                          ["common_text.n_hours_n_mins".translate(count: 1, n_mins: "common_text.n_mins".translate(count: 15)), 75],
                          ["common_text.n_hours_n_mins".translate(count: 1, n_mins: "common_text.n_mins".translate(count: 30)), 90],
                          ["common_text.n_hours_n_mins".translate(count: 1, n_mins: "common_text.n_mins".translate(count: 45)), 105],
                          ["common_text.hour".translate(count: 2), 120],
                          ["common_text.n_hours_n_mins".translate(count: 2, n_mins: "common_text.n_mins".translate(count: 15)), 135],
                          ["common_text.n_hours_n_mins".translate(count: 2, n_mins: "common_text.n_mins".translate(count: 30)), 150],
                          ["common_text.n_hours_n_mins".translate(count: 2, n_mins: "common_text.n_mins".translate(count: 45)), 165],
                          ["common_text.hour".translate(count: 3), 180]]
  return login_expiry_array
  end

  def get_common_question_type_options_array
    options_array = [["app_constant.question_type.Single_line".translate, CommonQuestion::Type::STRING],
                     ["app_constant.question_type.Multi_line".translate, CommonQuestion::Type::TEXT],
                     ["app_constant.question_type.Multiple_entries".translate, CommonQuestion::Type::MULTI_STRING],
                     ["app_constant.question_type.Pick_one_answer".translate, CommonQuestion::Type::SINGLE_CHOICE],
                     ["app_constant.question_type.Pick_multiple_answers".translate, CommonQuestion::Type::MULTI_CHOICE]]
    return options_array
  end

  def get_question_type_options_array(class_name)
    options_array = get_common_question_type_options_array + 
                    (class_name == "SurveyQuestion" ? get_survey_question_type_options_array : get_file_question_type_options_array)
    return options_array
  end

  def get_email_options_array
    options_array = [["app_constant.question_type.Email".translate, ProfileQuestion::Type::EMAIL]]
    return options_array
  end

  def get_name_options_array
    options_array = [["app_constant.question_type.Name".translate, ProfileQuestion::Type::NAME]]
    return options_array
  end

  def get_profile_question_type_options_array(include_location=false, include_email=false, include_name=false, include_manager=false)
    ([
      ["app_constant.question_type.Text_Entry".translate, CommonQuestion::Type::STRING],
      ["app_constant.question_type.Multiple_Text_Entry".translate, CommonQuestion::Type::MULTI_STRING],
      ["app_constant.question_type.Multi_line".translate, CommonQuestion::Type::TEXT],
      ["app_constant.question_type.Pick_one_answer".translate, CommonQuestion::Type::SINGLE_CHOICE],
      ["app_constant.question_type.Pick_multiple_answers".translate, CommonQuestion::Type::MULTI_CHOICE]
    ] + get_file_question_type_options_array + [
      ["app_constant.question_type.Ordered_Options".translate, ProfileQuestion::Type::ORDERED_OPTIONS],
      ["app_constant.question_type.Education".translate, ProfileQuestion::Type::MULTI_EDUCATION],
      ["app_constant.question_type.Experience".translate, ProfileQuestion::Type::MULTI_EXPERIENCE],
      ["app_constant.question_type.publication".translate, ProfileQuestion::Type::MULTI_PUBLICATION],
      ["app_constant.question_type.Skype_ID".translate, ProfileQuestion::Type::SKYPE_ID],
      ["app_constant.question_type.Date".translate, ProfileQuestion::Type::DATE]
    ] + get_specific_profile_question_type_options_array(include_location, include_email, include_name, include_manager)).sort_translated_contents
  end

  # Question types for survey.
  def get_survey_question_type_options_array
    options_array = [["app_constant.question_type.Rating_Scale".translate, CommonQuestion::Type::RATING_SCALE], ["app_constant.question_type.matrix_rating".translate, CommonQuestion::Type::MATRIX_RATING]]
    return options_array
  end

  # Question types for upload file option.
  def get_file_question_type_options_array
    options_array = [["app_constant.question_type.Upload_File".translate, CommonQuestion::Type::FILE]]
    return options_array
  end

  # Question types for location.
  def get_location_question_type_options_array
    options_array = [["app_constant.question_type.Location".translate, ProfileQuestion::Type::LOCATION]]
    return options_array
  end

  # Question types for manager.
  def get_manager_question_type_options_array
    [["app_constant.question_type.manager".translate, ProfileQuestion::Type::MANAGER]]
  end

  def get_mentor_limit_options(no_limit_value = nil)
    options_array = [["app_constant.mentor_limit.No_limit".translate, no_limit_value]]

    10.times do |i|
      options_array << ["app_constant.mentor_limit.n_mentors".translate(count: i+1, mentor: _mentor, mentors: _mentors), i+1]
    end
    return options_array
  end

  def get_circle_limit_options
    options_array = [["app_constant.circle_limit.No_limit".translate, nil]]

    10.times do |i|
      options_array << ["app_constant.circle_limit.n_circles".translate(count: i+1, mentoring_connection: _mentoring_connection, mentoring_connections: _mentoring_connections), i+1]
    end
    return options_array
  end

  def get_max_request_limit_for_mentee_options 
    options_array = [["app_constant.request_limit.No_limit".translate, nil]]
    10.times do |i|
      options_array << ["app_constant.request_limit.n_requests".translate(count: i+1), i+1]
    end
    return options_array
  end

  def get_connection_tracking_period_options
    options_array = [["app_constant.connection_tracking_period.Never".translate, nil]]
    #get intervals with a gap of 1 week 
    [1, 2, 3].each do |week|
      options_array << ["app_constant.connection_tracking_period.n_weeks".translate(count: week), week*7]
    end

    options_array << ["app_constant.connection_tracking_period.n_months".translate(count: 1), Program::DEFAULT_CONNECTION_TRACKING_PERIOD]

    #get intervals with a gap of 1 or 2 month(2), from 2 months to 12 months
    [2, 3, 4, 6, 8, 10, 12].each do |month|
      options_array << ["app_constant.connection_tracking_period.n_months".translate(count: month), month*30]
    end

    return options_array
  end

  private

  def get_specific_profile_question_type_options_array(include_location, include_email, include_name, include_manager)
    (include_manager ? get_manager_question_type_options_array : []) +
    (include_location ? get_location_question_type_options_array : []) +
    (include_email ? get_email_options_array : []) +
    (include_name ? get_name_options_array : [])
  end

end