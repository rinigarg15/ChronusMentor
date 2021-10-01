class AddScheduleToNonScheduleMeetings< ActiveRecord::Migration[4.2]
  include IceCube
  def change
    schedule = Schedule.new
    daily_rule = IceCube::Rule.daily
    ActiveRecord::Base.transaction do
      Meeting.unscoped.where(schedule: nil).select([:id, :start_time, :end_time, :schedule]).find_each do |m|
        schedule.start_time = m.start_time
        schedule.end_time = m.end_time
        schedule.add_recurrence_rule daily_rule.until(schedule.start_time)
        m.update_column(:schedule, schedule.to_yaml)
      end
    end
  end
end
