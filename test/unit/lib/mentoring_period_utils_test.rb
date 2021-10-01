require_relative './../../test_helper.rb'

class MentoringPeriodUtilsTest < ActiveSupport::TestCase
  include MentoringPeriodUtils

  def setup
    super
    @program = programs(:albers)
    @mentoring_model = create_mentoring_model(title: "Test title", program_id: @program.id)
  end

  def test_mentoring_period_value
    assert_equal 180, @program.mentoring_period_value
    @program.update_attribute(:mentoring_period, 10.days)
    assert_equal 10, @program.mentoring_period_value
    @program.update_attribute(:mentoring_period, 2.weeks)
    assert_equal 2, @program.mentoring_period_value

    assert_equal 180, @mentoring_model.mentoring_period_value
    @mentoring_model.update_attribute(:mentoring_period, 2.weeks)
    assert_equal 2, @mentoring_model.mentoring_period_value
    @mentoring_model.update_attribute(:mentoring_period, 10.days)
    assert_equal 10, @mentoring_model.mentoring_period_value
  end

  def test_mentoring_period_unit
    @program.update_attribute(:mentoring_period, 10.days)
    assert_equal MentoringPeriodUtils::MentoringPeriodUnit::DAYS, @program.mentoring_period_unit
    @program.update_attribute(:mentoring_period, 2.weeks)
    assert_equal MentoringPeriodUtils::MentoringPeriodUnit::WEEKS, @program.mentoring_period_unit

    assert_equal MentoringPeriodUtils::MentoringPeriodUnit::DAYS, @mentoring_model.mentoring_period_unit
    @mentoring_model.update_attribute(:mentoring_period, 2.weeks)
    assert_equal MentoringPeriodUtils::MentoringPeriodUnit::WEEKS, @mentoring_model.mentoring_period_unit
  end

  def test_set_mentoring_period
    program = programs(:albers)
    program.set_mentoring_period(MentoringPeriodUtils::MentoringPeriodUnit::WEEKS, 10)
    assert_equal(10.weeks, program.mentoring_period)
    program.set_mentoring_period(MentoringPeriodUtils::MentoringPeriodUnit::DAYS, 20)
    assert_equal(20.days, program.mentoring_period)
  end
end