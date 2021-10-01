class UpdatingProfileQuestionTypeForNewProfileUiInDemo< ActiveRecord::Migration[4.2]
  def up
    if Rails.env.demo?
      ChronusMigrate.data_migration(has_downtime: false) do
        ProfileQuestion.where(question_type: ProfileQuestion::Type::EDUCATION).update_all(question_type: ProfileQuestion::Type::MULTI_EDUCATION)
        ProfileQuestion.where(question_type: ProfileQuestion::Type::EXPERIENCE).update_all(question_type: ProfileQuestion::Type::MULTI_EXPERIENCE)
        ProfileQuestion.where(question_type: ProfileQuestion::Type::PUBLICATION).update_all(question_type: ProfileQuestion::Type::MULTI_PUBLICATION)
      end
    end
  end

  def down  
  end
end
