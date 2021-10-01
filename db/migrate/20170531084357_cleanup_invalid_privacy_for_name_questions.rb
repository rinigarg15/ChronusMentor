class CleanupInvalidPrivacyForNameQuestions< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      RoleQuestion.where(profile_question_id: ProfileQuestion.name_question.select(:id)).where(private: RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE).update_all(private: RoleQuestion::PRIVACY_SETTING::ALL)
    end
  end

  def down
    # do nothing
  end
end
