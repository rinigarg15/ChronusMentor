module Messages
  class AdminMessagesPresenter < Messages::BasePresenter
    def initialize(wob_member, current_program_or_organization, args = {})
      @current_program_or_organization = current_program_or_organization
      @search_filters_params = args[:search_filters]
      @include_system_generated_param = args[:include_system_generated]
      init_messages_filter
      super(args[:tab], args[:page], wob_member, args[:html_request])
    end

    def unread_messages_count
      @current_program_or_organization.admin_messages_unread_count
    end

    def include_system_generated
      @messages_filter.include_system_generated
    end

    private

    def init_messages_filter
      @messages_filter = AdminMessagesFilterService.new((@search_filters_params || {}), @include_system_generated_param)
    end

    def populate_inbox_tab
      messages_ids = @messages_filter.inbox_messages_ids(@wob_member, @current_program_or_organization)
      tab_data(messages_ids, MessageConstants::Tabs::INBOX)
    end

    def populate_sent_tab
      messages_ids = @messages_filter.sent_messages_ids(@wob_member, @current_program_or_organization)
      tab_data(messages_ids, MessageConstants::Tabs::SENT)
    end
  end
end