require_relative './../../test_helper.rb'

class TranslatedCountsTest < ActionView::TestCase
  include TranslatedCounts

  def test_get_score_for_prog_or_org
    program = programs(:albers)
    scores_by_category = {
      LocalizableContent::ANNOUNCEMENT => [0, 8],
      LocalizableContent::CAMPAIGN => [0, 70],
      LocalizableContent::INSTRUCTION => [1, 1],
      LocalizableContent::PROGRAM_EVENTS => [0, 2],
      LocalizableContent::SURVEY => [0, 3],
      LocalizableContent::SURVEY_QUESTION => [0, 147],
      LocalizableContent::PROGRAM_SETTINGS => [3, 29]
    }
    porg_scores = get_score_for_prog_or_org(program, "es")[program.id]
    scores_by_category.each do |category, score|
      assert_equal score, porg_scores[category]
    end
  end

  def test_get_score_by_program
    program = programs(:albers)
    TranslatedCountsTest.any_instance.expects(:get_score_of_category).times(LocalizableContent.program_level.select{|category| can_show_category?(category, program)}.size)
    get_category_wise_score(program, "es")
  end

  def test_get_score_by_organization
    organization = programs(:org_primary)
    TranslatedCountsTest.any_instance.expects(:get_score_of_category).times(LocalizableContent.org_level.select{|category| can_show_category?(category, organization)}.size)
    get_category_wise_score(organization, "es")
  end

  def test_get_score_of_category
    program = programs(:albers)
    TranslatedCountsTest.any_instance.expects(:get_score_for_program_settings).once
    TranslatedCountsTest.any_instance.expects(:get_score_by_tree_in_category).once
    get_score_of_category(LocalizableContent::ANNOUNCEMENT, program, "es")
    get_score_of_category(LocalizableContent::PROGRAM_SETTINGS, program, "es")
  end

  def test_get_score_for_program_settings
    program = programs(:albers)
    score_by_tabs_in_program = {
      ProgramsController::SettingsTabs::GENERAL => [0, 2],
      ProgramsController::SettingsTabs::TERMINOLOGY => [0, 24],
      ProgramsController::SettingsTabs::MEMBERSHIP => [2, 2],
      ProgramsController::SettingsTabs::MATCHING => [1, 1]
    }
    computed_program_settings_scores = get_score_for_program_settings(program, "es")
    score_by_tabs_in_program.each do |tab, score|
      assert_equal score, computed_program_settings_scores[tab]
    end
    organization = program.organization
    score_by_tabs_in_organization = {
      ProgramsController::SettingsTabs::GENERAL => [0, 3],
      ProgramsController::SettingsTabs::TERMINOLOGY => [0, 6]
    }
    computed_organization_settings_scores = get_score_for_program_settings(organization, "es")
    score_by_tabs_in_organization.each do |tab, score|
      assert_equal score, computed_organization_settings_scores[tab]
    end
  end

  def test_get_score_by_tree_in_category
    program = programs(:albers)
    tree = LocalizableContent.relations[LocalizableContent::ANNOUNCEMENT]
    assert_equal [0, 8], get_score_by_tree_in_category(tree, [program.id], "es", Program)
    program.announcements.first.translations.create!(locale: "es", title: "Hello")
    assert_equal [1, 8], get_score_by_tree_in_category(tree, [program.id], "es", Program)
  end

  def test_get_score_for_klass
    program = programs(:albers)
    assert_equal [0, 8], get_score_for_klass(Announcement, program.announcements.pluck(:id), "es")
    program.announcements.first.translations.create!(title: "Hello", body: "Hai", locale: "es")
    assert_equal [2, 8], get_score_for_klass(Announcement, program.announcements.pluck(:id), "es")
  end

  def test_get_score_for_klass_by_column
    program = programs(:albers)
    assert_equal [0, 4], get_score_for_klass_by_column(Announcement::Translation, :title, program.announcements.pluck(:id), :announcement_id, "es")
    program.announcements.first.translations.create!(title: "Hello", body: "Hai", locale: "es")
    assert_equal [1, 4], get_score_for_klass_by_column(Announcement::Translation, :title, program.announcements.pluck(:id), :announcement_id, "es")
  end

  def test_get_object_ids_for_node
    program = programs(:albers)
    assert_equal_unordered program.announcements.collect(&:id), get_object_ids_for_node(Announcement, [program.id], :program_id, Program)
  end

  def test_get_translatable_objects_program_settings
    program = programs(:albers)
    assert_equal [program], get_translatable_objects_program_settings(ProgramsController::SettingsTabs::GENERAL, program)
    assert_equal [program], get_translatable_objects_program_settings(ProgramsController::SettingsTabs::MATCHING, program)
    assert_equal program.get_terms_for_view, get_translatable_objects_program_settings(ProgramsController::SettingsTabs::TERMINOLOGY, program)
    assert_equal program.roles_without_admin_role, get_translatable_objects_program_settings(ProgramsController::SettingsTabs::MEMBERSHIP, program)
    assert_equal program.permitted_closure_reasons, get_translatable_objects_program_settings(ProgramsController::SettingsTabs::CONNECTION, program)
    organization = programs(:org_foster)
    assert organization.standalone?
    assert_equal organization.programs, get_translatable_objects_program_settings(ProgramsController::SettingsTabs::GENERAL, organization)
    assert_equal organization.programs, get_translatable_objects_program_settings(ProgramsController::SettingsTabs::MATCHING, organization)
    assert_equal organization.get_terms_for_view, get_translatable_objects_program_settings(ProgramsController::SettingsTabs::TERMINOLOGY, organization)
    assert_equal organization.programs.first.roles_without_admin_role, get_translatable_objects_program_settings(ProgramsController::SettingsTabs::MEMBERSHIP, organization)
    assert_equal organization.programs.first.permitted_closure_reasons, get_translatable_objects_program_settings(ProgramsController::SettingsTabs::CONNECTION, organization)
  end

  def test_get_email_templates_from_abstract_campaigns
    program = programs(:albers)
    assert_equal_unordered program.abstract_campaigns.collect(&:email_templates).flatten.collect(&:id), get_email_templates_from_abstract_campaigns(program.abstract_campaigns.pluck(:id))
  end

  def test_get_visible_surveys_from_program
    program = programs(:albers)
    assert_equal_unordered program.visible_surveys.pluck(:id), get_visible_surveys_from_program([program.id])
    survey_with_due_yesterday = program.visible_surveys.first
    survey_with_due_yesterday.update_column(:due_date, 1.day.ago)
    assert_equal_unordered (program.visible_surveys.pluck(:id) - [survey_with_due_yesterday.id]), get_visible_surveys_from_program([program.id])
  end

  def test_get_sections_from_organization
    organization = programs(:org_primary)
    assert_equal_unordered organization.sections.select{|s| !s.default_field? }.collect(&:id), get_sections_from_organization([organization.id])
  end

  def test_templates_without_handle_hybrid_templates_from_mentoring_models
    program = programs(:albers)
    assert_equal [], get_goal_templates_without_handle_hybrid_templates_from_mentoring_models(program.mentoring_models.pluck(:id))
    assert_equal [], get_task_templates_without_handle_hybrid_templates_from_mentoring_models(program.mentoring_models.pluck(:id))
    assert_equal [], get_facilitation_templates_without_handle_hybrid_templates_from_mentoring_models(program.mentoring_models.pluck(:id))
    assert_equal [], get_milestone_templates_without_handle_hybrid_templates_from_mentoring_models(program.mentoring_models.pluck(:id))
  end
end