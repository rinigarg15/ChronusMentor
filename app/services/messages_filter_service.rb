class MessagesFilterService < AbstractMessagesFilterService

  def inbox_messages_ids(wob_member, current_organization)
    received_root_ids = wob_member.received_messages.pluck(:root_id)
    get_message_ids_and_scope(received_root_ids, wob_member, current_organization) 
  end

  def sent_messages_ids(wob_member, current_organization)
    sent_root_ids = wob_member.sent_messages.pluck(:root_id)
    get_message_ids_and_scope(sent_root_ids, wob_member, current_organization) 
  end

  private

  def get_message_ids_and_scope(root_ids, wob_member, current_organization)
    program_ids_with_admin_role = get_program_ids_with_admin_role(wob_member)
    default_messages_scope = get_messages_scope(root_ids, wob_member, current_organization, program_ids_with_admin_role)
    filtered_root_ids = messages_ids_scope(default_messages_scope, wob_member: wob_member, current_organization: current_organization, program_ids_with_admin_role: program_ids_with_admin_role).pluck(:root_id).uniq
    return default_messages_scope.where(root_id: filtered_root_ids).pluck(:id), default_messages_scope
  end

  def get_program_ids_with_admin_role(wob_member)
    program_ids = wob_member.administered_programs.collect(&:id)
    wob_member.admin? ? program_ids : (program_ids + [wob_member.organization_id])
  end

  ## Since a message can exist without message receivers, we are doing, Left Outer Join.
  ## Assume admin1 sends a admin message to admin2 and nonadmin; nonadmin replies to the message. This replied message is received message for admin2 also, so we include that message receiver also.
  ## Auto generated messages have sender set to some admin of program - those messages should be excluded in sent items.
  def get_messages_scope(root_ids, wob_member, current_organization, program_ids_with_admin_role)
    sent_non_auto_messages = "messages.sender_id = :member_id AND messages.auto_email = :auto_email"
    received_messages = "abstract_message_receivers.member_id = :member_id AND abstract_message_receivers.status != :status"
    other_received_admin_messages_in_thread = "messages.program_id IN (:program_ids) AND abstract_message_receivers.member_id IS NULL AND abstract_message_receivers.email IS NULL AND abstract_message_receivers.status != :status"

    AbstractMessage.joins("LEFT OUTER JOIN abstract_message_receivers ON abstract_message_receivers.message_id = messages.id").
      where("messages.root_id" => root_ids).
      where("(#{sent_non_auto_messages}) OR (#{received_messages}) OR (#{other_received_admin_messages_in_thread})", member_id: wob_member.id, auto_email: false, program_ids: program_ids_with_admin_role, status: AbstractMessageReceiver::Status::DELETED)
  end

  ## Excluding auto messages because an auto generated message's sender and receiver can be same even after get_messages_scope method been applied.
  def filter_by_sender(messages_scope, args)
    members_ids = members(args[:current_organization], @search_params_hash[:sender]).pluck(:id)
    messages_scope.where("messages.sender_id IN (?) AND messages.auto_email = ?", members_ids, false)
  end

  def filter_by_receiver(messages_scope, args)
    members_ids = members(args[:current_organization], @search_params_hash[:receiver]).pluck(:id)
    messages_scope.where("abstract_message_receivers.member_id IN (?)", members_ids)
  end

  def members(current_organization, name_with_email)
    Member.by_email_or_name(name_with_email, current_organization)
  end

  def filter_by_status_read(messages_scope, args)
    messages_scope.where("abstract_message_receivers.member_id = ? OR (messages.program_id IN (?) AND abstract_message_receivers.member_id IS NULL AND abstract_message_receivers.email IS NULL)", args[:wob_member].id, args[:program_ids_with_admin_role]).
      group("abstract_message_receivers.message_root_id").
      having("SUM(IF(abstract_message_receivers.status = #{AbstractMessageReceiver::Status::UNREAD}, 1, 0)) = 0")
  end

  def filter_by_status_unread(messages_scope, args)
    messages_scope.where("abstract_message_receivers.member_id = ? OR (messages.program_id IN (?) AND abstract_message_receivers.member_id IS NULL AND abstract_message_receivers.email IS NULL)", args[:wob_member].id, args[:program_ids_with_admin_role]).
      where("abstract_message_receivers.status = ?", AbstractMessageReceiver::Status::UNREAD)
  end

end