class RemoveOtherOptionFromNonSelectTypeQuestions< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      common_questions_select_type = [CommonQuestion::Type::SINGLE_CHOICE, CommonQuestion::Type::MULTI_CHOICE]
      profile_questions_select_type = [ProfileQuestion::Type::SINGLE_CHOICE, ProfileQuestion::Type::MULTI_CHOICE, ProfileQuestion::Type::ORDERED_OPTIONS]
      CommonQuestion.where(allow_other_option: true).where.not(question_type: common_questions_select_type).update_all(allow_other_option: false)
      ProfileQuestion.where(allow_other_option: true).where.not(question_type: profile_questions_select_type).update_all(allow_other_option: false)
    end
  end

  def down
    #Do nothing
  end
end