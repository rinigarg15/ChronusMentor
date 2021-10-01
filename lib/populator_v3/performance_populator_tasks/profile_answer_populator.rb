class ProfileAnswerPopulator < PopulatorTask
  def patch(options = {})
    original_counts = @counts_ary

    @program.roles.non_administrative.each do |role|
      questions = @program.profile_questions_for(role.name).select{|q| q.non_default_type? && !q.file_type?}
      @options[:profile_question] = questions
      @counts_ary = original_counts.map{|c| c * questions.size}

      member_ids = role.users.active.pluck(:member_id)
      profile_answer_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, member_ids)
      process_patch(member_ids, profile_answer_hsh)
    end
  end

  def add_profile_answers(member_ids, answers_count, options = {})
    questions = options[:profile_question]
    populate_bulk_answers(member_ids, questions, answers_count)
  end

  def remove_profile_answers(member_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Answer....." do
      profile_answer_ids = ProfileAnswer.where(:ref_obj_id => member_ids).select("profile_answers.id, ref_obj_id").group_by(&:ref_obj_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      ProfileAnswer.where(:id => profile_answer_ids).destroy_all
      self.class.display_deleted_count(member_ids.size * count, "Profile Answer")
    end
  end

  def populate_bulk_answers(member_ids, questions, options = {})
    members_size = member_ids.size
    self.class.benchmark_wrapper "Profile Answer" do
      question_counter = 0
      member_ids_index = 0
      member_ids_size = member_ids.size
      ProfileAnswer.populate(member_ids_size * questions.size, :per_query => 5_000) do |answer|
        question = questions[question_counter / member_ids_size]
        answer.profile_question_id = question.id
        answer.ref_obj_id = member_ids[member_ids_index % member_ids_size]
        answer.ref_obj_type = Member.to_s
        set_answer_text!(question, answer)
        self.dot
        question_counter += 1
        member_ids_index += 1
      end
      self.class.display_populated_count(member_ids.size * questions.size, "Profile Answer")
    end
  end

  def set_answer_text!(profile_question, answer)
    question_type = profile_question.question_type
    case question_type
    when ProfileQuestion::Type::LOCATION
      set_location!(answer)
    when ProfileQuestion::Type::TEXT
      answer.answer_text = Populator.sentences(1..2)
    when ProfileQuestion::Type::STRING
      answer.answer_text = Populator.words(2)
    when ProfileQuestion::Type::MULTI_STRING
      answer.answer_text = Populator.words(1..4).split(" ").join(ProfileAnswer::MULTILINE_SEPERATOR)
    end
    choices = get_choices(profile_question, question_type) || []
    populate_profile_answer_choices(profile_question, answer, choices, question_type)
  end

  def set_location!(answer)
    answer.answer_text = Populator.interpret_value(Demo::Locations::Addresses).values.join(", ")
    create_location(answer)
  end

  def create_location(answer)
    Location.populate 1 do |location|
      location.reliable = false
      location.full_address = answer.answer_text
      location.profile_answers_count = 1
      answer.location_id = location.id
    end
  end

  def populate_profile_answer_choices(profile_question, answer, choices, question_type)
    return unless choices.present?
    question_choices = profile_question.default_question_choices.index_by(&:text)
    position = 0
    answer.answer_text = choices.join(",")
    choices.each do |text|
      question_choice = question_choices[text]
      AnswerChoice.populate 1 do |answer_choice|
        answer_choice.ref_obj_id = answer.id
        answer_choice.question_choice_id = question_choice.id
        answer_choice.ref_obj_type = ProfileAnswer.name
        answer_choice.position = position
        position += 1 if question_type == ProfileQuestion::Type::ORDERED_OPTIONS
      end
    end
  end

  def get_choices(profile_question, question_type)
    case question_type
    when ProfileQuestion::Type::MULTI_CHOICE
      self.class.pick_random_answer(profile_question.default_question_choices.collect(&:text), [*3..7])
    when ProfileQuestion::Type::ORDERED_OPTIONS
      self.class.pick_random_answer(profile_question.default_question_choices.collect(&:text), [profile_question.options_count])
    when ProfileQuestion::Type::SINGLE_CHOICE
      self.class.pick_random_answer(profile_question.default_question_choices.collect(&:text), [1])
    end
  end

end