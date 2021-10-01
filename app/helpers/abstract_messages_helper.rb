module AbstractMessagesHelper
  
  RECEIVERS_THRESHOLD = 10

  module FROM_TO_DETAILS
    MEMBERS_THRESHOLD = 4
    LENGTH_THRESHOLD = 25
    SEPARATOR = " .. "
    MORE_INDICATOR = ", ..."
    SENT_MESSAGES_THRESHOLD = 4
    MESSAGE_RECEIVERS_THRESHOLD = 4
    MEMBERS_PICTURES_THRESOLD = 4
  end

  module TruncateConstants
    SubjectLimit = 45
    ContentEnableLimit = 35
    ContentRemainingLength = 42
    ContentLimit = 45
  end

  def display_message_content(message)
    content_tag(:div, class: "clearfix") do
      sanitize(textilize(auto_link(message.content.html_safe)))
    end
  end

  def messages_tab_title(total_messages_count, tab)
    content = get_safe_string
    if tab == MessageConstants::Tabs::SENT
      icon_class = "fa-paper-plane-o"
      tab_header = "feature.messaging.tab.Sent_Items_v1".translate
    else
      icon_class = "fa-inbox"
      tab_header = "feature.messaging.tab.Inbox".translate
    end
    content += embed_icon("fa #{icon_class}")
    content += content_tag(:span, tab_header, class: "m-r-xxs")
    content << content_tag(:span, "(#{total_messages_count})", class: "cjs_messages_count")
    content
  end

  # Display the sender's list of the thread in inbox
  def get_from_details(message, viewer, options = {})
    details = { members: [], member_pictures: [], unread: {}, size: 0 }
    messages = collect_messages(message, options)
    is_preloaded = options[:from_scrap].present? && options[:preloaded].present?
    messages.each do |message|
      is_viewable = (is_preloaded ? message.can_be_viewed?(viewer, preloaded: true, has_receiver: options[:viewable_scraps_hash][message.id].present?, is_deleted: options[:deleted_scraps_hash][message.id].present?) : message.can_be_viewed?(viewer))
      if is_viewable
        sender_id_or_name = (message.sender_id || message.sender_name)
        details[:members] << (message.sender_id.nil? ? [sender_id_or_name] : [sender_id_or_name, get_from_name(message, viewer)])
        details[:member_pictures] << display_profile_pic(message, size: "21x21", :class=> "img-circle m-l-n-xs", :override_size => :tiny)
        details[:unread][sender_id_or_name] ||= (is_preloaded ? options[:unread_scraps_hash][message.id].present? : message.unread?(viewer))
        details[:size] += 1
      end
    end
    details[:members] = details[:members].uniq
    details[:member_pictures] = details[:member_pictures].uniq.compact

    from_names_size = 0
    has_unread = details[:unread].values.include?(true)
    essential_members = if details[:members].size >= FROM_TO_DETAILS::MEMBERS_THRESHOLD
      [details[:members][0], details[:members][-2], details[:members][-1]]
    else
      details[:members]
    end
    from_names = essential_members.collect do |member|
      from_name = member[1] || member[0]
      from_names_size += from_name.size
      if options[:from_scrap]
        from_name = content_tag(:span, from_name, :class => "font-600 cjs-from-name") if details[:unread][member[0]]
      else
        if details[:unread][member[0]]
          from_name = content_tag(:span, from_name, :class => "h5 font-600 m-b-0 m-t-0 cjs-from-name #{hidden_on_web}") +
                      content_tag(:span, from_name, :class => "font-600 cjs-from-name #{hidden_on_mobile}")
        end
      end
      from_name
    end
    from_details = if details[:members].size <= 2 || from_names_size <= FROM_TO_DETAILS::LENGTH_THRESHOLD
      safe_join(from_names, COMMON_SEPARATOR)
    elsif details[:members].size >= FROM_TO_DETAILS::MEMBERS_THRESHOLD
      get_safe_string + from_names[0] + FROM_TO_DETAILS::SEPARATOR + safe_join(from_names.last(2), COMMON_SEPARATOR)
    else
      get_safe_string + from_names[0] + FROM_TO_DETAILS::SEPARATOR + from_names[-1]
    end
    from_details += " (#{details[:size]})" if details[:size] > 1
    {names: from_details, unread: has_unread, pictures: details[:member_pictures]}
  end

  # Display the receiver's list of the thread in sent items
  def get_to_details(message, viewer, options = {})
    details = message.thread_receivers_details(viewer, options)
    first_sent_message = details[:first_sent_message]
    message_receivers = first_sent_message.present? ? first_sent_message.message_receivers.first(FROM_TO_DETAILS::MESSAGE_RECEIVERS_THRESHOLD) : []
    to_names = []

    if message_receivers.any?
      message_receivers.each do |message_receiver|
        to_names << if message_receiver.member_id.nil?
          message_receiver.email.nil? ? _Admin : message_receiver.name
        else
          message_receiver.member_id == viewer.id ? "display_string.me".translate : message_receiver.member.name
        end
      end
    else
      to_names << "feature.messaging.content.message_receiver_removed_user".translate
    end
    to_details = to_names.shift
    to_names.each do |to_name|
      if to_details.size + to_name.size > FROM_TO_DETAILS::LENGTH_THRESHOLD
        to_details += FROM_TO_DETAILS::MORE_INDICATOR
        break
      else
        to_details += (COMMON_SEPARATOR + to_name)
      end
    end
    to_details += " (#{details[:size]})" if details[:size] > 1
    {names: to_details, unread: details[:unread]}
  end

  # Display the from to names in messages#show page
  def message_from_to_names(message, viewing_member, options={}) 
    from_names = get_safe_string
    from_names += if message.is_a?(AdminMessage) && message.auto_email?
      _Admin
    elsif message.sender_id.nil?
      message.sender_email.present? ? get_safe_string + message.sender_name+ " <" + mail_to(message.sender_email) +">" : message.sender_name.to_s
    elsif message.sender_id == viewing_member.id
      "feature.messaging.content.Me".translate
    elsif message.for_organization? || message.viewer_and_sender_from_same_program?(viewing_member)
      link_to_user(message.sender, options)
    elsif message.is_a?(Scrap)
      get_safe_string + message.sender.name(:name_only => true)
    elsif message.for_program? && !message.viewer_and_sender_from_same_program?(viewing_member)
      get_safe_string + message.sender.name(:name_only => true) + " <" + mail_to(message.sender.email) + ">"
    else
      "feature.messaging.content.message_receiver_removed_user".translate
    end

    # Admin bulk messaging users should behave like 'bcc' for users.
    admin_to_user_for_non_admins = message.is_a?(AdminMessage) && !message.user_to_admin? && !message.is_member_admin_for_this_msg?(viewing_member)
    
    unless options[:skip_to_names]
      to_names = display_message_receivers(message, viewing_member, admin_to_user_for_non_admins, RECEIVERS_THRESHOLD)
      to_names << show_more_receivers_link(message) if (message.message_receivers.size > RECEIVERS_THRESHOLD && !admin_to_user_for_non_admins)
    else
      to_names = []
    end 
    {from: from_names, to: to_sentence_sanitize(to_names)}
  end

  def display_message_receivers(message, viewing_member, is_bcc = false, limit)
    if is_bcc
      ["feature.messaging.content.me".translate]
    else
      message_receivers = message.message_receivers.order(:id).includes(member: :users)
      if message_receivers.present?
        message_receivers = message_receivers.limit(limit) if limit.present?
        message_receivers.collect do |message_receiver|
          if message_receiver.member_id.nil?
            message_receiver.email.nil? ? _Admin : get_safe_string + (message_receiver.name) +" <" + mail_to(message_receiver.email) + ">"
          elsif message_receiver.member_id == viewing_member.id
            "feature.messaging.content.me".translate
          elsif message.for_organization? || message.viewer_and_receiver_from_same_program?(message_receiver.member, viewing_member)
            link_to_user(message_receiver.member)
          elsif message.is_a?(Scrap)
            get_safe_string + message_receiver.member.name(:name_only => true)
          elsif message.for_program? && message_receiver.member.present? && !message.viewer_and_receiver_from_same_program?(message_receiver.member, viewing_member)
            get_safe_string + message_receiver.member.name(:name_only => true) + " <" + mail_to(message_receiver.member.email) + ">"
          else
            "feature.messaging.content.message_receiver_removed_user".translate
          end
        end
      else
        ["feature.messaging.content.message_receiver_removed_user".translate]
      end
    end
  end

  def get_message_path(message, is_inbox = false, filters_params = {})
    if message.is_a?(Message)
      message_path(message, filters_params: filters_params, is_inbox: is_inbox)
    elsif message.is_a?(AdminMessage)
      admin_message_path(message, filters_params: filters_params, is_inbox: is_inbox, from_inbox: true)
    else
      scrap_path(message, root: message.program.root, filters_params: filters_params, is_inbox: is_inbox, from_inbox: true)
    end
  end

  def message_content_format(message)
    if message.has_rich_text_content?
      message.formatted_content
    else
      chronus_auto_link(message.content)
    end
  end

  def get_reply_path(reply, from_inbox = false)
    if reply.is_a?(Message)
      messages_path
    elsif reply.is_a?(AdminMessage)
      admin_messages_path(:root => reply.program.root, :from_inbox => from_inbox)
    else
      from_inbox ? scraps_path(:from_inbox => from_inbox) : scraps_path(format: :js)
    end
  end

  def display_profile_pic(message, image_options = {})
    message_sender = message.sender
    return image_tag(UserConstants::DEFAULT_PICTURE[:small], {:class => "img-circle m-b-xs"}.merge(image_options)) if (message_sender.nil? || (message.is_a?(AdminMessage) && message.auto_email?))
    profile_picture = message_sender.profile_picture
    if profile_picture.present? && !profile_picture.not_applicable?
      image_tag(message_sender.picture_url(:small), {:class => "img-circle m-b-xs"}.merge(image_options))
    else
      generate_block_with_initials(message_sender, image_options[:override_size] || :small, {:class => "img-circle m-b-xs"}.merge(image_options))
    end
  end

  def collapsible_message_users_filters(use_name_only_autocomplete = false)

    content = []
    %w(sender receiver).each_with_index do |sender_or_receiver, index|
      title = {"sender" => "feature.messaging.label.from".translate, "receiver" => "feature.messaging.label.to".translate}[sender_or_receiver]
      value = @messages_presenter.search_params_hash.present? ? (@messages_presenter.search_params_hash[sender_or_receiver.to_sym] || "") : ""
      content << profile_filter_wrapper(title, value.blank?, true, false) do
        message_user_field(sender_or_receiver, title, value, use_name_only_autocomplete)
      end
    end
    content << javascript_tag("MessageSearch.initializeMemberFilters();")
    safe_join(content, " ")
  end

  def self.get_message_url_for_notification(message, organization, options = {})
    if message.is_a?(Message)
      Rails.application.routes.url_helpers.message_url(message.get_root, {subdomain: organization.subdomain, is_inbox: true}.merge(options))
    elsif message.is_a?(AdminMessage)
      Rails.application.routes.url_helpers.admin_message_url(message.get_root, {subdomain: organization.subdomain, is_inbox: true}.merge(options))
    elsif message.is_group_message?
      group = message.ref_obj
      Rails.application.routes.url_helpers.group_scraps_url(group, {subdomain: organization.subdomain, root: group.program.root}.merge(options))
    else
      meeting = message.ref_obj
      current_occurrence_time = meeting.first_occurrence.to_s
      Rails.application.routes.url_helpers.meeting_scraps_url(meeting, {subdomain: organization.subdomain, root: meeting.program.root, :current_occurrence_time => current_occurrence_time}.merge(options))
    end
  end

  def preview_leaf_message_in_listing(leaf_message)
    strip_tags(leaf_message.content).gsub(/&[^;]+;/, '')
  end

  def get_reply_delete_buttons(message, viewing_member, preloaded_options = {}, other_options = {})
    buttons = "".html_safe
    if message.can_be_deleted?(viewing_member, preloaded_options)
      delete_text = "display_string.Delete".translate
      delete_button_attributes = { label: append_text_to_icon("fa fa-trash #{other_options[:icon_class]}", delete_text), url: other_options[:delete_action], data: { confirm: "common_text.confirmation.sure_to_delete_this".translate(title: "feature.messaging.content.message".translate)}, method: :delete, class: "cjs_delete_link", id: "delete_link_#{message.id}" }
      delete_button_attributes[:data][:remote] = true if other_options[:remote]
      buttons += dropdown_buttons_or_button([delete_button_attributes], dropdown_title: "", btn_class: "pull-right", btn_group_btn_class: "btn-sm btn-white #{ other_options[:additional_class] }", is_not_primary: true)
    end
    if message.can_be_replied?(viewing_member, preloaded_options)
      buttons += dropdown_buttons_or_button([{ label: get_icon_content("fa fa-reply #{other_options[:icon_class]}")+ set_screen_reader_only_content("display_string.Reply".translate), js: other_options[:reply_action], id: "reply_link_#{message.id}" }], btn_class: "cjs_reply_link pull-right", primary_btn_class: "btn-white btn-sm")
    end
    buttons
  end

  private

  def collect_messages(message, options={})
    if options[:siblings].present?
      options[:siblings]
    elsif options[:messages_scope].present? && !wob_member.is_admin? 
      options[:messages_scope].where(root_id: message.id)
    else
      message.tree
    end
  end

  def get_from_name(message, viewer)
    if message.is_a?(AdminMessage) && message.auto_email?
      _Admin
    elsif message.sender == viewer
      "display_string.me".translate
    elsif message.for_organization? || message.sender.present?
      message.sender.name
    else
      "feature.messaging.content.message_receiver_removed_user".translate
    end
  end

  def message_user_field(sender_or_receiver, title, value, use_name_only_autocomplete)
    right_addon =  {type: "btn", content: "display_string.Go".translate, btn_options: {:onclick => "return MessageSearch.applyFilters();", :class => 'btn btn-primary', type: "submit"}}

    link_to_function("display_string.Clear".translate, %Q[jQuery("#search_filters_#{sender_or_receiver}").val(""); MessageSearch.applyFilters();], :class => 'clear_filter hide', :id => "reset_filter_#{sender_or_receiver}") +
    content_tag(:div, class: "fields m-b-sm") do
      label_tag("search_filters[#{sender_or_receiver}]", title, for: "search_filters_#{sender_or_receiver}", class: "sr-only") +
      if use_name_only_autocomplete
        construct_input_group({}, right_addon) do
          text_field_tag("search_filters[#{sender_or_receiver}]", value, class: "form-control", id: "search_filters_#{sender_or_receiver}")
        end
      else
        text_field_tag_with_auto_complete("search_filters[#{sender_or_receiver}]", value, nil,
                      {class: "form-control", id: "search_filters_#{sender_or_receiver}", right_addon: right_addon},
                      {url: auto_complete_for_name_or_email_members_path(format: :json), param_name: "search", highlight: true})
      end
    end
  end

  def show_more_receivers_link(message)
    remaining_receivers_count = message.message_receivers.size - RECEIVERS_THRESHOLD
    link_text = "#{remaining_receivers_count} #{'display_string.more'.translate} #{'feature.admin_view.content.user'.translate(count: remaining_receivers_count)}"
    content_tag(:span, class: "cjs_more_receivers_#{message.id}") do
      link_to(link_text, "javascript:void(0)", class: "cjs_more_receivers_link_#{message.id}") +
      loc_loading(class: "m-r-md m-t-sm ", id: "loading_object", loader_class: "cjs-loading-more") +
      javascript_tag("Messages.showMoreReceivers('#{show_receivers_abstract_message_path(message, format: :js)}', #{message.id});")
    end
  end
end