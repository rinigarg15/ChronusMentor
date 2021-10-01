class AddProcessedmatchingDetails< ActiveRecord::Migration[4.2]
  def change
    add_column :match_configs, :matching_details_for_matching, :text
    rename_column :match_configs, :matching_details, :matching_details_for_display
    MatchConfig.reset_column_information
    MatchConfig.where(:matching_type => MatchConfig::MatchingType::SET_MATCHING).each do |mc|
      program = mc.program
      mapping =  mc.matching_details_for_display

      student_choices = program.role_questions.find(mc.student_question_id).profile_question.default_choices
      index_to_student_choices = Hash[(1..student_choices.size).zip student_choices]
      mentor_choices = program.role_questions.find(mc.mentor_question_id).profile_question.default_choices
      index_to_mentor_choices = Hash[(1..mentor_choices.size).zip mentor_choices]
      
      display_mapping = {}
      match_mapping = Hash[student_choices.zip [[]]*student_choices.size]
      mapping.each do |mentee_choice_id, mentor_choice_ids|
        student_choice = index_to_student_choices[mentee_choice_id]
        mentor_choice_list = mentor_choice_ids.map{|choice| index_to_mentor_choices[choice]}
        match_mapping[student_choice] += mentor_choice_list
      	display_mapping[student_choice] = mentor_choice_list.join(",")
      end
      mc.matching_details_for_display = display_mapping
      mc.matching_details_for_matching = match_mapping
      mc.save!
    end
  end
end
