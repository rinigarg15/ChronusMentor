class AdminMessagesFilterService < AbstractMessagesFilterService
  attr_reader :include_system_generated

  def initialize(search_filters_params, include_system_generated_param = false)
    initialize_include_system_generated_filter(include_system_generated_param)
    super(search_filters_params)
  end

  def inbox_messages_ids(wob_member, current_program_or_organization)
    received_root_ids = current_program_or_organization.received_admin_message_ids.pluck(:root_id).uniq
    get_ids_and_scope(received_root_ids, wob_member, current_program_or_organization)
  end

  def sent_messages_ids(wob_member, current_program_or_organization)
    sent_messages = current_program_or_organization.sent_admin_message_ids
    sent_root_ids = (@include_system_generated ? sent_messages : sent_messages.where(auto_email: false)).pluck(:root_id).uniq
    get_ids_and_scope(sent_root_ids, wob_member, current_program_or_organization)
  end

  private

  def get_ids_and_scope(root_ids, wob_member, current_program_or_organization)
    default_messages_scope = get_messages_scope(root_ids, wob_member, current_program_or_organization)
    filtered_root_ids = messages_ids_scope(default_messages_scope, wob_member: wob_member, current_program_or_organization: current_program_or_organization).pluck(:root_id).uniq
    default_messages_scope.where(root_id: filtered_root_ids).pluck(:id).uniq
  end

  ## Since a message can exist without message receivers, we are doing Left Outer Join.
  ## message_receivers.message_id IS NULL - needed because all the other conditions are on 'receivers' table.
  def get_messages_scope(root_ids, wob_member, current_program_or_organization)
    current_program_or_organization.admin_messages.
      joins("LEFT OUTER JOIN abstract_message_receivers ON abstract_message_receivers.message_id = messages.id").
      where("messages.root_id" => root_ids).
      where("abstract_message_receivers.message_id IS NULL OR
        (abstract_message_receivers.member_id = :member_id AND abstract_message_receivers.status != :status) OR
        (abstract_message_receivers.member_id IS NOT NULL OR abstract_message_receivers.email IS NOT NULL) OR
        (abstract_message_receivers.member_id IS NULL AND abstract_message_receivers.email IS NULL AND abstract_message_receivers.status != :status)",
        member_id: wob_member.id, status: AbstractMessageReceiver::Status::DELETED)
  end

  def initialize_include_system_generated_filter(include_system_generated_param)
    @include_system_generated = !!ActiveRecord::Type::Boolean.new.cast(include_system_generated_param)
  end

  ## Sender of auto messages are just randomly populated with some admin.
  def filter_by_sender(messages_scope, args)
    name_with_email = @search_params_hash[:sender]
    members_ids, email = member_filter_params(name_with_email, args[:current_program_or_organization])
    name_email_query_string = if email.present?
      "messages.sender_email = '#{email}'"
    else
      "messages.sender_name LIKE '%#{name_with_email}%'"
    end
    messages_scope = messages_scope.where(auto_email: false)
    if members_ids.present?
      messages_scope.where("messages.sender_id IN (?) OR #{name_email_query_string}", members_ids)
    else
      messages_scope.where("#{name_email_query_string}")
    end
  end

  def filter_by_receiver(messages_scope, args)
    name_with_email = @search_params_hash[:receiver]
    members_ids, email = member_filter_params(name_with_email, args[:current_program_or_organization])
    name_email_query_string = if email.present?
      "abstract_message_receivers.email = '#{email}'"
    else
      "abstract_message_receivers.name LIKE '%#{name_with_email}%'"
    end
    if members_ids.present?
      messages_scope.where("abstract_message_receivers.member_id IN (?) OR #{name_email_query_string}", members_ids)
    else
      messages_scope.where("#{name_email_query_string}")
    end
  end

  def member_filter_params(name_with_email, current_program_or_organization)
    members_ids = members(current_program_or_organization, name_with_email).pluck(:id)
    email = ValidatesEmailFormatOf::validate_email_format(name_with_email).nil? ? name_with_email : Member.extract_email_from_name_with_email(name_with_email)
    [members_ids, email]
  end

  def members(current_program_or_organization, name_with_email)
    organization = current_program_or_organization.is_a?(Program) ? current_program_or_organization.organization : current_program_or_organization
    Member.by_email_or_name(name_with_email, organization)
  end

  def filter_by_status_read(messages_scope, args)
    messages_scope.where("abstract_message_receivers.member_id = ? OR (abstract_message_receivers.member_id IS NULL AND abstract_message_receivers.email IS NULL)", args[:wob_member].id).
      group("abstract_message_receivers.message_root_id").
      having("SUM(IF(abstract_message_receivers.status = #{AbstractMessageReceiver::Status::UNREAD}, 1, 0)) = 0")
  end

  def filter_by_status_unread(messages_scope, args)
    messages_scope.where("abstract_message_receivers.member_id = ? OR (abstract_message_receivers.member_id IS NULL AND abstract_message_receivers.email IS NULL)", args[:wob_member].id).
      where("abstract_message_receivers.status = ?", AbstractMessageReceiver::Status::UNREAD)
  end

end