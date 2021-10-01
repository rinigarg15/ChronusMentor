class Api::V2::ConnectionProfileFieldsPresenter < Api::V2::BasePresenter
  SEPERATOR = ","
  # get all program's questions
  def list(params = {})
    data = program.connection_questions.includes(:translations, question_choices: :translations).map { |q| question_hash(q) }
    # map received data to array
    success_hash data
  end

protected
  def question_hash(question)
    {
      id:      question.id,
      label:   question.question_text,
      type:    question.question_type,
      choices: question.default_choices.join_by_separator(SEPERATOR)
    }
  end
end
