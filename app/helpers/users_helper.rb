module UsersHelper

  STATE_TO_FILTER_MAPPING = ActiveSupport::OrderedHash.new
  STATE_TO_FILTER_MAPPING[User::Status::PENDING] = "feature.user.filter.unpublished_profiles"
  STATE_TO_FILTER_MAPPING[User::Status::SUSPENDED] = "feature.user.filter.suspended_profiles_v1"

  STATE_TO_STRING_MAP = {
    User::Status::PENDING => "Unpublished",
    User::Status::SUSPENDED => "Suspended",
    User::Status::ACTIVE => "Active"
  }

  STATE_TO_INTEGER_MAP = {
    User::Status::ACTIVE => 0,
    User::Status::PENDING => 1,
    User::Status::SUSPENDED => 3
  }

  STATE_INTEGER_TO_STRING_MAP = STATE_TO_INTEGER_MAP.invert
  MAX_MENTORING_CONNECTION_MEMBERS_IN_PROFILE                            = 5
  MAX_PROJECT_MEMBERS_IN_HOME_PAGE_WIDGET                                = 3

  #
  # Link to user's page ('users/1')
  #
  # By default, their login is used as link text and link title (tooltip)
  #
  # Takes options
  # * :content_text => 'Content text in place of user.login', escaped with
  #   the standard h() function.
  # * :content_method => :user_instance_method_to_call_for_content_text
  # * :title_method => :user_instance_method_to_call_for_title_attribute
  # * :current_user => Returns You if the user is current_user
  # * :no_hovercard => controls the display of hovercard
  # * as well as link_to()'s standard options
  #
  # Examples:
  #   link_to_user current_user
  #   # => <a href="/users/3" title="barmy">barmy</a>
  #
  #   # if you've added a .name attribute:
  #  content_tag :span, :class => :vcard do
  #    (link_to_user user, :class => 'fn n', :title_method => :login, :content_method => :name) +
  #          ': ' + (content_tag :span, user.email, :class => 'email')
  #   end
  #   # => <span class="vcard"><a href="/users/3" title="barmy" class="fn n">Cyril Fotheringay-Phipps</a>: <span class="email">barmy@blandings.com</span></span>
  #
  #   link_to_user current_user, :content_text => 'Your user page'
  #   # => <a href="/users/3" title="barmy" class="nickname">Your user page</a>
  #
  def link_to_user(user, options={})
    raise "display_string.Invalid_user".translate unless user
    member = user.is_a?(User) ? user.member : user
    url_opts = options.delete(:params) || {}
    cur_user_passed = options.delete(:current_user)
    cur_user = cur_user_passed || current_user
    have_verb = options.delete(:verb)
    user_link = options.delete(:user_link)
    no_link = !!options.delete(:no_link)
    is_not_visible = options.delete(:is_not_visible)
    return (have_verb ? "display_string.You_are".translate : "display_string.You".translate) if cur_user_passed && (cur_user == user)
    # Anonymous view if the viewer does not have the permission to view
    # the +user+'s role.
    return "display_string.Anonymous".translate if is_not_visible || (cur_user && user.is_a?(User) && !user.visible_to?(cur_user))

    options.reverse_merge! :content_method => :name, :title_method => :name, :class => :nickname
    content_text = options.delete(:content_text)
    content_text ||= user.send(*options.delete(:content_method))

    display_content = h(content_text)
    user_obj = (cur_user && user.is_a?(Member)) ? member.users.find{|us| us.program_id == @current_program.id} : user
    user_link ||= member_path(member, url_opts)
    hide_hover = options[:no_hovercard] || !cur_user || !user_obj
    options[:title] ||= user.send(options.delete(:title_method)) if hide_hover
    link_or_text = no_link ? display_content : link_to(display_content, user_link, options)
    return_value = hide_hover ? link_or_text : construct_hovercard_container(user_obj, link_or_text, options[:group_view_id])
    return_value += (' ' + "display_string.is".translate) if have_verb && cur_user

    if options[:show_favorite_links] && cur_user != user
      favorite_link = render partial: "users/show_favorite_links", locals: {mentor_id: user.id, favorite_preferences_hash: options[:favorite_preferences_hash], src: url_opts[:src]} 
      return_value += content_tag(:span, favorite_link, class: "mentor_favorite_#{user.id} m-l-xs display-inline animated")
    end

    return return_value
  end

  def link_to_user_for_admin(user, options={})
    raise "feature.user.content.invalid_user".translate unless user
    options.reverse_merge! :content_method => :name, :class => :nickname
    content_text = options.delete(:content_text)
    content_text    ||= user.send(options.delete(:content_method))
    options[:title] ||= content_text
    url_opts = options.delete(:params) || {}
    user_link ||= member_path(user.member, url_opts)

    display_content = h(content_text)
    return_value = construct_hovercard_container(user, link_to(display_content, user_link, options))
    return return_value.html_safe
  end

  # We enable this for new records and when the admin is editing the profile of user who belongs to single program
  def disable_name_or_email_field(member, acting_member = wob_member)
    case
    when member.new_record? || (member == acting_member) || acting_member.admin?
      false
    when acting_member.is_admin?
      !check_admin_of_user_in_all_programs(member, acting_member)
    else
      false
    end
  end

  def check_admin_of_user_in_all_programs(member, acting_member)
    member.users.collect(&:program).each do |program|
      admin_user = program.admin_users.of_member(acting_member).first
      return false if !admin_user
    end
    return true
  end

  def status_indicator(user, options = {})
    return unless current_user

    states = []
    options.reverse_merge! :consider_user_as_student => false, :consider_user_as_mentor => false, :show_availability => false, :from_preferred_mentoring => false
    options[:show_availability] = false unless @current_program.career_based?

    states << get_user_status_based_label(user) if current_user.is_admin?

    if user.is_student? && options[:consider_user_as_student]
      states << status_indicator_for_pending_user if current_user.is_admin? && user.profile_incomplete_for?(RoleConstants::STUDENT_NAME, @current_program, {:required_questions => options[:student_required_questions]})
    end

    if user.is_mentor? && options[:consider_user_as_mentor]
      states << status_indicator_for_pending_user if current_user.is_admin? && user.profile_incomplete_for?(RoleConstants::MENTOR_NAME, @current_program, {:required_questions => options[:mentor_required_questions]})

      if options[:show_availability]
        if options[:from_preferred_mentoring]
          help_text = 'feature.user.content.tooltips.slots_preferred_html'.translate(User: user.name, connection_count: content_tag(:b, user.max_connections_limit), connection: content_tag(:b, pluralize_only_text(user.max_connections_limit, _mentoring_connection, _mentoring_connections)))
          help_text += 'feature.user.content.tooltips.slots_assigned_html'.translate(connection_count: content_tag(:b, user.filled_slots), connection: content_tag(:b, pluralize_only_text(user.filled_slots, _mentoring_connection, _mentoring_connections)))
          states << { content: "feature.user.content.status.slots_available".translate(count: user.slots_available), label_class: "label-default",
            options: { data: { toggle: "tooltip", title: help_text } } }
        end

        user_can_mentor = options[:mentors_with_slots].present? ? options[:mentors_with_slots].include?(user.id) : user.can_receive_mentoring_requests?
        unless user_can_mentor || current_user.is_mentor_only?
          states << status_indicator_for_unavailable_mentor
        end
      else
        groups = options[:mentor_groups_map] ? options[:mentor_groups_map][user] : Group.involving(current_user, user)
        if groups.present? && groups.any?(&:active?)
          states << { content: "feature.user.content.status.my_mentor_v1".translate(mentor: _mentor), label_class: "label-success" }
        end
      end
    end
    states.compact!
    options[:return_hash] ? states.uniq : labels_container(states.uniq, options[:wrapper_options] || {})
  end

  def drafted_connections_indicator(user, program, options = {})
    if current_user && current_user.is_admin? && program
      drafted_connections_count = options[:draft_count].present? ? options[:draft_count][user.id].to_i : user.groups.drafted.size
      unless drafted_connections_count.zero?
        url_params = {
          tab: MembersController::ShowTabs::MANAGE_CONNECTIONS,
          filter: GroupsController::StatusFilters::Code::DRAFTED
        }
        link_text = 'feature.user.content.drafted_connections'.translate(
          count: drafted_connections_count,
          connection: _mentoring_connection,
          connections: _mentoring_connections)
        return {
          content: link_to(link_text, member_path(user.member, url_params), class: "font-bold btn-link"),
          label: "label-default"
        }
      end
    end
  end

  def show_last_logged_in(profile_user, options = {}, &block)
    return unless current_user.try(&:is_admin?)

    last_login = profile_user.last_seen_at
    last_logged_in =
      if last_login
        if options[:no_format]
          last_login
        elsif options[:with_prefix]
          "feature.user.label.last_login_time".translate(time: formatted_time_in_words(last_login, no_ago: false))
        else
          formatted_time_in_words(last_login, no_ago: false)
        end
      else
        return if options[:no_placeholder]
        "feature.user.content.never_logged_in".translate
      end
    block.call(last_logged_in)
  end

  def mentor_links_in_container(user, mentors_list = nil)
    return unless current_user.is_admin?

    mentors = (mentors_list || user.mentors).collect {|mentor| link_to_user(mentor)}
    return if mentors.empty?
    content_tag(:div, profile_field_container(_Mentors, mentors.join(", ").html_safe, { class: "m-t-sm m-b-xs" } ), class: "m-b-sm")
  end

  def user_role_str(user)
    RoleConstants.human_role_string(user.role_names, :program => user.program, :no_capitalize => true, :articleize => true)
  end

  # Returns the page actions in the mentors listing page depending on the viewer
  def users_listing_page_actions(listing_viewer, role_name, program)
    actions = []
    if listing_viewer.present? && listing_viewer.is_admin?
      if (admin_view_type = AdminView::DefaultAdminView::ROLE_TO_TYPE_MAP[role_name]) && program.admin_views.where(default_view: admin_view_type).first.present?
        label_text = program.term_for(CustomizedTerm::TermType::ROLE_TERM, role_name).pluralized_term
        actions << {:label => "feature.user.label.Manage_role".translate(:role => label_text), :url => send("admin_view_#{role_name.pluralize}_path")}
      end
    end
    if role_name == RoleConstants::MENTOR_NAME
      actions += mentors_listing_page_actions(listing_viewer, program)
    else
      actions += role_listing_page_actions(listing_viewer, role_name, program)
    end

    return actions.flatten.compact
  end

  def mentors_listing_page_actions(listing_viewer, program)
    unless listing_viewer # if the user is not logged in
      if program.matching_by_mentee_and_admin? && program.allow_mentoring_requests?
        return [{:label => "feature.user.label.request_mentor".translate(:a_mentor => _a_mentor), :url => new_mentor_request_path, :title => "feature.user.content.signup_to_send_a_request_v1".translate(:mentor => _mentor)}]
      else
        return [program.allow_join_now? ? {:label => "feature.user.label.join_program".translate(:program => _Program), :url => new_membership_request_path} : nil]
      end
    end

    actions = role_listing_page_actions(listing_viewer, RoleConstants::MENTOR_NAME, program)

    if listing_viewer.student_of_moderated_groups?
      if program.allow_mentoring_requests?
        actions <<  {:label => "feature.user.action.request_connection".translate(:connection => _Mentoring_Connection), :url => new_mentor_request_path, :title => "feature.user.content.click_here_to_send_a_request_v1".translate(:mentor => _mentor)}
      else
        actions <<  {:label => "feature.user.action.request_a_mentor".translate(:a_mentor => _a_mentor), :disabled => true, :tooltip => flash_msg_for_not_allowing_mentoring_requests(program), :class => "btn btn-primary btn-large opacity-50"}
      end
    end
    return actions
  end

  def role_listing_page_actions(listing_viewer, role_name, program)
    return [] unless listing_viewer.present?
    actions = []
    role_term = program.term_for(CustomizedTerm::TermType::ROLE_TERM, role_name)
    if Permission.exists_with_name?("invite_#{role_name.pluralize}") && listing_viewer.send("can_invite_#{role_name.pluralize}?")
      actions << {:label => "feature.user.action.invite_role".translate(role: role_term.pluralized_term), :url => invite_users_path(:role => role_name, :from => current_user.role_names)}
    end
    if listing_viewer.can_add_non_admin_profiles?
      actions << {:label => "feature.user.action.add_user_directly".translate(role: role_term.pluralized_term), :url => new_user_path(:role => role_name)}
    end
    return actions
  end

  # Renders a profile completion tip, with a link and % increase in the profile
  #
  # ==== Params
  # <tt>link_name</tt> : This will be the string which will be displayed for the link
  # <tt>url</tt> : The url pointing to the edit location
  # <tt>max_value</tt> : Maximum value the item in profile can take
  # <tt>current_value</tt>: This is the current value
  #
  def profile_completion_tip(link_name, url, max_value, current_value)
    value = max_value - current_value
    return unless value > 0
    content = link_to(link_name, url)
    {content: content, value: value}
  end

  def unanswered_question_in_sidebar(profile_question, user, options = {})
    image = options[:image]
    profile_question_id = profile_question.try(:id)
    required = image ? false : profile_question.required_for(user.program, user.role_names)
    link_title = image ? ProfileCompletion::Name::IMAGE.call : profile_question.question_text
    content = link_to(link_title, options[:url], :class => 'cjs_not_applicable_question truncate-with-ellipsis whitespace-nowrap col-xs-8 no-padding')
    unless required
      content << content_tag(:span, link_to(content_tag(:span, "feature.profile_question.label.mark_not_applicable_v1".translate, class: "small pull-right"), "javascript:void(0)", :class => 'cjs_skip text-muted', :'data-question-id' => profile_question_id, :'data-url' => skip_answer_member_path(user.member, :question_id => profile_question_id, :home_page => options[:home_page], :profile_picture => image, :format => :js)), :class => "col-xs-4 no-padding")
      content << content_tag(:span, link_to(content_tag(:span, 'display_string.Undo'.translate, class: "small pull-right"), "javascript:void(0)", :class => 'cjs_undo_skip hide', :'data-question-id' =>profile_question_id), :class => "col-xs-4 no-padding")
    end

    content_tag(:li, content, :class => "cjs_hover_toggle list-group-item no-horizontal-padding clearfix", :id => "not_applicable_item_#{profile_question_id}")
  end

  # Renders a text based filter field for the given <i>field_name</i> and
  # default text as <i>default_text</i>
  def filter_text_field(field_name, default_text, options = {})
    field_code = text_field_tag(
      field_name, default_text, {
        :onclick => "clearDefaultText(this, '#{default_text}')",
        :onblur => "setDefaultText(this, '#{default_text}')",
        :onfocus => "clearDefaultText(this, '#{default_text}')"
      }.merge(options)
    )

    field_code << javascript_tag("MentorSearch.registerTextFilter('#{sanitize_to_id(field_name)}', '#{default_text}')")
  end

  def title_for_user_actions_dropdown(show_connect)
    show_connect ? "feature.user.label.Connect".translate : "display_string.Actions".translate
  end

  def actions_for_mentees_listing(profile_viewer, profile_user, options = {})
    return [[], ""] if profile_viewer == profile_user

    actions = []
    if @current_program.ongoing_mentoring_enabled? && !profile_user.suspended? && options[:viewer_can_find_mentor] && !options[:students_with_no_limit][profile_user.id]
      actions << {:label => append_text_to_icon("fa fa-users", "feature.user.label.find_mentor".translate(:a_mentor => _a_Mentor)), :url => matches_for_student_users_path(:student_name => profile_user.name_with_email, :src => "students_listing") }
    end

    if options[:mentee_groups_map] && options[:mentee_groups_map][profile_user].present?
      groups = options[:mentee_groups_map][profile_user]
      actions += group_links_hash(groups, "mentees_listing")
    elsif options[:offer_pending] && options[:offer_pending][profile_user.id]
      actions << {:label => append_text_to_icon("fa fa-user-plus", "feature.user.label.mentoring_offer_pending".translate), :url => "javascript:void(0);", :disabled => true}
    elsif @current_program.ongoing_mentoring_enabled? && options[:viewer_can_offer] && !options[:students_with_no_limit][profile_user.id] && profile_viewer.opting_for_ongoing_mentoring?
      offer_mentoring_options = {:label => append_text_to_icon("fa fa-user-plus", "feature.user.action.offer_mentoring_v1".translate(:Mentoring => _Mentoring)),
        :js => (%Q[OfferMentoring.renderPopup('#{new_mentor_offer_path(student_id: profile_user.id, src: options[:analytics_param])}')]).html_safe}
      offer_mentoring_options.merge!(disabled: true) if (@connection_request_sender_ids && @connection_request_sender_ids.count(profile_user.id) > 0)
      actions << offer_mentoring_options
    end

    if show_send_message_link?(profile_user, profile_viewer)
      actions << { :label => append_text_to_icon("fa fa-envelope", "feature.user.label.send_message".translate) }.merge(get_send_message_link(profile_user, profile_viewer, :receiver_id => profile_user.member.id, src: EngagementIndex::Src::MessageUsers::USER_LISTING_PAGE, :listing_page => true))
    end

    dropdown_title = title_for_user_actions_dropdown(profile_user.is_student? && profile_viewer.is_mentor?)
    return [actions.flatten, dropdown_title]
  end

  def display_match_score(match_score, options = {})
    tooltip = { "data-title" => match_score_tool_tip(match_score, options[:tooltip_options] || {}), "data-toggle" => "tooltip" }
    mentor_ignored = options[:tooltip_options][:mentor_ignored] if options[:tooltip_options].present?
    favorite_ignore_links = options[:show_favorite_ignore_links] && !options[:from_quick_connect] ? render_show_favorite_links(options) + render_ignore_preference_link(options) : get_safe_string 

    score_class = "no-margins #{match_score.present? && !match_score.zero? && !options[:from_quick_connect] ? 'text-navy' : options[:match_score_color_class].to_s} #{options[:class_name]} #{'cui_display_inline' if options[:from_quick_connect]}"

    score_label = "#{match_score_label(match_score, false, mentor_ignored)}"
    score_content = content_tag(:span, { class: "#{"text-muted" if mentor_ignored} ct-match-percent" }.merge(tooltip)) do
      (match_score.blank? || match_score.zero?) ? score_label : "feature.meetings.content.match_score_html".translate(:match_score => content_tag(:span, score_label, class: "#{'h5 font-600' if options[:from_quick_connect]}").html_safe)
    end + favorite_ignore_links
    options[:from_quick_connect] ? content_tag(:span, score_content, class: score_class) : content_tag(:h4, score_content, class: score_class)
  end

  def render_show_favorite_links(options={})
    content_tag(:span, class: "pull-left animated mentor_favorite_#{options[:mentor_id]} #{options[:from_quick_connect] ? 'm-l-sm' : ''}") do
      render partial: "users/show_favorite_links", locals: {mentor_id: options[:mentor_id], favorite_preferences_hash: options[:favorite_preferences_hash], src: options[:src]} 
    end
  end

  def render_ignore_preference_link(options={})
    content_tag(:div, class: "pull-right #{'m-r-sm' unless options[:from_quick_connect]} m-l-sm mentor_ignore_#{options[:mentor_id]} text-muted") do
      render partial: "users/show_ignore_links", locals: {mentor_id: options[:mentor_id], ignore_preferences_hash: {}, recommendations_view: options[:recommendations_view], show_match_config_matches: options[:show_match_config_matches]} 
    end
  end

  def render_ignore_preference_dropdown(options={})
    dropdown_title = get_icon_content('fa fa-ellipsis-h fa-fw fa-lg text-white') + content_tag(:span, "display_string.Close".translate, class: "sr-only")
    actions = []
    actions << { label: "common_text.dont_show_again".translate, url: "javascript:void(0)", additional_class: "cjs_create_ignore_preference", title: "common_text.dont_show_again".translate, data: {url: get_ignore_preference_url(false, {preference_marked_user_id: options[:mentor_id], recommendations_view: options[:recommendations_view] ,show_match_config_matches: options[:show_match_config_matches]}) }}
    build_dropdown_filters_without_button(dropdown_title, actions, btn_group_class: 'pull-right m-l-xs', font_class: 'text-default cui_quick_connect_no_border_link', without_caret: true)
  end

  def show_compatibility_link?(can_see_match_label, show_match_details, match_score)
    can_see_match_label && show_match_details && !(match_score.blank? || match_score.zero?)
  end

  def actions_for_mentor_listing(profile_viewer, profile_user, options = {})
    return [[], ""] if profile_viewer == profile_user

    actions = []
    show_connect = false
    options.reverse_merge!(student_can_connect_to_mentor: true)

    if profile_viewer.is_student?
      show_connect = true
      groups = options[:mentor_groups_map] ? options[:mentor_groups_map][profile_user] : Group.involving(profile_viewer, profile_user)
      actions += group_links_hash(groups, "mentors_listing")

      request_mentoring_action_options = { prevent_zero_match_connection: !options[:student_can_connect_to_mentor], is_connected_already: groups.present? }
      request_mentoring_action_options.merge!(options.pick(:user_favorite, :mentors_with_slots, :active_received_requests, :analytics_param))
      request_mentoring_action = get_request_mentoring_action_hash(profile_viewer, profile_user, request_mentoring_action_options)
      actions << request_mentoring_action if request_mentoring_action.present?

      request_meeting_action_options = { prevent_zero_match_connection: !options[:student_can_connect_to_mentor], :analytics_param => options[:analytics_param] }
      request_meeting_action = get_request_meeting_action_hash(profile_viewer, profile_user, request_meeting_action_options)
      actions << request_meeting_action if request_meeting_action.present?
    end

    if show_send_message_link?(profile_user, profile_viewer)
      actions << {
        label: append_text_to_icon("fa fa-envelope", "feature.user.label.send_message".translate)
      }.merge(get_send_message_link(profile_user, profile_viewer, receiver_id: profile_user.member_id, src: EngagementIndex::Src::MessageUsers::USER_LISTING_PAGE, listing_page: true))
    end

    dropdown_title = title_for_user_actions_dropdown(profile_viewer && show_connect)
    return [actions.flatten, dropdown_title]
  end

  def actions_for_other_non_administrative_user_listing(profile_viewer, profile_user, options = {})
    return [[], ""] if profile_viewer == profile_user

    actions = []
    actions << {:label => append_text_to_icon("fa fa-envelope", "display_string.Send_Message".translate)}.merge(get_send_message_link(profile_user, profile_viewer, :receiver_id => profile_user.member.id, src: EngagementIndex::Src::MessageUsers::USER_LISTING_PAGE, :listing_page => true)) if show_send_message_link?(profile_user, profile_viewer)

    dropdown_title = "display_string.Actions".translate
    return [actions.flatten, dropdown_title]
  end

  def get_request_mentoring_action_hash(profile_viewer, profile_user, options = {})
    action_hash = {}
    options.reverse_merge!(
      is_connected_already: false,
      prevent_zero_match_connection: nil,
      user_favorite: nil,
      mentors_with_slots: nil,
      active_received_requests: nil,
      no_slots_available: nil,
      pending_request_id: nil,
      analytics_param: nil,
      skip_icons: false
    )

    return {} unless profile_viewer.is_student? && profile_user.is_mentor?

    if @current_program.only_career_based_ongoing_mentoring_enabled? && profile_viewer.can_send_mentor_request?
      if @current_program.matching_by_mentee_and_admin_with_preference? && options[:user_favorite].nil?
        action_hash[:label] ="feature.preferred_mentoring.action.add_to_list".translate(mentors: _mentors)
      elsif @current_program.matching_by_mentee_alone? && !options[:is_connected_already]
        action_hash[:label] ="feature.user.label.request_mentoring_v1".translate(Mentoring_Connection: _Mentoring_Connection)
      else
        return {}
      end

      if options[:prevent_zero_match_connection].nil?
        options[:prevent_zero_match_connection] = !profile_viewer.can_connect_to_mentor?(profile_user)
      end
      if options[:no_slots_available].nil?
        options[:no_slots_available] = !(options[:mentors_with_slots].present? ? options[:mentors_with_slots].include?(profile_user.id) : profile_user.can_receive_mentoring_requests?)
      end
      if options[:pending_request_id].nil?
        options[:pending_request_id] = (options[:active_received_requests].nil? ? profile_user.received_mentor_requests.from_student(profile_viewer).active.first.try(:id) : options[:active_received_requests][profile_user.id])
      end

      if options[:pending_request_id]
        action_hash[:label] = "feature.user.label.view_your_pending_request".translate
        action_hash[:url] = mentor_requests_path(mentor_request_id: options[:pending_request_id], filter: AbstractRequest::Filter::BY_ME, src: options[:analytics_param])
      elsif !profile_user.opting_for_ongoing_mentoring?
        action_hash[:disabled] = true
        action_hash[:tooltip] = tooltip_double_escape("feature.user.label.mentor_does_not_allow_ongoing_mentoring_v1".translate(Mentor: _Mentor, mentoring: _mentoring))
      elsif !@current_program.allow_mentoring_requests?
        action_hash[:disabled] = true
        action_hash[:tooltip] = tooltip_double_escape(flash_msg_for_not_allowing_mentoring_requests(@current_program))
      elsif @current_program.matching_by_mentee_and_admin_with_preference?
        action_hash = add_favorite_action_hash(profile_user)
      elsif @current_program.matching_by_mentee_alone?
        if options[:prevent_zero_match_connection]
          action_hash[:disabled] = true
          action_hash[:tooltip] = tooltip_double_escape(@current_program.zero_match_score_message)
        elsif options[:no_slots_available]
          action_hash[:disabled] = true
          action_hash[:tooltip] = tooltip_double_escape("feature.user.label.mentor_has_no_slots_available".translate(Mentor: _Mentor, mentoring: _mentoring, mentoring_connection: _mentoring_connection))
        elsif options[:analytics_param] == EngagementIndex::Src::SendRequestOrOffers::QUICK_CONNECT_BOX && !(profile_viewer.connection_limit_as_mentee_reached? || profile_viewer.pending_request_limit_reached_for_mentee?)
          # Connection limit and pending requests limit checks are handled in MentorRequestsController; so simply redirecting there
          action_hash[:url] = "javascript:void(0)"
          action_hash[:additional_class] = "cjs_home_quick_connect_button"
          action_hash[:title] = "feature.user.label.request_mentoring_v1".translate(Mentoring_Connection: _Mentoring_Connection)
          action_hash[:data] = { url: new_mentor_request_path(mentor_id: profile_user.id, format: :js, src: options[:analytics_param]) }
        else
          action_hash[:url] = "javascript:void(0)"
          action_hash[:additional_class] = "cjs_request_mentoring_button #{AbstractRequest::MENTOR_REQUEST}"
          action_hash[:data] = { url: new_mentor_request_path(mentor_id: profile_user.id, format: :js, src: options[:analytics_param]) }
        end
      end
    end

    if !options[:skip_icons] && action_hash[:label].present?
      action_hash[:label] = action_hash[:disabled] ? append_text_to_icon("fa fa-ban", action_hash[:label]) : append_text_to_icon("fa fa-user-plus", action_hash[:label])
    end
    return action_hash
  end

  def get_request_meeting_action_hash(profile_viewer, profile_user, options = {})
    action_hash = {}
    options.reverse_merge!(
      analytics_param: nil,
      prevent_zero_match_connection: nil,
      skip_icons: false
    )

    return {} unless profile_viewer.is_student? && profile_user.is_mentor?

    if options[:prevent_zero_match_connection].nil?
      options[:prevent_zero_match_connection] = !profile_viewer.can_connect_to_mentor?(profile_user)
    end

    if @current_program.calendar_enabled? && profile_viewer.can_view_mentoring_calendar?
      action_hash[:label] = "feature.user.label.request_meeting_v1".translate(Meeting: _Meeting)
      if !profile_user.opting_for_one_time_mentoring?
        action_hash[:disabled] = true
        action_hash[:tooltip] = tooltip_double_escape("feature.user.label.mentor_does_not_allow_onetime_meeting_v1".translate(Mentor: _Mentor, meetings: _meetings, mentor: _mentor, mentoring: _mentoring))
      elsif options[:prevent_zero_match_connection]
        action_hash[:disabled] = true
        action_hash[:tooltip] = tooltip_double_escape(@current_program.zero_match_score_message)
      elsif (capacity_reached = profile_user.is_capacity_reached_for_current_and_next_month?(Time.now.in_time_zone(profile_viewer.member.get_valid_time_zone), profile_viewer, {error_message: true}))[0]
        action_hash[:disabled] = true
        action_hash[:tooltip] = tooltip_double_escape(capacity_reached[1])
      elsif options[:analytics_param] == EngagementIndex::Src::SendRequestOrOffers::QUICK_CONNECT_BOX
        action_hash[:url] = "javascript:void(0)"
        action_hash[:additional_class] = "cjs_home_quick_connect_button"
        action_hash[:title] = "feature.user.label.request_meeting_v1".translate(Meeting: _Meeting)
        action_hash[:data] = { url: mini_popup_meetings_path(member_id: profile_user.member_id, src: options[:analytics_param]) }
      else
        action_hash[:js] = %Q[Meetings.renderMiniPopup('#{mini_popup_meetings_path(member_id: profile_user.member_id, src: options[:analytics_param])}')]
        action_hash[:additional_class] = " #{AbstractRequest::MEETING_REQUEST}"
      end
    end

    if !options[:skip_icons] && action_hash[:label].present?
      action_hash[:label] = action_hash[:disabled] ? append_text_to_icon("fa fa-ban", action_hash[:label]) : append_text_to_icon("fa fa-calendar", action_hash[:label])
    end
    return action_hash
  end

  def remove_user_prompt(user)
    connection_content = remove_user_prompt_connections_part(user, :active) || "".html_safe
    connection_content += remove_user_prompt_connections_part(user, :closed) || "".html_safe
    contributions_content = remove_user_prompt_contributions_part(user)

    groups_any = !connection_content.blank?
    contributions_any = !contributions_content.blank?

    if user.suspended?
      display_message = "feature.profile.content.remove_user_cannot_suspend".translate(user_name: user.name, program: @current_organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term_downcase)
      show_suspend_message = false
    else
      display_message = "feature.profile.content.remove_user_v2".translate(user_name: user.name, program: @current_organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term_downcase)
      show_suspend_message = true
    end

    content = content_tag(:div, :class => "help_text") do
      display_message
    end
    return [content, show_suspend_message]
  end

  # Displays the flash message to active users who need to fill some required
  # questions.
  def update_profile_message(user)
    ProfileQuestion.unscoped do
      Section.unscoped do
        profile_incomplete_roles = user.profile_incomplete_roles

        if profile_incomplete_roles.any?
          render(
            :partial => "programs/profile_update_notification",
            :locals => {:profile_incomplete_roles => profile_incomplete_roles})
        end
      end
    end
  end

  def status_filter_links_ajax(filter_fields, applied_filter, show_calendar_filter, options = {})
    options.reverse_merge!({show_as_radio: false})
    content = "".html_safe
    mentor_fields = (@role == RoleConstants::MENTOR_NAME)
    expanded_sections = []
    @initialize_filter_fields_js ||= []
    filter_fields.each do |filter_field|

      if show_calendar_filter && is_calendar_filter?(filter_field)
        is_calendar_range_filter = true
        content << hidden_field_tag(:calendar_availability_default, @calendar_availability_default)
      end

      is_long_term_availability_filter = show_calendar_filter && is_long_term_availability_filter?(filter_field)

      div_content = content_tag :label, :class => "choice_item status_filters #{show_calendar_filter && options[:show_as_radio] ? "radio" : "checkbox"}" do
        cb_id = "filter_#{filter_field[:class]}"
        on_click_function = is_calendar_range_filter || is_long_term_availability_filter ? "MentorSearch.handleAvailabilityFilter('#{filter_field[:class]}');" : "BBQPlugin.toggleStatusFilter('#{filter_field[:class]}');"
        options_hash = {:id => cb_id, :onclick => on_click_function, :class => "profile_checkbox #{filter_field[:class]} #{options[:ei_class]}", data: {activity: options[:activity]}}

        element_content = send(show_calendar_filter && options[:show_as_radio] ? "radio_button_tag" : "check_box_tag", "filter#{'[]' if mentor_fields}", filter_field[:value], false, options_hash)

        label_id = "#{cb_id}_label"
        label_class = "".html_safe
        label_class << " ttip" if filter_field[:tool_tip]
        label_content = h(filter_field[:label])
        label_content << tooltip(label_id, filter_field[:tool_tip]) if filter_field[:tool_tip]

        element_content << content_tag(:div, :class => label_class, :id => label_id) {label_content}

        if applied_filter && applied_filter.include?(filter_field[:value])
          expanded_sections << filter_field[:section]
          @initialize_filter_fields_js << filter_field[:js]
          element_content << javascript_tag(%Q[jQuery('##{cb_id}').prop('checked', true);])
        end
        element_content
      end

      content << div_content
    end
    expanded_sections = expanded_sections.compact.uniq
    @initialize_filter_fields_js.unshift("ChronusEffect.ExpandSection(#{expanded_sections.first.to_json}, #{(expanded_sections[1, -1] || []).to_json})") unless expanded_sections.blank?
    @initialize_filter_fields_js.compact!
    content
  end

  def render_user_bottom_pagination(items_per_page, users, user_ids, filter_field, user_references, view_params, path)
    if current_user && current_user.is_admin?
      per_page_options = {
        page_url: path,
        current_number: items_per_page,
        url_params: { filter: filter_field }.merge(view_params),
        use_ajax: true
      }
    end
    pagination_options = { collection: user_ids }
    bottom_bar_in_listing(pagination_options, per_page_options)
  end

  def name_with_id(user_ids)
    output = []
    user_ids.each do |user_id|
      user = User.find(user_id)
      link = member_path(user.member)
      content = content_tag(:span, user.member.name(:name_only => true), "data-userid".to_sym => user.member.id, "data-memberlink".to_sym => link)
      output << content
    end
    return output
  end

  def calendar_specific_filters(user, mentoring_calendar = false)
    filter_options = [
      {:value => UsersIndexFilters::Values::CALENDAR_AVAILABILITY, :label => "feature.user.filter.available_for_meeting_v2_html".translate(:meeting => _meeting, time_period_text_html: "<br/><span class='text-muted small'>#{get_current_and_next_month_text(user.member)}</span>".html_safe), :class => 'available_for_a_meeting'}
    ]
    if @current_program.ongoing_mentoring_enabled? && !mentoring_calendar && (user.can_send_mentor_request? || user.is_admin?)
      filter_options << {:value => UsersIndexFilters::Values::AVAILABLE, :label => "feature.user.filter.long_term_availability_v2".translate(:mentoring_connection => _mentoring_connection), :class => 'long_term_availability'
      }
    end
    filter_options.map{|o| o.merge(section: "#{_mentor}_availability_")}
  end

  def populate_sort_options(user, options ={})
    sort_fields = [
      {:field => "name", :order => :asc, :label => "feature.user.label.name_asc".translate},
      {:field => "name", :order => :desc, :label => "feature.user.label.name_desc".translate},
      {:field => "created_at", :order => :asc, :label => "feature.user.label.recently_joined_asc".translate},
      {:field => "created_at", :order => :desc, :label => "feature.user.label.recently_joined_desc".translate}
    ]
    sort_fields << { :field => UserSearch::SortParam::RELEVANCE, :label => "feature.user.label.relevance".translate } if options[:is_relevance_view]
    
    populate_sort_options_for_match_view(user, sort_fields) if options[:is_match_view]
    
    if user && user.is_admin?
      sort_fields << {:field => "last_seen_at", :order => :asc, :label => "feature.user.label.recently_logged_in_asc".translate}
      sort_fields << {:field => "last_seen_at", :order => :desc, :label => "feature.user.label.recently_logged_in_desc".translate}
    end
    return sort_fields
  end

  def populate_sort_options_for_match_view(user, sort_fields)
    if user.explicit_preferences_configured?
      sort_fields << {:field => UserSearch::SortParam::PREFERENCE, :order => :desc, :label => "feature.user.label.preference".translate}
    else
      sort_fields << {:field => :match, :order => :asc, :label => "feature.user.label.match_asc".translate}
      sort_fields << {:field => :match, :order => :desc, :label => "feature.user.label.match_desc".translate}
    end
  end

  def get_add_member_bulk_actions_box
    bulk_actions = [
      {
        :label => get_icon_content("fa fa-plus") + "feature.member.action.Add_to_Program".translate(:program => _Program),
        :id => "cjs_add_to_program",
        :url => "#",
        :data => { :url => bulk_confirmation_view_users_path }
      }
    ]

    build_dropdown_button("display_string.Actions".translate, bulk_actions, :btn_group_btn_class => "btn btn-white", :btn_class => "m-r cur_page_info pagination_search_and_filters text-primary", :is_not_primary => true)
  end

  def get_collapsible_filter_for_programs(programs, filter_options)
    profile_filter_wrapper _Program + "/" + "feature.member.label.role".translate, false, false, true, {:modern_filter => true, :pane_footer_content_class => 'scroll-4', :id => 'programs', ignore_role_group: true} do
      content = "".html_safe

      role_should_be_checked = filter_options[:role].present? && filter_options[:role].include?(MembersHelper.state_to_string_map[Member::Status::DORMANT])
      label = content_tag(:b, "feature.user.label.dormant_users".translate)

      content += choices_wrapper("feature.user.label.dormant_users".translate) do
        content_tag(:label, :class => 'checkbox') do
          check_box_tag("filter_role[]", MembersHelper.state_to_string_map[Member::Status::DORMANT], role_should_be_checked, :class => "filter_role cjs_filter_dormant_role cjs_reset_program_role_filter") + label
        end + content_tag(:hr, "", :class => "m-b-xs m-t-xs")
      end

      programs.each do |program|
        if @current_program != program
          program_roles = program.roles.select("id, name")
          program_should_be_checked = (filter_options[:program_id].present? ? (filter_options[:program_id] == program.id) : false)
          label = program_should_be_checked ? content_tag(:b, program.name) : program.name
          content += choices_wrapper(program.name) do
            content_tag(:label, :class => 'checkbox block p-t-sm font-bold') do
              check_box_tag("filter_program_id[]", program.id, program_should_be_checked, :class => "filter_program cjs_filter_program cjs_reset_program_role_filter", :id => "filter_program_id_#{program.id}") + label
            end
          end

          role_content = "".html_safe
          program_roles.each_with_index do |role, index|
            role_should_be_checked = filter_options[:role] && filter_options[:role].include?(role.id.to_s)
            label = program.term_for(CustomizedTerm::TermType::ROLE_TERM, role.name).term

            role_content += content_tag(:label, :class => "checkbox inline-block m-l-md") do
              check_box_tag("filter_role[]", role.id, role_should_be_checked, :class => "filter_role cjs_filter_role cjs_program_roles_#{program.id} cjs_reset_program_role_filter", :id => "filter_role_#{role.id}", 'data-program' => program.id) + label
            end
          end
          content += choices_wrapper("display_string.Roles".translate) {role_content}
        end
      end

      content += link_to("display_string.reset".translate, "#", :id => "reset_filter_program_role", :class => "hide reset_filters", :remote => true)

      content
    end
  end

  def get_columns(sort_options)
    columns = UserService::AddMemberFromProgram::ColumnSort.keys
    header_th = "".html_safe
    columns.each do |column|
      order = sort_options[:column] == column ? sort_options[:order] : "both"
      html_options = {
        :class => "sort_#{order} pointer cjs_sortable_element",
        :id => "sort_by_#{column}",
        :data => {
          :sort_param => column,
          :url => new_from_other_program_users_path
        },
        :nowrap => ""
      }
      header_th += content_tag(:th, content_tag(:span, "feature.member.content.add_from_program.column_title.#{column}".translate, :class => "pull-left"), html_options)
    end
    header_th
  end

  def populate_user_row(member)
    td_text = "".html_safe
    ["first_name", "last_name"].each do |column|
      td_text << content_tag(:td, member.send(column), :nowrap => "")
    end
    td_text << content_tag(:td, member.email, :nowrap => "")
    td_text
  end

  # For display in users' listing page and hovercards
  def display_profile_summary(user, in_summary_questions, show_in_hovercard = false)
    summary_pane = "".html_safe
    all_answers = user.member.profile_answers.group_by(&:profile_question_id)
    in_summary_profile_questions = in_summary_questions.select{|q| q.visible_listing_page?(current_user, user)}.collect(&:profile_question).uniq
    in_summary_profile_questions = ProfileQuestion.sort_listing_page_filters(in_summary_profile_questions)
    if show_in_hovercard
      profile_summary_in_hovercard = display_profile_summary_in_hovercard(user, in_summary_profile_questions, all_answers)
      summary_pane += content_tag(:div, profile_summary_in_hovercard, :class => "form-horizontal") if profile_summary_in_hovercard.present?
    else
      in_summary_profile_questions.each do |question|
        next unless question.conditional_text_matches?(all_answers)
        summary_pane << content_tag(:div, profile_field_container(question.question_text, fetch_formatted_profile_answers(user, question, all_answers, true), { class: "m-t-sm m-b-xs" } ), :class => "m-b")
      end
    end
    summary_pane
  end

  def display_profile_summary_in_hovercard(user, in_summary_profile_questions, all_answers)
    content = "".html_safe
    in_summary_profile_questions.each do |question|
      next unless question.conditional_text_matches?(all_answers) && all_answers[question.id].present?
      content += control_group(:class => "m-b-xs") do
        content_tag(:label, question.question_text, :valign => "top", :class => "col-sm-3 text-right m-b-0 m-t-xxs h6 font-600 word_break") +
        content_tag(:div, fetch_formatted_profile_answers(user, question, all_answers, true), :class => "col-sm-9")
      end
    end
    content
  end

  def get_hovercard_actions(profile_viewer, profile_user, viewing_group)
    return if profile_viewer == profile_user
    not_self_view = (profile_viewer != profile_user)
    actions = []
    # Send Message
    if show_send_message_link?(profile_user, profile_viewer)
      actions << link_to("feature.user.label.Message".translate, get_send_message_link(profile_user, profile_viewer, receiver_id: profile_user.member_id, src: EngagementIndex::Src::MessageUsers::HOVERCARD))
    end
    # Skype
    if @current_program.organization.skype_enabled? && viewing_group
      actions << link_to("feature.user.label.Skype".translate, "skype:" + profile_user.skype_id + "?call", data: { activity: EngagementIndex::Activity::SKYPE_CALL}, class: "cjs_track_js_ei_activity") unless profile_user.skype_id.blank?
    end
    # Work on behalf
    if !working_on_behalf? && (!profile_user.member.admin? || current_member.admin?) && not_self_view && profile_viewer.can_work_on_behalf? && @current_program.has_feature?(FeatureName::WORK_ON_BEHALF)
       actions << link_to("feature.profile.label.wob".translate, work_on_behalf_user_path(profile_user), :method => :post, :class => "wob_link user_action_link")
    end

    actions_before_dropdown = actions.count

    # Go to mentoring area
    viewer_as_student_groups = Group.involving(profile_viewer, profile_user)
    viewer_as_mentor_groups = Group.involving(profile_user, profile_viewer)
    groups = viewer_as_student_groups.active + viewer_as_mentor_groups.active
    if groups.present? && !viewing_group
      groups.each do |group|
        actions << link_to("feature.user.label.go_to_mentoring_area_v1".translate(Mentoring_Area: group.name(true)), group_path(group, src: EngagementIndex::Src::SendRequestOrOffers::HOVERCARD))
      end
    end
    # Find a mentor
    can_find_mentor = profile_viewer.is_admin? && profile_user.is_student? && !@current_program.project_based?
    if can_find_mentor && !profile_user.suspended? && (!@current_program.max_connections_for_mentee.present? || (profile_user.groups.active.count < @current_program.max_connections_for_mentee))
      actions << link_to("feature.user.label.find_mentor".translate(:a_mentor => _a_Mentor), matches_for_student_users_path(student_name: profile_user.name_with_email, src: EngagementIndex::Src::SendRequestOrOffers::HOVERCARD))
    end
    # Mentor actions when viewing a mentee
    if profile_user.is_student? && profile_viewer.is_mentor? && @current_program.mentor_offer_enabled? && @current_program.only_career_based_ongoing_mentoring_enabled? && profile_viewer.opting_for_ongoing_mentoring?
      actions << get_actions_for_mentor_viewing_mentee(profile_viewer, profile_user)
    end
    # Mentee actions when viewing a mentor
    if profile_user.is_mentor? && profile_viewer.is_student?
      actions << get_actions_for_mentee_viewing_mentor(profile_viewer, profile_user, viewer_as_student_groups)
    end
    # Provide a rating
    if viewing_group && show_provide_rating_link?(viewing_group, profile_user, profile_viewer)
      actions << link_to("feature.connection.content.provide_a_rating".translate, "javascript:void(0)", :class => "cjs_mentor_rating", :id => "mentor_rating_#{profile_user.id}", :data => {:url => new_feedback_response_path({group_id: viewing_group.id, recipient_id: profile_user.id})})
    end
    display_hovercard_actions(actions.flatten, profile_viewer, actions_before_dropdown) if actions.present?
  end

  def show_user_groups_in_hovercard(groups, profile_user, profile_viewer)
    content = "".html_safe
    groups.each do |group|
       content += group_in_hovercard(group, profile_user, profile_viewer)
    end
    content_tag(:div, content)
  end

  def group_in_hovercard(group, profile_user, profile_viewer)
    content_tag(:div, :class => "media") do
      content_tag(:div, class: "media-left") do
        image_tag(group.logo_url, :size => "32x32", :class => "img-circle")
      end +
      content_tag(:div, class: "media-body") do
        group_title_and_action_in_user_profile(profile_viewer, group, {:class => "font-600", :show_roles => true, :group_member => profile_user})
      end
    end
  end

  def display_coach_rating_and_reviews(mentor)
    rating = mentor.user_stat.present? ? mentor.user_stat.average_rating.round(2) : 0
    alignment_class = rating > 0 ? "cui_has_rating" : "cui_zero_rating"
    content_tag(:div, display_coach_rating(mentor, rating) + coach_reviews_link(mentor), :class => "cui_rating_content #{alignment_class}")
  end

  def display_coach_rating(mentor, rating)
    tooltip_message = rating > 0 ? rating.to_s : "feature.coach_rating.label.not_rated_yet".translate
    content_tag(:div, "", :class => "display-star-rating m-r-xxs pull-left ", :id => "mentor_rating_#{mentor.id}", 'data-score'=> rating, "data-title" => tooltip_message, "data-toggle" => "tooltip")
  end

  def coach_reviews_link(mentor)
    return unless mentor.user_stat
    no_of_ratings = mentor.user_stat.rating_count
    content_tag(:span, "(#{link_to(reviews_link_text(no_of_ratings), "javascript:void(0)", class: "show_mentor_ratings", id: "mentor_reviews_#{mentor.id}", data: {url: reviews_user_path(mentor.id)})})".html_safe, class:  "small")
  end

  def reviews_link_text(count)
    count.to_s + "feature.coach_rating.label.rating_text".translate.pluralize(count)
  end

  def display_rating(rating)
    content_tag(:span, "", :class => "display-star-rating", 'data-score'=> rating)
  end

  def can_show_rating_to_the_viewer?(program, viewer)
    program.coach_rating_enabled? && viewer && viewer.can_view_coach_rating?
  end

  def can_show_rating_for_the_user?(program, user, viewer)
    user && user.is_mentor? && can_show_rating_to_the_viewer?(program, viewer)
  end

  def get_availablility_status_filter_fields(role)
    if role == RoleConstants::MENTOR_NAME
      if current_user.try(:can_render_calendar_ui_elements?, role)
        filter_fields = calendar_specific_filters(current_user)
      elsif current_program.ongoing_mentoring_enabled?
        filter_fields = [
          {
            value: UsersIndexFilters::Values::AVAILABLE,
            label: "feature.user.filter.abailable_mentors".translate(:mentors => _Mentors),
            class: 'abailable_mentors',
            section: 'status_'
          }
        ]
      end
    elsif current_program.ongoing_mentoring_enabled? && role == RoleConstants::STUDENT_NAME
      filter_fields = [
        {
          value: UsersIndexFilters::Values::CONNECTED,
          label: "feature.user.filter.connected_mentees".translate(:mentees => _Mentees),
          class: "connected_mentees"
        },
        {
          value: UsersIndexFilters::Values::UNCONNECTED,
          label: "feature.user.filter.unconnected_mentees".translate(:mentees => _Mentees),
          class: 'unconnected_mentees',
          tool_tip: "feature.user.filter.unconnected_mentees_tooltip_v1".translate(:mentees => _mentees, :mentoring_connection => _mentoring_connection)
        },
        {
          value: UsersIndexFilters::Values::NEVERCONNECTED,
          label: "feature.user.filter.never_connected_mentees".translate(:mentees => _Mentees),
          class: 'never_connected_mentees',
          tool_tip: "feature.user.filter.never_connected_mentees_tooltip_v1".translate(:mentees => _mentees, :mentoring_connection => _mentoring_connection)
        }
      ]
    end
  end

  def get_match_mentor_actions(mentor, student, dropdown_options = {})
    actions = []
    actions << {
      label: "feature.user.action.create_a_mentoring_connection".translate(:mentoring_connection => _mentoring_connection),
      url: assign_match_form_groups_path(mentor_id: mentor.id, student_id: student.id),
      class: "assign_match_btns"
    }  
    actions << {
      label: "feature.user.action.draft_a_mentoring_connection".translate(:mentoring_connection => _mentoring_connection),
      url: save_as_draft_groups_path(mentor_id: mentor.id, student_id: student.id),
      class: "assign_match_btns"
    }
    dropdown_buttons_or_button(actions, { dropdown_title: "feature.user.action.Connect".translate }.merge(dropdown_options))
  end

  def display_favorite(favorite)
    content = content_tag(:li, class: "list-group-item") do
      content_tag(:div, class: "media-left") do
        user_picture(favorite, { no_name: true, size: :small, src: EngagementIndex::Src::BrowseMentors::MENTOR_LISTING_PAGE }, { class: "img-circle" } )
      end +
      content_tag(:div, class: "media-body") do
        content_tag(:div, class: "m-t-xs") do
          link_to_user(favorite, class: "font-bold m-r-xs", src: EngagementIndex::Src::BrowseMentors::MENTOR_LISTING_PAGE) +
          remove_favorite_link(favorite, current_user.get_user_favorite(favorite))
        end
      end
    end
  end

  def get_prompt_preferred_request_message
    if current_program.allow_mentoring_requests? && !current_user.connection_limit_as_mentee_reached? && !current_user.pending_request_limit_reached_for_mentee?
      visible_favourites = current_user.get_visible_favorites
      if current_user.ready_to_request?
        get_prompt_to_request_preferred_mentors_message(visible_favourites.size, class: "alert-link")
      else
        preferred_mentor_text = "feature.user.content.preferred_mentor".translate(count: visible_favourites.size, mentor: _mentor, mentors: _mentors)
        remaining_size = current_program.min_preferred_mentors - current_user.user_favorites.size
        display_string = pluralize_only_text(remaining_size , _mentor, _mentors)
        "flash_message.mentor_request_flash.prompt_a_request_remaining".translate(count_with_name: preferred_mentor_text, n: remaining_size, mentors: display_string)
      end
    end
  end

  def get_prompt_to_request_preferred_mentors_message(preferred_mentors_count, link_options = {})
    preferred_mentor_text = "feature.user.content.preferred_mentor".translate(count: preferred_mentors_count, mentor: _mentor, mentors: _mentors)
    send_request_path = link_to('display_string.send_a_request'.translate, new_mentor_request_path, link_options)
    "flash_message.mentor_request_flash.prompt_a_request_v1_html".translate(count_with_name: preferred_mentor_text, send_req: send_request_path, mentor: _mentor, mentors: _mentors, administrator: _admin)
  end

  def users_view_params(role)
    if role == RoleConstants::MENTOR_NAME
      {}
    elsif role == RoleConstants::STUDENT_NAME
      {:view => RoleConstants::STUDENTS_NAME}
    else
      {:view => role}
    end
  end

  def icons_for_availability(user, options = {})
    return unless user.is_mentor?
    program = user.program
    return unless program.only_career_based_ongoing_mentoring_enabled? && program.calendar_enabled? && program.allow_mentoring_requests? && !program.matching_by_admin_alone?

    availability_icons = get_safe_string
    a_mentoring_connection_term = options[:weekly_updates_email] ? @_a_mentoring_connection_string : _a_mentoring_connection
    a_meeting_term = options[:weekly_updates_email] ? @_a_meeting_string : _a_meeting
    user_can_mentor = options[:mentors_with_slots].present? ? options[:mentors_with_slots].include?(user.id) : user.can_receive_mentoring_requests?

    availability_icons +=
    if user.opting_for_ongoing_mentoring? && user_can_mentor
      get_available_icon_content(title: "feature.user.content.available_for_connection".translate(a_connection: a_mentoring_connection_term), email: options[:weekly_updates_email], ongoing: true, no_left_margin: options[:no_left_margin])
    else
      get_unavailable_icon_content(title: "feature.user.content.unavailable_for_connection".translate(a_connection: a_mentoring_connection_term), email: options[:weekly_updates_email], ongoing: true, no_left_margin: options[:no_left_margin])
    end
    availability_icons +=
    if user.opting_for_one_time_mentoring?
      get_available_icon_content(title: "feature.user.content.available_for_meeting".translate(a_meeting: a_meeting_term), email: options[:weekly_updates_email], onetime: true, no_left_margin: options[:no_left_margin])
    else
      get_unavailable_icon_content(title: "feature.user.content.unavailable_for_meeting".translate(a_meeting: a_meeting_term), email: options[:weekly_updates_email], onetime: true, no_left_margin: options[:no_left_margin])
    end
    availability_icons
  end

  def get_available_icon_content(options = {})
    if options[:email]
      image_url = options[:ongoing] ? UserAvailabilityImages::Ongoing::AVAILABLE : UserAvailabilityImages::Onetime::AVAILABLE
      content_tag(:span, image_tag(image_url, width: 20, height: 18), style: "padding-left: 5px;") # Hardcoded width and height for Outlook 10 & 13
    else
      fa_class = options[:ongoing] ? "fa fa-user-plus #{"m-l-xs" unless options[:no_left_margin]}" : "fa fa-calendar"
      get_icon_content(fa_class, "data-title" => options[:title], "data-toggle" => "tooltip" )
    end
  end

  def get_unavailable_icon_content(options = {})
    if options[:email]
      image_url = options[:ongoing] ? UserAvailabilityImages::Ongoing::UNAVAILABLE : UserAvailabilityImages::Onetime::UNAVAILABLE
      content_tag(:span, image_tag(image_url, width: 24, height: 24), style: "padding-left: 5px;") # Hardcoded width and height for Outlook 10 & 13
    else
      fa_class = options[:ongoing] ? "fa-user-plus" : "fa-calendar"
      get_icon_content("fa fa-ban", container_class: fa_class, container_stack_class: "fa-stack-1x", icon_stack_class: "fa-stack-2x", invert: "", stack_class: "#{"m-l-xs" unless options[:no_left_margin]} fa-small", "data-title" => options[:title], "data-toggle" => "tooltip" )
    end
  end

  def get_user_role_for_ga(user)
    return unless user
    roles = []
    if user.is_admin_only?
      roles << "Admin Only"
    elsif user.is_mentor_or_student?
      roles << "Mentor" if user.is_mentor?
      roles << "Mentee" if user.is_student?
    else
      roles << "Other Role"
    end
    roles.join(" ")      
  end

  def get_track_level_connection_status(user)
    return unless user
    past_connection_status = user.past_connection_status
    if check_connection_status(:connected, user.current_connection_status)
      User::ConnectionStatusForGA::CURRENT
    elsif check_connection_status(:connected, past_connection_status)
      User::ConnectionStatusForGA::PAST
    elsif check_connection_status(:not_connected, past_connection_status) && !user.pending?
      get_never_connected_status(user)
    else
      User::ConnectionStatusForGA::NA
    end
  end

  def group_links_hash(groups, src = nil)
    group_links = []
    link_options = {}
    link_options[:src] = src if src.present?

    if groups.present?
      groups.select(&:active?).each do |group|
        group_links << {
          label: append_text_to_icon("fa fa-users", "feature.user.label.go_to_mentoring_area_v1".translate(Mentoring_Area: h(group.name(true)))),
          url: group_path(group, link_options)
        }
      end
    end
    group_links
  end

  private

  # This function shows the visual tag for a user who hasn't answered mandatory questions.
  def status_indicator_for_pending_user
    return {
      content: "feature.user.content.status.fields_missing".translate,
      label_class: "label-danger",
      options: {
        data: {
          toggle: "tooltip",
          title: "feature.user.content.tooltips.fields_missing".translate
        }
      }
    }
  end

  def status_indicator_for_unavailable_mentor(options = {})
    return {
      content: "feature.user.content.status.unavailable".translate,
      label_class: "label-warning",
      options: {
        data: {
          toggle: "tooltip",
          title: "feature.user.content.tooltips.student_listing".translate(Mentor: _Mentor, mentee: _mentee)
        }
      }
    }
  end

  def check_connection_status(method, connection_status)
    User::ConnectionStatus::ConnectionStatus.send(method).include?(connection_status)
  end

  def get_never_connected_status(user)
    (user.sent_mentor_requests.size > 0) ? User::ConnectionStatusForGA::NEVER_CONNECTED_INITIATED : User::ConnectionStatusForGA::NEVER_CONNECTED_NEVER_INITIATED
  end

  def get_user_status_based_label(user)
    case user.state
    when User::Status::PENDING
      {
        content: "feature.user.content.status.profile_unpublished".translate,
        label_class: "label-danger"
      }
    when User::Status::SUSPENDED
      {
        content: "feature.user.content.status.membership_suspended_v1".translate,
        label_class: "label-danger"
      }
    end
  end

  def remove_user_prompt_connections_part(user, group_status = :active)
    mentoring_groups_any = user.mentoring_groups.send(group_status).any?
    studying_groups = user.studying_groups.send(group_status).select{|group| group.single_mentee?} # All the groups where the student is only mentee

    if mentoring_groups_any || studying_groups.size > 0
      span_title = (group_status == :active) ? "display_string.Active".translate : "display_string.Closed".translate
      span_title = span_title + " #{_Mentoring_Connections}:".html_safe
      content = content_tag(:span, span_title, :class => 'content_title')
      content += content_tag(:ul) do
        ul_content = "".html_safe
        ul_content += content_tag(:li, "feature.profile.content.user_metoring_students_v1_html".translate(a_mentor: _a_mentor, user_name: user.name, student_links: user.students(group_status).collect{|stu| link_to_user(stu)}.join(", ").html_safe)) if mentoring_groups_any
        studying_groups.each do |group|
          ul_content += content_tag(:li, "feature.profile.content.user_metored_by_v1_html".translate(user_name: user.name, Mentors: _Mentors, mentor_links: group.mentors.collect{|mentor| link_to_user(mentor)}.join(", ").html_safe))
        end
        ul_content
      end
    end
  end

  def remove_user_prompt_contributions_part(user)
    if user.articles.published.any? || user.qa_questions.any? || user.qa_answers.any? || user.topics.any? || user.posts.any?
      content = content_tag(:span, "#{"feature.profile.label.Contributions".translate}:", :class => 'content_title')
      content += content_tag(:ul) do
        ul_content = "".html_safe
        if user.articles.published.any?
          article_count = pluralize(user.articles.published.count, _article)
          ul_content += content_tag(:li, "feature.profile.content.articles_by_user_html".translate(n_articles: link_to(article_count, member_path(user.member, :tab => 'articles')), user_name: user.name))
        end
        if user.qa_questions.any?
          questions_count = "feature.profile.label.question".translate(count: user.qa_questions.count)
          ul_content += content_tag(:li, "feature.profile.content.questions_by_user_html".translate(n_questions: link_to(questions_count, member_path(user.member, :tab => 'qa_questions')), user_name: user.name))
        end
        if user.qa_answers.any?
          ans_count = "feature.profile.label.answer".translate(count: user.qa_answers.count)
          ul_content += content_tag(:li, "feature.profile.content.answers_by_user_html".translate(n_answers: link_to(ans_count, member_path(user.member, :tab => 'qa_answers')), user_name: user.name))
        end
        if user.topics.any? || user.posts.any?
          ul_content += content_tag(:li, "feature.profile.content.topics_and_posts_by_user".translate(user_name: user.name))
        end
        ul_content
      end
    end
  end

  def profile_filter_wrapper(title, collapsed = true, dont_concat = false, first = false, options = {}, &block)
    wrapper_text = capture do
      inner_html_options = {class: "filter_box clearfix"}.reverse_merge(options[:inner_html] || {})
      inner_html_options.reverse_merge!(role: "group", aria: {label: title}) unless options[:ignore_role_group]
      collapsible_content(title, [], collapsed, { render_panel: true, additional_header_class: "p-sm", class: "filter_item b-b", pane_content_class: "p-t-0" }.merge(options)) do
        content_tag(:div, capture(&block), inner_html_options)
      end
    end

    if dont_concat
      wrapper_text
    else
      concat wrapper_text
    end
  end

  def profile_filter_container(profile_question, filter_value = nil, options = {})
    return if profile_question.choice_or_select_type?

    default_options = {
      element_name: "sf[pq][#{profile_question.id}]",
      element_id: "sf_pq_#{profile_question.id}",
      element_value: filter_value,
      label: profile_question.question_text
    }

    content = ""
    reset_method = ""
    options_array = get_profile_filter_container_options(profile_question, filter_value, {ei_class: options[:ei_class], activity: options[:activity]})

    options_array.each_with_index do |options, index|
      options = default_options.merge(options)
      content += content_tag(:div, class: "form-group") do
        label_tag(options[:element_name], options[:label], for: options[:element_id], class: "sr-only") +
        if options[:set_autocomplete_field]
          options[:tag_options].merge!(left_addon: options[:left_options], right_addon: options[:right_options])
          text_field_with_auto_complete(options[:element_name], options[:method], options[:tag_options], options[:completion_options])
        elsif options[:set_date_field]
          reset_method += "DateRangePicker.clearInputs(jQuery('##{options[:element_id]}'));"
          construct_daterange_picker(options[:element_name], {}, presets: DateRangePresets.for_date_profile_field_quick_filter, right_addon: options[:right_options], hidden_field_attrs: {class: ProfileQuestionsHelper::DATE_RANGE_PICKER_FOR_PROFILE_QUESTION})
        else
          construct_input_group(options[:left_options], options[:right_options], {}) do
            filter_text_field(options[:element_id], "", class: "form-control input-sm", name: options[:element_name], value: (options[:element_value] || ""), placeholder: options[:placeholder], onclick: "", onfocus: "", onblur: "")
          end
        end
      end

      reset_method += "jQuery('##{options[:element_id]}').val('');"
      if index == (options_array.size - 1)
        content += link_to_function("display_string.reset".translate, "#{reset_method} MentorSearch.applyFilters();", id: "reset_filter_profile_question_#{profile_question.id}", class: "hide")
      end
    end
    content.html_safe
  end

  def can_render_calendar_ui_elements?(user, role)
    user && user.program.calendar_enabled? && user.can_view_mentoring_calendar? && role == RoleConstants::MENTOR_NAME
  end

  def is_long_term_availability_filter?(filter_field)
    filter_field[:value] == UsersIndexFilters::Values::AVAILABLE
  end

  def is_calendar_filter?(filter_field)
    filter_field[:value] == UsersIndexFilters::Values::CALENDAR_AVAILABILITY
  end

  def get_reasons_for_not_removing_roles(user, program, roles = nil)
    roles ||= program.roles
    reasons_for_not_removing_role = {}
    roles.each do |role|
      reasons_for_not_removing_role[role.name] = get_reasons_for_not_removing_role_name(user, role, program)
    end
    reasons_for_not_removing_role
  end

  def get_reasons_for_not_removing_role_name(user, role, program)
    reasons = []
    return reasons unless user.role_names.include?(role.name) && !role.administrative?
    pending_project_requests = user.sent_project_requests.with_role(role).active.size
    active_groups, pending_mentor_requests, pending_mentor_offers, pending_meeting_requests = 0, 0, 0, 0
    if role.name == RoleConstants::STUDENT_NAME
      active_groups = program.groups.active.with_student(user).size
      pending_mentor_requests = user.sent_mentor_requests.active.size
      pending_mentor_offers = user.received_mentor_offers.pending.size
      pending_meeting_requests = user.sent_meeting_requests.active.size
    elsif role.name == RoleConstants::MENTOR_NAME
      active_groups = program.groups.active.with_mentor(user).size
      pending_mentor_requests = user.received_mentor_requests.active.size
      pending_mentor_offers = user.sent_mentor_offers.pending.size
      pending_meeting_requests = user.received_meeting_requests.active.size
    end

    reasons << "feature.user.content.change_roles.has_ongoing_connection".translate(mentoring_connection: _Mentoring_Connection, mentoring_connections: _Mentoring_Connections, count: active_groups) if active_groups > 0
    reasons << "feature.user.content.change_roles.has_pending_mentor_requests".translate(mentor: _mentor, count: pending_mentor_requests) if pending_mentor_requests > 0
    reasons << "feature.user.content.change_roles.has_pending_mentor_offers".translate(mentor: _mentor, count: pending_mentor_offers) if pending_mentor_offers > 0
    reasons << "feature.user.content.change_roles.has_pending_meeting_requests".translate(meeting: _meeting, count: pending_meeting_requests) if pending_meeting_requests > 0
    reasons << "feature.user.content.change_roles.has_pending_project_requests".translate(mentoring_connection: _mentoring_connection, count: pending_project_requests) if pending_project_requests > 0

    reasons
  end

  def reason_list(list)
    return unless list.present?
    if list.size == 1
      content_tag(:div, list.first)
    else
      list_content = "".html_safe
      list.each do |list_entry|
        list_content << content_tag(:li, list_entry, class: 'tooltip-list')
      end
      content_tag(:ul) do
        list_content
      end
    end
  end

  def get_result_pane_alert
    if @match_view && !@student_document_available
      display_match_score_unavailable_flash
    elsif @from_global_search && current_user.can_manage_user_states?
      display_deactivated_users_omitted_flash
    end
  end

  def display_match_score_unavailable_flash
    display_alert("feature.user.content.match_score_not_available_yet".translate(mentors: _mentors), "alert-warning")
  end

  def display_deactivated_users_omitted_flash
    all_users = link_to("feature.admin_view.content.all_users".translate, admin_view_all_users_path)
    display_alert("feature.user.content.deactivated_not_listed_html".translate(all_users: all_users), "alert-info")
  end

  def display_alert(alert_text, alert_class)
    content = button_tag(class: "close", data: { dismiss: "alert" } ) do
      get_icon_content("fa fa-times m-r-0") +
      set_screen_reader_only_content("display_string.Close".translate)
    end
    content += append_text_to_icon("fa fa-info-circle", alert_text)
    content_tag(:div, content, class: "alert #{alert_class} alert-dismissable")
  end

  def self.state_to_string_map
    {
      User::Status::PENDING => "feature.admin_view.status.unpublished".translate,
      User::Status::SUSPENDED => "feature.admin_view.status.deactivated".translate,
      User::Status::ACTIVE => "feature.admin_view.status.active".translate
    }
  end

  def render_user_role_check_boxes(options = {})
    program = options[:program]
    return unless program
    check_boxes = []
    selected_roles = options[:roles] || []
    program.roles.includes(:customized_term => :translations).each do |role|
      val = role.name
      check_boxes << content_tag(:label, check_box_tag('role[]', val, (selected_roles.include?(val)), :id => "role_#{val}", :class => 'cjs_role_name_check_box') + RoleConstants.human_role_string([role.name], program: program), class: "checkbox inline") if current_user.add_user_directly?([role])
    end

    choices_wrapper("display_string.Roles".translate){raw(check_boxes.join(' '))}
  end

  def render_user_role_check_boxes_from_other_program(roles)
    choices_wrapper("display_string.Roles".translate) do
      raw(roles.collect do |role|
        options = { :class => 'checkbox inline'}
        checkbox_options = {:onchange => "jQuery('#form_user_bulk_actions .alert').toggle();"} if role.administrative?
        content_tag(:label, check_box_tag('roles[]', role.name, false, {:id => role.name.capitalize}.merge(checkbox_options || {}))  + role.customized_term.term, options)
      end.join(' '))
    end
  end

  def import_members_enabled?
    !@current_organization.standalone? && current_user.import_members_from_subprograms?
  end

  def construct_hovercard_container(user, link_or_text, group_view_id = nil)
    user_id = user.is_a?(User) ? user.id : user
    content_tag(:span, "", :class => "cjs-user-link-container #{hidden_on_mobile}", data: { user_id: "#{user_id}_#{SecureRandom.hex(3)}" } ) do
      content_tag(:span, link_or_text, :class => "cjs-onhover-text inline", :data => {hovercard_url: hovercard_user_path(user, format: :js, :group_view_id => group_view_id)})
    end +
    content_tag(:span, "", :class => hidden_on_web) do
      content_tag(:span, link_or_text, :class => "cjs-onhover-text inline", :data => {hovercard_url: hovercard_user_path(user, format: :js, :group_view_id => group_view_id)})
    end
  end

  def get_actions_for_mentor_viewing_mentee(mentor, mentee)
    mentor_actions = []
    if mentor.can_offer_mentoring_to?(mentee)
      if @current_program.mentor_offer_needs_acceptance? && mentor.sent_mentor_offers.pending.where(student_id: mentee.id).present?
        mentor_actions << link_to("feature.user.label.mentoring_offer_pending".translate, "javascript:void(0);", class: "dim")
      else
        mentor_actions << link_to_function("feature.user.action.offer_mentoring_v1".translate(:Mentoring => _Mentoring), "OfferMentoring.renderPopup('#{new_mentor_offer_path(student_id: mentee.id, src: EngagementIndex::Src::SendRequestOrOffers::HOVERCARD)}')")
      end
    end
    mentor_actions
  end

  def get_actions_for_mentee_viewing_mentor(mentee, mentor, groups = [])
    mentee_actions = []
    action_options = { analytics_param: EngagementIndex::Src::SendRequestOrOffers::HOVERCARD, skip_icons: true }

    if @current_program.matching_by_mentee_alone?
      request_mentoring_action_hash = get_request_mentoring_action_hash(mentee, mentor, action_options.merge!(is_connected_already: groups.present?))
      mentee_actions << render_action_for_dropdown_button(request_mentoring_action_hash) if request_mentoring_action_hash.present?
    end

    request_meeting_action_hash = get_request_meeting_action_hash(mentee, mentor, action_options)
    mentee_actions << render_action_for_dropdown_button(request_meeting_action_hash) if request_meeting_action_hash.present?
    mentee_actions
  end

  def display_hovercard_actions(actions, viewer, actions_before_dropdown)
    actions_content = "".html_safe
    if actions.count == 1
      actions_content = actions.first
    else
      actions_before_dropdown = 1 if actions_before_dropdown.zero?
      actions_content += actions.first(actions_before_dropdown).join(circle_separator).html_safe
      if actions.count > actions_before_dropdown
        dropdown_menu_text = viewer.is_admin? ? "feature.user.label.Manage".translate : "display_string.Actions".translate
        actions_content += circle_separator
        actions_content += dropdown_in_hovercard(dropdown_menu_text, actions[actions_before_dropdown..-1])
      end
    end
    content_tag(:span, actions_content, class: "small")
  end

  def dropdown_in_hovercard(title, actions)
    dropdown_content = content_tag(:div, :class => "group-filters btn-group") do
      link_to((title + get_icon_content("fa fa-caret-down m-r-0 m-l-xxs")).html_safe, "javascript:void(0);", 'data-toggle' => 'dropdown') +
      content_tag(:ul, :class => "dropdown-menu") do
        other_actions = "".html_safe
        actions.each do |ac|
          other_actions << content_tag(:li, ac)
        end
        other_actions
      end
    end
    dropdown_content
  end

  def connections_and_activity_items
    activity_items = []
    user = @profile_user
    if (@current_program.mentoring_connections_v2_enabled? || @current_program.calendar_enabled?) && @current_program.contract_management_enabled? && @is_owner_mentor
      activity_items << total_coaching_hours(user)
    end

    unless @is_owner_admin_only
      if @current_program.ongoing_mentoring_enabled?
        activity_items << ongoing_connections_metatdata(user)
        activity_items << closed_connections_metatdata(user)
        activity_items << draft_connections_metatdata(user) if @is_admin_view
      end
    end

    if @current_program.ongoing_mentoring_enabled? && @is_owner_mentor
      activity_items << available_slots_metatdata(user)
      activity_items << average_request_response_time_metatdata(user)
      activity_items << pending_mentor_requests_metadata(user) if @current_program.matching_by_mentee_alone?
    end

    activity_items << requests_initiated_metatdata(user) if @current_program.ongoing_mentoring_enabled? && @is_owner_student && @current_program.matching_by_mentee_alone?

    if (@current_program.mentoring_connections_v2_enabled? || @current_program.calendar_enabled?) && !@is_owner_admin_only
      activity_items << past_meetings_metatdata(user)
      if @current_program.calendar_enabled?
        activity_items << meetings_requests_initiated_metatdata(user)
        if @is_owner_mentor
          activity_items << average_meeting_response_time_metatdata(user)
          activity_items << slots_available_metatdata(@current_and_next_month_session_slots) if @current_and_next_month_session_slots.present?
        end
      end
    end

    activity_items << mentor_offers_requests_initiated_metatdata(user) if @current_program.ongoing_mentoring_enabled? && @current_program.mentor_offer_enabled? && @is_owner_mentor && user.sent_mentor_offers.any?
    activity_items << profile_completeness_metatdata(user) if @is_admin_view
    activity_items.compact
  end

  def activity_sidebar_item(value)
    content_tag(:span, raw(value))
  end

  def prepare_response_time(mentor_requests)
    mentor_requests_timestamp_data = mentor_requests.pluck(:updated_at, :created_at)
    ((mentor_requests_timestamp_data.sum { |updated_at, created_at| updated_at - created_at } / mentor_requests_timestamp_data.size) / 1.hour).round(2)
  end

  def ongoing_connections_metatdata(user)
    groups_count = user.groups.active.count
    groups_link = @is_admin_view ? member_path(user.member, :tab => MembersController::ShowTabs::MANAGE_CONNECTIONS, :filter => GroupsController::StatusFilters::Code::ONGOING) : groups_path(:tab => Group::Status::ACTIVE)
    text = "feature.user.label.ongoing_mentoring_connections".translate(:mentoring_connections => _mentoring_connections)
    [groups_count.zero? ? text : link_to(text, groups_link), activity_sidebar_item(groups_count)]
  end

  def closed_connections_metatdata(user)
    groups_count = user.groups.closed.count
    groups_link = @is_admin_view ? member_path(user.member, :tab => MembersController::ShowTabs::MANAGE_CONNECTIONS, :filter => GroupsController::StatusFilters::Code::CLOSED) : groups_path(:tab => Group::Status::CLOSED)
    text = "feature.user.label.past_mentoring_connections".translate(:mentoring_connections => _mentoring_connections)
    [groups_count.zero? ? text : link_to(text, groups_link), activity_sidebar_item(groups_count)]
  end

  def draft_connections_metatdata(user)
    [link_to("feature.user.label.draft_mentoring_connections".translate(:mentoring_connections => _mentoring_connections), member_path(user.member, :tab => MembersController::ShowTabs::MANAGE_CONNECTIONS, :filter => GroupsController::StatusFilters::Code::DRAFTED)), activity_sidebar_item(user.groups.drafted.count)] if user.groups.drafted.any?
  end

  def available_slots_metatdata(user)
    ["feature.profile.content.available_slots_v1".translate(:Mentoring_Connection => _Mentoring_Connection), activity_sidebar_item(user.slots_available)]
  end

  def pending_mentor_requests_metadata(user)
    new_mentor_requests_count = user.new_mentor_requests_count
    title, tooltip =
      if new_mentor_requests_count > 0 && user.slots_available_for_mentor_request == 0
        ["feature.user.content.pending_mentor_requests_html".translate(mentor: _mentor, tooltip: embed_icon(TOOLTIP_IMAGE_CLASS, '', id: 'pending_mentor_requests_help_text')), tooltip("pending_mentor_requests_help_text", "feature.user.content.pending_mentor_requests_help_text".translate(Mentees: _Mentees, user_name: user.name(name_only: true)))]
      else
        ["feature.reports.label.Pending_mentor_requests".translate(mentor: _mentor)]
      end
    [title, activity_sidebar_item(new_mentor_requests_count), tooltip]
  end

  def average_request_response_time_metatdata(user)
    requests = user.received_mentor_requests.answered
    if requests.any?
      response_time = prepare_response_time(requests)
      response_time, display_time_in = time_in_hours_days_weeks(response_time)
      text = "feature.profile.content.average_request_response_time".translate + "(" + "feature.profile.content.#{display_time_in}".translate(:count => response_time) + ")"
      [text, activity_sidebar_item(response_time)]
    end
  end

  def requests_initiated_metatdata(user)
    ["feature.profile.content.requests_initiated".translate, activity_sidebar_item(user.sent_mentor_requests.count)]
  end

  def past_meetings_metatdata(user)
    archived_meetings = Meeting.past_recurrent_meetings(Meeting.get_meetings_for_view(nil, nil, user.member, @current_program))
    ["feature.profile.content.past_meetings".translate(:meetings => _meetings), activity_sidebar_item(archived_meetings.size)]
  end

  def meetings_requests_initiated_metatdata(user)
    ["feature.profile.content.meetings_requests_initiated_v1".translate(:Meeting => _Meeting), activity_sidebar_item(user.sent_meeting_requests.count)]
  end

  def total_coaching_hours(user)
    total_coaching_hrs = user.group_checkins_duration
    text = "feature.profile.content.total_coaching_hours".translate(:mentoring => _mentoring)
    [(total_coaching_hrs.zero? || !@is_admin_view) ? text : link_to(text, group_checkins_path(user: user.id)), activity_sidebar_item(total_coaching_hrs)]
  end
  def average_meeting_response_time_metatdata(user)
    requests = user.received_meeting_requests.answered
    if requests.any?
      response_time = prepare_response_time(requests)
      response_time, display_time_in = time_in_hours_days_weeks(response_time)
      text = "feature.profile.content.average_meeting_request_response_time".translate(:meeting => _meeting) + "(" + "feature.profile.content.#{display_time_in}".translate(:count => response_time) + ")"
      [text, activity_sidebar_item(response_time)]
    end
  end

  def slots_available_metatdata(next_month_session_slots)
    content = content_tag(:span, "feature.profile.content.slots_available".translate(Meeting: _Meeting))
    content += get_icon_content("fa fa-info-circle m-l-xxs", data: { toggle: "tooltip",
      title: "feature.profile.content.in_current_and_next_month".translate(time_period: get_current_and_next_month_text(wob_member)) } )
    [content, activity_sidebar_item(next_month_session_slots)]
  end

  def mentor_offers_requests_initiated_metatdata(user)
    ["feature.profile.content.requests_initiated".translate, activity_sidebar_item(user.sent_mentor_offers.count)]
  end

  def profile_completeness_metatdata(user)
    ["feature.profile.content.profile_completeness_score".translate, activity_sidebar_item("#{user.profile_score.sum}%")]
  end

  def time_in_hours_days_weeks(hours)
    return [(hours * 60).to_i, "minute"] if hours < 1
    # display as minutes if less that one hour, display hours in whole or .5, display days,weeks as whole or .5
    days,hours = hours.divmod(24)
    weeks,days = days.divmod(7)
    hours = (hours * 2).round / 2.0 # get closest whole value or 0.5
    hours = hours.modulo(1) == 0 ? hours.to_i : hours  #Display as integer if whole
    days += 0.5 if hours >= 12 && days > 0
    weeks += 0.5 if days > 3 && weeks > 0
    return (weeks == 0) ? (days == 0 ? [hours,"hour"] : [days,"day"]) : [weeks,"week"]
  end

  def available_groups_for_user_profile(profile_user, viewing_user, program)
    content = "".html_safe
    profile_user.public_groups_available_for_others_to_join.each do |group|
      content += group_in_users_listing(group, viewing_user, program)
    end
    content_tag(:div, content)
  end

  def group_in_users_listing(group, user, program)
    content_tag(:div, class: "list-group-item") do
      group_members_list = group_members_for_users_listing(group, max_mentoring_connection_members_in_profile_for(program))
      content_tag(:div, class: "group-users hidden-xs pull-right") do
        group_members_list
      end +
      content_tag(:div, class: "media m-t-0") do
        content_tag(:div, class: "group-logo media-left") do
          image_tag(group.logo_url, :class => "img-circle", :size => "50x50")
        end +
        content_tag(:div, class: "group-title media-body h5 p-t-xs") do
          group_title_and_action_in_user_profile(user, group)
        end
      end +
      content_tag(:div, class: "m-t-sm group-users visible-xs") do
        group_members_list
      end
    end
  end

  def group_members_for_users_listing(group, max_limit, options = {})
    content = "".html_safe
    users_to_display = options[:mentors_only] ? group.mentors : options[:students_only] ? group.students : options[:teachers_only] ? group.custom_users : group.members
    
    users_of_group_to_display = max_limit
    remaining_users_to_display = users_to_display.count - users_of_group_to_display
    users_of_group_to_display += 1 if remaining_users_to_display == 1

    users_to_display.first(users_of_group_to_display).each do |user|
      content += content_tag(:span, link_to_user(user, {:content_text => user_picture(user, {:row_fluid => true, :no_name => true, :dont_link => true, :size => :small})}), :class => "m-r-xs")
    end

    if remaining_users_to_display > 1
      content += content_tag(:span, link_to("+#{remaining_users_to_display}", profile_group_url(group), class: "ct_show_more_link font-600"), class: "circular-show-more")
    end
    content
  end

  def group_title_and_action_in_user_profile(user, group, options = {})
    content = link_to(h(group.name), profile_group_url(group), class: options[:class] || "larger")
    content += content_tag(:div, RoleConstants.human_role_string([group.membership_of(options[:group_member]).role.name], :program => user.program), :id => "user_roles") if options[:show_roles]
    content += content_tag(:div, link_to("feature.connection.action.Join".translate(Mentoring_Connection: _Mentoring_Connection), profile_group_url(group, :join_request => "true"))) if user.can_apply_for_join?(group)

    content_tag(:div) do
      content
    end
  end

  def available_and_ongoing_groups_list(user)
    user.groups.select{|group| group.global && (group.active? || group.pending?)}.map{|group| link_to(h(group.name), profile_group_url(group), class: "hide_in_affixed_container")}.join(", ").html_safe
  end

  def max_mentoring_connection_members_in_profile_for(program)
    MAX_MENTORING_CONNECTION_MEMBERS_IN_PROFILE
  end

  def max_project_members_in_home_page_widget_for
    MAX_PROJECT_MEMBERS_IN_HOME_PAGE_WIDGET
  end

  def drafted_survey_responses_list(user)
    list = []
    user.drafted_responses_for_widget.each do |dsr|
      survey = user.program.surveys.find(dsr.survey_id)
      options = {response_id: dsr.response_id, src: Survey::SurveySource::HOME_PAGE_WIDGET}
      if dsr.task_id.present?
        options.merge!(task_id: dsr.task_id)
      elsif dsr.group_id.present?
        options.merge!(group_id: dsr.group_id)
      end
      list << render(partial: "users/home_page_widgets/drafted_survey", locals: {survey: survey, dsr: dsr, options: options})
    end
    list
  end

  def get_profile_filter_container_options(profile_question, filter_value, options = {})
    input_group_addon_options = {
      type: "addon",
      class: "gray-bg"
    }
    input_group_btn_options = {
      type: "btn",
      content: "display_string.Go".translate,
      btn_options: {
        class: "btn btn-primary btn-sm no-margins #{options[:ei_class]}",
        onclick: "return MentorSearch.applyFilters();",
        data: {
          activity: options[:activity]
        }
      }
    }

    options_array = if profile_question.education?
      [ {
        placeholder: "feature.user.placeholder.education_v1".translate,
        left_options: input_group_addon_options.merge( { icon_class: "fa fa-graduation-cap no-margins" } ),
        right_options: input_group_btn_options
      } ]
    elsif profile_question.experience?
      [ {
        placeholder: "feature.user.placeholder.experience_v1".translate,
        left_options: input_group_addon_options.merge( { icon_class: "fa fa-suitcase no-margins" } ),
        right_options: input_group_btn_options
      } ]
    elsif profile_question.publication?
      [ {
        placeholder: "feature.user.placeholder.publication_v1".translate,
        left_options: input_group_addon_options.merge( { icon_class: "fa fa-book no-margins" } ),
        right_options: input_group_btn_options
      } ]
    elsif profile_question.location?
      [ {
        label: "feature.user.label.location_filter_name".translate,
        element_name: "sf[location][#{profile_question.id}]",
        element_id: "search_filters_location_#{profile_question.id}_name",
        left_options: input_group_addon_options.merge( { icon_class: "fa fa-map-marker no-margins" } ),
        right_options: input_group_btn_options,
        set_autocomplete_field: true,
        method: :name,
        tag_options: {
          value: (filter_value[:name] if filter_value.present?),
          class: "form-control input-sm",
          id: "search_filters_location_#{profile_question.id}_name",
          placeholder: "feature.user.placeholder.location_search".translate,
          element_id: profile_question.id,
          autocomplete: "off"
        },
        completion_options: {
          min_chars: 0,
          url: get_filtered_locations_for_autocomplete_locations_path(format: :json),
          param_name: "loc_name"
        }
      } ]
    elsif profile_question.date?
      [{
        right_options: input_group_btn_options,
        set_date_field: true
      }]
    else
      [ {
        right_options: input_group_btn_options
      } ]
    end
  end

  def get_mentor_availability_text(mentor)
    view_date = Time.now
    is_capacity_reached_current_month = mentor.is_max_capacity_user_reached?(view_date)
    is_capacity_reached_next_month = mentor.is_max_capacity_user_reached?(view_date.next_month)
    availability_text, icon_class = if is_capacity_reached_current_month && is_capacity_reached_next_month
      ["feature.user.content.not_available_v1".translate(calendar_month: DateTime.localize(view_date.next_month, format: :month_year)), "fa-times-circle text-danger"]
    elsif is_capacity_reached_next_month
      ["feature.user.content.available_current_month".translate, "fa-check-circle text-navy"]
    elsif is_capacity_reached_current_month
      ["feature.user.content.available_next_month".translate, "fa-check-circle text-warning"]
    else
      ["feature.user.content.available".translate, "fa-check-circle text-navy"]
    end
      append_text_to_icon("fa #{icon_class}", availability_text)
  end
end