class WithdrawPendingRequestsExceedingLimit < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      includes_list = [
        :meeting_proposed_slots,
        student: [{ program: :calendar_setting }, :member]
      ]

      MeetingRequest.active.includes(includes_list).find_each do |meeting_request|
        if meeting_request.meeting_proposed_slots.any? { |slot| meeting_request.student.is_student_meeting_limit_reached?(slot.start_time) }
          meeting_request.skip_email_notification = true if meeting_request.meeting_proposed_slots.any? { |slot| slot.start_time < Time.current }
          meeting_request.update_status!(meeting_request.student, AbstractRequest::Status::WITHDRAWN)
        end
      end
    end
  end

  def down
  end
end
