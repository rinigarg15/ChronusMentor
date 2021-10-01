module MobileApi::V1::MessagesHelper
  NAME_DELIMITER = ", "
  def from_details(message, viewer)
    details = message.thread_members_and_size(viewer)
    details[:members].map{|member| member.is_a?(Member) ? from_name_string(message, member, viewer) : member}.join(NAME_DELIMITER)
  end

  def to_details(message, viewer)
    to_details = []
    if message.is_a?(AdminMessage)
      if !(message.sender_id && message.sent_by_admin? && message.is_member_admin_for_this_msg?(viewer)) && !message.user_to_admin?
        to_details << "feature.messaging.content.me".translate
      elsif message.message_receivers.any?
        message.message_receivers.each do |msg_rcvr|
          if msg_rcvr.member_id.nil?
            to_details << ((msg_rcvr.name.nil?) ? _Admin : "#{msg_rcvr.name} <#{msg_rcvr.email}>")
          elsif message.for_program?
            to_details << (message.get_user(msg_rcvr.member).present? ? msg_rcvr.member.name : "feature.messaging.content.message_receiver_removed_user".translate)
          else
            to_details << msg_rcvr.member.name
          end
        end
      else
        to_details << "feature.messaging.content.message_receiver_removed_user".translate
      end
    elsif message.message_receivers.present?
      message.message_receivers.each do |msg_rcvr|
        if msg_rcvr.member_id.nil?
          to_details << ((msg_rcvr.name.nil?) ? "feature.messaging.content.message_receiver_removed_user".translate : "#{msg_rcvr.name} <#{msg_rcvr.email}>")
        else
          to_details << ((msg_rcvr.member == viewer) ? "feature.messaging.content.me".translate : msg_rcvr.member.name)
        end
      end
    else
      to_details << "feature.messaging.content.message_receiver_removed_user".translate
    end
    to_details.to_sentence
  end

  def from_name_string(message, member, viewer)
    if message.is_a?(AdminMessage) && message.sent_by?(member) && message.auto_email?
      _Admin
    else
      member == viewer ? "display_string.me".translate : member.name(:name_only => true)
    end
  end

  def message_from_and_to_names_details(message, viewer)
    if (message.is_a?(AdminMessage) && !message.auto_email? && (message.sender_id == viewer.id)) || (!message.is_a?(AdminMessage) && message.sent_by?(viewer))
      from_details = "feature.messaging.content.Me".translate
    elsif message.sender_id.nil?
      from_details = "#{message.sender_name}"
      from_details += " <#{message.sender_email}>" if message.sender_email
    elsif (message.is_a?(AdminMessage) && message.auto_email?)
      from_details = _Admin
    else
      if message.for_program?
        from_details = (message.sender_user.present? ? message.sender.name : "feature.messaging.content.message_receiver_removed_user".translate)
      else
        from_details = message.sender.name
      end
    end
    {:from => from_details, :to => to_details(message, viewer)}
  end

  def fetch_messages_data(tab_data, member)
    data = Struct.new(:messages_attachments, :latest_messages, :last_created_at).new
    data.messages_attachments = tab_data.messages_attachments
    data.latest_messages = []
    data.last_created_at = {}
    tab_data.messages_ids.each do |msg|
      message = tab_data.messages_index[msg.root_id]
      message = message.get_next_not_marked_as_deleted(member) if message.deleted?(member)
      last_msg = message.is_a?(AdminMessage)? message.member_admin_filtered_tree(member).select{|msg| msg.can_be_viewed?(member)}.last : message.tree.select{|msg| msg.can_be_viewed?(member)}.last
      if last_msg.present?
        data.latest_messages << message
        data.last_created_at[msg.root_id] = last_msg.created_at
      end
    end
    data
  end
end