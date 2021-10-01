class Api::V2::MentoringTemplatePresenter < Api::V2::BasePresenter

  def list(params = {})
    if program.mentoring_connections_v2_enabled?
      data = program.mentoring_models.map { |mentoring_model| mentoring_model_hash(mentoring_model) }
      success_hash data
    else
      errors_hash(ApiConstants::ACCESS_UNAUTHORISED)
    end
  end

protected
  def mentoring_model_hash(mentoring_model)
    {
      id:           mentoring_model.id,
      name:         mentoring_model.title,
      description:  mentoring_model.description,
      duration:     mentoring_model.mentoring_period
    }
  end

end