And /^I create activity data$/ do
  program = Program.find_by(root: :albers)
  program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
  prog_goal = program.goal_templates.first
  mentoring_model = program.default_mentoring_model
  mentoring_model.update_attribute(:goal_progress_type, MentoringModel::GoalProgressType::MANUAL)
  goal_template = mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")
  goal_template.update_attribute(:program_goal_template_id, prog_goal.id)
  group = create_group(:mentors => [program.mentor_users.first], student: [program.student_users.first])
  connection_goals = group.mentoring_model_goals.where(:mentoring_model_goal_template_id => goal_template.id)
  goal_1 = connection_goals.first
  act1 = create_mentoring_model_goal_activity(goal_1, {progress_value: nil})
  act2 = create_mentoring_model_goal_activity(goal_1, {progress_value: 45})
  act3 = create_mentoring_model_goal_activity(goal_1, {progress_value: 78})  
end