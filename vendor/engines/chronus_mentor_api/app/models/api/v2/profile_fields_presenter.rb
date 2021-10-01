class Api::V2::ProfileFieldsPresenter < Api::V2::BasePresenter
  include AppConstantsHelper
  SEPERATOR = ","

  def list(params = {})
    profile_question_ids =
      if (params.has_key?(:parent_field_id) && params.has_key?(:answer_text) && (parent_profile_question = ProfileQuestion.find_by(id: params[:parent_field_id])).present?)
        parent_profile_question ? parent_profile_question.dependent_questions.select{ |pq| pq.conditional_answer_matches_any_of_conditional_choices?(params[:answer_text]) }.collect(&:id) : []
      elsif params.has_key?(:parent_field_id) || params.has_key?(:answer_text)
        []
      elsif organization.skype_enabled?
        organization.profile_question_ids
      else
        organization.profile_questions.where.not(question_type: ProfileQuestion::Type::SKYPE_ID).pluck(:id)
      end

    includes_list = [:translations, :conditional_question_choices, roles: :program, question_choices: :translations]
    profile_questions = ProfileQuestion.select(:id, :question_type, :conditional_question_id).where(id: profile_question_ids).includes(includes_list)
    result = profile_questions.map { |question| question_hash(question) }
    return success_hash(result)
  end

  protected

  def question_hash(question)
    results_hash = {}
    results_hash[:id] = question.id
    results_hash[:label] = question.question_text
    results_hash[:type] = convert_question_type(question.question_type)
    results_hash[:choices] = question.default_choices.join_by_separator(SEPERATOR) if question.choice_or_select_type?
    results_hash[:condition_to_show] = {id: question.conditional_question_id, answer: question.conditional_text_choices.join_by_separator(SEPERATOR)} if question.conditional_question_id
    results_hash[:description] = question.help_text.to_s
    results_hash[:programs] = program_roles_mapping(question.roles)
    return results_hash
  end

  def program_roles_mapping(roles)
    prog_roles_map = {}
    roles.each do |role|
      prog_name = role.program.name
      role_name = RolesMapping.aliased_names([role.name])
      prog_roles_map[prog_name] = prog_roles_map[prog_name].nil? ? role_name : prog_roles_map[prog_name] + role_name
    end
    return prog_roles_map
  end

  # get type
  def convert_question_type(question_type)
    get_profile_question_type_options_array(true, false, false, organization.manager_enabled?).find { |key,value|
      value == (PROFILE_MERGED_QUESTIONS[question_type].presence || question_type)
    }.first
  end
end
