require_relative './../../../test_helper.rb'

class Messages::MessagesPresenterTest < ActiveSupport::TestCase
  def setup
    super
    scraps = Scrap.all.to_a
    reindex_documents(deleted: scraps)
    Scrap.destroy_all
    group = groups(:group_nwen)
    group.terminate!(users(:f_admin_nwen), "This is the reason for termination", group.program.permitted_closure_reasons.first.id)

    @wob_member = members(:f_mentor)
    @organization = @wob_member.organization
  end

  def test_unread_messages_count
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [1]).returns(AbstractMessage.where(id: [1]).paginate(page: 1, per_page: AbstractMessage::PER_PAGE))
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [2]).returns(AbstractMessage.where(id: [2]).paginate(page: 1, per_page: AbstractMessage::PER_PAGE))
    presenter = Messages::MessagesPresenter.new(@wob_member, @organization)
    assert_equal @wob_member.inbox_unread_count, presenter.unread_messages_count
  end

  def test_search_params_hash
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, []).returns([]).twice
    presenter = Messages::MessagesPresenter.new(@wob_member, @organization, search_filters: {sender: 'sender'})
    filter = MessagesFilterService.new({sender: 'sender'})
    assert_equal filter.search_params_hash, presenter.search_params_hash
  end

  def test_my_filters
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, []).returns([]).twice

    presenter = Messages::MessagesPresenter.new(@wob_member, @organization, search_filters: {sender: 'sender'})
    filter = MessagesFilterService.new({sender: 'sender'})
    assert_equal filter.my_filters, presenter.my_filters
  end

  def test_tab_number
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [1]).returns(AbstractMessage.where(id: [1]).paginate(page: 1, per_page: AbstractMessage::PER_PAGE)).twice
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [2]).returns(AbstractMessage.where(id: [2]).paginate(page: 1, per_page: AbstractMessage::PER_PAGE)).twice
    presenter = Messages::MessagesPresenter.new(@wob_member, @organization)
    assert_equal 0, presenter.tab_number

    presenter = Messages::MessagesPresenter.new(@wob_member, @organization, tab: 1)
    assert_equal 1, presenter.tab_number
  end

  def test_active_tab_is_sent
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [1]).returns(AbstractMessage.where(id: [1]).paginate(page: 1, per_page: AbstractMessage::PER_PAGE))
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [2]).returns(AbstractMessage.where(id: [2]).paginate(page: 1, per_page: AbstractMessage::PER_PAGE))
    current_tab = MessageConstants::Tabs::INBOX
    presenter = Messages::MessagesPresenter.new(@wob_member, @organization, tab: current_tab)
    presenter.stubs(:inbox_messages_count).returns(0)
    presenter.stubs(:sent_messages_count).returns(10)
    assert_equal MessageConstants::Tabs::SENT, presenter.active_tab
  end

  def test_active_tab_is_inbox
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [1]).returns(AbstractMessage.where(id: [1]).paginate(page: 1, per_page: AbstractMessage::PER_PAGE))
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [2]).returns(AbstractMessage.where(id: [2]).paginate(page: 1, per_page: AbstractMessage::PER_PAGE))
    current_tab = MessageConstants::Tabs::INBOX
    presenter = Messages::MessagesPresenter.new(@wob_member, @organization, tab: current_tab)
    presenter.stubs(:inbox_messages_count).returns(10)
    presenter.stubs(:sent_messages_count).returns(0)
    assert_equal MessageConstants::Tabs::INBOX, presenter.active_tab
  end

  def test_active_tab_remains_the_same
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [1]).returns(AbstractMessage.where(id: [1]).paginate(page: 1, per_page: AbstractMessage::PER_PAGE))
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [2]).returns(AbstractMessage.where(id: [2]).paginate(page: 1, per_page: AbstractMessage::PER_PAGE))
    current_tab = MessageConstants::Tabs::INBOX
    presenter = Messages::MessagesPresenter.new(@wob_member, @organization, tab: current_tab)
    presenter.stubs(:inbox_messages_count).returns(10)
    presenter.stubs(:sent_messages_count).returns(20)
    assert_equal MessageConstants::Tabs::INBOX, presenter.active_tab
  end

  def test_active_tab_is_current_while_paginating
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(2, [1]).returns(AbstractMessage.where(id: [1]).paginate(page: 2, per_page: AbstractMessage::PER_PAGE))
    current_tab = MessageConstants::Tabs::INBOX
    presenter = Messages::MessagesPresenter.new(@wob_member, @organization, tab: current_tab, page: 2)
    presenter.stubs(:inbox_messages_count).returns(0)
    presenter.stubs(:sent_messages_count).returns(10)
    assert_equal current_tab, presenter.active_tab
  end

  def test_tabs_data
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [1]).returns(AbstractMessage.where(id: [1]).paginate(page: 1, per_page: AbstractMessage::PER_PAGE)).twice
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [2]).returns(AbstractMessage.where(id: [2]).paginate(page: 1, per_page: AbstractMessage::PER_PAGE)).twice
    presenter = Messages::MessagesPresenter.new(members(:f_mentor_student), programs(:albers))
    inbox_tab_data = presenter.tabs_data[MessageConstants::Tabs::INBOX]
    assert_equal_unordered [messages(:second_message)].collect(&:id), inbox_tab_data.messages_ids.collect(&:root_id)
    assert_false inbox_tab_data.messages_attachments[messages(:second_message).id]

    presenter = Messages::MessagesPresenter.new(members(:f_mentor_student), programs(:albers))
    sent_tab_data = presenter.tabs_data[MessageConstants::Tabs::SENT]
    assert_equal_unordered [messages(:first_message)].collect(&:id), sent_tab_data.messages_ids.collect(&:root_id)
    assert_false sent_tab_data.messages_attachments[messages(:second_message).id]
  end

  def test_tabs_data_with_page
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [1]).returns(AbstractMessage.where(id: [1]).paginate(page: 1, per_page: AbstractMessage::PER_PAGE))
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(2, [2]).returns(AbstractMessage.where(id: [2]).paginate(page: 1, per_page: AbstractMessage::PER_PAGE)).twice
    presenter = Messages::MessagesPresenter.new(members(:f_mentor_student), programs(:albers), page: 2)
    assert_equal 1, presenter.tabs_data.size
    assert presenter.tabs_data[MessageConstants::Tabs::INBOX]
    assert_nil presenter.tabs_data[MessageConstants::Tabs::SENT]

    presenter = Messages::MessagesPresenter.new(members(:f_mentor_student), programs(:albers), page: 2, html_request: true)
    assert_equal 2, presenter.tabs_data.size
    assert presenter.tabs_data[MessageConstants::Tabs::INBOX]
    assert presenter.tabs_data[MessageConstants::Tabs::SENT]
  end

  def test_sent_tab_data_messages_attachments
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [1]).returns(AbstractMessage.where(id: [1]).paginate(page: 1, per_page: AbstractMessage::PER_PAGE))
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [2]).returns(AbstractMessage.where(id: [2]).paginate(page: 1, per_page: AbstractMessage::PER_PAGE))
    m = messages(:second_message)
    m.attachment = fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
    m.save!

    presenter = Messages::MessagesPresenter.new(members(:f_mentor), programs(:albers))
    tab_data = presenter.tabs_data[MessageConstants::Tabs::SENT]
    assert tab_data.messages_attachments[m.id]
  end

  def test_inbox_tab_data_filter_system_generated
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [1]).returns(AbstractMessage.where(id: [1]).paginate(page: 1, per_page: AbstractMessage::PER_PAGE))
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [2]).returns(AbstractMessage.where(id: [2]).paginate(page: 1, per_page: AbstractMessage::PER_PAGE))
    m = messages(:second_message)
    m.update_column(:auto_email, true)

    presenter =Messages::MessagesPresenter.new(members(:f_mentor_student), programs(:albers))
    tab_data = presenter.tabs_data[MessageConstants::Tabs::INBOX]
    assert_equal_unordered [messages(:second_message)].collect(&:id), tab_data.messages_ids.collect(&:root_id)
  end


  def test_sent_tab_data_filter_system_generated
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [1]).returns(AbstractMessage.where(id: [1]).paginate(page: 1, per_page: AbstractMessage::PER_PAGE))
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [2]).returns(AbstractMessage.where(id: [2]).paginate(page: 1, per_page: AbstractMessage::PER_PAGE))
    m = messages(:second_message)
    m.update_column(:auto_email, true)

    presenter =Messages::MessagesPresenter.new(members(:f_mentor_student), programs(:albers))
    tab_data = presenter.tabs_data[MessageConstants::Tabs::SENT]
    assert_equal_unordered [messages(:first_message)].collect(&:id), tab_data.messages_ids.collect(&:root_id)
  end
end