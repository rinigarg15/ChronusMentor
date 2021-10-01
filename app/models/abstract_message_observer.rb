class AbstractMessageObserver < ActiveRecord::Observer
  def before_validation(abstract_message)
    abstract_message.strip_whitespace_from(abstract_message.sender_email)
  end

  def after_create(abstract_message)
    root_id = if abstract_message.parent_id
      abstract_message.parent.root_id.zero? ? abstract_message.parent_id : abstract_message.parent.root_id
    else
      abstract_message.id
    end
    abstract_message.update_attribute(:root_id, root_id)
    abstract_message.message_receivers.update_all("message_root_id=#{root_id}")

    if abstract_message.is_a?(Message) || abstract_message.is_a?(Scrap)
      if abstract_message.is_a?(Message)
        if abstract_message.relavant_groups.any?
          abstract_message = convert_message_to_group_scrap(abstract_message)
          ### Message is sent from outside the mentoring area ###
          abstract_message.add_to_activity_log
        elsif abstract_message.relavant_meetings.any?
          abstract_message = convert_message_to_meeting_scrap(abstract_message)
        end
      end
      create_scrap_activities(abstract_message) if abstract_message.is_a?(Scrap)
      abstract_message.delay(:queue => DjQueues::HIGH_PRIORITY).create_comment_from_scrap if abstract_message.is_a?(Scrap) && !abstract_message.root? && abstract_message.root.try(:comment).present?
      return if abstract_message.no_email_notifications
      trigger_emails(abstract_message)
    end
  end

  def after_destroy(abstract_message)
    return if abstract_message.allow_scrubber_to_destroy
    logger_message = "#{Time.now} Destroyed Message ID ##{abstract_message.attributes.inspect}!" + caller.join("\n")
    Airbrake.notify(StandardError.new(logger_message))
    unless Rails.env.test?
      respond_to?(:logger) ? logger.info(logger_message) : (puts logger_message)
    end
  end

  private

  def convert_message_to_group_scrap(message)
    message.attach_to_related_group
    AbstractMessage.find(message.id) ### Type is changed, Reload will not work ###
  end

  def convert_message_to_meeting_scrap(message)
    message.attach_to_related_meetings
    AbstractMessage.find(message.id) ### Type is changed, Reload will not work ###
  end

  def create_scrap_activities(scrap)
    RecentActivity.create!(
      :programs => [scrap.ref_obj.program],
      :ref_obj => scrap,
      :action_type => RecentActivityConstants::Type::SCRAP_CREATION,
      :member => scrap.sender,
      :target => RecentActivityConstants::Target::NONE
    )

    scrap.add_to_activity_log if scrap.posted_via_email?
  end

  def trigger_emails(abstract_message)
    AbstractMessage.delay(:queue => DjQueues::HIGH_PRIORITY).send_email_notifications(abstract_message.id, abstract_message.inbox_message_notification_type)
    Push::Base.queued_notify(PushNotification::Type::MESSAGE_SENT_NON_ADMIN, abstract_message)
  end
end