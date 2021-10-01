class UpdateMemberAndProgramEventTimezonesToTzInfoTimezones< ActiveRecord::Migration[4.2]
  def up
    klasses = [Member, ProgramEvent]
    klasses.each do |klass|
      time_zones_present_in_db = klass.where(time_zone: ActiveSupport::TimeZone::MAPPING.keys).pluck("DISTINCT(time_zone)")
      time_zones_present_in_db.each do |time_zone|
        new_time_zone = ActiveSupport::TimeZone::MAPPING[time_zone]
        klass.where(time_zone: time_zone).update_all(time_zone: new_time_zone)
      end
    end
  end

  def down
    # nothing
  end
end
