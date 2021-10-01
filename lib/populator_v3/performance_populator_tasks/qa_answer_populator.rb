class QaAnswerPopulator < PopulatorTask
  def patch(options = {})
    qa_question_ids = @program.qa_questions.pluck(:id)
    qa_answer_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, qa_question_ids)
    process_patch(qa_question_ids, qa_answer_hsh)
  end

  def add_qa_answers(qa_question_ids, answers_count, options = {})
    self.class.benchmark_wrapper "Qa Answers" do
      temp_qa_question_ids = qa_question_ids * answers_count
      program = options[:program]
      user_ids = program.users.active.pluck(:id)

      QaAnswer.populate (answers_count * qa_question_ids.size) do |answer|
        answer.qa_question_id = temp_qa_question_ids.shift
        answer.user_id = user_ids.first
        user_ids = user_ids.rotate
        answer.content = Populator.sentences(2..4)
        answer.score = 0
        self.dot
      end
      ActiveRecord::Base.transaction do
        QaQuestion.where(id: qa_question_ids).update_all(qa_answers_count: answers_count)
      end
      self.class.display_populated_count(qa_question_ids.size * answers_count, "Qa Answer")
    end
  end

  def remove_qa_answers(qa_question_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Qa answers....." do
      program = options[:program]
      qa_answer_ids = program.qa_answers.where(:qa_question_id => qa_question_ids).select("qa_answers.id, qa_question_id").group_by(&:qa_question_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      program.qa_answers.where(:id => qa_answer_ids).destroy_all
      self.class.display_deleted_count(qa_question_ids.size * count, "Qa Answer")
    end
  end
end