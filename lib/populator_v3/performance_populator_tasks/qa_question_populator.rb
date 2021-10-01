class QaQuestionPopulator < PopulatorTask
  def patch(options = {})
    user_ids = @program.users.active.pluck(:id)
    qa_question_hsh =  get_children_hash(@program, @options[:args]["model"]||@node, @foreign_key, user_ids)
    process_patch(user_ids, qa_question_hsh) 
  end

  def add_qa_questions(user_ids, questions_count, options = {})
    self.class.benchmark_wrapper "Qa Questions" do
      all_student_ids = user_ids * questions_count
      program = options[:program]
      QaQuestion.populate user_ids.size * questions_count do |question|
        question.program_id = program.id
        question.user_id = all_student_ids.shift
        question.summary = Populator.words(4..8)
        question.description = Populator.sentences(4..8)
        question.qa_answers_count = 0
        question.created_at = program.created_at
        question.updated_at = program.created_at..Time.now
        self.dot
      end
      populate_activity(program, user_ids, ActivityLog::Activity::QA_VISIT, 1)
      self.class.display_populated_count(user_ids.size * questions_count, "Qa Question")
    end
  end

  def remove_qa_questions(user_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Qa questions....." do
      program = options[:program]
      qa_question_ids = program.qa_questions.where(:user_id => user_ids).select([:id, :user_id]).group_by(&:user_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      program.qa_questions.where(:id => qa_question_ids).destroy_all
      self.class.display_deleted_count(user_ids.size * count, "Qa Question")
    end
  end
end