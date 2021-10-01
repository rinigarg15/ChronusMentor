class MembershipRequestObserver < ActiveRecord::Observer
  def after_create(membership_request)
    program = membership_request.program
    if !membership_request.joined_directly?
      RecentActivity.create!(
        :programs => [program],
        :ref_obj => membership_request,
        :action_type => RecentActivityConstants::Type::CREATE_MEMBERSHIP_REQUEST,
        :target => RecentActivityConstants::Target::ADMINS
      )
      membership_request.delay(:queue => DjQueues::HIGH_PRIORITY).send_membership_notification
    end
  end

  def before_validation(membership_request)
    membership_request.strip_whitespace_from(membership_request.email)
  end

  def after_update(membership_request)
    return if membership_request.skip_observer
    # Making the membership request email consistent with member email so as to send mails to the updated address
    if membership_request.member.present? && membership_request.email.downcase != membership_request.member.email.downcase
      membership_request.email = membership_request.member.email
      membership_request.skip_observer_and_save
    end

    unless membership_request.joined_directly?
      status_changes = membership_request.saved_changes["status"]

      if status_changes == [MembershipRequest::Status::UNREAD, MembershipRequest::Status::ACCEPTED]
        user = membership_request.create_user_from_accepted_request
        MembershipRequest.delay.send_membership_request_accepted_notification(membership_request.id)
      elsif status_changes == [MembershipRequest::Status::UNREAD, MembershipRequest::Status::REJECTED]
        MembershipRequest.delay.send_membership_request_not_accepted_notification(membership_request.id)
      end
    end
  end
end