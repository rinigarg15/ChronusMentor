class GenericAdminMessagePopulator < PopulatorTask

  def add_admin_messages(member_ids, count, options = {})
    self.class.benchmark_wrapper "Admin Message" do
      admin_member_id = options[:admin_member_id]
      member_ids = member_ids * count
      member_size = member_ids.size
      program = options[:program]
      AdminMessage.populate(member_size, :per_query => 50_000) do |admin_message|
        admin_message.program_id = program.id
        admin_message.sender_id = admin_member_id
        admin_message.subject = Populator.words(8..12)
        admin_message.content = Populator.paragraphs(1..3)
        admin_message.type = AdminMessage.to_s
        admin_message.auto_email = options[:auto_email] || false
        admin_message.root_id = admin_message.id
        admin_message.created_at = program.created_at..Time.now
        AdminMessages::Receiver.populate 1 do |admin_message_receiver|
          admin_message_receiver.member_id = member_ids.shift
          admin_message_receiver.message_id = admin_message.id
          admin_message_receiver.status = [AbstractMessageReceiver::Status::UNREAD, AbstractMessageReceiver::Status::READ]
          admin_message_receiver.api_token = "adminmessage-api-token-#{self.class.random_string}_#{admin_message_receiver.member_id}"
          admin_message_receiver.message_root_id = admin_message.id
          admin_message_receiver.created_at = admin_message.created_at
        end
        self.dot
      end
      self.class.display_populated_count(member_size, "Admin Message")
    end
  end

  def remove_admin_messages(member_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Admin Messages................" do
      program = options[:program]
      admin_message_ids = program.admin_message_receivers.where(:member_id => member_ids).select("abstract_message_receivers.id, member_id, message_id").group_by(&:member_id).map{|a| a[1].last(count)}.flatten.collect(&:message_id)
      program.admin_messages.where(:id => admin_message_ids, :auto_email => options[:auto_email]).destroy_all
      self.class.display_deleted_count(admin_message_ids.size * count, "Admin Message")
    end
  end
end