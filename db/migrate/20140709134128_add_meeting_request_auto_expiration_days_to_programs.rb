class AddMeetingRequestAutoExpirationDaysToPrograms< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :meeting_request_auto_expiration_days, :integer
  end
end
