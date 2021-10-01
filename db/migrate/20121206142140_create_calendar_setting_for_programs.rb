class CreateCalendarSettingForPrograms< ActiveRecord::Migration[4.2]
  def change
    CalendarSetting.create_default_calendar_setting
  end
end
