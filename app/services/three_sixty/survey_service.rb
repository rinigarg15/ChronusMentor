class ThreeSixty::SurveyService
  def survey_dashboard(params, state, organization, program)
    options = {}
    # page, per_page, sort_param and sort_order in options are used in views
    options[:sort_param] = params[:sort_param] || "title"
    options[:sort_order] = params[:sort_order] || "asc"
    options[:page] = (params[:page] || 1).to_i
    options[:per_page] = ThreeSixty::SurveysController::DEFAULT_PER_PAGE
    options[:search_params] = {}
    options[:search_params][:page] = options[:page]
    options[:search_params][:per_page] = options[:per_page]
    options[:search_params][:sort_field] = options[:sort_param]
    options[:search_params][:sort_order] = options[:sort_order]
    options[:filter] = {organization_id: organization.id, state: state}
    options[:filter][:program_id] = program.id if program
    if state == ThreeSixty::Survey::PUBLISHED
      options[:includes_list] = [{survey: [:program]}, :assessee, {reviewers: :answers}]
      survey_assessees_ids = (program || organization).three_sixty_survey_assessees.pluck(:id)
      options[:filter][:id] = survey_assessees_ids.presence || [0]
    else
      options[:includes_list] = [:program, :survey_questions, :survey_reviewer_groups, {survey_assessees: :assessee}]
      survey_ids = (program || organization).three_sixty_surveys.pluck(:id)
      options[:filter][:id] = survey_ids.presence || [0]
    end
    options
  end
end