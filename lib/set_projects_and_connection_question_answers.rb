module SetProjectsAndConnectionQuestionAnswers

  def set_projects_and_connection_question_in_summary_hash
    set_projects
    set_connection_question_and_answers_hash
  end

  def set_projects
    @projects, @show_all_projects_option = @current_user.available_projects_for_user(true)
    @projects = @projects.first(ProgramsController::MAX_PROJECTS_TO_SHOW_IN_HOME_PAGE_WIDGET)
  end

  def set_connection_question_and_answers_hash
    @connection_question = @current_program.connection_summary_question
    @connection_question_answer_in_summary_hash =  Hash[@projects.collect(&:answers).flatten.select{|answer| answer.common_question_id == @connection_question.id}.group_by(&:group_id).map { |k, v| [k, v.first.answer_text] } ] if @connection_question && !@connection_question.is_admin_only?
  end
  
end