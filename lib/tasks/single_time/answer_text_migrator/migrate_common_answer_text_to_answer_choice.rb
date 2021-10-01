class MigrateCommonAnswerTextToAnswerChoice
  def migrator
    start_time = Time.now
    load_objects
    migrate_answer_choices
    puts "Time taken: #{Time.now - start_time}"
  end

  def migrate_delta_answer_to_answer_choices(delta_common_answer_ids)
    return if delta_common_answer_ids.empty?
    common_answers = CommonAnswer.where(id: delta_common_answer_ids)
    ca_ids_for_choice_deletion = delta_common_answer_ids - common_answers.collect(&:id)
    cq_ids = common_answers.collect(&:common_question_id)
    non_choice_cq_ids = CommonQuestion.where(id: cq_ids).where.not(question_type: CommonQuestion::Type.choice_based_types).pluck(:id)
    ca_ids_for_choice_deletion += common_answers.where(common_question_id: non_choice_cq_ids).pluck(:id)

    AnswerChoice.where(ref_obj_id: ca_ids_for_choice_deletion, ref_obj_type: CommonAnswer.name).delete_all

    common_answers = common_answers.where.not(id: ca_ids_for_choice_deletion).includes({common_question: [question_choices: :translations]}, :answer_choices)

    return if common_answers.empty?

    question_choices_hash = build_choices_hash(cq_ids)

    common_answers.each do |common_answer|
      answer_choices = common_answer.answer_text.split(",").map(&:strip).reject(&:blank?)
      common_question = common_answer.common_question.get_question
      question_choices = question_choices_hash[common_question.id]
      answer_choice_ids = []

      position = 0
      answer_choices.each do |choice|
        question_choice_id = find_or_create_delta_question_choice!(common_question, question_choices, choice)
        next if question_choice_id.blank?
        ans_choice = common_answer.answer_choices.find {|ac| ac.question_choice_id == question_choice_id && ac.position == position}
        if ans_choice.blank? && (ans_choice = common_answer.answer_choices.find {|ac| ac.question_choice_id == question_choice_id}).present?
          ans_choice.update_columns(position: position)
        end
        ans_choice ||= common_answer.answer_choices.create!(question_choice_id: question_choice_id, position: position)
        answer_choice_ids << ans_choice.id
      end
      common_answer.answer_choices.where.not(id: answer_choice_ids).delete_all
    end
  end

  def build_choices_hash(common_question_ids)
    common_question_ids += CommonQuestion.where(id: common_question_ids).pluck(:matrix_question_id)
    question_choices = QuestionChoice.includes(:translations).where(ref_obj_type: CommonQuestion.name, ref_obj_id: common_question_ids, is_other: false).select(:id, :ref_obj_id)
    hsh = {}
    question_choices.each do |qc|
      hsh[qc.ref_obj_id] ||= {}
      qc.translations.each do |qct|
        hsh[qc.ref_obj_id][qct.text.downcase] = qc.id
      end
    end
    hsh
  end

  def find_or_create_delta_question_choice!(common_question, question_choices, choice)
    downcased_choice = choice.downcase
    question_choice_id = question_choices[downcased_choice]
    if question_choice_id.blank? && common_question.allow_other_option?
      question_choice = common_question.question_choices.find_or_initialize_by(text: choice, is_other: true)
      question_choice.position = question_choices.size + 1
      question_choice.save! if question_choice.new_record?
      question_choice_id = question_choice.id
    end
    question_choice_id
  end

  def load_objects
    choice_based_types = [CommonQuestion::Type::SINGLE_CHOICE, CommonQuestion::Type::MULTI_CHOICE, CommonQuestion::Type::RATING_SCALE, CommonQuestion::Type::MATRIX_RATING]
    @common_question_ids = CommonQuestion.where(question_type: choice_based_types).pluck(:id)
    @question_choices_hash = build_question_choices_hash
    @other_choices_hash = {}
    @allow_other_q_ids = CommonQuestion.where(id: @common_question_ids, allow_other_option: true).pluck(:id)
    @matrix_q_ids = CommonQuestion.where(id: @common_question_ids).where.not(matrix_question_id: nil).select(:id, :matrix_question_id).index_by(&:id)
  end

  def build_question_choices_hash
    question_choices = QuestionChoice.includes(:translations).where(ref_obj_type: 'CommonQuestion').select(:id, :ref_obj_id)
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
    common_answers_sets = create_common_answer_sets
    Parallel.map_with_index(common_answers_sets, in_processes: @processes) do |common_answer_set, set_index|
      begin
        @other_choices_hash[set_index] ||= {}
        self.instance_variable_set("@import_list_#{set_index}", [])
        common_answer_set.each.with_index do |common_answer, index|
          # common_answer[1] => answer_text
          next if common_answer[1].blank?
          populate_answer_choices_import_list(common_answer, set_index)
          puts index if (index % 10000).zero?
        end
        import_list = self.instance_variable_get("@import_list_#{set_index}")
        columns = [:ref_obj_id, :ref_obj_type, :question_choice_id, :position]
        AnswerChoice.import(columns, import_list, validate: false)
      rescue => ex
        puts ex.message
        puts ex.backtrace
        raise ex
      end
    end
  end

  def create_common_answer_sets
    common_answers = CommonAnswer.where(common_question_id: @common_question_ids).where.not(answer_text: nil).where.not(answer_text: "").pluck(:id, :answer_text, :common_question_id)
    @processes = (Class.new.extend(Parallel::ProcessorCount).processor_count)/2
    slice_size = (common_answers.size.to_f/(@processes)).ceil
    slice_size = 1 if slice_size.zero?
    common_answers.each_slice(slice_size).to_a
  end

  def populate_answer_choices_import_list(common_answer, set_index)
    common_answer_id = common_answer[0]
    answer_text = common_answer[1]
    common_question_id = get_common_question_id(common_answer[2])
    answer_choices = answer_text.split(",").map(&:strip).reject(&:blank?)
    question_choices = @question_choices_hash[common_question_id]

    position = 0
    answer_choices.each do |choice|
      question_choice_id = find_or_create_question_choice(common_question_id, question_choices, choice, set_index)
      next if question_choice_id.blank?
      import_list = self.instance_variable_get("@import_list_#{set_index}")
      import_list << [common_answer_id, CommonAnswer.name, question_choice_id, position]
      self.instance_variable_set("@import_list_#{set_index}", import_list)
    end
  end

  def find_or_create_question_choice(common_question_id, question_choices, choice, set_index)
    downcased_choice = choice.downcase
    question_choice_id = question_choices[downcased_choice]
    if question_choice_id.blank? && is_allow_other_option_question?(common_question_id)
      question_choice_id  = @other_choices_hash[set_index][common_question_id][downcased_choice] if @other_choices_hash[set_index][common_question_id]
      if question_choice_id.blank?
        condition = {text: choice, ref_obj_id: common_question_id, ref_obj_type: CommonQuestion.name, is_other: true}
        question_choice = QuestionChoice.includes(:translations).find_or_initialize_by(condition)
        question_choice.position = question_choices.size + 1
        question_choice.save(validate: false) if question_choice.new_record?
        question_choice_id = question_choice.id
        @other_choices_hash[set_index][common_question_id] ||= {}
        @other_choices_hash[set_index][common_question_id][downcased_choice] = question_choice_id
      end
    end
    question_choice_id
  end

  def is_allow_other_option_question?(common_question_id)
    @allow_other_q_ids.include?(common_question_id)
  end

  def get_common_question_id(common_question_id)
    return common_question_id unless @matrix_q_ids[common_question_id].present?
    return @matrix_q_ids[common_question_id].matrix_question_id
  end
end