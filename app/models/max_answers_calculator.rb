module MaxAnswersCalculator
  def self.included(base)
    base.class_eval do
      extend ClassMethods
    end
  end

  module ClassMethods
    def max_count_by_program(program, profile_question_id = nil)
      organization_id = program.is_a?(Program) ? program.parent_id : program.id
      profile_question_conditions = { :organization_id => organization_id }
      profile_question_conditions.merge!(:id => profile_question_id) if profile_question_id.present?

      first = self.joins(:profile_answer => :profile_question).
        where(:profile_questions => profile_question_conditions).
        group('profile_answers.id').
        select('count(profile_answer_id) as count_all').
        order('count_all DESC').
        first
      (first && first.count_all).to_i
    end
  end
end