class ConnectionQuestionPopulator < PopulatorTask

  def patch(options = {})
    program_ids = @organization.programs.select(&:engagement_enabled?).collect(&:id)
    connection_questions_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, program_ids)
    process_patch(program_ids, connection_questions_hsh)
  end

  def add_connection_questions(program_ids, count, options = {})
    self.class.benchmark_wrapper "Connection Questions" do
      iterator = 0
      temp_program_ids = program_ids * count
      Connection::Question.populate(program_ids.size * count) do |connection_question|
        question_text = Populator.words(5..8)
        help_text = Populator.words(3..5)
        connection_question.type = Connection::Question.to_s
        connection_question.program_id = temp_program_ids.shift
        connection_question.question_type = [CommonQuestion::Type::STRING, CommonQuestion::Type::TEXT, CommonQuestion::Type::SINGLE_CHOICE]
        connection_question.position = iterator += 1
        connection_question.required = [false, false, true]
        connection_question.is_admin_only = [false, false, false, true]
        connection_question.allow_other_option = [false, false, true]

        locales = @translation_locales.dup
        CommonQuestion::Translation.populate @translation_locales.count do |common_question_translation|
          common_question_translation.common_question_id = connection_question.id
          common_question_translation.question_text = DataPopulator.append_locale_to_string(question_text, locales.last)
          common_question_translation.help_text = DataPopulator.append_locale_to_string(help_text, locales.last)
          common_question_translation.question_info = nil
          common_question_translation.locale = locales.pop
        end

        populate_question_choices(connection_question, CommonQuestion.name, @translation_locales)
        self.dot
      end
      self.class.display_populated_count(program_ids.size * count, "Connection Question")
    end
  end

  def remove_connection_questions(program_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Connection Question................" do
      connection_question_ids = Connection::Question.where(:program_id => program_ids).select([:id, :program_id]).group_by(&:program_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      Connection::Question.where(:id => connection_question_ids).destroy_all
      self.class.display_deleted_count(program_ids.size * count, "Connection Question")
    end
  end
end