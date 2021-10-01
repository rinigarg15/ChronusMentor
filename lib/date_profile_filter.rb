module DateProfileFilter
  
  # input : "from_date - to_date - preset"
  def get_date_query(date_string, options = {})
    date_range_query = construct_date_range_query(initialize_date_range_for_filter(date_string), options)
    join_date_answers_query = join_date_answers if (options[:join_date_answers] && date_range_query.present?)
    profile_question_query = scope_join_to_profile_question(options[:profile_question]) if (options[:profile_question] && date_range_query.present?)
    "#{options[:query_prefix]} #{join_date_answers_query} #{date_range_query} #{profile_question_query} #{options[:query_suffix]}"
  end

  def profile_question_answer_join_query(ref_obj_type, options = {})
    "join profile_answers on (profile_answers.ref_obj_id = #{options[:members] || 'members'}.id AND profile_answers.ref_obj_type=#{ref_obj_type})
     join profile_questions on profile_questions.id = profile_answers.profile_question_id"
  end
  
  # input : "from_date - to_date - preset"
  # output : [from_date, to_date, preset]
  def initialize_date_range_for_filter(date_string)
    values = date_string.to_s.split(DATE_RANGE_SEPARATOR)
    from_date, to_date, preset = values
    {
      from_date: get_safe_date(from_date, "time.formats.date_range".translate),
      to_date: get_safe_date(to_date, "time.formats.date_range".translate),
      preset: (preset.presence || DateRangePresets::CUSTOM)
    }
  end

  def get_date_range_string_for_variable_days(date_string, number_of_days, preset)
    if ([DateRangePresets::NEXT_N_DAYS, DateRangePresets::LAST_N_DAYS].include?(preset)) && (number_of_days.present?)
      date_string = date_range_string_for_variable_preset(preset, number_of_days)
    end
    date_string.to_s
  end
  
  def join_date_answers(options = {})
    ref_obj_id = options[:ref_obj_id] || "profile_answers.id"
    ref_obj_type = options[:ref_obj_type] || ActiveRecord::Base.connection.quote(ProfileAnswer.name)
    "#{options[:join_type]} join date_answers on (date_answers.ref_obj_id = #{ref_obj_id} AND date_answers.ref_obj_type = #{ref_obj_type})"
  end

  private
  
  def construct_date_range_query(date_range_hash, options = {})
    if construct_from_and_to_range?(date_range_hash)
      get_from_and_to_range_query(date_range_hash, options)
    elsif construct_from?(date_range_hash)
      get_from_query(date_range_hash, options)
    elsif construct_to?(date_range_hash)
      get_to_query(date_range_hash, options)
    end
  end


  def construct_from_and_to_range?(date_range_hash)
    construct_from?(date_range_hash) && construct_to?(date_range_hash)
  end

  def construct_from?(date_range_hash)
    date_range_hash[:from_date].present?
  end

  def construct_to?(date_range_hash)
    date_range_hash[:to_date].present?
  end

  def get_from_and_to_range_query(date_range_hash, options)
    "#{get_where_query unless options[:exclude_where]} date_answers.answer BETWEEN '#{date_range_hash[:from_date]}' AND '#{date_range_hash[:to_date]}'"
  end

  def get_from_query(date_range_hash, options)
    "#{get_where_query unless options[:exclude_where]} date_answers.answer >= '#{date_range_hash[:from_date]}'"
  end

  def get_to_query(date_range_hash, options)
    "#{get_where_query unless options[:exclude_where]} date_answers.answer <= '#{date_range_hash[:to_date]}'"
  end

  def get_where_query
    'where'
  end

  def scope_join_to_profile_question(profile_question)
    "AND profile_questions.id = #{profile_question.id}"
  end

  def date_range_string_for_variable_preset(preset, number_of_days)
    dates = case preset
            when DateRangePresets::NEXT_N_DAYS
              date_range_for_next_n_days(number_of_days)
            when DateRangePresets::LAST_N_DAYS
              date_range_for_last_n_days(number_of_days)
            when DateRangePresets::BEFORE_LAST_N_DAYS
              date_range_before_last_n_days(number_of_days)
            when DateRangePresets::AFTER_NEXT_N_DAYS
              date_range_after_next_n_days(number_of_days)
            else
              [nil, nil]
            end      
    (dates + [preset]).join(DATE_RANGE_SEPARATOR)
  end

  def get_safe_date(date_string, format)
    Date.strptime(date_string.to_s, format).strftime() 
  rescue ArgumentError
    nil
  end

  def dates_in_m_d_y_format(dates)
    dates.is_a?(Array) ? dates.collect { |date| date&.strftime("time.formats.date_range".translate) } : dates&.strftime("time.formats.date_range".translate)
  end

  def date_range_for_next_n_days(number_of_days)
    dates_in_m_d_y_format([Date.current, (Date.current + number_of_days.to_i.days)])
  end

  def date_range_for_last_n_days(number_of_days)
    dates_in_m_d_y_format([(Date.current - number_of_days.to_i.days), Date.current])
  end

  def date_range_before_last_n_days(number_of_days)
    dates_in_m_d_y_format([nil, (Date.current - number_of_days.to_i.days)])
  end

  def date_range_after_next_n_days(number_of_days)
    dates_in_m_d_y_format([(Date.current + number_of_days.to_i.days), nil])
  end
end