class UserCampaignAdminMessagePopulator < PopulatorTask

  def patch(options = {})
    return unless @options[:common]["campaign_management_enabled?"]
    user_campaign_ids = @program.user_campaigns.pluck(:id)
    user_campaign_message_ids = CampaignManagement::UserCampaignMessage.where(campaign_id: user_campaign_ids).pluck(:id)
    user_campaign_admin_messages_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, user_campaign_message_ids)
    process_patch(user_campaign_message_ids, user_campaign_admin_messages_hsh) 
  end

  def add_user_campaign_admin_messages(user_campaign_message_ids, count, options = {})
    self.class.benchmark_wrapper "User Campaign Admin Message" do
      program = options[:program]
      admin_member_ids = program.admin_users.pluck(:id)
      temp_admin_member_ids = admin_member_ids.dup
      user_ids = program.users.active.pluck(:id)
      temp_user_ids = user_ids.dup
      campaign_messages = CampaignManagement::UserCampaignMessage.where(id: user_campaign_message_ids).to_a
      temp_campaign_messages = campaign_messages * count
      AdminMessage.populate(user_campaign_message_ids.size * count, :per_query => 10_000) do |admin_message|
        cm_message = temp_campaign_messages.shift
        temp_user_ids = user_ids.dup if temp_user_ids.blank?
        temp_admin_member_ids = admin_member_ids.dup if temp_admin_member_ids.blank?
        admin_message.program_id = program.id
        admin_message.sender_id = temp_admin_member_ids.shift
        admin_message.subject = Populator.words(8..12)
        admin_message.content = Populator.paragraphs(1..3)
        admin_message.type = AdminMessage.to_s
        admin_message.auto_email = false
        admin_message.root_id = admin_message.id
        admin_message.campaign_message_id = cm_message.id
        admin_message.created_at = [Time.now - rand(1..100).days, cm_message.created_at].max 
        AdminMessages::Receiver.populate 1 do |admin_message_receiver|
          admin_message_receiver.member_id = temp_user_ids.shift
          admin_message_receiver.message_id = admin_message.id
          admin_message_receiver.status = [AbstractMessageReceiver::Status::UNREAD, AbstractMessageReceiver::Status::READ]
          admin_message_receiver.api_token = "adminmessage-api-token-#{self.class.random_string}_#{admin_message_receiver.member_id}"
          admin_message_receiver.message_root_id = admin_message.id
        end
        self.dot
      end
      self.class.display_populated_count(user_campaign_message_ids.size * count, "User Campaign Admin Message")
    end
  end

  def remove_user_campaign_admin_messages(user_campaign_message_ids, count, options = {})
    self.class.benchmark_wrapper "Removing User Campaign Admin Message Jobs................" do
      campaign_admin_message_ids = AdminMessage.where(:campaign_message_id => user_campaign_message_ids).select([:id, :campaign_message_id]).group_by(&:campaign_message_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      AdminMessage.where(:id => campaign_admin_message_ids).destroy_all
      self.class.display_deleted_count(user_campaign_message_ids.size * count, "User Campaign Admin Message")
    end
  end
end