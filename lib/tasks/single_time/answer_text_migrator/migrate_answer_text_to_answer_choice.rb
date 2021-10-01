class MigrateAnswerTextToAnswerChoice
  def migrator
    start_time = Time.now
    load_objects
    migrate_answer_choices
    puts "Time taken: #{Time.now - start_time}"
  end

  def load_objects
    choice_based_types = [ProfileQuestion::Type::SINGLE_CHOICE, ProfileQuestion::Type::MULTI_CHOICE, ProfileQuestion::Type::RATING_SCALE, ProfileQuestion::Type::ORDERED_OPTIONS]
    @profile_question_ids = ProfileQuestion.where(question_type: choice_based_types).pluck(:id)
    @question_choices_hash = build_question_choices_hash
    @other_choices_hash = {}
    @allow_other_pq_ids = ProfileQuestion.where(id: @profile_question_ids, allow_other_option: true).pluck(:id)
    @ordered_option_pq_ids = ProfileQuestion.where(id: @profile_question_ids, question_type: ProfileQuestion::Type::ORDERED_OPTIONS).pluck(:id)
  end

  def build_question_choices_hash
    question_choices = QuestionChoice.includes(:translations).where(ref_obj_type: "ProfileQuestion").select(:id, :ref_obj_id)
    hsh = {}
    question_choices.each do |qc|
      hsh[qc.ref_obj_id] ||= {}
      qc.translations.each do |qct|
        hsh[qc.ref_obj_id][qct.text.downcase] = qc.id
      end
    end
    hsh
  end

  def migrate_answer_choices
    profile_answers_sets = create_profile_answer_sets
    Parallel.map_with_index(profile_answers_sets, in_processes: @processes) do |profile_answer_set, set_index|
      begin
        @other_choices_hash[set_index] ||= {}
        self.instance_variable_set("@import_list_#{set_index}", [])
        profile_answer_set.each.with_index do |profile_answer, index|
          # profile_answer[1] => answer_text
          next if profile_answer[1].blank?
          populate_answer_choices_import_list(profile_answer, set_index)
          puts index if (index % 10000).zero?
        end
        import_list = self.instance_variable_get("@import_list_#{set_index}")
        columns = [:ref_obj_id, :ref_obj_type, :question_choice_id, :position]
        AnswerChoice.import(columns, import_list, validate: false)
      rescue => ex
        puts ex.message
        raise ex
      end
    end
  end

  def create_profile_answer_sets
    profile_answers = ProfileAnswer.where(profile_question_id: @profile_question_ids).where.not(answer_text: nil).where.not(answer_text: "").pluck(:id, :answer_text, :profile_question_id)
    @processes = (Class.new.extend(Parallel::ProcessorCount).processor_count)/2
    slice_size = (profile_answers.size.to_f/(@processes)).ceil
    slice_size = 1 if slice_size.zero?
    profile_answers.each_slice(slice_size).to_a
  end

  def populate_answer_choices_import_list(profile_answer, set_index)
    profile_answer_id = profile_answer[0]
    answer_text = profile_answer[1]
    profile_question_id = profile_answer[2]
    separator = get_answer_text_separator(profile_question_id)
    answer_choices = answer_text.split(separator).map(&:strip).reject(&:blank?)
    question_choices = @question_choices_hash[profile_question_id]

    position = 0
    answer_choices.each do |choice|
      question_choice_id = find_or_create_question_choice(profile_question_id, question_choices, choice, set_index)
      next if question_choice_id.blank?
      import_list = self.instance_variable_get("@import_list_#{set_index}")
      import_list << [profile_answer_id, "ProfileAnswer", question_choice_id, position]
      self.instance_variable_set("@import_list_#{set_index}", import_list)
      position += 1 if is_ordered_option_question?(profile_question_id)
    end
  end

  def find_or_create_question_choice(profile_question_id, question_choices, choice, set_index)
    downcased_choice = choice.downcase
    question_choice_id = question_choices[downcased_choice]
    if question_choice_id.blank? && is_allow_other_option_question?(profile_question_id)
      question_choice_id  = @other_choices_hash[set_index][profile_question_id][downcased_choice] if @other_choices_hash[set_index][profile_question_id]
      if question_choice_id.blank?
        condition = {text: choice, ref_obj_id: profile_question_id, ref_obj_type: "ProfileQuestion", is_other: true}
        question_choice = QuestionChoice.includes(:translations).find_or_initialize_by(condition)
        question_choice.position = question_choices.size + 1
        question_choice.save(validate: false) if question_choice.new_record?
        question_choice_id = question_choice.id
        @other_choices_hash[set_index][profile_question_id] ||= {}
        @other_choices_hash[set_index][profile_question_id][downcased_choice] = question_choice_id
      end
    end
    question_choice_id
  end

  def get_answer_text_separator(profile_question_id)
    return ProfileAnswer::DELIMITOR if is_ordered_option_question?(profile_question_id)
    ProfileAnswer::SEPERATOR
  end

  def is_ordered_option_question?(profile_question_id)
    @ordered_option_pq_ids.include?(profile_question_id)
  end

  def is_allow_other_option_question?(profile_question_id)
    @allow_other_pq_ids.include?(profile_question_id)
  end
end