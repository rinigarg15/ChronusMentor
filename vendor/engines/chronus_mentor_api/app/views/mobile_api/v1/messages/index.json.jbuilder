jbuilder_responder(json, local_assigns) do
  json.list do
    tab_number = @messages_presenter.tab_number
    page = @messages_presenter.page
    tab_data = @messages_presenter.tabs_data[tab_number]

    result = fetch_messages_data(tab_data, @current_member)
    json.messages do
      json.array! result.latest_messages do |message|
        json.extract! message, :id, :subject, :type
        json.has_attachment  result.messages_attachments[message.root_id]
        json.thread_count    message.thread_members_and_size(@current_member)[:size]
        json.unread          message.tree_contains_unread_for_member?(@current_member)
        json.created_at      result.last_created_at[message.root_id]

        if tab_number == MessageConstants::Tabs::INBOX
          json.from from_details(message, @current_member)
          if message.sender.nil? || message.is_a?(AdminMessage) && message.auto_email?
            json.member_picture_url generate_member_url(nil, size: :small)
          else
            json.member_picture_url generate_member_url(message.sender, size: :small)
          end
        else
          json.to to_details(message, @current_member)
          if message.is_a?(AdminMessage) && !(message.sender_id && message.sent_by_admin? && message.is_member_admin_for_this_msg?(@current_member)) && !message.user_to_admin?
            json.member_picture_url generate_member_url(@current_member, size: :small)
          else
            json.member_picture_url generate_member_url(message.receivers.first, size: :small)
          end
        end
      end
    end

    json.total_count tab_data.total_messages_count
    if tab_number == MessageConstants::Tabs::INBOX || page == 1
      json.inbox_count @messages_presenter.tabs_data[MessageConstants::Tabs::INBOX].total_messages_count
    end
    if tab_number == MessageConstants::Tabs::SENT || page == 1
      json.sent_count  @messages_presenter.tabs_data[MessageConstants::Tabs::SENT].total_messages_count
    end
    json.inbox_unread_count @current_member.inbox_unread_count
    json.search_filters @messages_presenter.my_filters
  end
end
