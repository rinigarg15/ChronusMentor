class AddAdvanceBookingTimeToCalendar< ActiveRecord::Migration[4.2]
  def change
    add_column :calendar_settings, :advance_booking_time, :integer, :default => 24
  end
end
