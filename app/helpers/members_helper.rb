module MembersHelper

  def mentoring_settings_options_for_validate
    scope = program_view? ? @current_program : @current_organization
    if(scope.calendar_enabled? && @profile_user.is_mentor? && @is_first_visit)
      {
        boundaries: (Meeting.valid_start_time_boundaries + [Meeting.valid_end_time_boundaries.last]),
        slot_diff: (@allowed_individual_slot_duration/Meeting::SLOT_TIME_IN_MINUTES),
        errorMsg: 'feature.calendar.content.end_time_mustbe_greater'.translate(allowed_slot_time: @allowed_individual_slot_duration),
        today_midnight: DateTime.localize(Time.now.at_midnight, format: :short_time_small),
      }
    end
  end

  def self.state_to_string_map
    {
      Member::Status::ACTIVE => "feature.admin_view.status.active".translate,
      Member::Status::SUSPENDED => "feature.admin_view.status.suspended".translate,
      Member::Status::DORMANT => "feature.admin_view.status.dormant".translate
    }
  end

  def options_for_join_as(program, roles)
    array = []
    roles.each do |role|
      array << [RoleConstants.human_role_string([role], program: program), role]
    end

    string = "".html_safe
    array.each do |ele|
      string += "<option value='#{ele[1]}'>#{ele[0]}</option>".html_safe
    end
    return string
  end

  def get_simple_section_questions(questions, options = {})
    sections = []
    questions_with_section_ids = questions.group_by(&:section_id)
    @current_organization.sections.where(id: questions_with_section_ids.keys).sort_by(&:position).each do |section|
      next if options[:exclude_basic_section] && section.default_field?
      sections << get_section_hash(section, questions_with_section_ids)
    end
    return sections
  end

  def get_basic_section_questions(questions)
    questions_with_section_ids = questions.group_by(&:section_id)
    default_section = @current_organization.sections.default_section.first
    return get_section_hash(default_section, questions_with_section_ids)
  end

  def get_section_hash(section, questions_with_section_ids)
    profile_questions = questions_with_section_ids[section.id] || []
    return { section: section, section_title: section.title, questions: profile_questions.sort_by(&:position), section_id: section.id, file_present: profile_questions.any?(&:file_type?) }
  end

  def remove_non_default_questions(questions, default_sections)
    relevant_section_questions = questions.select{|ques| !ques.section.default_field?}
    relevant_section_questions = questions - relevant_section_questions if default_sections
    return relevant_section_questions
  end

  def remove_member_prompt(member)

    if member.state == Member::Status::SUSPENDED
      display_message = "feature.profile.content.remove_member_from_org_cannot_suspend_html".translate(user_name: member.name, program: member.organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).pluralized_term_downcase)
      show_suspend_message = false
    else
      display_message = "feature.profile.content.remove_member_from_org_v2_html".translate(user_name: member.name, program: member.organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).pluralized_term_downcase, count: member.programs.count)
      show_suspend_message = true
    end

    content = content_tag(:div, :class => "help_text") do
      display_message
    end

    return [content, show_suspend_message]
  end

  def render_section_questions(role_section, expanded, last_section)
    ibox_class = expanded ? "cjs_section" : "cjs_section collapsed"
    has_edu_exp_ques = role_section.present? && role_section[:questions].present? ? has_importable_question?(role_section[:questions]) : false
    section = role_section[:section]
    ibox role_section[:section_title], {show_collapse_link: true, collapse_link_class: "pull-right", ibox_class: ibox_class, ibox_content_id: "collapsible_section_content_#{section.id}"} do
      render "members/edit/profile", section: section, has_edu_exp_ques: has_edu_exp_ques,
        questions: role_section[:questions], last_section: last_section, file_present: role_section[:file_present]
    end
  end

  def render_section_questions_xhr(role_section, expanded, last_section)
    ibox_class = expanded ? "cjs_section" : "cjs_section collapsed"
    url = fill_section_profile_detail_member_path(@profile_member,:section_id => role_section.id, :last_section => last_section, :format => :js)
    ibox role_section.title, {show_collapse_link: true, collapse_link_class: "pull-right", ibox_class: ibox_class, collapse_html_options: {onclick: "MemberEdit.loadSectionData('#{url}','#{role_section.id}')\;"}, ibox_content_id: "collapsible_section_content_#{role_section.id}"} do
      content_tag(:div, content_tag(:i, "", class: "fa fa-spinner fa-spin fa-2x") , class: "text-center")
    end
  end

  def basic_information_form_content_wrapper(&block)
    blk = capture(&block)
    @is_first_visit ? concat(content_tag(:fieldset, blk)) : concat(blk)
  end

  def render_basic_information(profile_member, profile_user, is_general_section, program_questions_for_user, options = {})
    ibox_class = is_general_section ? "cjs_section" : "cjs_section collapsed"
    ibox profile_member.organization.sections.default_section.first.title, { show_collapse_link: true, collapse_link_class: "pull-right", ibox_class: ibox_class, ibox_content_id: "basic_information", ibox_id: "basic_information_section" } do
      section_info = get_basic_section_questions(program_questions_for_user)
      last_section = get_simple_section_questions(program_questions_for_user, exclude_basic_section: true).empty?
      basic_questions = section_info[:questions]
      has_edu_exp_ques = basic_questions.present? ? has_importable_question?(basic_questions) : false
      locals = {
        profile_member: profile_member,
        profile_user: profile_user,
        basic_questions: basic_questions,
        section: section_info[:section],
        has_edu_exp_ques: has_edu_exp_ques,
        file_present: section_info[:file_present],
        experiment: options[:experiment],
        last_section: last_section,
        grouped_role_questions: options[:grouped_role_questions]
      }
      render :partial => "members/edit/general", locals: locals
    end
  end

  def render_settings_section(options = {})
    render :partial => "members/edit/settings", locals: options
  end
 

  def render_notifications_section
    render :partial => "members/edit/notifications"
  end

  def render_mentoring_settings_section(is_first_visit)
    ibox "feature.profile.label.mentoring_preferences".translate(:Mentoring => _Mentoring), {show_collapse_link: !is_first_visit, collapse_link_class: "pull-right", :ibox_class => (is_first_visit ? "" : "collapsed"), :ibox_content_id => "mentoring_settings"} do
      simple_form_for @profile_member, :html => {:multipart => true, :class => 'form-horizontal'} do |user|
        render :partial => "members/edit/mentoring_settings"
      end
    end
  end

  def get_availability_flash_and_scroll_to_id(user, is_connection_limit_zero, is_meeting_limit_zero, notify_user_if_unavailable)
    availability_flash = nil
    scroll_to_id = nil
    return [availability_flash, scroll_to_id] unless notify_user_if_unavailable

    scroll_to_id = if user.is_available_for_ongoing_and_one_time_mentoring? && (is_connection_limit_zero || is_meeting_limit_zero)
      is_connection_limit_zero ? "#settings_section_ongoing" : "#settings_section_onetime"
    elsif user.is_available_only_for_ongoing_mentoring? && is_connection_limit_zero
      "#settings_section_ongoing"
    elsif user.is_available_only_for_one_time_mentoring? && is_meeting_limit_zero
      "#settings_section_onetime"
    end

    availability_flash = "flash_message.program_flash.set_availability_flash".translate(mentoring: _mentoring) if scroll_to_id.present?
    [availability_flash, scroll_to_id]
  end

  def get_member_edit_title(section, role_str, member)
    if section == MembersController::EditSection::PROFILE || section == MembersController::EditSection::MENTORING_SETTINGS
      "feature.user.content.complete_your_role_profile".translate(role_str: role_str)
    else
      "feature.user.content.welcoming".translate(name: member.name)
    end
  end

  def member_program_roles(member)
    content = ''.html_safe
      member.users.each do |user|
        program = user.program
        content += content_tag(:div, '', :class => '') do
          content_tag(:b, link_to(program.name,program_root_path(:root => program.root)), :class =>'no-margin') +
          content_tag(:span, ' ('+RoleConstants.to_program_role_names(program, user.role_names).join(', ')+')', :class =>'')
        end
      end
    content
  end

  def member_state(member)
    MembersHelper.state_to_string_map[member.state]
  end

  def render_default_questions(user_or_membership_request, grouped_role_questions, form, options = {})
    skip_validation_hash = {}
    is_viewing_user_admin = current_user && current_user.is_admin?
    content = get_safe_string
    @current_organization.default_questions.each do |question|
      role_questions = grouped_role_questions[question.id]
      admin_only_viewable = !options[:membership_form] && !question.name_type? && (role_questions.nil? || role_questions.any?(&:restricted_to_admin_alone?))
      admin_only_editable = admin_only_viewable || role_questions.nil? || role_questions.any?(&:admin_only_editable)
      non_viewable = (admin_only_viewable && !is_viewing_user_admin)
      non_editable = (admin_only_editable && !is_viewing_user_admin)
      skip_validation_hash[question.question_type] = non_viewable || non_editable
      unless non_viewable
        content += render_name_or_email_question(user_or_membership_request, question, form, non_editable: non_editable, disabled: options[:disable][question.id], skip_visibility_info: options[:skip_visibility_info])
      end
    end
    options[:skip_validation_hash] ? [content, skip_validation_hash] : content
  end

  def render_name_or_email_question(user_or_membership_request, question, form, options = {})
    control_group(class: (question.name_type? && !options[:non_editable]) ? "cui_edit_name" : "") do
      profile_answer_label(question, user_or_membership_request, class: "col-sm-2", skip_visibility_info: options[:skip_visibility_info]) +
      if options[:non_editable].present?
        controls(class: 'col-sm-10') do
          content_tag(:p, class: "form-control-static") do
            render_non_editable_default_questions(user_or_membership_request, question, form) +
            fetch_formatted_profile_answers(user_or_membership_request, question, [], false)
          end
        end
      else
        get_name_or_email_response(question, form, options[:disabled])
      end
    end
  end

  def get_name_or_email_response(question, form, disabled)
    if question.name_type?
      render_user_name_fields(form, disabled, question: question)
    else
      content_tag(:div, class: "controls col-sm-10" + (form.object.errors[:email].present? ? ' has-error' : "")) do
        form.input :email, hint: question.help_text.try(:html_safe), as: :string, input_html: { disabled: disabled,
          class: "form-control" }, wrapper_html: { class: "no-margins" }, label_html: { class: 'sr-only' }, hint_html: { class: 'small text-muted' }
      end
    end
  end

  def render_user_name_with_label(form, disabled, options = {})
    control_group do
      (content_tag :div, set_required_field_label("display_string.Name".translate), class: "false-label control-label #{options[:horizontal_input_label_class] || "col-sm-2"}") +
      render_user_name_fields(form, disabled, options)
    end
  end

  def render_user_name_fields(form, disabled, options = {})
    controls(class: options[:horizontal_input_class] || "col-sm-10") do
      content_tag(:div, class: "row") do
        [:first_name, :last_name].inject(get_safe_string) do |content, attribute_name|
          content += content_tag(:div, { class: "col-sm-6 no-padding" + (form.object.errors[attribute_name].present? ? ' has-error' : "") }) do
            (form.label attribute_name, Member.human_attribute_name(attribute_name), :class => "sr-only") +
            (form.input attribute_name, label: false, wrapper_html: { class: "no-horizontal-margins col-xs-12 m-b-0" }, input_html: { class: 'form-control', required: true, disabled: disabled, placeholder: Member.human_attribute_name(attribute_name)})
          end
        end
      end +
      fetch_help_text(options[:question])
    end
  end

  def will_set_availability_help_text(member)
    "feature.profile.content.visit_set_availability_html".translate(click_here: link_to("display_string.Click_here".translate, member_url(member, :tab => MembersController::ShowTabs::AVAILABILITY)))
  end

  def link_to_member(member, is_visible, options = {})
    raise "display_string.Invalid_member".translate unless member

    url_opts = options.delete(:params) || {}

    user = nil
    return link_to_user(user, {:is_not_visible => !is_visible, :params => url_opts}) if program_view? && (user = member.user_in_program(current_program))

    return "display_string.You".translate if wob_member == member

    return "display_string.Anonymous".translate if !is_visible
    member_link = member_path(member, url_opts)
    return_value = link_to(member.name(:name_only => true), member_link)
    return return_value
  end

  def check_visibility?(member)
    if program_view? && (user = member.users.find{|user| user.program_id == current_program.id})
      user.visible_to?(current_user)
    else
      member.visible_to?(wob_member)
    end
  end

  def get_member_groups_tab_details(program, profile_user, groups_scope, status_filter)
    filter_fields = member_groups_filter_fields(program, profile_user)
    filter_fields.inject([]) do |tabs_array, filter_field|
      filter_field_label_with_count = "#{filter_field[:label]} (#{groups_scope.with_status(GroupsController::StatusFilters::MAP[filter_field[:value]]).size})"
      tabs_array << {
        label: filter_field_label_with_count,
        url: member_path(profile_user.member, {tab: MembersController::ShowTabs::MANAGE_CONNECTIONS, filter: filter_field[:value], page: 1}),
        active: (filter_field[:value].to_s == status_filter.to_s)
      }
    end
  end

  def need_profile_complete_sidebar?(user)
    !user.hide_profile_completion_bar? && !session[UsersController::SessionHidingKey::PROFILE_COMPLETE_SIDEBAR]
  end

  def member_photo_select(member, profile_member, show_image=false)
    member.fields_for :profile_picture do |picture|
      control_group do
        content_tag(:div, "feature.user.photo.photo".translate, :class => "false-label control-label col-sm-2") +
        controls(class: "col-sm-10") do
          content_tag(:div, :class => "well white-bg") do
            edit_picture_field(profile_member, picture, show_image)
          end
        end
      end
    end
  end

  def get_org_level_connection_status(member)
    return unless member
    connection_statuses = member.users.collect{ |user| get_track_level_connection_status(user) }
    if connection_statuses.include?(User::ConnectionStatusForGA::CURRENT)
      User::ConnectionStatusForGA::CURRENT
    elsif connection_statuses.include?(User::ConnectionStatusForGA::PAST)
      User::ConnectionStatusForGA::PAST
    elsif never_connected?(connection_statuses)
      User::ConnectionStatusForGA::NEVER
    elsif connection_statuses.include?(User::ConnectionStatusForGA::NA)
      User::ConnectionStatusForGA::NA
    end
  end

  def get_first_profile_section(pending_profile_questions)
    pending_profile_section_questions = get_simple_section_questions(pending_profile_questions)
    profile_section = pending_profile_section_questions.first
    return profile_section
  end

  def render_add_role_without_approval(profile_user, program)
    to_add_role = profile_user.get_applicable_role_to_add_without_approval(program)

    return unless to_add_role.present?

    content = content_tag(:hr)
    content += content_tag(:div, class: "text-center") do
      content_tag(:p, "feature.profile.content.add_other_role_without_approval_v1".translate(to_add_role: to_add_role.customized_term.articleized_term_downcase, program: _program), class: "text-muted p-t-sm no-margins" ) +
      content_tag(:u, link_to_function("display_string.Click_here".translate, "jQueryShowQtip('#confirm_add_role', 600, '#{add_role_popup_user_path(current_user)}', '', {modal: true});", class: "font-bold"))
    end
    content
  end

  private

  ## Before this code was replicated in two places - members/show.html.erb, members/_show_mentor.html.erb
  ## Moved to a common method, but in general, we need to see why role specific pages have been created in the first place.
  def member_groups_filter_fields(program, profile_user)
    filter_fields = get_member_groups_tabs_header_data
      filter_fields.delete_if { |filter_field| filter_field[:value] == GroupsController::StatusFilters::Code::PENDING } unless program.project_based?
    unless program.project_based? && (program.mentoring_roles_with_permission(RolePermission::PROPOSE_GROUPS).exists? || profile_user.groups.where(status: [Group::Status::PROPOSED, Group::Status::REJECTED]).exists?)
      filter_fields.delete_if { |filter_field| filter_field[:value] == GroupsController::StatusFilters::Code::PROPOSED }
      filter_fields.delete_if { |filter_field| filter_field[:value] == GroupsController::StatusFilters::Code::REJECTED }
    end

    unless (program.project_based? && profile_user.groups.where(status: [Group::Status::WITHDRAWN]).exists?)
      filter_fields.delete_if { |filter_field| filter_field[:value] == GroupsController::StatusFilters::Code::WITHDRAWN }
    end
    filter_fields
  end

  def never_connected?(connection_status)
    connection_status.include?(User::ConnectionStatusForGA::NEVER_CONNECTED_INITIATED) || connection_status.include?(User::ConnectionStatusForGA::NEVER_CONNECTED_NEVER_INITIATED)
  end

  def get_member_groups_tabs_header_data
    return [
      {:value => GroupsController::StatusFilters::Code::ONGOING, :label => "feature.connection.header.status.Ongoing".translate },
      {:value => GroupsController::StatusFilters::Code::CLOSED,   :label => "feature.connection.header.status.Closed".translate },
      {:value => GroupsController::StatusFilters::Code::DRAFTED,   :label => "feature.connection.header.status.Drafted".translate },
      {:value => GroupsController::StatusFilters::Code::PENDING,   :label => "feature.connection.header.status.Available".translate },
      {:value => GroupsController::StatusFilters::Code::PROPOSED,   :label => "feature.connection.header.status.Proposed".translate },
      {:value => GroupsController::StatusFilters::Code::REJECTED,   :label => "feature.connection.header.status.Rejected".translate },
      {:value => GroupsController::StatusFilters::Code::WITHDRAWN,   :label => "feature.connection.header.status.Withdrawn".translate }
    ]
  end

  def edit_tab_title(tab)
    content = get_safe_string
    tabcontent=""
    case tab
    when MembersController::Tabs::PROFILE
      icon_class = "fa-user"
      tabcontent = "feature.profile.label.profile".translate
    when MembersController::Tabs::SETTINGS
      icon_class = "fa-cog"
      tabcontent = "feature.profile.label.settings".translate
    when MembersController::Tabs::NOTIFICATIONS
      icon_class = "fa-bell"
      tabcontent = "feature.profile.label.notifications".translate
    end
    content += embed_icon("fa-fw fa-lg fa #{icon_class} no-margins")
    content += content_tag(:span , tabcontent , class: "m-l-xs m-r-xxs hidden-xs") + content_tag(:div, tabcontent, class: "m-r-xxs visible-xs small m-t-xs font-bold")
    content
  end


  def current_notification_settting_values(user)
    setting_hash={}
    notification_settings = user.user_notification_settings.index_by(&:notification_setting_name)
    UserNotificationSetting::SettingNames.all.each do |setting_name|
      setting_hash[setting_name] = notification_settings[setting_name].try(:disabled) || false
    end
    setting_hash
  end


  def notification_section_content
    content = {}
    content[UserNotificationSetting::SettingNames::END_USER_COMMUNICATION] = {title: "feature.profile.label.end_user_notifications", description: "feature.profile.content.end_user_notifications"}
    content[UserNotificationSetting::SettingNames::PROGRAM_MANAGEMENT] = {title: "feature.profile.label.program_management_notifications", description: "feature.profile.content.program_management_notifications"}
    content[UserNotificationSetting::SettingNames::DIGEST_AND_ALERTS] = {title: "feature.profile.label.program_digest_notifications", description: "feature.profile.content.program_digest_notifications"}
    content
  end


  def render_non_editable_default_questions(user_or_membership_request, question, form)
    if question.email_type?
      form.hidden_field :email, value: user_or_membership_request.email
    elsif question.name_type?
      form.hidden_field(:first_name, value: user_or_membership_request.first_name) +
      form.hidden_field(:last_name, value: user_or_membership_request.last_name)
    end
  end

  def get_green_and_gray_profile_sections(all_profile_section_ids, profile_questions_per_section, sections_filled)
    green_section_ids = []
    all_profile_section_ids.each do |section_id|
      green_section_ids << section_id if (profile_questions_per_section[section_id].blank? && section_id != MembersController::EditSection::MENTORING_SETTINGS && section_id != MembersController::EditSection::CALENDAR_SYNC_V2_SETTINGS) || sections_filled.include?(section_id.to_s)
    end
    green_section_ids = green_section_ids.uniq
    gray_section_ids = all_profile_section_ids - green_section_ids.uniq
    [green_section_ids, gray_section_ids]
  end

  def get_first_time_profile_section_title(all_profile_section_titles_hash, section_id)
    if section_id == MembersController::EditSection::MENTORING_SETTINGS 
      return "feature.profile.label.mentoring_preferences".translate(:Mentoring => _Mentoring)
    elsif section_id == MembersController::EditSection::CALENDAR_SYNC_V2_SETTINGS
      return "program_settings_strings.tab.calendar".translate
    else
      return all_profile_section_titles_hash[section_id]
    end
  end

  def get_guidance_popup_action_label(src)
    src == OneTimeFlag::Flags::Popups::MENTEE_GUIDANCE_POPUP_TAG ? 'verify_organization_page.label.get_started'.translate : "feature.user.label.find_mentor".translate(a_mentor: _a_mentor)
  end

end