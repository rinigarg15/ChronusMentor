module MatchConfigsHelper
  def mentor_question_form_column(match_config, options = {})
    cur_value = match_config.mentor_question_id if (match_config && match_config.mentor_question)
    questions_scope = @current_program.
      role_questions_for([RoleConstants::MENTOR_NAME], fetch_all: true).role_profile_questions
    questions_scope = get_updated_scope(questions_scope, options)
    label = options[:label].presence || "match_config[mentor_question_id]"
    select_tag label, options_for_select(questions_scope.collect{|q| [q.question_text, q.id, question_type: q.question_type]}, cur_value), :class => "form-control cjs_question"
  end

  def student_question_form_column(match_config, options = {})
    cur_value = match_config.student_question.id if (match_config && match_config.student_question)
    question_scope = @current_program.
      role_questions_for([RoleConstants::STUDENT_NAME], fetch_all: true).role_profile_questions
    question_scope = get_updated_scope(question_scope, options)
    label = options[:label].presence || "match_config[student_question_id]"
    select_tag label, options_for_select(question_scope.collect{|q| [q.question_text, q.id, question_type: q.question_type]}, cur_value), :class => "form-control cjs_question"
  end

  def weight_form_column(match_config)
    field_weight_select_tag('match_config[weight]', match_config.weight)
  end

  def field_weight_select_tag(control_name, field_value)
    step = 0.1
    range = (-1..1)
    values = range.step(step).to_a.reverse.collect { |v| ['%.2f' % v] * 2 }
    select_tag control_name, options_for_select(values, '%.2f' % field_value), :class => "form-control"
  end

  def match_configs_to_json(match_configs)
    hash = []
    match_configs.each do |mc|
      sq = mc.student_question.profile_question
      mq = mc.mentor_question.profile_question

      hash << {
        :id => mc.id,
        :questions => [
          {:text => sq.question_text, :type => sq.question_type, :choices => sq.default_choices, :count => sq.options_count}, 
          {:text => mq.question_text, :type => mq.question_type, :choices => mq.default_choices, :count => mq.options_count}
         ],
        :weight => mc.weight, 
        :threshold => mc.threshold,
        :operator => (mc.operator == MatchConfig::Operator.lt) ? 1 : -1,
        :fscore => 0
      }
    end

    return hash.to_json
    
  end

  private

  def get_updated_scope(question_scope, options)
    question_type = options[:supplementary_scope] ? SupplementaryMatchingPair::Type.all : RoleQuestion::MatchType::MATCH_TYPE_FOR_QUESTION_TYPE.keys
    question_scope.joins(:profile_question).where(profile_questions: { question_type: question_type })
  end
end