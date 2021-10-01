namespace :survey_populator do
  desc "Repopulate Surveys for performance"
  task surveys_for_performance: :environment do
    ActiveRecord::Base.connection.execute("truncate table surveys")
    ActiveRecord::Base.connection.execute("truncate table common_answers")
    CommonQuestion.where(:type => "SurveyQuestion").destroy_all
    puts "next"
    survey_populator = PerformancePopulator.new    
    number_of_surveys = 10
    responses_for_survey = 25000
    program = Program.first
    mentor_name = program.roles.with_name([RoleConstants::MENTOR_NAME])
    student_name = program.roles.with_name([RoleConstants::STUDENT_NAME])
    roles = [mentor_name , student_name, mentor_name + student_name]
    mentors = program.mentor_users.active
    students = program.student_users.active
    survey_populator.populate_surveys(program, number_of_surveys, {:roles => Array(roles.sample)})
    survey_populator.populate_survey_answers(program, mentors, students, responses_for_survey)
    number_of_connection_questions = 10
    survey_populator.populate_connection_questions(program, number_of_connection_questions)
    survey_populator.populate_connection_answers(program)
  end
end