module MentoringPeriodUtils
  #---------------------------------------------------------------------------------
  # --- The below methods are generic enough to be used for any duration calculation
  # --- Currently, this being used in mentoring_model and program.
  #---------------------------------------------------------------------------------
  module MentoringPeriodUnit
    DAYS = 1
    WEEKS = 2
  end

  # Returns the number of weeks or days
  # ex: 12 days => 12 days
  #     14 days => 2 weeks
  def mentoring_period_value
    (mentoring_period_in_days % 7 == 0) ? (mentoring_period_in_days / 7) : mentoring_period_in_days
  end

  # Returns the mentoring period's unit.
  # This method is to get if the 'mentoring_period_value' is returning weeks or days.
  def mentoring_period_unit
    (mentoring_period_in_days % 7 == 0) ? MentoringPeriodUnit::WEEKS : MentoringPeriodUnit::DAYS
  end

  # Sets the mentoring period. The unit can be months, weeks or days.
  # "1" represents months, "2" represents days and "3" represents weeks
  def set_mentoring_period(unit, value)
    unit = unit.to_i
    value = value.to_i
    self.mentoring_period =
      if unit == MentoringPeriodUnit::WEEKS
        value * 1.week
      else
        value * 1.day
      end
  end

  def mentoring_period_in_days
    self.mentoring_period / 1.day
  end
end