namespace :single_time do
  task :add_user_roles_survey_column => :environment do
    puts "Adding User roles as default column in survey response column..."
    Common::RakeModule::Utils.execute_task do
      Survey.where.not(type: Survey::Type::MEETING_FEEDBACK).all.each do |survey|
        survey.survey_response_columns.create!(:column_key => SurveyResponseColumn::Columns::Roles, :position => 3, :ref_obj_type => SurveyResponseColumn::ColumnType::DEFAULT)
      end
    end
  end

  task :update_connection_membership_role_id_in_survey_answers => :environment do
    Common::RakeModule::Utils.execute_task do
      iterate = 1
      query = SurveyAnswer.joins("INNER JOIN groups ON groups.id = common_answers.group_id INNER JOIN connection_memberships ON connection_memberships.user_id = common_answers.user_id AND connection_memberships.group_id = common_answers.group_id").select("common_answers.id, connection_memberships.role_id")
      survery_answer_id_role_id_hash = Hash[ActiveRecord::Base.connection.exec_query(query.to_sql).rows]

      SurveyAnswer.where.not(group_id: nil).find_each do |survey_answer|
        survey_answer.update_columns(connection_membership_role_id: survery_answer_id_role_id_hash[survey_answer.id], skip_delta_indexing: true)
        print "." if (iterate % 1000) == 0
        iterate += 1
      end
      Common::RakeModule::Utils.print_success_messages("Updated SurveyAnswer connection_membership_role_id.")
    end
    start_time = Time.now
    ElasticsearchReindexing.indexing_flipping_deleting([SurveyAnswer.name])
    Common::RakeModule::Utils.print_success_messages("SurveyAnswer indexed successfully.")
    puts "Time Taken for indexing: #{Time.now - start_time} seconds."
  end
end