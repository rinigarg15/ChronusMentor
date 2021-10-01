class AddMentorRequestExpirationDaysToPrograms< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :mentor_request_expiration_days, :integer
  end
end
