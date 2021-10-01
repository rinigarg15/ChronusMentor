class MentorOfferObserver < ActiveRecord::Observer
  def after_create(mentor_offer)
    # Notify the mentee about the new offer.
    create_ra_and_notify_mentee_about_new_mentor_offer(mentor_offer)
    MentorOffer.es_reindex(mentor_offer)
  end

  def after_update(mentor_offer)
    return if mentor_offer.skip_observer
    if mentor_offer.saved_change_to_status?
      MentorOffer.es_reindex(mentor_offer)
      if mentor_offer.status == MentorOffer::Status::ACCEPTED
        # Notify the mentor and group members about the acceptance.
        create_ra_and_notify_mentor_about_mentoring_offer_acceptance(mentor_offer)
      elsif mentor_offer.status == MentorOffer::Status::REJECTED
        # Notify the mentor about the rejection.
        create_ra_and_notify_mentor_about_mentoring_offer_rejection(mentor_offer)
      elsif mentor_offer.status == MentorOffer::Status::WITHDRAWN
        create_ra_and_notify_mentee_about_mentor_offer_withdrawal(mentor_offer)
      end
    end
  end

  def after_destroy(mentor_offer)
    MentorOffer.es_reindex(mentor_offer)
  end

  private

  def create_ra_and_notify_mentee_about_new_mentor_offer(mentor_offer)
    create_mentor_offer_ra(mentor_offer, mentor_offer.mentor, mentor_offer.student, RecentActivityConstants::Type::MENTORING_OFFER_CREATION)
    MentorOffer.delay(queue: DjQueues::HIGH_PRIORITY).send_group_mentoring_offer_notification_to_new_mentee(mentor_offer.id)
    Push::Base.queued_notify(PushNotification::Type::MENTOR_OFFER, mentor_offer)
  end

  def create_ra_and_notify_mentor_about_mentoring_offer_acceptance(mentor_offer)
    create_mentor_offer_ra(mentor_offer, mentor_offer.student, mentor_offer.mentor, RecentActivityConstants::Type::MENTORING_OFFER_ACCEPTANCE)
    MentorOffer.delay(queue: DjQueues::HIGH_PRIORITY).send_mentor_offer_accepted_notification_to_mentor(mentor_offer.id)
    Push::Base.queued_notify(PushNotification::Type::MENTOR_OFFER_ACCEPTED, mentor_offer)
    group = mentor_offer.group
    (group.members - [mentor_offer.mentor, mentor_offer.student]).each do |member|
      membership = group.membership_of(member)
      membership.send_email(mentor_offer, RecentActivityConstants::Type::MENTORING_OFFER_ACCEPTANCE)
    end
  end

  def create_ra_and_notify_mentor_about_mentoring_offer_rejection(mentor_offer)
    create_mentor_offer_ra(mentor_offer, mentor_offer.student, mentor_offer.mentor, RecentActivityConstants::Type::MENTORING_OFFER_REJECTION)
    MentorOffer.send_mentor_offer_rejected_notification_to_mentor(mentor_offer.id)
    Push::Base.queued_notify(PushNotification::Type::MENTOR_OFFER_REJECTED, mentor_offer)
  end

  def create_ra_and_notify_mentee_about_mentor_offer_withdrawal(mentor_offer)
    create_mentor_offer_ra(mentor_offer, mentor_offer.mentor, mentor_offer.student, RecentActivityConstants::Type::MENTOR_OFFER_WITHDRAWAL)
    MentorOffer.send_mentor_offer_withdrawn_notification(mentor_offer.id)
  end

  def create_mentor_offer_ra(mentor_offer, user, receiver, type)
    RecentActivity.create!(
      :programs => [mentor_offer.program],
      :ref_obj => mentor_offer,
      :action_type => type,
      :member => user.member,
      :for => receiver.member,
      :target => RecentActivityConstants::Target::USER)
  end
end
