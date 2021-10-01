require_relative './../test_helper.rb'

class PushNotificationTest < ActiveSupport::TestCase

  def test_should_not_create_with_out_notification_params
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :notification_params do
      PushNotification.create!
    end
  end

  def test_mark_as_read
    sender = members(:robert)
    @member = members(:rahim)
    @message = create_message(:sender => sender, :receiver => @member)
    object = {object_id: @message.id, category: @message.type}
    notification = @member.push_notifications.create!(notification_params: object, ref_obj_id: @message.id, ref_obj_type: @message.type, notification_type: PushNotification::Type::MESSAGE_SENT_ADMIN)
    assert notification.unread?
    notification.mark_as_read!
    assert_false PushNotification.find(notification.id).unread?
  end

  def test_validate_presence
    notification = PushNotification.new
    assert_false notification.save
    sender = members(:robert)
    @member = members(:rahim)
    @message = create_message(:sender => sender, :receiver => @member)
    object = {object_id: @message.id, category: "Message"}
    notification = @member.push_notifications.create(notification_params: object)
    assert_false notification.save
    notification = @member.push_notifications.create(notification_params: object, ref_obj_id: @message.id)
    assert_false notification.save
    notification = @member.push_notifications.create(notification_params: object, ref_obj_id: @message.id, ref_obj_type: @message.type)
    assert_false notification.save
    notification = @member.push_notifications.create(notification_params: object, ref_obj_id: @message.id, ref_obj_type: @message.type, notification_type: PushNotification::Type::MESSAGE_SENT_NON_ADMIN)
    assert notification.save
  end

  def test_ref_obj_type
    sender = members(:robert)
    member = members(:rahim)
    message = create_message(:sender => sender, :receiver => member, :organization => programs(:org_primary))
    object = {object_id: message.id, category: "Message"}
    notification = create_push_notification(member, object, message, PushNotification::Type::MESSAGE_SENT_NON_ADMIN)

    assert_equal "AbstractMessage", notification.ref_obj_type
    assert_equal "Message", notification.ref_obj.class.name
  end
  
  private
  def create_push_notification(member, notification_params, ref_obj, notification_type)
    member.push_notifications.create!(notification_params: notification_params, ref_obj_id: ref_obj.id, ref_obj_type: ref_obj.class.name, notification_type: notification_type)
  end

end