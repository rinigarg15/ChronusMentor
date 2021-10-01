When /I click message "([^\"]*)" of "([^\"]*)" message list/ do |message_text, items_type|
  row_selector = "#cjs_#{items_type == 'Inbox' ? '0' : '1'}_messages_list li:contains(\'#{message_text}\')"
  page.execute_script("jQuery(\"#{row_selector}\").click()")
end

Then /^I should see "([^\"]*)" as read message/ do |message_text|
  row_selector = ".cjs_messages_list .cjs_preview_section:visible:contains(\'#{message_text}\')"
  assert page.evaluate_script("jQuery(\"#{row_selector}\").length > 0")
end

Then /^I should see "([^\"]*)" as unread message/ do |message_text|
  row_selector = ".cjs_messages_list .cjs_detailed_section:visible:contains(\'#{message_text}\')"
  assert page.evaluate_script("jQuery(\"#{row_selector}\").length > 0")
end


Then /^I send a admin message to mentoring connection$/ do
  within "div#title_actions" do
    step "I click \"span.caret\""
  end
  steps %{
    And I follow "Send Message to Mentoring Connections"
    And I fill in "admin_message_subject" with "Subject"
    And I fill in CKEditor "admin_message_content" with "Message to the Mentoring Connection"
  }
  page.execute_script("jQuery('input#admin_message_connection_ids').val('2')")
  page.execute_script("jQuery('input#receiver').val('student_c example and Non requestable mentor')")
  step "I press \"Send Message\""
end

And /^I try to visit malformed contact admin url and get page not found result$/ do
  # commenting PATH_INFO in char_converter.rb will result in "ArgumentError: invalid byte sequence in UTF-8"
  assert_raise(ActionController::RoutingError) do
    visit "/p/albers/contact_admin++%ed"
  end
end

Given /"([^\"]*)" last "([^\"]*)" exist/ do |count, message_type|
  model_name, filter_service = (message_type == "admin message" ? [AdminMessage, AdminMessagesFilterService] : [AbstractMessage, MessagesFilterService])
  messages = model_name.order("id desc").limit(count.to_i).to_a
  messages_index = messages.inject({}) {|mem, message| mem[message.id] = message; mem[message.root_id || message.id] = message; mem}
  messages_attachments = messages.inject({}) {|mem, message| mem[message.id] = false; mem}
  filter_service.any_instance.expects(:get_paginated_messages_hash).at_least(0).returns(
    {
      total_messages_count: messages.count, latest_messages: messages.paginate(:page => 1, :per_page => AbstractMessage::PER_PAGE), 
      messages_index: messages_index, messages_attachments: messages_attachments
    }
  )
end
