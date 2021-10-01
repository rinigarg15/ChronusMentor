class AdminMessagePopulator < GenericAdminMessagePopulator

  def patch(options = {})
    return if @options[:common]["flash_type"]
    admin_member_ids = @program.admin_users.pluck(:member_id)
    @options[:admin_member_id] = admin_member_ids.first
    member_ids = @program.users.active.pluck(:member_id) - admin_member_ids
    admin_message_ids = @program.admin_messages.where(:campaign_message_id => nil, auto_email: false)
    @options.merge!({auto_email: false})
    admin_message_receivers_hsh = @program.admin_message_receivers.where(:message_id => admin_message_ids).pluck(:member_id).group_by{|x| x}
    process_patch(member_ids, admin_message_receivers_hsh) 
  end
end