module ThreeSixty::SurveyAssesseesHelper
  def assigned_survey_assessees(survey)
    survey_assessees = survey.survey_assessees
    if survey_assessees.empty?
      content_tag(:span, "display_string.None".translate, :class => 'dim')
    else
      and_downcase = "feature.three_sixty.dashboard.assessees.and".translate
      show_less = "display_string.laquo_show_less_html".translate
      remaining_users_count = survey_assessees.size - ThreeSixty::SurveyAssessee::NO_OF_FIRST_USERS
      links_to_first_three_users = safe_join(survey_assessees.first(ThreeSixty::SurveyAssessee::NO_OF_FIRST_USERS).collect{ |survey_assessee| link_to_user(survey_assessee.assessee) }, ", ")
      links_to_all_users_with_show_less = content_tag(:span, safe_join(survey_assessees.collect{ |survey_assessee| link_to_user(survey_assessee.assessee) }, ", ") + " "  + link_to(show_less, '#', :class => "three_sixty_toggle_class"), :style => "display:none;")
      links_to_first_three_users_and_show_others = content_tag(:span, "#{links_to_first_three_users} #{and_downcase} ".html_safe + link_to("#{remaining_users_count} #{'other'.pluralize(remaining_users_count)}", '#', :class => "three_sixty_toggle_class")) + links_to_all_users_with_show_less
      (remaining_users_count > 0) ? links_to_first_three_users_and_show_others : links_to_first_three_users
    end
  end

  def three_sixty_text_answers_for(survey_reviewer_group, survey_question, reviewers)
    answers = []
    (reviewers[survey_reviewer_group.id]||[]).each do |reviewer|
      answer = reviewer.answers.find{ |answer| answer.three_sixty_survey_question_id == survey_question.id }
      answers << answer if answer.present?
    end
    answers
  end

  def three_sixty_reviewer_group_lables(survey_reviewer_groups, reviewers, survey_question, reviewers_per_group)
    reviewer_group_lables = []
    survey_reviewer_groups.each do |srg|
      reviewer_group_lables << "#{srg.name.pluralize.truncate(30)} (#{(reviewers[srg.id]||[]).select{|r| r.answers.collect(&:three_sixty_survey_question_id).include?(survey_question.id)}.size} of #{reviewers_per_group[srg.id]})"
    end
    reviewer_group_lables
  end

  def three_sixty_reviewer_group_labels_for_competency(survey_reviewer_groups)
    reviewer_group_lables_for_competency = []
    survey_reviewer_groups.each do |srg|
      reviewer_group_lables_for_competency << srg.name.pluralize.truncate(30)
    end
    reviewer_group_lables_for_competency
  end

  def three_sixty_question_chart_height(survey_reviewer_groups)
    160 + survey_reviewer_groups.size * 50
  end

  def three_sixty_average_per_group(survey_reviewer_groups, average_reviewer_group_answer_values, survey_question)
    average_per_group = []
    survey_reviewer_groups.each do |srg|
      average_per_group << (average_reviewer_group_answer_values[[survey_question.question.id, srg.id]]||[]).first.try(:avg_value).to_f.round(2)
    end
    average_per_group
  end

  def three_sixty_get_data_for_question_or_competency(question_or_competency_percentiles, question_or_competency, survey_reviewer_groups, reviewer_group_for_self)
    question_or_competency_percentiles_per_reviewer_group = (question_or_competency_percentiles[question_or_competency.id]||{}).index_by(&:three_sixty_reviewer_group_id)
    percentile_per_group = []
    # Self Percentile
    percentile_per_group << question_or_competency_percentiles_per_reviewer_group[reviewer_group_for_self.id].try(:percentile).to_f.round(2)
    # All Evaluators Percentile
    percentile_per_group << question_or_competency_percentiles_per_reviewer_group[0].try(:percentile).to_f.round(2)
    survey_reviewer_groups.each do |srg|
      percentile_per_group << question_or_competency_percentiles_per_reviewer_group[srg.three_sixty_reviewer_group_id].try(:percentile).to_f.round(2)
    end
    percentile_per_group
  end

  def three_sixty_get_question_additional_data(survey_reviewer_groups, average_reviewer_group_answer_values, survey_question, question_infos, rating_answers_for_self)
    average_score = (question_infos.find{ |info| info.three_sixty_question_id == survey_question.question.id}.try(:average_value) || 0).to_f.round(2)
    self_score = (rating_answers_for_self.find{ |answer| answer.three_sixty_survey_question_id == survey_question.id}.try(:answer_value) || 0).to_f.round(2)
    [self_score, average_score] + three_sixty_average_per_group(survey_reviewer_groups, average_reviewer_group_answer_values, survey_question)
  end

  def three_sixty_get_competency_additional_data(survey_reviewer_groups, average_reviewer_group_answer_values, survey_competency, competency_infos, reviewer_group_for_self)
    average_score = (competency_infos.find{ |info| info.three_sixty_competency_id == survey_competency.competency.id}.try(:average_value) || 0).to_f.round(2)
    self_score = (competency_infos.find{ |info| info.three_sixty_competency_id == survey_competency.competency.id && reviewer_group_for_self.id == info.three_sixty_reviewer_group_id }.try(:average_value) || 0).to_f.round(2)
    [self_score, average_score] + three_sixty_competency_average_per_group(survey_reviewer_groups, average_reviewer_group_answer_values, survey_competency)
  end

  def three_sixty_competency_average_per_group(survey_reviewer_groups, average_reviewer_group_answer_values, survey_competency)
    average_per_group = []
    survey_reviewer_groups.each do |srg|
      average_per_group << (average_reviewer_group_answer_values[[survey_competency.competency.id, srg.id]]||[]).first.try(:avg_value).to_f.round(2)
    end
    average_per_group
  end

  def three_sixty_report_reviewers_per_group(survey_reviewer_groups, reviewers)
    reviewers_per_group = []
    survey_reviewer_groups.each do |srg|
      reviewers_per_group[srg.id] = (reviewers[srg.id]||[]).size
    end
    reviewers_per_group
  end

  def three_sixty_report_reviewers_per_group_text(survey_reviewer_groups, reviewers_per_group)
    content = []
    survey_reviewer_groups.each do |srg|
      content << "#{reviewers_per_group[srg.id]} #{srg.name.pluralize(reviewers_per_group[srg.id])}"
    end
    content.to_sentence(:last_word_connector =>  " #{'display_string.and'.translate} ")
  end
end