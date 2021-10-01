require_relative './../../test_helper.rb'

class GlobalizationUtilsTest < ActiveSupport::TestCase
  def test_run_in_locale_should_change_the_locale_to_the_passed_parameter
    assert_equal ["Stand", "Walk", "Run"], GlobalizationUtils.run_in_locale(:en) {  profile_questions(:student_multi_choice_q).default_choices }
    assert_equal ["Supporter", "Marcher", "Course"], GlobalizationUtils.run_in_locale(:'fr-CA') { profile_questions(:student_multi_choice_q).default_choices }
  end

  def test_run_in_locale_should_propagate_exception_to_the_caller
    assert_raise(RuntimeError, "yoError") do
      GlobalizationUtils.run_in_locale(:en) {  profile_questions(:student_multi_choice_q).default_choices; raise "yoError"}
    end
  end

  def test_is_in_default_locale
    assert GlobalizationUtils::is_default_locale?
    assert GlobalizationUtils::is_default_locale?(:en)
    assert_false GlobalizationUtils::is_default_locale?(:'fr-CA')

    run_in_another_locale(:'fr-CA') do
      assert_false GlobalizationUtils::is_default_locale?
    end

    Globalize.with_locale(:'fr-CA') do
      assert_false GlobalizationUtils::is_default_locale?
    end
  end

  def test_globalize_fallback_to_default_locale
    announcement = announcements(:assemble)
    assert_equal "All come to audi small", announcement.title

    Globalize.with_locale(:'fr-CA') do
      announcement.update_attributes!(title: "Test French Title")
      assert_equal "Test French Title", announcement.title
    end
    assert_equal "All come to audi small", announcement.title

    # fallback to i18n default locale value if value is nil
    Globalize.with_locale(:'fr-CA') do
      announcement.update_attributes!(title: nil)
      assert_equal "All come to audi small", announcement.title
    end
    assert_equal "All come to audi small", announcement.title
  end
end