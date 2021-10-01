class ConvertSingleOrderedChoiceToSingleChoice< ActiveRecord::Migration[4.2]
  def change
    # change existing match configs
    single_ordered_role_ques = ProfileQuestion.where(:question_type => ProfileQuestion::Type::ORDERED_SINGLE_CHOICE).collect(&:role_questions).flatten.index_by(&:id)
    ques_ids = single_ordered_role_ques.keys
    mcs = (MatchConfig.where(:mentor_question_id => ques_ids) ||  MatchConfig.where(:student_question_id => ques_ids)).distinct - MatchConfig.where(:matching_type => MatchConfig::MatchingType::SET_MATCHING)
    mcs.each do |mc|
      mentor_choices = single_ordered_role_ques[mc.mentor_question_id].profile_question.default_choices.map(&:downcase)
      student_choices = single_ordered_role_ques[mc.student_question_id].profile_question.default_choices.map(&:downcase)
      mentor_choice_size = mentor_choices.size
      display_hash = {}
      matching_hash = {}
      # existing scenario we do not have any match config with greater than as operator so not checking that
      up = (mc.threshold > 0.5) ? 1 : 0
      student_choices.each_with_index do |student_choice, i|
        matchable_mentor_choices = mentor_choices[(i+up)..mentor_choice_size].to_a
        matching_hash[student_choice] = matchable_mentor_choices
        display_hash[student_choice] = matchable_mentor_choices.join(",")
      end
      mc.matching_details_for_matching = matching_hash
      mc.matching_details_for_display = display_hash
      mc.matching_type =  MatchConfig::MatchingType::SET_MATCHING
      mc.save!
    end

    ProfileQuestion.where(:question_type => ProfileQuestion::Type::ORDERED_SINGLE_CHOICE).each do |ques|
      ActiveRecord::Base.transaction do
        previous_answers_count = ques.profile_answers.size
        ques.question_type = ProfileQuestion::Type::SINGLE_CHOICE
        ques.save!
        raise "Answers deleted for #{ques.question_text}" unless (previous_answers_count == ques.profile_answers.size)
      end
    end
  end
end
