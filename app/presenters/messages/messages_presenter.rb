module Messages
  class MessagesPresenter < Messages::BasePresenter
    def initialize(wob_member, current_organization, args = {})
      @current_organization = current_organization
      @search_filters_params = args[:search_filters]
      init_messages_filter
      super(args[:tab], args[:page], wob_member, args[:html_request])
    end

    def unread_messages_count
      @wob_member.inbox_unread_count
    end

    private

    def init_messages_filter
      @messages_filter = MessagesFilterService.new(@search_filters_params)
    end

    def populate_inbox_tab
      messages_ids, messages_scope = @messages_filter.inbox_messages_ids(@wob_member, @current_organization)
      tab_data(messages_ids, MessageConstants::Tabs::INBOX, {messages_scope: messages_scope})
    end

    def populate_sent_tab
      messages_ids, messages_scope = @messages_filter.sent_messages_ids(@wob_member, @current_organization)
      tab_data(messages_ids, MessageConstants::Tabs::SENT, {messages_scope: messages_scope})
    end
  end
end