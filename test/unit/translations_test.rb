require_relative './../test_helper.rb'

class TranslationsTest < ActionController::TestCase

  def test_missing_translation_notifier
    assert_raise(RuntimeError) do
      "some.missing.translation".translate
    end
    begin
      default_exception_handler = I18n.exception_handler
      I18n.exception_handler = :missing_translation_silent_notifier
      Airbrake.expects(:notify).once
      assert_equal "translation missing: en.some.missing.translation", "some.missing.translation".translate
    ensure
      I18n.exception_handler = default_exception_handler
    end
  end

  def test_dynamic_content_missing_translations_workflow
    program = Program.create(name: "English program name", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, organization: programs(:org_primary), root: "prog1")
    assert program.id
    assert_equal "English program name", program.name

    run_in_another_locale(:fr) { assert_equal "English program name", program.name }
  end

  def test_updating_secondary_locales_should_not_update_default_locale
    program = Program.create(name: "English program name", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, organization: programs(:org_primary), root: "prog1")
    assert program.id
    assert_equal "English program name", program.name
    Program.any_instance.stubs(:can_have_match_report?).returns(false)
    run_in_another_locale(:fr) do
      program.update_attributes(name: "French program name")
      assert_equal "French program name", program.name
    end
    assert_equal "English program name", program.name
  end

  def test_dup_with_translations_functionality
    program = programs(:albers)
    assert program.respond_to?(:dup_with_translations)
    assert_not_equal program.translations.collect(&:name), program.dup.translations.collect(&:name)
    assert_equal program.translations.collect(&:name), program.dup_with_translations.translations.collect(&:name)
  end

  def test_fill_default_locale_value_when_created_in_other_locale
    resource = nil
    run_in_another_locale(:fr) do
      assert I18n.locale != I18n.default_locale
      resource = Resource.create!(title: "fr title", content: "fr content", organization: programs(:org_primary))
      assert_equal "fr title", resource.title
    end

    assert_equal "fr title", resource.title
    resource.update_attribute(:title, "en title")
    assert_equal "en title", resource.title

    run_in_another_locale(:fr) do
      assert_equal "fr title", resource.title
    end
  end

  def test_with_locale
    mm = MentoringModel.first
    mm.translations.destroy_all
    mm.translations.create!(title: "en title", locale: "en")
    mm.translations.create!(title: "fr-CA title", locale: "fr-CA")
    mm.save!

    assert_equal "en title", mm.title
    exception = assert_raises(RuntimeError) do
      Globalize.with_locale("fr-CA") { raise "runtime error" }
    end
    assert_equal "runtime error", exception.message
    assert_equal "en title", mm.title
  end

  def test_locale_reset_in_delayed_job
    current_locale = I18n.locale
    Delayed::Worker.delay_jobs = true
    Delayed::Job.delete_all
    assert_equal 0, Delayed::Job.count
    TranslationsTest.delay.dj_method_without_error
    TranslationsTest.delay.dj_method_without_error(true, :es)
    TranslationsTest.delay.dj_method_without_error(false)
    TranslationsTest.delay.dj_method_with_error
    TranslationsTest.delay.dj_method_without_error(false)

    assert_equal 5, Delayed::Job.count

    worker = Delayed::Worker.new
    assert_difference 'Delayed::Job.count', -3 do
      worker.work_off(1)
      assert_equal "uk", Announcement.last.body
      assert_equal_unordered [:uk, :en], Announcement.last.translations.collect(&:locale)

      worker.work_off(1)
      assert_equal "es", Announcement.last.body
      assert_equal_unordered [:es, :en], Announcement.last.translations.collect(&:locale)

      worker.work_off(1)
      assert_equal "en", Announcement.last.body
      assert_equal_unordered [:en], Announcement.last.translations.collect(&:locale)
    end

    assert_no_difference 'Delayed::Job.count' do
      worker.work_off(1)
    end

    assert_difference 'Delayed::Job.count', -1 do
      worker.work_off(1)
      assert_equal_unordered [:en], Announcement.last.translations.collect(&:locale)
      assert_equal "en", Announcement.last.body
    end
  ensure
    Delayed::Worker.delay_jobs = false
  end

  def test_save_two_times_should_not_create_french_entry
    run_in_another_locale(:"fr-CA") do
      mm = MentoringModel.first
      mm.translations.destroy_all
      mm.translations.create!(title: "en title", locale: "en")
      mm = mm.reload
      mm.save!
      mm.save! #this save is intentional
      assert_equal 1, mm.reload.translations.count
    end
  end

  def test_fallbacks
    survey = surveys(:one)
    survey_name = survey.name

    assert_equal survey, Survey.find_by(name: survey_name)
    run_in_another_locale(:de) do
      assert_equal survey_name, survey.name
      assert_equal survey, Survey.find_by(name: survey_name)
    end
  end

  def test_dirty
    survey = surveys(:one)
    survey_name = survey.name
    updated_survey_name = survey_name + "v2"

    survey.name = updated_survey_name
    assert survey.name_changed?
    assert_equal [survey_name, updated_survey_name], survey.changes["name"]
    assert_equal survey_name, survey.name_was

    survey.save!
    assert survey.saved_change_to_name?
    assert_equal [survey_name, updated_survey_name], survey.saved_changes["name"]
    assert_equal survey_name, survey.name_before_last_save
    assert_equal survey_name, survey.attribute_before_last_save("name")
  end

  def self.dj_method_without_error(change_locale = true, locale = :uk)
    I18n.locale = locale if change_locale

    program = Program.first
    announcement = program.announcements.new(title: Time.now.to_f.to_s, body: I18n.locale.to_s, email_notification: UserConstants::DigestV2Setting::ProgramUpdates::DONT_SEND.to_s)
    announcement.admin = program.admin_users.first
    announcement.recipient_role_names = [RoleConstants::MENTOR_NAME]
    announcement.save!
  end

  def self.dj_method_with_error
    I18n.locale = :uk
    raise "-------------- error occured"
  end
end