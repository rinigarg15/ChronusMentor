class AdminMessageAutoEmailPopulator < GenericAdminMessagePopulator

  def patch(options = {})
    return if @options[:common]["flash_type"]
    admin_members = @program.admin_users.pluck(:member_id)
    @options[:admin_member] = admin_members.first
    member_ids = @program.users.active.pluck(:member_id) - admin_members
    admin_message_ids = @program.admin_messages.where(:campaign_message_id => nil, auto_email: true)
    admin_message_receivers_hsh = @program.admin_message_receivers.where(:message_id => admin_message_ids).pluck(:member_id).group_by{|x| x}
    process_patch(member_ids, admin_message_receivers_hsh) 
  end

  def add_admin_message_auto_emails(member_ids, count, options = {})
    add_admin_messages(member_ids, count, options.merge!({auto_email: true}))
  end

  def remove_admin_message_auto_emails(member_ids, count, options = {})
    remove_admin_messages(member_ids, count, options.merge!({auto_email: true}))
  end
end