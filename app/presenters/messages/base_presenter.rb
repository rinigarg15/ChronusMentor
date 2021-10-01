module Messages
  class BasePresenter
    attr_reader :tabs_data, :tab_number, :page, :fetch_data_for_all_tabs

    ALL_TABS = [MessageConstants::Tabs::INBOX, MessageConstants::Tabs::SENT].freeze

    # fetch_data_for_all_tabs will be false if it is an AJAX req and the page number is not 1.
    # To avoid loading data again
    def initialize(tab, page, wob_member, html_request = false)
      @tab_number = tab.to_i
      @page = page.to_i != 0 ? page.to_i : 1
      @fetch_data_for_all_tabs = html_request || @page == 1
      @wob_member = wob_member
      @tabs_data = {}
      populate_tabs_data
    end

    def search_params_hash
      @messages_filter.search_params_hash
    end

    def my_filters
      @messages_filter.my_filters
    end

    def active_tab
      if fetch_data_for_all_tabs
        if (inbox_messages_count > 0 && sent_messages_count > 0) || (inbox_messages_count == 0 && sent_messages_count == 0)
          tab_number
        elsif inbox_messages_count > 0
          MessageConstants::Tabs::INBOX
        elsif sent_messages_count > 0
          MessageConstants::Tabs::SENT
        end
      else # in the case we paginate in one tab
        tab_number
      end
    end

    private

    def populate_tabs_data
      tabs_to_populate = fetch_data_for_all_tabs ? ALL_TABS : ALL_TABS.select {|tab| tab == @tab_number}
      tabs_to_populate.each do |tab|
        @tabs_data[tab] = case tab
          when MessageConstants::Tabs::INBOX then populate_inbox_tab
          when MessageConstants::Tabs::SENT then populate_sent_tab
        end
      end
    end

    def populate_inbox_tab
      raise "Method must be defined in Messages::BasePresenter's inheritor"
    end

    def populate_sent_tab
      raise "Method must be defined in Messages::BasePresenter's inheritor"
    end

    # tab_page - Page filter will be applied only in the requested tab
    def tab_data(messages_ids, requested_tab = MessageConstants::Tabs::INBOX, options = {})
      tab_page = (tab_number == requested_tab) ? @page : 1
      messages_hash = @messages_filter.get_paginated_messages_hash(tab_page, @wob_member, messages_ids)
      data = Struct.new(:messages_attachments, :messages_index, :messages_ids, :total_messages_count, :messages_scope).new
      data.messages_attachments = messages_hash[:messages_attachments]
      data.messages_index = messages_hash[:messages_index]
      data.messages_ids = messages_hash[:latest_messages]
      data.total_messages_count = messages_hash[:total_messages_count]
      data.messages_scope = options[:messages_scope].present? ? options[:messages_scope] : nil
      data
    end

    def inbox_messages_count
      tabs_data[MessageConstants::Tabs::INBOX].total_messages_count
    end

    def sent_messages_count
      tabs_data[MessageConstants::Tabs::SENT].total_messages_count
    end
  end
end