jbuilder_responder(json, local_assigns) do
  json.message do
    json.array! @message.tree.select{|message| message.can_be_viewed?(@current_member)} do |message|
      json.extract! message, :id, :created_at, :subject, :parent_id, :root_id, :type

      json.content message.formatted_content

      name_details = message_from_and_to_names_details(message, @current_member)
      json.from name_details[:from]
      json.to name_details[:to]
      json.can_reply_or_delete message.can_be_replied_or_deleted?(@current_member)
      json.can_be_replied message.can_be_replied?(@current_member)

      if message.sender.nil? || message.is_a?(AdminMessage) && message.auto_email?
        json.sender_picture_url generate_member_url(nil, size: :small)
      else
        json.sender_picture_url generate_member_url(message.sender, size: :small)
      end
      if message.attachment.present?
        json.attachment_file_name message.attachment_file_name
        json.attachment_url message.attachment.url
      end
    end
  end
end
