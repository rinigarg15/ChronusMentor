class EmailEventLogPopulator < PopulatorTask

  def patch(options = {})
    return unless @options[:common]["campaign_management_enabled?"]
    admin_message_ids = @program.admin_messages.where("campaign_message_id IS NOT NULL").pluck(:id)
    email_event_logs_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key,admin_message_ids)
    process_patch(admin_message_ids, email_event_logs_hsh)
  end

  def add_email_event_logs(admin_message_ids, count, options = {})
    self.class.benchmark_wrapper "email_event_logs" do
      admin_messages = AdminMessage.where(id: admin_message_ids).to_a
      temp_admin_messages = admin_messages * count
      iterator = 0
      CampaignManagement::EmailEventLog.populate(admin_message_ids.size * count, :per_query => 10_000) do |email_event_log|
        temp_admin_messages = admin_messages.dup if temp_admin_messages.blank?
        admin_message = temp_admin_messages.shift
        email_event_log.message_id = admin_message.id
        temp_admin_messages = admin_messages.dup if temp_admin_messages.blank?
        email_event_log.event_type = [CampaignManagement::EmailEventLog::Type::CLICKED, CampaignManagement::EmailEventLog::Type::OPENED, CampaignManagement::EmailEventLog::Type::DROPPED, CampaignManagement::EmailEventLog::Type::BOUNCED, CampaignManagement::EmailEventLog::Type::SPAMMED, CampaignManagement::EmailEventLog::Type::OPENED, CampaignManagement::EmailEventLog::Type::DELIVERED, CampaignManagement::EmailEventLog::Type::DELIVERED, CampaignManagement::EmailEventLog::Type::DELIVERED, CampaignManagement::EmailEventLog::Type::DELIVERED].sample
        email_event_log.timestamp = admin_message.created_at + iterator.days
        email_event_log.message_type = CampaignManagement::EmailEventLog::MessageType::ADMIN_MESSAGE
        iterator += 1
        self.dot
      end
      self.class.display_populated_count(admin_message_ids.size * count, "email_event_logs")
    end
  end

  def remove_email_event_logs(admin_message_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Email Event Log................" do
      email_event_log_ids = CampaignManagement::EmailEventLog.where(:message_id => admin_message_ids).select([:id, :message_id]).group_by(&:message_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      CampaignManagement::EmailEventLog.where(:id => email_event_log_ids).destroy_all
      self.class.display_deleted_count(admin_message_ids.size * count, "email_event_logs")
    end
  end
end