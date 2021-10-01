jbuilder_responder(json, local_assigns) do
  json.group_name @group.name
  json.scrap do
    json.array! @scrap.tree.select{|scrap| scrap.can_be_viewed?(@current_member)} do |scrap|
      json.extract! scrap, :id, :created_at, :subject, :parent_id, :root_id, :type, :group_id
      json.content scrap.formatted_content
      name_details = message_from_and_to_names_details(scrap, @current_member)
      json.from name_details[:from]
      json.to name_details[:to]
      json.can_reply_or_delete scrap.can_be_replied_or_deleted?(@current_member)
      json.can_be_replied scrap.can_be_replied?(@current_member)
      json.sender_picture_url generate_member_url(scrap.sender, size: :small)
      if scrap.attachment.present?
        json.attachment_file_name scrap.attachment_file_name
        json.attachment_url scrap.attachment.url
      end
    end
  end
end