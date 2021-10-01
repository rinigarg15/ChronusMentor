class AbstractMessagesFilterService
  attr_reader :search_params_hash, :my_filters

  def initialize(search_filters_params)
    initialize_common_search_filters(search_filters_params)
    initialize_my_filters
  end

  def get_paginated_messages_hash(page, wob_member, messages_ids)
    paginated_filtered_messages = get_paginated_filtered_messages(page, messages_ids)
    total_entries = paginated_filtered_messages.empty? ? 0 : paginated_filtered_messages.total_entries
    return_value = {total_messages_count: total_entries, latest_messages: paginated_filtered_messages}
    messages_index = get_messages_index(paginated_filtered_messages)
    return_value.merge(
      messages_index: messages_index,
      messages_attachments: get_messages_attachments(wob_member, messages_index)
    )
  end

  private

  def messages_ids_scope(messages_scope, args)
    if @search_params_hash.present?
      messages_scope = filter_by_sender(messages_scope, args) if @search_params_hash[:sender].present?
      messages_scope = filter_by_receiver(messages_scope, args) if @search_params_hash[:receiver].present?
      messages_scope = filter_by_status(messages_scope, args) if @search_params_hash[:status].present?
      messages_scope = filter_by_date_range(messages_scope) if @search_params_hash[:date_range].present?
    end
    messages_scope
  end

  def filter_by_sender(default_messages_scope = nil, args = {})
    raise "Method must be defined in AbstractMessagesFilterService's inheritor"
  end

  def filter_by_receiver(default_messages_scope, args)
    raise "Method must be defined in AbstractMessagesFilterService's inheritor"
  end

  def filter_by_status(messages_scope, args)
    statuses = @search_params_hash[:status].values
    case statuses
    when [AbstractMessageReceiver::Status::READ.to_s]
      filter_by_status_read(messages_scope, args)
    when [AbstractMessageReceiver::Status::UNREAD.to_s]
      filter_by_status_unread(messages_scope, args)
    else
      messages_scope
    end
  end

  def filter_by_date_range(messages_scope)
    messages_scope.where("messages.created_at BETWEEN ? AND ?", @search_params_hash[:date_range][:start_time], @search_params_hash[:date_range][:end_time])
  end

  def get_paginated_filtered_messages(page, messages_ids)
    return [] unless messages_ids.present?
    results = AbstractMessage.get_filtered_messages_from_es(@search_params_hash[:search_content] || '', messages_ids)
    root_ids = results.response.aggregations.group_by_root_id.buckets.collect{|bucket| bucket[:key]}
    return [] unless root_ids.present?
    AbstractMessage.where(id: root_ids).order("FIELD(id, #{root_ids.join(",")})").paginate(page: page, per_page: AbstractMessage::PER_PAGE)
  end

  def get_messages_index(paginated_filtered_messages)
    message_root_ids = paginated_filtered_messages.map(&:root_id)
    AbstractMessage.where(id: message_root_ids).
      includes(:children, :message_receivers, sender: { users: :program }).
      index_by(&:id)
  end

  def get_messages_attachments(wob_member, messages_index)
    messages_index.values.inject({}) do |messages_attachments, message|
      messages_attachments[message.id] = message.sibling_has_attachment?(wob_member)
      messages_attachments
    end
  end

  def initialize_common_search_filters(search_filters_params)
    if search_filters_params.present?
      start_time, end_time = CommonFilterService.initialize_date_range_filter_params(search_filters_params[:date_range])
      @search_params_hash = {
        sender: search_filters_params[:sender],
        receiver: search_filters_params[:receiver],
        status: search_filters_params[:status],
        program_id: search_filters_params[:program_id],
        search_content: search_filters_params[:search_content]
      }
      @search_params_hash.merge!(date_range: { start_time: start_time, end_time: end_time } ) if start_time.present? && end_time.present?
    else
      @search_params_hash = {}
    end
  end

  def initialize_my_filters
    @my_filters = []
    if @search_params_hash
      @my_filters << {:label => "feature.messaging.label.from".translate, :reset_suffix => 'sender'} if @search_params_hash[:sender].present?
      @my_filters << {:label => "feature.messaging.label.to".translate, :reset_suffix => 'receiver'} if @search_params_hash[:receiver].present?
      @my_filters << {:label => "feature.messaging.label.status".translate, :reset_suffix => 'status'} if @search_params_hash[:status].present?
      @my_filters << {:label => "display_string.Program".translate, :reset_suffix => 'program'} if @search_params_hash[:program_id].present?
      @my_filters << {:label => "common_text.filter.label.date_range".translate, :reset_suffix => 'date_range'} if @search_params_hash[:date_range].present?
    end
  end

end