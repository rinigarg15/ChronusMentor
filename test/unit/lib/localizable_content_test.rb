require_relative './../../test_helper.rb'

class LocalizableContentTest < ActiveSupport::TestCase

  def test_attributes_for_model
    hash1 = LocalizableContent.attributes_for_model(category: LocalizableContent::PROGRAM_SETTINGS, tab: ProgramsController::SettingsTabs::GENERAL)
    hash2 = LocalizableContent.attributes_for_model(category: LocalizableContent::PROGRAM_SETTINGS, tab: ProgramsController::SettingsTabs::MATCHING)
    hash3 = LocalizableContent.attributes_for_model(category: LocalizableContent::MENTORING_MODEL, tab: ProgramsController::SettingsTabs::MATCHING)
    assert_equal [:name, :description], hash1[Program]
    assert_equal [:name, :description], hash1[AbstractProgram]
    assert_equal [:agreement, :privacy_policy, :browser_warning], hash1[Organization]
    assert_equal [:zero_match_score_message], hash2[Program]
    assert_equal [:name, :description], hash3[Program]
  end

  def test_tab_relations
    assert_equal :get_terms_for_view, LocalizableContent.tab_relations[ProgramsController::SettingsTabs::TERMINOLOGY]
    assert_equal :roles_without_admin_role, LocalizableContent.tab_relations[ProgramsController::SettingsTabs::MEMBERSHIP]
    assert_equal :permitted_closure_reasons, LocalizableContent.tab_relations[ProgramsController::SettingsTabs::CONNECTION]
  end

  def test_ckeditor_type
    assert_equal :default, LocalizableContent.ckeditor_type[Organization][:agreement]
    assert_equal :default, LocalizableContent.ckeditor_type[Organization][:privacy_policy]
    assert_equal :default, LocalizableContent.ckeditor_type[Organization][:browser_warning]
  end

  def test_ckeditor_required_type
    assert_equal ["content"], LocalizableContent.ckeditor_type_required_content[Resource]
    assert_equal ["source"], LocalizableContent.ckeditor_type_required_content[Mailer::Template]
    assert_equal ["message"], LocalizableContent.ckeditor_type_required_content[MentoringModel::FacilitationTemplate]
    assert_nil LocalizableContent.ckeditor_type_required_content[Organization]
  end
end