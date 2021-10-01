class MigrateDeltaCommonQuestionInfoAndAnswerTextToChoices< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration do
      ActiveRecord::Base.transaction do
        delta_common_question_ids = ActiveRecord::Base.connection.exec_query("select ref_obj_id from temp_profile_objects where ref_obj_type = '#{CommonQuestion.name}'").rows.flatten
        MigrateCommonQuestionInfoToQuestionChoice.new.migrate_delta_question_info_to_question_choices(delta_common_question_ids)
        delta_common_answer_ids = ActiveRecord::Base.connection.exec_query("select ref_obj_id from temp_profile_objects where ref_obj_type = '#{CommonAnswer.name}'").rows.flatten
        MigrateCommonAnswerTextToAnswerChoice.new.migrate_delta_answer_to_answer_choices(delta_common_answer_ids)
      end
    end
  end


  def down
    # nothing
  end

end
