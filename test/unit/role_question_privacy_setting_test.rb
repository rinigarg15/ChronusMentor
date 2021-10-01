require File.expand_path("../../test_helper", __FILE__)

class RoleQuestionPrivacySettingTest < ActiveSupport::TestCase

  def test_validations
    setting = RoleQuestionPrivacySetting.new
    assert_false setting.valid?

    assert_equal(["can't be blank"], setting.errors[:role_question])
    assert_equal(["can't be blank", "is not included in the list"], setting.errors[:setting_type])

    setting.role_question_id = role_questions(:string_role_q).id
    setting.setting_type = RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS
    assert setting.valid?

    setting.setting_type = RoleQuestionPrivacySetting::SettingType::ROLE
    assert_false setting.valid?
    assert_equal(["can't be blank"], setting.errors[:role])

    setting.role_id = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    assert setting.valid?
  end

  def test_by_role
    role_question = role_questions(:string_role_q)
    roles = role_question.program.roles.non_administrative
    mentor_role = roles.where(name: RoleConstants::MENTOR_NAME).first
    mentee_role = roles.where(name: RoleConstants::STUDENT_NAME).first

    setting1 = RoleQuestionPrivacySetting.create!(role_question_id: role_question.id, setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS)
    setting2 = RoleQuestionPrivacySetting.create!(role_question_id: role_question.id, setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: mentor_role.id)
    setting3 = RoleQuestionPrivacySetting.create!(role_question_id: role_question.id, setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: mentee_role.id)

    assert_equal [], role_question.privacy_settings.by_role
    assert_equal [setting2], role_question.privacy_settings.by_role(mentor_role.id)
    assert_equal [setting3], role_question.privacy_settings.by_role(mentee_role.id)
    assert_equal [setting2, setting3], role_question.privacy_settings.by_role([mentor_role.id, mentee_role.id])
  end

  def test_restricted_privacy_setting_options_for
    mentor_role = programs(:albers).roles.with_name(RoleConstants::MENTOR_NAME).first
    mentee_role = programs(:albers).roles.with_name(RoleConstants::STUDENT_NAME).first
    user_role = programs(:albers).roles.with_name("user").first
    expected_output = [
      {label: "User's mentoring connections", privacy_type: RoleQuestion::PRIVACY_SETTING::RESTRICTED, privacy_setting: {setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS, role_id: nil}},
      {label: "All mentors", privacy_type: RoleQuestion::PRIVACY_SETTING::RESTRICTED, privacy_setting: {setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: mentor_role.id}},
      {label: "All students", privacy_type: RoleQuestion::PRIVACY_SETTING::RESTRICTED, privacy_setting: {setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: mentee_role.id}},
      {label: "All users", privacy_type: RoleQuestion::PRIVACY_SETTING::RESTRICTED, privacy_setting: {setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: user_role.id}}
    ]
    assert_equal expected_output, RoleQuestionPrivacySetting.restricted_privacy_setting_options_for(programs(:albers))

    employee_role = programs(:primary_portal).roles.with_name(RoleConstants::EMPLOYEE_NAME).first
    expected_output = [{label: "All employees", privacy_type: RoleQuestion::PRIVACY_SETTING::RESTRICTED, privacy_setting: {setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: employee_role.id}}]
    assert_equal expected_output, RoleQuestionPrivacySetting.restricted_privacy_setting_options_for(programs(:primary_portal))
  end

  def test_has_all_settings
    program = programs(:albers)
    settings = program.roles.non_administrative.collect do |role|
      RoleQuestionPrivacySetting.new(setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: role.id)
    end << RoleQuestionPrivacySetting.new(setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS)

    assert_equal 4, settings.size
    assert_false RoleQuestionPrivacySetting.has_all_settings?(program, [])
    assert_false RoleQuestionPrivacySetting.has_all_settings?(program, settings.first(2))
    assert_false RoleQuestionPrivacySetting.has_all_settings?(program, settings.first(2) << settings.last)
    assert RoleQuestionPrivacySetting.has_all_settings?(program, settings)
    assert RoleQuestionPrivacySetting.has_all_settings?(program, settings * 2)
  end

  def test_has_all_settings_for_portal
    program = programs(:primary_portal)
    employee_role = program.get_role(RoleConstants::EMPLOYEE_NAME)
    assert_false RoleQuestionPrivacySetting.has_all_settings?(program, [])

    setting = RoleQuestionPrivacySetting.new(setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: employee_role.id)
    assert RoleQuestionPrivacySetting.has_all_settings?(program, [setting])
    assert RoleQuestionPrivacySetting.has_all_settings?(program, [setting] * 2)
  end
end
