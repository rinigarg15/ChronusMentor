class MentorRequestObserver < ActiveRecord::Observer
  def after_create(mentor_request)
    # Notify the mentor or admins about the new request.
    return if mentor_request.skip_observer
    if mentor_request.program.matching_by_mentee_and_admin?
      send_mentee_to_admin_request(mentor_request)
    else
      send_mentee_to_mentor_request(mentor_request)
    end

    if mentor_request.program.matching_by_mentee_alone?
      create_recent_activity(mentor_request, RecentActivityConstants::Type::MENTOR_REQUEST_CREATION, mentor_request.student, mentor_request.mentor)
    end
    MentorRequest.es_reindex(mentor_request)
  end

  def after_update(mentor_request)
    return if mentor_request.skip_observer
    if mentor_request.saved_change_to_status?
      MentorRequest.es_reindex(mentor_request)
      mentoring_term = mentor_request.program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase
      case mentor_request.status
      when AbstractRequest::Status::ACCEPTED
        #In the case of tightly managed scenario, the group creation already triggered email, so we shouldnt call this method
        return if mentor_request.program.matching_by_mentee_and_admin?
        # Notify the student about the acceptance.
        receiver = mentor_request.student
        MentorRequest.delay(:queue => DjQueues::HIGH_PRIORITY).send_mails(mentor_request, receiver, RecentActivityConstants::Type::MENTOR_REQUEST_ACCEPTANCE, sender: mentor_request.mentor)
        # Notify the student using push notification
        Push::Base.queued_notify(PushNotification::Type::MENTOR_REQUEST_ACCEPT, mentor_request, {recipients: receiver})
        create_recent_activity(mentor_request, RecentActivityConstants::Type::MENTOR_REQUEST_ACCEPTANCE, mentor_request.mentor, mentor_request.student)
        # mark all not-answered connection as WITHDRAWN if student's connections limit reached
        mentor_request.student.withdraw_active_requests!

      when AbstractRequest::Status::REJECTED
        # Notify the student about the rejection.
        receiver = mentor_request.student
        MentorRequest.delay(:queue => DjQueues::HIGH_PRIORITY).send_mails(mentor_request, receiver, RecentActivityConstants::Type::MENTOR_REQUEST_REJECTION, {:rejector => mentor_request.rejector, sender: mentor_request.program.matching_by_mentee_and_admin? ? mentor_request.rejector : mentor_request.mentor})
        if mentor_request.program.matching_by_mentee_alone?
          # Notify the student using push notification
          Push::Base.queued_notify(PushNotification::Type::MENTOR_REQUEST_REJECT, mentor_request, {recipients: receiver})
          create_recent_activity(mentor_request, RecentActivityConstants::Type::MENTOR_REQUEST_REJECTION, mentor_request.mentor, mentor_request.student)
        end

      when AbstractRequest::Status::WITHDRAWN
        if mentor_request.program.matching_by_mentee_and_admin?
          mentor_request.receivers.each do |receiver|
            MentorRequest.delay(:queue => DjQueues::HIGH_PRIORITY).send_mails(mentor_request, receiver, RecentActivityConstants::Type::MENTOR_REQUEST_WITHDRAWAL_TO_ADMIN, sender: mentor_request.student)
          end
        else
          mentor_request.receivers.each do |receiver|
            MentorRequest.delay(:queue => DjQueues::HIGH_PRIORITY).send_mails(mentor_request, receiver, RecentActivityConstants::Type::MENTOR_REQUEST_WITHDRAWAL, sender: mentor_request.student)
          end
          create_recent_activity(mentor_request, RecentActivityConstants::Type::MENTOR_REQUEST_WITHDRAWAL, mentor_request.student, mentor_request.mentor)
        end
      end
    end
  end

  def after_destroy(mentor_request)
    MentorRequest.es_reindex(mentor_request)
  end

  private

  def send_mentee_to_admin_request(mentor_request)
    mentor_request.receivers.each do |receiver|
      MentorRequest.delay(:queue => DjQueues::HIGH_PRIORITY).send_mails(mentor_request, receiver, RecentActivityConstants::Type::MENTOR_REQUEST_TO_ADMIN, sender: mentor_request.student)
    end
  end

  def send_mentee_to_mentor_request(mentor_request)
    mentor_request.receivers.each do |receiver|
      MentorRequest.delay(:queue => DjQueues::HIGH_PRIORITY).send_mails(mentor_request, receiver, RecentActivityConstants::Type::MENTOR_REQUEST_CREATION, sender: mentor_request.student)
      Push::Base.queued_notify(PushNotification::Type::MENTOR_REQUEST_CREATE, mentor_request, {recipients: receiver})
    end
  end


  def create_recent_activity(mentor_request, activity_type, user, receiver)
    RecentActivity.create!(
      :programs => [mentor_request.program],
      :member => user.member,
      :ref_obj => mentor_request,
      :action_type => activity_type,
      :for => receiver.member,
      :target => RecentActivityConstants::Target::USER)
  end
end
