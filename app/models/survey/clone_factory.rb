# clones survey by given parameters
#
# usage:
#   factory = Survey::CloneFactory.new(src_survey, program)
#   new_survey = factory.clone
#   new_survey.save!

class Survey::CloneFactory
  attr_reader :source, :clone

  def initialize(source, program = nil)
    @source = source
    # clone for the same program if not given
    @program = program || @source.program
    # clone it
    make_clone!
  end

  protected

  def make_clone!
    @program.surveys << (@clone = @source.dup_with_translations)
    @clone.total_responses = 0
    @clone.due_date = nil
    @clone.form_type = nil
    @clone.progress_report = false unless @program.share_progress_reports_enabled?
    clone_questions!
    clone_roles!
  end

  def clone_questions!
    @source.survey_questions.includes(:rating_questions, :question_choices).each do |q|
      q_dup = q.dup_with_translations
      q_dup.program = @program
      q_dup.survey = @clone
      q_dup.positive_outcome_options = nil
      q_dup.positive_outcome_options_management_report = nil
      if q.matrix_question_type?
        q.rating_questions.map(&:dup_with_translations).each do |rq|
          rq.program = @program
          rq.matrix_question = q_dup
          rq.survey = @clone
          rq.positive_outcome_options = nil
          rq.positive_outcome_options_management_report = nil
          q_dup.rating_questions << rq
        end
      end
      if q.choice_or_select_type?
        q.question_choices.map(&:dup_with_translations).each do |qc|
          qc.ref_obj = q_dup
          q_dup.question_choices << qc
        end
      end
      @clone.survey_questions << q_dup
    end
  end

  def clone_roles!
    @clone.recipient_roles = @source.recipient_roles if @clone.program_survey?
  end
end