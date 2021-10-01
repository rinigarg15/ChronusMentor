class CreateNotificationSettings< ActiveRecord::Migration[4.2]
  def change
    create_table :notification_settings do |t|
      t.integer :program_id
      t.integer :messages_notification, default: 0 # previously UserConstants::NotifySetting::ALL
      t.integer :connection_notification, default: 1 # previously MentoringAreaConstants::NotifySetting::DAILY_DIGEST
      t.timestamps null: false
    end

    Organization.all.each do |organization|
      # organization.create_notification_setting!
      organization.programs.each do |program|
        program.create_notification_setting!
      end
    end
  end
end
