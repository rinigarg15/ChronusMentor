require_relative './../../../test_helper.rb'

class Messages::AdminMessagesPresenterTest < ActiveSupport::TestCase
  def setup
    super
    @receiver = @wob_member = members(:f_admin)
    @sender = members(:f_mentor_student)
    @sender2 = members(:f_mentor)
    @program = programs(:albers)
  end

  def test_unread_messages_count
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [3, 4, 5, 6]).returns(AbstractMessage.where(id: [4, 3]).order("FIELD(id, 4,3)").paginate(page: 1, per_page: AbstractMessage::PER_PAGE)).times(2)
    presenter = Messages::AdminMessagesPresenter.new(members(:f_admin), @program)
    assert_equal @program.admin_messages_unread_count, presenter.unread_messages_count
  end

  def test_inbox_tabs_data
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [3, 4, 5, 6]).returns(AbstractMessage.where(id: [4, 3]).order("FIELD(id, 4,3)").paginate(page: 1, per_page: AbstractMessage::PER_PAGE)).twice
    presenter = Messages::AdminMessagesPresenter.new(members(:f_admin), @program)
    tab_data = presenter.tabs_data[MessageConstants::Tabs::INBOX]
    assert_equal_unordered [messages(:first_admin_message), messages(:second_admin_message)].collect(&:id), tab_data.messages_ids.collect(&:root_id)
  end

  def test_sent_tabs_data
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [3, 4, 5, 6]).returns(AbstractMessage.where(id: [4, 3]).order("FIELD(id, 4,3)").paginate(page: 1, per_page: AbstractMessage::PER_PAGE)).twice
    presenter = Messages::AdminMessagesPresenter.new(members(:f_admin), @program)
    tab_data = presenter.tabs_data[MessageConstants::Tabs::SENT]
    assert_equal_unordered [messages(:first_admin_message), messages(:second_admin_message)].collect(&:id), tab_data.messages_ids.collect(&:root_id)
  end

  def test_sent_tabs_data_messages_system_generated
    m = messages(:third_admin_message)
    m.update_column(:auto_email, true)
    message = AbstractMessage.find(m.id)
    presenter = Messages::AdminMessagesPresenter.new(members(:f_admin), @program)
    tab_data = presenter.tabs_data[MessageConstants::Tabs::SENT]
    assert_equal_unordered [messages(:second_admin_message)].map(&:id), tab_data.messages_ids.collect(&:root_id)

    presenter = Messages::AdminMessagesPresenter.new(members(:f_admin), @program, {include_system_generated: false})
    tab_data = presenter.tabs_data[MessageConstants::Tabs::SENT]
    assert_equal_unordered [messages(:second_admin_message)].map(&:id), tab_data.messages_ids.collect(&:root_id)

    presenter = Messages::AdminMessagesPresenter.new(members(:f_admin), @program, {include_system_generated: true})
    tab_data = presenter.tabs_data[MessageConstants::Tabs::SENT]
    assert_equal_unordered [messages(:first_admin_message), messages(:second_admin_message), messages(:seventh_campaigns_admin_message), messages(:first_campaigns_admin_message),  messages(:second_campaigns_admin_message), messages(:eigth_campaigns_admin_message), messages(:third_campaigns_admin_message), messages(:first_campaigns_second_admin_message), messages(:first_campaigns_third_admin_message) ].map(&:id), tab_data.messages_ids.collect(&:root_id)
  end

  def test_tabs_data_with_page
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(2, [3, 4, 5, 6]).returns(AbstractMessage.where(id: [4, 3]).order("FIELD(id, 4,3)").paginate(page: 1, per_page: AbstractMessage::PER_PAGE)).times(2)
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [3, 4, 5, 6]).returns(AbstractMessage.where(id: [4, 3]).order("FIELD(id, 4,3)").paginate(page: 1, per_page: AbstractMessage::PER_PAGE)).times(1)

    presenter = Messages::AdminMessagesPresenter.new(members(:f_mentor_student), programs(:albers), page: 2)
    assert_equal 1, presenter.tabs_data.size
    assert presenter.tabs_data[MessageConstants::Tabs::INBOX]
    assert_nil presenter.tabs_data[MessageConstants::Tabs::SENT]

    presenter = Messages::AdminMessagesPresenter.new(members(:f_mentor_student), programs(:albers), page: 2, html_request: true)
    assert_equal 2, presenter.tabs_data.size
    assert presenter.tabs_data[MessageConstants::Tabs::INBOX]
    assert presenter.tabs_data[MessageConstants::Tabs::SENT]
  end
end