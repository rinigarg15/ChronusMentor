class UpdateOrderedChoiceActivities < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      ordered_question_ids = ProfileQuestion.where(question_type: ProfileQuestion::Type::ORDERED_OPTIONS).pluck(:id)
      activities = UserSearchActivity.where(profile_question_id: ordered_question_ids, question_choice_id: nil)
      activities.each do |activity|
        ordered_options_ids = YAML.load(activity.search_text)
        next unless ordered_options_ids.is_a?(Array)
        ordered_options_ids.each do |option_id|
          question_choice = QuestionChoice.find_by(id: option_id)
          next if question_choice.nil?
          search_activity = UserSearchActivity.find_or_initialize_by({user_id: activity.user_id, program_id: activity.program_id, profile_question_id: activity.profile_question_id, question_choice_id: option_id, search_text: question_choice.text, session_id: activity.session_id, locale: activity.locale})
          search_activity.created_at = activity.created_at
          search_activity.updated_at = activity.updated_at
          search_activity.save! if search_activity.new_record?
        end
      end
      activities.delete_all
    end
  end

  def down
  end
end
