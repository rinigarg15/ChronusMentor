module ScrapExtensions
  def get_scrap_messages_index(root_message_ids, member, options = {})

    latest_messages_relation = get_latest_messages(root_message_ids, member, options)
    # Note that paginated_latest_messages is an array of latest messages (one per thread) with only root_id fetched
    if options[:home_page] && (latest_messages_relation.count == 0)
      options[:home_page] = false
      latest_messages_relation = get_latest_messages(root_message_ids, member, options)
      latest_messages_relation = latest_messages_relation.first(Scrap::HOME_LATEST_MESSAGE_LIMIT)
      options[:home_page] = true
    end
    paginated_latest_messages = latest_messages_relation.paginate(:page => options[:page], :per_page => options[:per_page])

    latest_message_root_ids = paginated_latest_messages.collect(&:root_id)
    messages_index = AbstractMessage.where(id: latest_message_root_ids).
      includes(sender: { users: [:roles, :program] }).
      index_by(&:id)

    preloaded_scraps_hash = get_preloaded_scraps_hash(latest_message_root_ids, member)
    messages_attachments = get_message_attachments(member, messages_index, preloaded_scraps_hash)
    
    if !options[:home_page]
      paginated_root_msg_last_created_hash = {}
      ActiveRecord::Base.connection.select_all(
        latest_messages_relation.where(:root_id => latest_message_root_ids)
      ).each do |obj|
        paginated_root_msg_last_created_hash[obj["root_id"]] = obj["maximum_created_at"]
      end
    end

    {latest_messages: options[:home_page] ? latest_messages_relation : paginated_latest_messages, messages_index: messages_index, messages_attachments: messages_attachments, messages_last_created_at: paginated_root_msg_last_created_hash}.merge(preloaded_scraps_hash)
  end

  def get_preloaded_scraps_hash(root_ids, member)
    siblings = AbstractMessage.where(root_id: root_ids).includes([:program, sender: [{ users: [:roles] }]])
    message_receivers = member.message_receivers.where(message_id: siblings.collect(&:id))
    preloaded_scraps_hash = {}
    preloaded_scraps_hash[:siblings_index] = siblings.group_by(&:root_id)
    preloaded_scraps_hash[:viewable_scraps_hash] = message_receivers.group_by(&:message_id)
    preloaded_scraps_hash[:unread_scraps_hash] = message_receivers.unread.group_by(&:message_id)
    preloaded_scraps_hash[:deleted_scraps_hash] = message_receivers.deleted.group_by(&:message_id)
    preloaded_scraps_hash
  end

  def is_latest_message_present?(root_message_ids, member)
    get_latest_messages(root_message_ids, member).present?
  end

  private
  def get_latest_messages(root_message_ids, member, options = {})
    root_id_condition = root_message_ids.is_a?(Array) ? ["messages.root_id IN (?)", root_message_ids] : "messages.root_id IN (#{root_message_ids.to_sql})"
    search_conditions = if options[:is_admin_viewing_scraps]
      []
    elsif options[:home_page]
      ["((abstract_message_receivers.member_id = ? AND abstract_message_receivers.status = ?))", member.id, AbstractMessageReceiver::Status::UNREAD]
    else
      ["(messages.sender_id = ? OR (abstract_message_receivers.member_id = ? AND abstract_message_receivers.status != ?))", member.id, member.id, AbstractMessageReceiver::Status::DELETED]
    end
    latest_message_query = AbstractMessage.
       select("messages.root_id, MAX(messages.created_at) AS maximum_created_at").
       joins("LEFT OUTER JOIN abstract_message_receivers ON abstract_message_receivers.message_id = messages.id").
       where(root_id_condition).
       where(search_conditions).
       group(:root_id).
       order("maximum_created_at DESC")
    if options[:home_page]
      latest_message_query.first(Scrap::UNREAD_MESSAGE_LIMIT)
    else
      latest_message_query
    end
  end

  def get_message_attachments(member, messages_index={}, preloaded_scraps_hash={})
    messages_attachments= {}
    messages_index.values.each do |message|
      sibling_options = {preloaded: true, siblings_index: preloaded_scraps_hash[:siblings_index], viewable_scraps_hash: preloaded_scraps_hash[:viewable_scraps_hash], deleted_scraps_hash: preloaded_scraps_hash[:deleted_scraps_hash]}
      messages_attachments[message.id] = message.sibling_has_attachment?(member, sibling_options)
    end
    messages_attachments
  end
end