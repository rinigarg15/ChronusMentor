require_relative './../../test_helper.rb'

class AbstractMessagesFilterServiceTest < ActiveSupport::TestCase

  def test_search_params_hash
    date_range = "05/26/2014 - 05/28/2014"
    start_time = Date.strptime("05/26/2014", "date.formats.date_range".translate)
    end_time = Date.strptime("05/28/2014", "date.formats.date_range".translate)
    search_params_hash = { sender: 'sender_email@test.com', receiver: 'receiver_email@test.com', status: { read: '1' }, program_id: 1, date_range: date_range, search_content: '' }
    filter = AbstractMessagesFilterService.new(search_params_hash)
    search_params_hash.merge!(date_range: { start_time: start_time.beginning_of_day.to_datetime, end_time: end_time.end_of_day.to_datetime })
    assert_equal_hash search_params_hash, filter.search_params_hash
  end

  def test_my_filters
    search_params_hash = {sender: 'sender_email@test.com', receiver: 'receiver_email@test.com', status: {read: '1'}, :program_id => 1, date_range: "05/26/2014 - 05/28/2014", search_content: ''}
    filter = AbstractMessagesFilterService.new(search_params_hash)
    my_filters = [
      {:label => "feature.messaging.label.from".translate, :reset_suffix => 'sender'},
      {:label => "feature.messaging.label.to".translate, :reset_suffix => 'receiver'},
      {:label => "feature.messaging.label.status".translate, :reset_suffix => 'status'},
      {:label => "display_string.Program".translate, :reset_suffix => 'program'},
      {:label => "common_text.filter.label.date_range".translate, :reset_suffix => 'date_range'}
    ]
    assert_equal my_filters, filter.my_filters
  end

  def test_get_paginated_messages_hash
    message = messages(:group_3_student_2)
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [message.id]).returns(AbstractMessage.where(id: [message.id]).paginate(page: 1, per_page: AbstractMessage::PER_PAGE))
    paginated_messages_hash = { total_messages_count: 1, latest_messages: [message], messages_index: { message.id => message }, messages_attachments: { message.id => false } }
    assert_equal_hash paginated_messages_hash, AbstractMessagesFilterService.new({}).get_paginated_messages_hash(1, members(:f_admin), [message.id])
  end

  def test_get_paginated_messages_hash_filtered_by_search_content
    message = messages(:group_3_student_2)
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [message.id]).returns(AbstractMessage.where(id: [message.id]).paginate(page: 1, per_page: AbstractMessage::PER_PAGE)).once
    assert_equal_unordered [message.id], AbstractMessagesFilterService.new(search_content: 'Subject').get_paginated_messages_hash(1, members(:f_admin), [message.id])[:latest_messages].map(&:id)

    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [message.id]).returns([]).once
    assert_empty AbstractMessagesFilterService.new(search_content: 'nohello').get_paginated_messages_hash(1, members(:f_admin), [message.id])[:latest_messages].map(&:id)
  end
end