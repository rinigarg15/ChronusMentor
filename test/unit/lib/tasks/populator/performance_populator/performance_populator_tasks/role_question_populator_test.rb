require_relative './../../../../../../test_helper'

class RoleQuestionPopulatorTest < ActiveSupport::TestCase
  def test_add_role_questions
    program = programs(:albers)
    role_question_ids = program.role_questions.pluck(:id)
    to_add_profile_question_ids = program.organization.profile_questions.pluck(:id).first(5)
    to_remove_profile_question_ids = program.role_questions.pluck(:profile_question_id).last(5)

    populator_add_and_remove_objects("role_question", "profile_question", to_add_profile_question_ids, to_remove_profile_question_ids, {program: program})
    program.role_questions.includes(:privacy_settings).each do |role_question|
      if role_question.private == RoleQuestion::PRIVACY_SETTING::RESTRICTED
        assert role_question.privacy_settings.present?, "No Privacy Setting for #{role_question.inspect}"
      end
    end
    RoleQuestionPrivacySetting.where(role_question_id: role_question_ids).includes(:role_question).each do |privacy_setting|
      assert privacy_setting.role_question.present?, "No Role Question present for #{privacy_setting.inspect}"
    end
  end
end