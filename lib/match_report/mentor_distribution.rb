class MatchReport::MentorDistribution

  MENTEE_COLOR = "#1ab394"
  MENTOR_COLOR = "#FFA500"
  SET_MATCH_COLOR = "#f3f3f4"
  CATEGORIES_SIZE = 5
  attr_accessor :program, :match_config

  def initialize(program, options={})
    self.program = program
    self.match_config = options[:match_config]
  end

  def get_section_data
  end

  class << self
    def fetch_default_admin_view(program, role)
      default_view = (role == RoleConstants::MENTOR_NAME ? self.fetch_default_mentor_view(program) : self.fetch_default_mentee_view(program))
      AbstractView.find_by(default_view: default_view, program_id: program.id)
    end

    def fetch_default_mentor_view(program)
      program.only_one_time_mentoring_enabled? ? AbstractView::DefaultType::MENTORS : AbstractView::DefaultType::AVAILABLE_MENTORS
    end

    def fetch_default_mentee_view(program)
      program.only_one_time_mentoring_enabled? ? AbstractView::DefaultType::NEVER_CONNECTED_MENTEES : AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES
    end

    def handle_series_in_legend(discrepancy_hash, show_legend)
      show_legend ? discrepancy_hash : discrepancy_hash.merge({showInLegend: false})
    end

    def initialise_series_data_array(categories, discrepancy_data, index)
      data = Array.new(categories.size, 0)
      data[index] = discrepancy_data
      return data
    end

    def handle_categories_and_discrepancy_size(discrepancy_data)
      categories = discrepancy_data.map{ |data| data[:student_answer_choice]}
      remaining_categories_size = categories.size - CATEGORIES_SIZE
      categories = categories.first(CATEGORIES_SIZE)
      discrepancy_data = discrepancy_data.first(CATEGORIES_SIZE)
      return [categories, discrepancy_data, remaining_categories_size]
    end

    def get_answer_text_hash(answer_texts_array)
      answer_texts_array.each_with_object(Hash.new(0)) { |answer_text, answer_text_hash| answer_text_hash[answer_text] += 1 }
    end
  end

  def get_discrepancy_graph_series_data
    discrepancy_data = calculate_data_discrepancy
    return get_series_data(discrepancy_data)
  end

  def calculate_data_discrepancy
    mentor_user_ids = get_match_report_admin_view_user_ids(RoleConstants::MENTOR_NAME)
    student_user_ids = get_match_report_admin_view_user_ids(RoleConstants::STUDENT_NAME)

    return match_config.matching_type == MatchConfig::MatchingType::DEFAULT ? get_data_discrepancy_for_default_type(mentor_user_ids, student_user_ids) : get_data_discrepancy_for_set_type(mentor_user_ids, student_user_ids)
  end

  def get_data_discrepancy_for_default_type(mentor_user_ids, student_user_ids)
    mentor_answer_texts = get_user_answer_texts(mentor_user_ids, match_config.mentor_question.profile_question)
    student_answer_texts = get_user_answer_texts(student_user_ids, match_config.student_question.profile_question)
    student_choice_texts = match_config.student_question.profile_question.question_choices.collect(&:text)

    mentor_answer_text_hash = MatchReport::MentorDistribution.get_answer_text_hash(mentor_answer_texts)
    student_answer_text_hash = MatchReport::MentorDistribution.get_answer_text_hash(student_answer_texts)
    return get_needs_offers_discrepancy_for_default_type(student_choice_texts, mentor_answer_text_hash, student_answer_text_hash)
  end

  def get_data_discrepancy_for_set_type(mentor_user_ids, student_user_ids)
    matching_details = match_config.matching_details_for_matching
    return [] unless matching_details.present?
    student_choice_texts = matching_details.keys & get_formatted_choices(match_config.student_question.profile_question.question_choices.collect(&:text))
    mentor_choice_texts = matching_details.values.flatten.uniq & get_formatted_choices(match_config.mentor_question.profile_question.question_choices.collect(&:text))

    mentor_answer_texts, @mentor_answers_downcase_hash = get_filtered_answer_texts(mentor_user_ids, match_config.mentor_question.profile_question, mentor_choice_texts)
    student_answer_texts, @student_answers_downcase_hash = get_filtered_answer_texts(student_user_ids, match_config.student_question.profile_question, student_choice_texts)

    mentor_answer_text_hash = MatchReport::MentorDistribution.get_answer_text_hash(mentor_answer_texts)
    student_answer_text_hash = MatchReport::MentorDistribution.get_answer_text_hash(student_answer_texts)
    return get_needs_offers_discrepancy_for_set_type(student_choice_texts, mentor_answer_text_hash, student_answer_text_hash, {matching_details: matching_details})
  end

  def get_user_answer_texts(user_ids, profile_question)
    member_ids = program.users.where(id: user_ids).pluck(:member_id)

    ProfileAnswer.where(ref_obj_id: member_ids).includes([{answer_choices: {question_choice: :translations}}]).where(profile_question_id: profile_question.id).map{ |ans| ans.answer_choices.collect(&:question_choice).collect(&:text)}.flatten
  end

  def get_filtered_answer_texts(user_ids, profile_question, choice_texts)
    answer_texts = get_formatted_choices(get_user_answer_texts(user_ids, profile_question))
    all_answers_downcase_hash = Hash[profile_question.question_choices.collect(&:text).map { |ans| [ans.remove_braces_and_downcase, ans] } ]
    return [answer_texts.select{|text| choice_texts.include?(text)}, all_answers_downcase_hash]
  end

  def get_match_report_admin_view_user_ids(role_type)
    admin_view = program.get_match_report_admin_view(MatchReport::Sections::MentorDistribution, role_type).admin_view || MatchReport::MentorDistribution.fetch_default_admin_view(program, role_type)
    admin_view.get_user_ids_for_match_report
  end

  def get_needs_offers_discrepancy_for_default_type(student_choice_texts, mentor_answer_text_hash, student_answer_text_hash)
    all_discrepancies = []
    student_choice_texts.each do |student_answer_choice|
      student_need_count = student_answer_text_hash[student_answer_choice] || 0
      mentor_offer_count = mentor_answer_text_hash[student_answer_choice] || 0
      all_discrepancies << {discrepancy: student_need_count - mentor_offer_count, student_need_count: student_need_count, mentor_offer_count: mentor_offer_count, student_answer_choice: student_answer_choice, match_config_id: match_config.id}
    end
    all_discrepancies.sort_by{|d| d[:discrepancy]}.reverse!
  end

  def get_needs_offers_discrepancy_for_set_type(student_choice_texts, mentor_answer_text_hash, student_answer_text_hash, options={})
    all_discrepancies = []
    student_choice_texts.each do |student_answer_choice|
      student_need_count = student_answer_text_hash[student_answer_choice] || 0
      mentor_choices = options[:matching_details][student_answer_choice].try(:flatten)
      next if mentor_choices.blank?
      mentor_choice_hash, mentor_offer_count = get_mentor_choice_hash(mentor_answer_text_hash, mentor_choices)
      all_discrepancies << {discrepancy: student_need_count - mentor_offer_count, student_need_count: student_need_count, mentor_answer_choices: mentor_choice_hash, student_answer_choice: @student_answers_downcase_hash[student_answer_choice], mentor_offer_count: mentor_offer_count, match_config_id: match_config.id}
    end
    all_discrepancies.sort_by{|d| d[:discrepancy]}.reverse!
  end

  def get_mentor_choice_hash(mentor_answer_text_hash, mentor_choices)
    mentor_choice_hash = {}
    mentor_choice_count = 0
    mentor_choices.each do |mentor_choice|
      mentor_choice_hash[mentor_choice] = (mentor_answer_text_hash[mentor_choice] || 0)
      mentor_choice_count += mentor_choice_hash[mentor_choice]
    end
    [mentor_choice_hash, mentor_choice_count]
  end

  def get_series_data(discrepancy_data)
    discrepancy_array = []
    categories, discrepancy_data, remaining_categories_size = MatchReport::MentorDistribution.handle_categories_and_discrepancy_size(discrepancy_data)
    show_mentee_legend = true
    show_mentor_legend = true
    discrepancy_data.each_with_index do |discrepancy, index|
      student_need_count = MatchReport::MentorDistribution.initialise_series_data_array(categories, discrepancy[:student_need_count], index)
      discrepancy_array << get_mentee_discrepancy_hash(student_need_count, show_mentee_legend)
      show_mentee_legend = false
      discrepancy_array << (match_config.matching_type == MatchConfig::MatchingType::DEFAULT ? get_mentor_series_for_default_type(discrepancy, categories, index, show_mentor_legend) : get_mentor_series_for_set_type(discrepancy, categories, index, show_mentor_legend))
      show_mentor_legend = false
    end
    return [categories, discrepancy_array.flatten.compact, remaining_categories_size, discrepancy_data.first[:discrepancy]]
  end

  def get_mentor_series_for_default_type(discrepancy, categories, index, show_mentor_legend=false)
    mentor_term = program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).pluralized_term
    mentor_offer_count = MatchReport::MentorDistribution.initialise_series_data_array(categories, discrepancy[:mentor_offer_count], index)
    return MatchReport::MentorDistribution.handle_series_in_legend({
      name: mentor_term,
      data: mentor_offer_count,
      stack: mentor_term,
      color: MENTOR_COLOR
    }, show_mentor_legend)
  end

  def get_mentor_series_for_set_type(discrepancy, categories, series_index, show_mentor_legend=false)
    mentor_discrepancy_array = []
    discrepancy[:mentor_answer_choices].each_with_index do |mentor_answer_choice, index|
      mentor_offer_count = MatchReport::MentorDistribution.initialise_series_data_array(categories, mentor_answer_choice.second, series_index)
      mentor_discrepancy_array << MatchReport::MentorDistribution.handle_series_in_legend({
        name: (discrepancy[:mentor_answer_choices].size == 1 ? program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).pluralized_term : @mentor_answers_downcase_hash[mentor_answer_choice.first]),
        data: mentor_offer_count,
        stack: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).pluralized_term,
        color: MENTOR_COLOR,
        borderColor: SET_MATCH_COLOR,
        borderWidth: 1
      }, show_mentor_legend)
      show_mentor_legend = false
    end
    mentor_discrepancy_array
  end

  def get_mentee_discrepancy_hash(student_need_count, show_mentee_legend)
    mentee_term = program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term
    mentee_discrepancy_hash = {
      name: mentee_term,
      data: student_need_count,
      stack: mentee_term,
      color: MENTEE_COLOR
    }
    MatchReport::MentorDistribution.handle_series_in_legend(mentee_discrepancy_hash, show_mentee_legend)
  end

  def get_formatted_choices(array)
    array.map{|choice| choice.remove_braces_and_downcase }
  end
end