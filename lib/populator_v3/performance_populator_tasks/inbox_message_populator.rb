class InboxMessagePopulator < PopulatorTask

  def patch(options = {})
    return if @options[:common]["flash_type"]
    member_ids = @organization.members.active.pluck(:id)
    @options[:member_ids] = member_ids
    messages_hsh = get_children_hash(@organization, @options[:args]["model"]||@node, @foreign_key, member_ids)
    process_patch(member_ids, messages_hsh)
  end

  def add_inbox_messages(member_ids, count, options = {})
    self.class.benchmark_wrapper "Inbox Messages" do
      temp_member_ids = member_ids * count
      organization = options[:organization]
      recepient_member_ids = options[:member_ids]
      iterator = 0
      Message.populate(member_ids.size * count, :per_query => 10_000) do |message|
        message.program_id = organization.id
        message.sender_id = temp_member_ids.shift
        message.subject = Populator.words(8..12)
        message.content = Populator.paragraphs(1..3)
        message.type = Message.to_s
        message.auto_email = false
        message.root_id = message.id
        message.created_at = organization.created_at
        message.updated_at = organization.created_at..Time.now
        Messages::Receiver.populate 1 do |message_receiver|
          message_receiver.member_id = (recepient_member_ids - [message.sender_id]).sample
          message_receiver.message_id = message.id
          message_receiver.status = [AbstractMessageReceiver::Status::UNREAD, AbstractMessageReceiver::Status::READ]
          message_receiver.api_token = "message-api-token-#{iterator += 1}#{self.class.random_string}"
          message_receiver.message_root_id = message.id
          message_receiver.created_at = message.created_at
          message_receiver.updated_at = message.updated_at
        end
        self.dot
      end
      self.class.display_populated_count(member_ids.size * count, "Inbox Message")
    end
  end

  def remove_inbox_messages(member_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Inbox Messages................" do
      organization = options[:organization]
      message_ids = organization.messages.where(:sender_id => member_ids).select([:id, :sender_id]).group_by(&:sender_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      organization.messages.where(:id => message_ids).destroy_all
      self.class.display_deleted_count(member_ids.size * count, "Inbox Message")
    end
  end
end