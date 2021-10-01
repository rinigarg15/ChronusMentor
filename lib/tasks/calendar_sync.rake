namespace :calendar_sync do
  desc "Add scheduling assistant emails Demo_USAGE: rake calendar_sync:add_scheduling_assistant_emails ACTIVE_EMAILS='xyz@example.com','abc@example.com' INACTIVE_EMAILS='pqr@example.com'"
  task add_scheduling_assistant_emails: :environment do
    active_emails = ENV['ACTIVE_EMAILS'].split(',')
    active_emails.each do |email|
      account = SchedulingAccount.find_or_initialize_by(email: email)
      account.status = SchedulingAccount::Status::ACTIVE
      account.save!
    end

    inactive_emails = ENV['INACTIVE_EMAILS'].split(',')
    inactive_emails.each do |email|
      account = SchedulingAccount.find_or_initialize_by(email: email)
      account.status = SchedulingAccount::Status::INACTIVE
      account.save!
    end

    existing_email_account = SchedulingAccount.find_by(email: APP_CONFIG[:scheduling_assistant_email].first)
    CalendarSyncNotificationChannel.update_all(scheduling_account_id: existing_email_account.id)
  end

  desc "Send rsvp emails manually to users for whom rsvp sync failed"
  task sync_rsvp_change: :environment do
    csv_path = Rails.root.to_s + '/tmp/calendar_sync_rsvp_failures.csv'
    csv_text = File.read(csv_path)
    csv = CSV.parse(csv_text, :headers => true)
    csv.each do |row|
      begin
        meeting_id, member_id, rsvp_state, rsvp_updated_time = row[0..3]
        member_meeting = MemberMeeting.find_by(meeting_id: meeting_id, member_id: member_id)
        next if member_meeting.nil? || member_meeting.updated_at.to_datetime.utc > rsvp_updated_time.to_datetime.utc || member_meeting.attending == rsvp_state.to_i
        member_meeting.update_column(:attending, rsvp_state.to_i)
        meeting = Meeting.find_by(id: meeting_id)
        if meeting.start_time > Time.now
          #Meeting.handle_update_calendar_event(meeting.id)
          meeting.member_meetings.where.not(id: member_meeting.id).each do |guest_member_meeting|
            ChronusMailer.meeting_rsvp_notification(guest_member_meeting.user, member_meeting).deliver_now
          end
          puts "RSVP update successful for member meeting with ID - #{member_meeting.id}"
        end
      rescue => e
        Airbrake.notify("RSVP update failed for member meeting with ID - #{member_meeting.id}---Exception - #{e.message}")
      end
    end
  end
end
