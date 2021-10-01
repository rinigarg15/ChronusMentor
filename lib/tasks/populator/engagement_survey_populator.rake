# rake enagement_surveys:create_for_performance
namespace :enagement_surveys do
  desc "Populate Admin Messages for Organization for performance"
  task create_for_performance: :environment do
    t1 = Time.now
    ActionMailer::Base.perform_deliveries = false
    survey_populator = PerformancePopulator.new
    program = Program.find_by(root: "p1")
    # program = Program::Domain.get_organization("localhost.com", "ceg").programs.where(:root => "cs").first
    survey_populator.populate_engagement_surveys(program, 10)
    models = program.mentoring_models.select{|m| m.base?}
    roles = program.roles.with_name([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    all_surveys = program.surveys.of_engagement_type
    tasks_in_model = {}
    models.each do |model|
      tasks_in_model[model.id] = {}
      roles.each do |role|
        tasks_in_model[model.id][role.id] = []
        all_surveys.sample(2).each do |survey|
          task_template = model.mentoring_model_task_templates.new
          task_template.role = role
          task_template.action_item_type = MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY
          task_template.action_item_id = survey.id
          task_template.title = survey.name
          task_template.duration = 0
          task_template.save!
          tasks_in_model[model.id][role.id] << task_template
        end
      end
    end

    puts "populated task templates => #{Time.now - t1}"
    
    response_id =  SurveyAnswer.maximum(:response_id).to_i + 1
    all_tasks = []
    program.groups.published.select([:id, :mentoring_model_id]).each do |group|
      group.memberships.each do |grp_mem|
        model = group.mentoring_model || program.default_mentoring_model
        next if tasks_in_model[model.id].nil?
        tasks_in_model[model.id][grp_mem.role_id].each do |tem_task|
          mentoring_model_task = group.mentoring_model_tasks.new(tem_task.attributes.pick("title", "description", "required", "position", "action_item_type", "action_item_id"))
          mentoring_model_task.connection_membership_id = grp_mem.id
          mentoring_model_task.status = MentoringModel::Task::Status::TODO
          mentoring_model_task.from_template = true
          mentoring_model_task.mentoring_model_task_template_id = tem_task.id
          mentoring_model_task.skip_observer = true
          mentoring_model_task.save!
          all_tasks << mentoring_model_task
        end
      end
    end
    puts "created individual task for templates => #{Time.now - t1}"

    smaller_size = all_tasks.size/4
    all_tasks.each_slice(smaller_size) do |tasks_subset|
      survey_populator.popluate_engagement_survey_answers(tasks_subset, response_id)
    end
    puts "created survey answers => #{Time.now - t1}"


    ActiveRecord::Base.transaction do
      all_surveys.collect(&:survey_questions).flatten.each do |ques|
        ques.update_attributes(:common_answers_count => SurveyAnswer.where(:common_question_id => ques.id).count)
      end
    end
    puts "updated survey question => #{Time.now - t1}"
  end
end