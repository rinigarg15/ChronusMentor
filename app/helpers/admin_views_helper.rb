module AdminViewsHelper
  include DateProfileFilter
  include DateTranslationHelper

  ACCORDION_PANE_CONTENT_CLASS = "well well-small no-border attach-bottom"
  MAX_LENGTH_ROLE_NAME = 20
  MAX_LENGTH_PROGRAM_NAME = 40
  COLUMN = "column"

  DYNAMIC_FILTER_PARAMS_HASH = {
    AdminViewColumn::Columns::Key::STATE => :state,
    AdminViewColumn::Columns::Key::GROUPS => :connected,
    AdminViewColumn::Columns::Key::ROLES => :role
  }

  module BulkActionType
    SEND_MESSAGE = 1
    SUSPEND_MEMBERSHIP = 2
    REMOVE_USER = 3
    ADD_ROLE = 4
    ADD_TAGS = 5
    INVITE_TO_PROGRAM = 6
    ADD_TO_PROGRAM = 7
    RESEND_SIGNUP_INSTR = 8
    SUSPEND_MEMBER_MEMBERSHIP = 9
    REMOVE_MEMBER = 10
    REACTIVATE_MEMBERSHIP = 11
    REACTIVATE_MEMBER_MEMBERSHIP = 12
    REMOVE_TAGS = 13
    ADD_TO_CIRCLE = 14
  end

  module QuestionType
    HAS_LESS_THAN = 1
    HAS_GREATER_THAN = 2
    WITH_VALUE = 3
    ANSWERED = 4
    NOT_ANSWERED = 5
    BETWEEN = 6
    IN = 7
    NOT_IN = 8
    NOT_WITH_VALUE = 9
    MATCHES = 10
    DATE_TYPE = 11
  end

  module Rating
    NOT_RATED = "not_rated"
    LESS_THAN = "less_than"
    GREATER_THAN = "greater_than"
    EQUAL_TO = "equal_to"
  end

  module RatingOptions
    ZERO = 0
    ONE = 1
    TWO = 2
    THREE = 3
    FOUR = 4
    FIVE = 5
  end

  def get_table_headers_json(admin_view_columns)
    headers = [ { title: get_primary_checkbox_for_kendo_grid("cjs_admin_view_primary_checkbox"), field: "check_box", encoded: false, sortable: false, filterable: false, width: Kendo::CHECK_BOX_WIDTH } ]
    if @admin_view.is_program_view?
      headers << { title: "feature.admin_view.label.Actions".translate, field: "actions", encoded: false , sortable: false, filterable: false, width: Kendo::ACTIONS_WIDTH }
    end

    choices_map = get_choices_map_for_admin_view(admin_view_columns)
    admin_view_columns.each do |column|
      title = h(column.get_title(get_custom_term_options))
      field_name = column.column_key || "#{COLUMN}#{column.id}"
      filter_option =
        if column.column_key == AdminViewColumn::Columns::Key::RATING
          false
        else
          get_kendo_filterable_options(field_name, choices_map, extra: AdminViewColumn::Columns::DateRangeColumns.all(@admin_view).include?(field_name))
        end
      headers << { headerTemplate: kendo_column_header_wrapper(title), field: field_name, encoded: false, filterable: filter_option, width: Kendo::DEFAULT_WIDTH }
    end
    headers.to_json
  end

  def get_choices_map_for_admin_view(admin_view_columns)
    choices_map = {}

    admin_view_columns.each do |column|
      profile_question = column.profile_question
      field_name = column.column_key || "#{COLUMN}#{column.id}"
      choices_map[field_name] =
        case column.column_key
        when AdminViewColumn::Columns::Key::ROLES
          @current_program.roles.collect do |role|
            { title: RoleConstants.human_role_string([role.name], program: @current_program), value: role.name }
          end
        when AdminViewColumn::Columns::Key::STATE
          (@admin_view.is_program_view? ? UsersHelper : MembersHelper).state_to_string_map.map { |value, title| { title: title, value: value } }
        when AdminViewColumn::Columns::Key::LANGUAGE
          [ { title: Language.for_english.title, value: Language.for_english.id.to_i } ] + Language.supported_for(super_console?, wob_member, program_context).map { |language| { title: language.get_title_in_organization(@current_organization), value: language.id } }
        when AdminViewColumn::Columns::Key::PROGRAM_USER_ROLES
          programs = wob_member.admin_only_at_track_level? ? get_ordered_managing_programs : @current_organization.programs.ordered
          programs.select(:id).includes(:translations).map { |program| { title: program.name, value: program.id } }
        when AdminViewColumn::Columns::Key::MENTORING_MODE
          mentoring_mode_to_string_map(@current_program).map{ |value,title| { title: title, value: value } }
        else
          if profile_question.present?
            if profile_question.file_type?
              [ { title: "feature.admin_view.select_option.Answered_v1".translate, value: true }, { title: "feature.admin_view.select_option.Not_Answered_v1".translate, value: false } ]
            elsif profile_question.choice_or_select_type?
              profile_question.values_and_choices.collect do |value, choice|
                { title: h(choice), value: h(value) }
              end
            end
          end
        end
    end
    choices_map
  end

  def get_table_content_json(users_or_members, admin_view_columns)
    content = []
    is_program_view = @admin_view.is_program_view?
    options = {:program => @current_program, :is_program_view => is_program_view}
    options.merge!(:date_ranges => @date_ranges) if @date_ranges.present?

    options = fetch_active_and_closed_engagements_map(users_or_members, admin_view_columns, options) unless is_program_view

    users_or_members.each do |users_or_member|
      content << populate_row(users_or_member, @admin_view_columns, @profile_answers_hash, @member_program_and_roles, options)
    end
    content.to_json.html_safe
  end

  def fetch_active_and_closed_engagements_map(users_or_members, admin_view_columns, options)
    admin_view_column_keys = admin_view_columns.collect(&:column_key) 
    ongoing_engagements_map = admin_view_column_keys.include?(AdminViewColumn::Columns::Key::ORG_LEVEL_ONGOING_ENGAGEMENTS) ? Member.get_groups_count_map_for_status(users_or_members.collect(&:id), Group::Status::ACTIVE_CRITERIA) : {}
    closed_engagements_map = admin_view_column_keys.include?(AdminViewColumn::Columns::Key::ORG_LEVEL_CLOSED_ENGAGEMENTS) ? Member.get_groups_count_map_for_status(users_or_members.collect(&:id), Group::Status::CLOSED) : {}
    options.merge(ongoing_engagements_map: ongoing_engagements_map, closed_engagements_map: closed_engagements_map)
  end

  def kendo_options_json(dynamic_filter_params={}, options = {})
    {
      readUrl: admin_view_path(@admin_view, default: true, alert_id: @alert.try(:id)),
      autoCompleteUrl: @admin_view.is_program_view? ? auto_complete_for_name_users_path(format: :json, show_all_users: true) : auto_complete_for_name_members_path(format: :json, show_all_members: true),
      autoCompleteFields: [AdminViewColumn::Columns::Key::FIRST_NAME, AdminViewColumn::Columns::Key::LAST_NAME, AdminViewColumn::Columns::Key::EMAIL],
      numericFields: [AdminViewColumn::Columns::Key::PROFILE_SCORE, AdminViewColumn::Columns::Key::AVAILABLE_SLOTS, AdminViewColumn::Columns::Key::NET_RECOMMENDED_COUNT, AdminViewColumn::Columns::Key::GROUPS, AdminViewColumn::Columns::Key::CLOSED_GROUPS, AdminViewColumn::Columns::Key::DRAFTED_GROUPS, AdminViewColumn::Columns::Key::ORG_LEVEL_ONGOING_ENGAGEMENTS, AdminViewColumn::Columns::Key::ORG_LEVEL_CLOSED_ENGAGEMENTS],
      dateFields: AdminViewColumn::Columns::DateRangeColumns.all(options[:admin_view]),
      sortField: @sort_param,
      sortDir: @sort_order,
      perPage: @items_per_page,
      perPageOptions: AdminViewConstants::PER_PAGE_OPTIONS,
      fromPlaceholder: 'display_string.From'.translate,
      toPlaceholder: 'display_string.To'.translate,
      filters: get_formatted_admin_view_kendo_filter(dynamic_filter_params),
      messages: kendo_options_messages,
      customAccessibilityMessages: kendo_custom_accessibilty_messages
    }.to_json
  end

  def kendo_options_messages
    entry_name = context_term(@admin_view)
    {
      itemsPerPage: 'feature.admin_view.kendo_pagination.messages.itemsPerPage'.translate(entry_name: entry_name),
      first: 'feature.admin_view.kendo_pagination.messages.first'.translate,
      previous: 'feature.admin_view.kendo_pagination.messages.previous'.translate,
      next: 'feature.admin_view.kendo_pagination.messages.next'.translate,
      last: 'feature.admin_view.kendo_pagination.messages.last'.translate,
      empty: 'feature.admin_view.kendo_pagination.messages.empty'.translate(entry_name: entry_name),
      display: 'feature.admin_view.kendo_pagination.messages.display'.translate(entry_name: entry_name)
    }.merge!(kendo_operator_messages)
  end

  def get_formatted_admin_view_kendo_filter(dynamic_filter_params)
    if dynamic_filter_params.present?
      return {filters: get_filters_for_admin_view_kendo_filter(dynamic_filter_params), logic: "and"}
    else
      return {}
    end
  end

  def check_dynamic_filter_params_if_columns_not_present(dynamic_filter_params, admin_view_column_keys)
    if dynamic_filter_params.present?
      columns_keys_to_check = []
      DYNAMIC_FILTER_PARAMS_HASH.each do |col_key, hash_key|
        columns_keys_to_check << col_key if dynamic_filter_params[hash_key].present?
      end
      missing_columns = columns_keys_to_check.select{|column_key| !admin_view_column_keys.include?(column_key)}
      return missing_columns
    else
      return []
    end
  end

  def get_missing_dynamic_filter_columns_text(missing_dynamic_filter_columns, click_here_text)
    options = get_custom_term_options
    colunm_names = missing_dynamic_filter_columns.map{|key| AdminViewColumn::Columns::ProgramDefaults.defaults(options)[key][:title]}.to_sentence
    "feature.admin_view.content.missing_dynamic_filter_columns_warning_html".translate(click_here: click_here_text, count: missing_dynamic_filter_columns.size, colunm_names: colunm_names)
  end

  def get_campaign_for_select2(ref_obj)
    return {} unless ref_obj.is_a?(CampaignManagement::AbstractCampaign)
    {campaign_id: ref_obj.new_record? ? "" : ref_obj.id}
  end

  def render_admin_view_info(ref_obj, program = current_program)
    return {id:"", title: ""} if ref_obj.new_record?
    if ref_obj.is_a?(CampaignManagement::AbstractCampaign)
      admin_view_id = ref_obj.trigger_params[1][0]
      {id: admin_view_id, title: program.admin_views.find_by(id: admin_view_id).title}
    else
      admin_view = ref_obj.resource_publications.find_by(program_id: program.id).admin_view
      admin_view.present? ? {id: admin_view.id, title: admin_view.title} : {id: "", title: ""}
    end
  end

  def get_bulk_actions_box(admin_view, options = {})
    bulk_popup_path = bulk_confirmation_view_admin_view_path(admin_view)
    action_export_to_csv = {:label => append_text_to_icon("fa fa-fw fa-download", "feature.admin_view.action.Export_to_csv".translate), :url => "#", :id => "cjs_export_csv", :data => {}}
    if admin_view.is_organization_view?
      allow_org_admin_actions = options[:member].nil? || options[:member].admin?
      bulk_actions = []
      bulk_actions <<  {:label => append_text_to_icon("fa fa-fw fa-envelope-o", "feature.admin_view.action.send_message".translate), :url => "#", :id => "cjs_send_message",
        :data => {:url => new_bulk_admin_message_admin_messages_path, :type => BulkActionType::SEND_MESSAGE, param_name: "members"}} if allow_org_admin_actions && !admin_view.organization.standalone?
      bulk_actions <<  {:label => append_text_to_icon("fa fa-fw fa-envelope", "feature.admin_view.action.Invite_to_Program".translate), :url => "#", :id => "cjs_invite_to_program",
        :data => {:type => BulkActionType::INVITE_TO_PROGRAM }}
      bulk_actions <<  {:label => append_text_to_icon("fa fa-fw fa-plus", "feature.admin_view.action.Add_to_Program".translate), :url => "#", :id => "cjs_add_to_program",
        :data => {:type => BulkActionType::ADD_TO_PROGRAM }}
      bulk_actions << action_export_to_csv
      if allow_org_admin_actions
        bulk_actions << {:render => content_tag(:li, "", :class => "divider")}
        bulk_actions += [
          {:label => append_text_to_icon("fa fa-fw fa-check", "feature.admin_view.action.Reactivate_Membership".translate), :url => "#", :id => "cjs_reactivate_member_membership",
              :data => {:type => BulkActionType::REACTIVATE_MEMBER_MEMBERSHIP }},
          {:label => append_text_to_icon("fa fa-fw fa-times", "feature.admin_view.action.Suspend_Membership".translate), :url => "#", :id => "cjs_suspend_member_membership",
              :data => {:type => BulkActionType::SUSPEND_MEMBER_MEMBERSHIP }},{:render => content_tag(:li, "", :class => "divider")},
          {:label => append_text_to_icon("fa fa-fw fa-trash", "feature.admin_view.action.Remove_Member".translate), :url => "#", :id => "cjs_remove_member",
              :data => {:type => BulkActionType::REMOVE_MEMBER }}
        ]
      end
    else
      bulk_actions = [
        {:label => append_text_to_icon("fa fa-fw fa-envelope-o", "feature.admin_view.action.send_message".translate), :url => "#", :id => "cjs_send_message",
        :data => {:url => new_bulk_admin_message_admin_messages_path, :type => BulkActionType::SEND_MESSAGE, param_name: "users" }},
        {:label => append_text_to_icon("fa fa-fw fa-user", "feature.admin_view.action.Add_Role".translate), :url => "#", :id => "cjs_add_role",
          :data => {:type => BulkActionType::ADD_ROLE }}]
      circle_name = admin_view.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term_downcase
      bulk_actions << { label: append_text_to_icon("fa fa-fw fa-plus", "feature.admin_view.action.add_to_circle".translate(circle_name: circle_name)), url: "#", id: "cjs_add_to_circle", data: { type: BulkActionType::ADD_TO_CIRCLE, title: "feature.admin_view.action.add_users_to_circle".translate(circle_name: circle_name) } } if admin_view.program.project_based?
      if options[:member_tagging_enabled]
        bulk_actions << {label: append_text_to_icon("fa fa-fw fa-plus", "feature.admin_view.action.Add_Tags".translate), url: "#", id: "cjs_add_tags",
          data: {type: BulkActionType::ADD_TAGS }}
        bulk_actions << {label: append_text_to_icon("fa fa-fw fa-minus-circle", "feature.admin_view.action.Remove_Tags".translate), url: "#", id: "cjs_remove_tags",
        data: {type: BulkActionType::REMOVE_TAGS }}
      end
      bulk_actions << action_export_to_csv
      bulk_actions << {:label => append_text_to_icon("fa fa-fw fa-retweet", "feature.admin_view.action.Resend_signup_instructions".translate), :url => "#", :id => "cjs_resend_signup_instr",
        :data => {:type => BulkActionType::RESEND_SIGNUP_INSTR}}

      bulk_actions << {:render => content_tag(:li, "", :class => "divider")}
      bulk_actions += [
        {:label => append_text_to_icon("fa fa-fw fa-check", "feature.admin_view.action.Reactivate_Membership".translate), :url => "#", :id => "cjs_reactivate_membership",
            :data => {:type => BulkActionType::REACTIVATE_MEMBERSHIP }},
        {:label => append_text_to_icon("fa fa-fw fa-times", "feature.admin_view.action.Deactivate_Membership".translate), :url => "#", :id => "cjs_suspend_membership",
            :data => {:type => BulkActionType::SUSPEND_MEMBERSHIP }},{:render => content_tag(:li, "", :class => "divider")},
        {:label => append_text_to_icon("fa fa-fw fa-trash", "feature.admin_view.action.Remove_User".translate), :url => "#", :id => "cjs_remove_from_program",
            :data => {:type => BulkActionType::REMOVE_USER }}
      ]
    end

    bulk_actions.each{|action_hash| action_hash[:data].reverse_merge!(:url => bulk_popup_path) if action_hash[:data].present?}
    dropdown_buttons_or_button(bulk_actions, dropdown_title: 'display_string.Actions'.translate, is_not_primary: true, embed_icon: true, primary_btn_class: "btn-white cur_page_info")
  end

  def add_users_dropdown
    bulk_actions = [
      {:label => "feature.admin_view.action.Add_Users".translate, :url => new_user_path},
      {:label => "feature.admin_view.action.Invite_Users".translate, :url =>  invite_users_path}
    ]
    bulk_actions
  end

  def get_back_link_label(source_info)
    return "feature.admin_view.back_link.views".translate if source_info.nil?
    case source_info[:controller]
    when "bulk_matches"
      "feature.admin_view.back_link.bulk_match".translate
    when "program_events"
      "feature.admin_view.back_link.program_event_v1".translate
    when "campaign_management/user_campaigns"
      "feature.admin_view.back_link.campaign_v1".translate
    end
  end

  def get_bulk_action_partial(bulk_action_type)
    bulk_action_popup = case bulk_action_type
    when BulkActionType::ADD_ROLE
      render :partial => "admin_views/bulk_add_role"
    when BulkActionType::ADD_TAGS, BulkActionType::REMOVE_TAGS
      render :partial => "admin_views/bulk_add_or_remove_tags", locals: {remove_tags: (bulk_action_type == BulkActionType::REMOVE_TAGS)}
    when BulkActionType::REMOVE_USER
      render :partial => "admin_views/bulk_remove_user"
    when BulkActionType::SUSPEND_MEMBERSHIP
      render :partial => "admin_views/bulk_suspend_membership"
    when BulkActionType::REACTIVATE_MEMBERSHIP
      render :partial => "admin_views/bulk_reactivate_membership"
    when BulkActionType::INVITE_TO_PROGRAM
      render :partial => "admin_views/bulk_invite_to_program"
    when BulkActionType::ADD_TO_PROGRAM
      render :partial => "admin_views/bulk_add_to_program", :locals => {:admin_view => @admin_view, :members => @members, :from => AdminViewsController::REFERER::ADMIN_VIEW}
    when BulkActionType::RESEND_SIGNUP_INSTR
      render :partial => "admin_views/bulk_resend_signup_instructions"
    when BulkActionType::SUSPEND_MEMBER_MEMBERSHIP
      render :partial => "admin_views/bulk_suspend_member_membership"
    when BulkActionType::REACTIVATE_MEMBER_MEMBERSHIP
      render :partial => "admin_views/bulk_reactivate_member_membership"
    when BulkActionType::REMOVE_MEMBER
      render :partial => "admin_views/bulk_remove_member"
    when BulkActionType::ADD_TO_CIRCLE
      render partial: "admin_views/bulk_add_to_circle"
    end
    return bulk_action_popup
  end

  def populate_row(user_or_member, admin_view_columns, profile_answers_hash = {}, member_program_and_roles = {}, options = {})
    td_text = get_safe_string
    results_hash = Hash.new
    results_hash["check_box"] = content_tag(:input, "", type: "checkbox", class: "cjs_admin_view_record", id: "ct_admin_view_checkbox_#{user_or_member.id}", value: "#{user_or_member.id}") +
      label_tag("ct_admin_view_checkbox_#{user_or_member.id}", "#{'display_string.Select'.translate} #{user_or_member.name(name_only: true)}", class: "sr-only")
    results_hash["actions"] = populate_actions(user_or_member) if options[:is_program_view]

    admin_view_columns.each do |column|
      html_options = {}
      formated_answer = format_answer(user_or_member, column.get_answer(user_or_member, profile_answers_hash, options), column, member_program_and_roles)
      title = column.column_key || "#{COLUMN}#{column.id}"
      results_hash[title] = h(formated_answer)
    end
    results_hash
  end

  def populate_actions(user_or_member)
    actions = get_safe_string
    user_or_member_name = user_or_member.name(name_only: true)

    unless (current_user == user_or_member) || working_on_behalf? || !@current_program.has_feature?(FeatureName::WORK_ON_BEHALF) || (user_or_member.member.admin? && !current_member.admin?)
      actions += link_to(work_on_behalf_user_path(user_or_member), method: :post, class: "inline", data: { toggle: "tooltip", title: "feature.admin_view.content.Work_on_Behalf".translate } ) do
        get_icon_content("fa fa-user-secret text-default") + set_screen_reader_only_content("feature.profile.content.wob_help_text_html".translate(user_name: user_or_member_name))
      end
    end
    actions += link_to(edit_member_path(user_or_member.member), class: "inline", data: { toggle: "tooltip", title: "app_layout.label.edit_profile".translate } ) do
      get_icon_content("fa fa-pencil text-default") + set_screen_reader_only_content("feature.profile.actions.edit_users_profile".translate(user_name: user_or_member_name))
    end
    content_tag(:div, actions, class: "text-center")
  end

  def format_answer(user_or_member, answer, column, member_program_and_roles)
    user_or_member.is_a?(User) ? format_user_answer(user_or_member, answer, column) : format_member_answer(user_or_member, answer, column, member_program_and_roles)
  end

  def format_user_answer(user, answer, column)
    if column.is_default?
      if column.column_key == AdminViewColumn::Columns::Key::ROLES
        li_array = []
        answer.split(AdminViewColumn::ROLES_SEPARATOR).each do |role_name|
          li_array << content_tag(:li, role_name)
        end
        answer = content_tag(:ul, li_array.join("").html_safe, :class => "unstyled no-margin")
      elsif [AdminViewColumn::Columns::Key::FIRST_NAME, AdminViewColumn::Columns::Key::LAST_NAME].include?(column.column_key)
        answer = link_to(answer, member_path(user.member))
      end
    elsif answer.is_a?(Array)
      answer = format_non_default_columns(answer, column)
    end
    answer
  end

  def format_experience_answer(fields, options = {} )
    separator = options[:for_csv] ? "-" : get_safe_string("&ndash;")
    title, start_year, end_year, company = fields
    res = []
    res << title if title.present?
    unless start_year.to_i.zero?
      years = [start_year]
      years << (end_year.to_i.zero? ? 'feature.admin_view.content.current'.translate : end_year)
      res << safe_join(years, separator)
    end
    res << company if company.present?
    safe_join(res, ", ")
  end

  def format_publication_answer(fields, options = {} )
    title, publisher, date, url, authors, desc = fields
    res = []
    res << ((url.present? && !options[:for_csv]) ? link_to(title, url, :target => "_blank") : title)
    res << publisher if publisher.present?
    res << date if date.present?
    res << authors if authors.present?
    safe_join(res, ", ")
  end

  def format_manager_answer(fields, options = {} )
    first_name, last_name, email = fields
    email = options[:for_csv] ? email : mail_to(email)
    get_safe_string + first_name.to_s + " "+ last_name.to_s + " (" + email.to_s + ")" if fields.present?
  end


  def format_member_answer(member, answer, column, member_program_and_roles)
    if column.is_default?
      if [AdminViewColumn::Columns::Key::FIRST_NAME, AdminViewColumn::Columns::Key::LAST_NAME].include?(column.column_key)
        answer = link_to(answer, member_path(member))
      elsif column.column_key == AdminViewColumn::Columns::Key::PROGRAM_USER_ROLES
        answer = member_sorted_program_roles(member, member_program_and_roles)
      end
    elsif answer.is_a?(Array)
      answer = format_non_default_columns(answer, column)
    end
    return answer
  end

  def format_non_default_columns(answer, column)
    if column.profile_question.file_type?
      link_to(answer[0], answer[1], :target => "_blank")
    elsif column.profile_question.education?
      render_more_less_rows(answer.map { |a| safe_join(a.reject(&:blank?), ", ") })
    elsif column.profile_question.experience?
      render_more_less_rows(answer.map { |a| format_experience_answer(a) })
    elsif column.profile_question.publication?
      render_more_less_rows(answer.map { |a| format_publication_answer(a) })
    elsif column.profile_question.manager?
      format_manager_answer(answer)
    end
  end

  def admin_view_section_title(step_number, header_text, options = {})
    title_text = options.delete(:skip_step_title) ? header_text : "feature.admin_view.header.step_title".translate(:step_number => step_number, :header_text => header_text)
    desc_content = get_safe_string
    if options[:desc].present?
      desc_content << content_tag(:small, options[:desc], :class => "m-l-xs")
    end
    title_text + desc_content
  end

  # To be cleaned up after choosing a fixed UI
  def old_field_set_wrapper(&block)
    content_tag(:div, capture(&block), :class => "clearfix has-below-3 has-above-1 row-fluid")
  end

  def field_set_wrapper(title, is_first = false, is_edit_view = false, &block)
    should_collapse = is_first || is_edit_view
    content_tag(:div, :class => "#{"m-t-0" unless is_first} m-b-0") do
      panel(title, :panel_class => "panel-default") do
        capture(&block)
      end
    end
  end

  def admin_view_page_actions(admin_view)
    actions = []
    actions << { label: "feature.admin_view.action.Update_View".translate, url: edit_admin_view_path(admin_view) }
    actions << get_delete_admin_view_action_hash(admin_view) if admin_view.deletable?
    actions
  end

  def get_update_admin_view_confirm_text(admin_view)
    in_management_report_metrics = admin_view.metrics.select(:id).present?
    in_campaigns = CampaignManagement::CampaignProcessor.instance.campaign_using_admin_view(admin_view)
    in_events = ProgramEvent.where(admin_view_id: admin_view.id).upcoming.select(:id).includes(:translations)
    in_match_report = MatchReportAdminView.where(admin_view_id: admin_view.id).present?

    auto_impacted_list = get_auto_impacted_list(in_management_report_metrics, in_campaigns, in_match_report)
    all_impacted_list = get_all_impacted_list(in_management_report_metrics, in_campaigns, in_match_report)
    all_impacted_list += in_events.collect { |event| link_to(event.title, program_event_path(event)) + " #{'feature.program_event.back_link.program_event_v1'.translate}" }
    confirmation_message = all_impacted_list.present? ? set_confirmation_message_for_update(all_impacted_list, auto_impacted_list, in_events) : ""
    confirmation_message.html_safe
  end

  def set_confirmation_message_for_update(all_impacted_list, auto_impacted_list, in_events)
    create_new_view_link = link_to('feature.admin_view.content.update_confirmation.create_new_view'.translate, new_admin_view_path)
    confirmation_message = ""
    confirmation_message += "feature.admin_view.content.update_confirmation.view_is_pinned_to_html".translate(objects_with_links: all_impacted_list.to_sentence.html_safe)
    confirmation_message += " #{'feature.admin_view.content.update_confirmation.updating_this_view_will_affect'.translate(objects: auto_impacted_list.to_sentence)}" if auto_impacted_list.present?
    confirmation_message += " #{'feature.admin_view.content.update_confirmation.event_implications'.translate}" if in_events.present?
    confirmation_message += " #{'feature.admin_view.content.update_confirmation.alternatively_create_new_view_html'.translate(new_view_link: create_new_view_link)}"
    confirmation_message += " #{'display_string.do_you_want_to_continue'.translate}"
    return confirmation_message
  end

  def get_auto_impacted_list(in_management_report_metrics, in_campaigns, in_match_report)
    auto_impacted_list = []
    auto_impacted_list << "feature.admin_view.content.update_confirmation.dashboard".translate if in_management_report_metrics
    auto_impacted_list << "feature.admin_view.content.update_confirmation.campaign_target_audience".translate if in_campaigns.present?
    auto_impacted_list << "feature.match_report.header.match_report".translate if in_match_report
    return auto_impacted_list
  end

  def get_all_impacted_list(in_management_report_metrics, in_campaigns, in_match_report)
    all_impacted_list = []
    all_impacted_list << link_to("#{_Admin} #{'feature.admin_view.content.update_confirmation.Dashboard'.translate}", management_report_path) if in_management_report_metrics
    all_impacted_list << link_to("#{_Admin} #{'feature.match_report.header.match_report'.translate}", match_reports_path) if in_match_report
    all_impacted_list += in_campaigns.collect { |campaign| link_to(campaign.title, details_campaign_management_user_campaign_path(campaign)) + " #{'feature.admin_view.content.update_confirmation.email_campaign'.translate}" }
    return all_impacted_list
  end

  def get_delete_admin_view_action_hash(admin_view)
    in_management_report_metrics = admin_view.metrics.select(:id).present?
    in_campaigns = CampaignManagement::CampaignProcessor.instance.campaign_using_admin_view(admin_view)
    in_bulk_match = admin_view.is_part_of_bulk_match?
    in_match_report = MatchReportAdminView.where(admin_view_id: admin_view.id).present?

    if in_campaigns.present? # Block Deletion
      link_to_campaigns = in_campaigns.collect { |campaign| link_to(campaign.title, details_campaign_management_user_campaign_path(campaign)) }
      alert_message = "feature.campaigns.errors.cannot_delete_admin_view_html".translate(campaign_links: link_to_campaigns.to_sentence.html_safe, count: link_to_campaigns.size)
      action = {
        label: "feature.admin_view.action.Delete_View".translate,
        js: "alert('#{j alert_message}');"
      }
    else
      confirmation_message = set_confirmation_message_for_delete(in_bulk_match, in_management_report_metrics, in_match_report)
      action = {
        label: "feature.admin_view.action.Delete_View".translate,
        url: admin_view_path(admin_view),
        method: :delete,
        data: { confirm: confirmation_message.html_safe }
      }
    end
    action
  end

  def set_confirmation_message_for_delete(in_bulk_match, in_management_report_metrics, in_match_report)
    match_report_link = link_to("feature.match_report.header.match_report".translate, match_reports_path) if in_match_report
    confirmation_message = ""
    confirmation_message += "<div class='m-b'>#{'feature.admin_view.content.bulk_match_warning_v1'.translate(mentoring_connections: _mentoring_connections)}</div>" if in_bulk_match
    confirmation_message += "<div class='m-b'>#{'feature.admin_view.content.delete_warning_with_metrics_v1'.translate(Admin: _Admin)}</div>" if in_management_report_metrics
    confirmation_message += "<div class='m-b'>#{'feature.admin_view.content.delete_warning_with_match_report'.translate(Admin: _Admin, match_report_link: match_report_link)}</div>" if in_match_report
    confirmation_message += "feature.admin_view.content.delete_warning".translate
    return confirmation_message
  end

  def options_for_connection_status_filter_category_select(options = {})
    [
      ["common_text.prompt_text.Select".translate, ""],
      ["feature.admin_view.status.Never_connected".translate, AdminView::ConnectionStatusCategoryKey::NEVER_CONNECTED],
      ["feature.admin_view.status.Currently_connected".translate, AdminView::ConnectionStatusCategoryKey::CURRENTLY_CONNECTED],
      ["feature.admin_view.status.Currently_not_connected".translate, AdminView::ConnectionStatusCategoryKey::CURRENTLY_UNCONNECTED],
      ["feature.admin_view.status.Currently_connected_for_first_time".translate, AdminView::ConnectionStatusCategoryKey::FIRST_TIME_CONNECTED],
      ["feature.admin_view.status.Connected_currently_or_in_the_past".translate, AdminView::ConnectionStatusCategoryKey::CONNECTED_CURRENTLY_OR_PAST],
      ["feature.admin_view.status.Advanced_filters".translate, AdminView::ConnectionStatusCategoryKey::ADVANCED_FILTERS]
    ]
  end

  def options_for_connection_status_filter_type_select(options = {})
    ret = [
      ["common_text.prompt_text.Select".translate, ""],
      ["feature.admin_view.status.Part_of_ongoing_connection".translate(connections: _mentoring_connections), AdminView::ConnectionStatusTypeKey::ONGOING],
      ["feature.admin_view.status.Part_of_closed_connection".translate(connections: _mentoring_connections), AdminView::ConnectionStatusTypeKey::CLOSED],
      ["feature.admin_view.status.Part_of_ongoing_or_closed_connection".translate(connections: _mentoring_connections), AdminView::ConnectionStatusTypeKey::ONGOING_OR_CLOSED]
    ]
    ret << ["feature.admin_view.status.Part_of_drafted_connection".translate(connections: _mentoring_connections), AdminView::ConnectionStatusTypeKey::DRAFTED] if options[:program]
    ret
  end

  def options_for_connection_status_filter_operator_select(options = {})
    [
      ["common_text.prompt_text.Select".translate, ""],
      ["feature.admin_view.status.Less_than".translate, AdminView::ConnectionStatusOperatorKey::LESS_THAN],
      ["feature.admin_view.status.Equals_to".translate, AdminView::ConnectionStatusOperatorKey::EQUALS_TO],
      ["feature.admin_view.status.Greater_than".translate, AdminView::ConnectionStatusOperatorKey::GREATER_THAN]
    ]
  end

  def generate_connection_status_filter_common(base_name, object_name)
    ["#{base_name}[#{object_name}]", "cjs-connection-status-filter-#{object_name}-0"]
  end

  def generate_program_role_state_filter_common(base_name, object_name)
    ["#{base_name}[#{object_name}]", "cjs-program-role-state-filter-#{object_name}-parent-0-child-0"]
  end

  def generate_program_role_state_filter_object_select(base_name, object_name, options = {})
    options = options.reverse_merge(multiple: true, disabled: true)
    name, html_id = generate_program_role_state_filter_common(base_name, object_name)
    title = "feature.admin_view.content.select_program_role_state_filter_#{object_name}".translate(program_and_roles: "feature.admin_view.label.program_and_roles".translate(program: _Program), program: _program)
    label_tag(html_id, title, class: "sr-only control-label") +
    select_tag(name, options_for_select(send("options_for_program_role_state_filter_#{object_name}_select", options), options[:selected]), class: "#{options[:class]} #{'no-border' unless object_name == AdminView::ProgramRoleStateFilterObjectKey::INCLUSION } cjs-program-role-state-filter-#{object_name}", id: html_id, multiple: options[:multiple], disabled: options[:disabled], data: options[:data], title: title)
  end

  def options_for_program_role_state_filter_role_select(options = {})
    roles = options[:organization].all_roles.collect(&:name).uniq
    roles.sort.collect { |role| [Role.get_role_translation_term(role.humanize.downcase).humanize, role]}
  end

  def options_for_program_role_state_filter_state_select(options = {})
    UsersHelper.state_to_string_map.sort_by(&:second).collect { |status| [status[1], status[0]] }
  end

  def options_for_program_role_state_filter_program_select(options = {})
    options[:organization].programs.collect{ |program| [program.name, program.id] }
  end

  def options_for_program_role_state_filter_inclusion_select(options = {})
    [["feature.admin_view.content.include_users".translate, AdminView::ProgramRoleStateFilterObjectKey::INCLUDE], ["feature.admin_view.content.exclude_users".translate, AdminView::ProgramRoleStateFilterObjectKey::EXCLUDE]]
  end

  def get_program_role_state_active_action(filter_params)
    program_role_state_hash = filter_params.try(:[], :program_role_state)
    if filter_params.blank? || program_role_state_all_members?(program_role_state_hash)
      AdminView::ProgramRoleStateFilterActions::ALL_MEMBERS
    elsif program_role_state_include_all_active_members?(program_role_state_hash)
      AdminView::ProgramRoleStateFilterActions::ALL_ACTIVE_MEMBERS
    elsif program_role_state_exclude_all_active_members?(program_role_state_hash)
      AdminView::ProgramRoleStateFilterActions::ALL_INACTIVE_MEMBERS
    else
      AdminView::ProgramRoleStateFilterActions::ADVANCED
    end
  end

  def program_role_state_all_members?(program_role_state_hash)
    program_role_state_hash[AdminView::ProgramRoleStateFilterObjectKey::ALL_MEMBERS].to_s.to_boolean
  end

  def program_role_state_include_all_active_members?(program_role_state_hash)
    return unless check_program_role_state_inclusion(program_role_state_hash, AdminView::ProgramRoleStateFilterObjectKey::INCLUDE)
    program_role_state_all_active_members?(program_role_state_hash)
  end

  def program_role_state_exclude_all_active_members?(program_role_state_hash)
    return unless check_program_role_state_inclusion(program_role_state_hash, AdminView::ProgramRoleStateFilterObjectKey::EXCLUDE)
    program_role_state_all_active_members?(program_role_state_hash)
  end

  def program_role_state_all_active_members?(program_role_state_hash)
    filter_conditions = program_role_state_hash[:filter_conditions]
    (filter_conditions.keys.length == 1) && (filter_conditions.values.first.keys.length == 1) && (filter_conditions.values.first.values.first == program_role_state_all_active_members_hash)
  end

  def program_role_state_all_active_members_hash
    HashWithIndifferentAccess.new({
      AdminView::ProgramRoleStateFilterObjectKey::STATE => [User::Status::ACTIVE],
      AdminView::ProgramRoleStateFilterObjectKey::PROGRAM => [], 
      AdminView::ProgramRoleStateFilterObjectKey::ROLE => []
    })
  end

  def check_program_role_state_inclusion(program_role_state_hash, value)
    program_role_state_hash[AdminView::ProgramRoleStateFilterObjectKey::INCLUSION] == value
  end

  def get_organization_role_names_tooltip(organization)
    result = get_safe_string
    role_names_hash = RoleConstants.program_roles_mapping(organization).collect { |key, value| [key.humanize, value.uniq] }.to_h
    role_names_hash.each do |role_base_term, custom_terms|
      role_base_term = Role.get_role_translation_term(role_base_term.downcase).humanize
      result << content_tag(:span, embed_icon(TOOLTIP_IMAGE_CLASS + " cjs-tool-tip p-xxs", role_base_term, data: {desc: "feature.admin_view.content.selecting_role_will_include".translate(role: role_base_term, customized_roles: custom_terms.to_sentence)}), class: "pull-sm-right p-xxs")
    end
    result
  end

  def generate_connection_status_filter_object_select(base_name, object_name, options = {})
    name, html_id = generate_connection_status_filter_common(base_name, object_name)
    label_tag(html_id, "feature.admin_view.content.select_connection_status_filter_#{object_name}".translate(connection: _mentoring_connection), class: "sr-only") +
    select_tag(name, options_for_select(send("options_for_connection_status_filter_#{object_name}_select", options)), class: "form-control cjs-connection-status-filter-#{object_name} #{"cjs-connection-status-category-dependent-visibility" unless object_name == AdminView::ConnectionStatusFilterObjectKey::CATEGORY}", id: html_id, disabled: true)
  end

  def generate_connection_status_filter_count_value_text_box(base_name, object_name)
    name, html_id = generate_connection_status_filter_common(base_name, object_name)
    label_tag(html_id, "feature.admin_view.content.connection_status_filter_#{object_name}".translate(connection: _mentoring_connection), class: "sr-only") +
    text_field_tag(name, "", class: "form-control cjs-connection-status-filter-#{object_name} cjs-connection-status-category-dependent-visibility", id: html_id, disabled: true)
  end

  def get_mentoring_connection_customized_terms(organization)
    pluralized_connection_terms = []
    singular_connection_terms = []
    term_type = CustomizedTerm::TermType::MENTORING_CONNECTION_TERM
    organization.programs.includes(customized_terms: :translations).each do |program|
      singular_term = program.term_for(term_type).articleized_term_downcase
      pluralized_term = program.term_for(term_type).pluralized_term_downcase
      singular_connection_terms << singular_term if singular_term.present?
      pluralized_connection_terms << pluralized_term if pluralized_term.present?
    end
    return singular_connection_terms.uniq.to_sentence(last_word_connector: "feature.admin_view.header.or".translate), pluralized_connection_terms.uniq.to_sentence(last_word_connector: "feature.admin_view.header.or".translate)
  end

  def generate_filter_role_type(name, options = {})
    html_id = options[:html_id] || "cjs-role-type-0"
    html_class = options[:class] || "cjs-roles-filter-type"
    label_tag(html_id, "feature.admin_view.content.select_role_type".translate, class: "sr-only") +
    select_tag(name, options_for_select([["feature.admin_view.content.include".translate, :include], ["feature.admin_view.content.exclude".translate, :exclude]]), class: "form-control #{html_class}", id: html_id, disabled: true)
  end

  def generate_roles_list(name, program)
    html_id = "cjs_new_view_filter_roles_0"
    label_tag(html_id, "display_string.Roles".translate, class: "sr-only") +
    select_tag(name, options_for_select(program.roles.map{|role| [RoleConstants.human_role_string([role.name], program: program), role.name]}), id: html_id, class: "form-control new_view_filter_roles no-padding no-border", multiple: true, disabled: true)
  end

  def generate_mentoring_mode_list(name, program, filter_params)
    value = ((filter_params.present? && filter_params[:connection_status].present?) ? filter_params[:connection_status][:mentoring_model_preference] : "")
    options = generate_mentoring_mode_list_options(program)
    select_tag(name, options_for_select(options, value), :class => "form-control", :id => "new_view_engagement_models")
  end

  def generate_mentoring_mode_list_options(program)
    options = [
      ["common_text.prompt_text.Select".translate, ''],
      ["feature.admin_view.mentoring_model_preference.ongoing".translate(Mentoring: _Mentoring), User::MentoringMode::ONGOING],
      ["feature.admin_view.mentoring_model_preference.one_time".translate(Mentoring: _Mentoring), User::MentoringMode::ONE_TIME],
      ["feature.admin_view.mentoring_model_preference.one_time_and_ongoing".translate(Mentoring: _Mentoring), User::MentoringMode::ONE_TIME_AND_ONGOING]
    ]
  end

  def mentoring_mode_to_string_map(program)
    mentoring_mode_term = program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term
    {
      User::MentoringMode::ONGOING => "feature.admin_view.mentoring_model_preference.ongoing".translate(Mentoring: mentoring_mode_term),
      User::MentoringMode::ONE_TIME => "feature.admin_view.mentoring_model_preference.one_time".translate(Mentoring: mentoring_mode_term),
      User::MentoringMode::ONE_TIME_AND_ONGOING => "feature.admin_view.mentoring_model_preference.one_time_and_ongoing".translate(Mentoring: mentoring_mode_term)
    }
  end

  def render_admin_view_check_box_or_radio_button(admin_view, name, value, text, filter_params, options = {})
    role_key_param = options[:key_param] || :state
    status_key = admin_view.is_program_view? ? :roles_and_status : :member_status
    checked = filter_params.present? && filter_params[status_key].present? && filter_params[status_key][role_key_param].present? && filter_params[status_key][role_key_param][value.to_s].present?
    if options[:checkbox]
      check_box_tag(name, value, checked) + text
    elsif options[:radio]
      radio_button_tag(name, value, checked) + text
    end
  end

  def get_options_for_meeting_connection_status
    [
      ["common_text.prompt_text.Select".translate, ""],
      ["feature.admin_view.meeting_connection_status.not_connected".translate(:meeting => _meeting), AdminView::UserMeetingConnectionStatus::NOT_CONNECTED],
      ["feature.admin_view.meeting_connection_status.connected".translate(:meeting => _meeting), AdminView::UserMeetingConnectionStatus::CONNECTED]
    ]
  end

  def get_options_for_connection_status_request_type(request_type, role_type)

    case request_type.to_sym
    when :mentoring_requests
      options_for_mentoring_request_filter(role_type)
    when :meeting_requests
      options_for_meeting_request_filter(role_type)
    when :mentor_recommendations
      options_for_mentor_recommendation_filter
    when :meetingconnection_status
      get_options_for_meeting_connection_status
    end
  end

  def get_value_for_connection_status_request_type(filter_params, request_type, role_type)
    return "" unless filter_params.present? && filter_params[:connection_status].present? && filter_params[:connection_status][request_type].present?

    if role_type.to_sym == :both
      filter_params[:connection_status][request_type]
    else
      filter_params[:connection_status][request_type][role_type]
    end
  end

  def generate_connection_status_request_filter(name, filter_params, role_type, request_type)
    value = get_value_for_connection_status_request_type(filter_params, request_type, role_type)
    options = get_options_for_connection_status_request_type(request_type, role_type)
    request_duration, selected_value = get_selected_duration_and_value(filter_params, role_type, request_type)

    content_tag(:div, :class => "col-sm-8 col-md-5") do
      select_tag(name, options_for_select(options, value), :value => value, :class => "form-control cjs_requests_filter", :id => "new_view_filter_#{role_type.to_s}_#{request_type.to_s}")
    end +
    content_tag(:div, :class => "col-sm-2 m-t-sm") do
      content_tag(:span, get_selected_advanced_option_text(request_duration, selected_value), :id => "selected_option_text_for_#{role_type.to_s}_#{request_type.to_s}", :class => "cjs_advanced_option_link_text") + link_to(get_advanced_options_link_text(request_duration, selected_value), "javascript:void(0)", {class: "hide cjs_advanced_option_link", :id => "advanced_options_for_#{role_type.to_s}_#{request_type.to_s}"})
    end
  end

  def find_filter_params_for_survey_user_status(filter_params)
    filter_params.present? && filter_params[:survey].present? ? filter_params[:survey].delete(:user) : {:users_status => "", :survey_id => ""}
  end

  def filter_params_for_survey_questions_present(filter_params)
    filter_params.present? && filter_params[:survey].present? && filter_params[:survey][:survey_questions].present?
  end

  def calculate_rows_size(filter_params)
    filter_params_for_survey_questions_present(filter_params) ? filter_params[:survey][:survey_questions].size : 1
  end

  def get_processed_filter_params(filter_params, surveys)
    filter_params[:survey][:survey_questions].each_pair do |key, params|
      survey =  surveys.detect{|survey| survey.id == params[:survey_id].to_i}
      survey_question =  survey.get_questions_in_order_for_report_filters.detect{|survey_question| survey_question.id == params[:question].split("answers").last.to_i} if survey.present?
      filter_params[:survey][:survey_questions].delete(key) if survey.blank? || survey_question.blank?
    end
    filter_params
  end

  def survey_questions_for_the_survey_filter(surveys, filter_params)
    survey =  surveys.detect{|survey| survey.id == filter_params[:survey_id].to_i}
    survey.present? ? survey.get_questions_in_order_for_report_filters : []
  end

  def survey_operator_options_for_survey_filter(filter_params)
     operator_options = [
      ["common_text.prompt_text.Select".translate, ""],
      ["feature.admin_view.select_option.Contains".translate, QuestionType::WITH_VALUE, :class => "cjs_additional_text_box cjs-show-non-choice-based cjs-show-choice-based"],
      ["feature.admin_view.select_option.Not_Contains".translate, QuestionType::NOT_WITH_VALUE, :class => "cjs_additional_text_box cjs-show-choice-based"],
      ["feature.admin_view.select_option.Answered_v1".translate, QuestionType::ANSWERED, :class => "cjs-show-choice-based cjs-show-non-choice-based"],
      ["feature.admin_view.select_option.Not_Answered_v1".translate, QuestionType::NOT_ANSWERED, :class => "cjs-show-choice-based cjs-show-non-choice-based"],
    ]
    return operator_options
  end

  def get_selected_duration_and_value(filter_params, role_type, request_type)
    request_duration = filter_params.present? && filter_params[:connection_status].present? && filter_params[:connection_status][:advanced_options].present? && filter_params[:connection_status][:advanced_options][request_type].present? && filter_params[:connection_status][:advanced_options][request_type][role_type].present? && filter_params[:connection_status][:advanced_options][request_type][role_type][:request_duration].presence

    selected_value = filter_params[:connection_status][:advanced_options][request_type][role_type][request_duration] if request_duration.present? && request_duration.to_i != AdminView::AdvancedOptionsType::EVER

    if selected_value.present? && (request_duration.to_i == AdminView::AdvancedOptionsType::AFTER || request_duration.to_i == AdminView::AdvancedOptionsType::BEFORE)
      selected_value = DateTime.localize(DateTime.strptime(selected_value, "date.formats.date_range".translate), format: :full_display_no_time)
    end
    return request_duration, selected_value
  end

  def get_selected_advanced_option_text(request_duration, selected_value)
    content = get_safe_string
    return "" unless request_duration.present? && selected_value.present?

    case request_duration.to_i
    when AdminView::AdvancedOptionsType::LAST_X_DAYS
      content += "feature.admin_view.action.in_last".translate + selected_value + "feature.admin_view.action.days".translate
    when AdminView::AdvancedOptionsType::AFTER
      "feature.admin_view.action.after".translate + selected_value
    when AdminView::AdvancedOptionsType::BEFORE
      "feature.admin_view.action.before".translate + selected_value
    end
  end

  def get_advanced_options_link_text(request_duration, selected_value)
    request_duration.present? && selected_value.present? ? "feature.admin_view.action.change_options".translate : "feature.admin_view.action.advanced_options".translate
  end

  def options_for_mentoring_request_filter(role_type)
    if role_type == :mentees
      [
        ["common_text.prompt_text.Select".translate, ""],
        ["feature.admin_view.mentoring_request.mentee.sent".translate(:mentoring => _mentoring), AdminView::RequestsStatus::SENT_OR_RECEIVED],
        ["feature.admin_view.mentoring_request.mentee.pending_action".translate(:mentoring => _mentoring), AdminView::RequestsStatus::SENT_OR_RECEIVED_WITH_PENDING_ACTION],
        ["feature.admin_view.mentoring_request.mentee.not_sent".translate(:mentoring => _mentoring), AdminView::RequestsStatus::NOT_SENT_OR_RECEIVED]
      ]
    else
      [
        ["common_text.prompt_text.Select".translate, ""],
        ["feature.admin_view.mentoring_request.mentor.received".translate(:mentoring => _mentoring), AdminView::RequestsStatus::SENT_OR_RECEIVED],
        ["feature.admin_view.mentoring_request.mentor.pending_action".translate(:mentoring => _mentoring), AdminView::RequestsStatus::SENT_OR_RECEIVED_WITH_PENDING_ACTION],
        ["feature.admin_view.mentoring_request.mentor.not_received".translate(:mentoring => _mentoring), AdminView::RequestsStatus::NOT_SENT_OR_RECEIVED],
        ["feature.admin_view.mentoring_request.mentor.rejected_action_v2".translate(:mentoring => _mentoring), AdminView::RequestsStatus::RECEIVED_WITH_REJECTED_ACTION],
        ["feature.admin_view.mentoring_request.mentor.closed_action_v2".translate(:mentoring => _mentoring), AdminView::RequestsStatus::RECEIVED_WITH_CLOSED_ACTION]
      ]
    end
  end

  def options_for_user_response_status()
    [
      ["common_text.prompt_text.Select".translate, ""],
      ["feature.admin_view.program_defaults.title.responded".translate, AdminView::SurveyAnswerStatus::RESPONDED],
      ["feature.admin_view.program_defaults.title.not_responded".translate, AdminView::SurveyAnswerStatus::NOT_RESPONDED],
    ]
  end

  def options_for_meeting_request_filter(role_type)
    if role_type == :mentees
      [
        ["common_text.prompt_text.Select".translate, ""],
        ["feature.admin_view.meeting_request.mentee.sent".translate(:meeting => _meeting), AdminView::RequestsStatus::SENT_OR_RECEIVED],
        ["feature.admin_view.meeting_request.mentee.pending_action".translate(:meeting => _meeting), AdminView::RequestsStatus::SENT_OR_RECEIVED_WITH_PENDING_ACTION],
        ["feature.admin_view.meeting_request.mentee.not_sent".translate(:meeting => _meeting), AdminView::RequestsStatus::NOT_SENT_OR_RECEIVED]
      ]
    else
      [
        ["common_text.prompt_text.Select".translate, ""],
        ["feature.admin_view.meeting_request.mentor.received".translate(:meeting => _meeting), AdminView::RequestsStatus::SENT_OR_RECEIVED],
        ["feature.admin_view.meeting_request.mentor.pending_action".translate(:meeting => _meeting), AdminView::RequestsStatus::SENT_OR_RECEIVED_WITH_PENDING_ACTION],
        ["feature.admin_view.meeting_request.mentor.not_received".translate(:meeting => _meeting), AdminView::RequestsStatus::NOT_SENT_OR_RECEIVED],
        ["feature.admin_view.meeting_request.mentor.rejected_action_v2".translate(:meeting => _meeting), AdminView::RequestsStatus::RECEIVED_WITH_REJECTED_ACTION],
        ["feature.admin_view.meeting_request.mentor.closed_action_v2".translate(:meeting => _meeting), AdminView::RequestsStatus::RECEIVED_WITH_CLOSED_ACTION]
      ]
    end
  end

  def options_for_mentor_recommendation_filter
    [
      ["common_text.prompt_text.Select".translate, ""],
      [ "feature.admin_view.mentor_recommendation.received_recommendations".translate(mentor: _mentor), AdminView::MentorRecommendationFilter::MENTEE_RECEIVED],
      [ "feature.admin_view.mentor_recommendation.not_received_recommendations".translate(mentor: _mentor), AdminView::MentorRecommendationFilter::MENTEE_NOT_RECEIVED]
    ]
  end

  def generate_mentor_availabilty_list(name, attr_options, filter_params)
    value = ((filter_params.present? && filter_params[:connection_status].present? && filter_params[:connection_status][:availability].present? && filter_params[:connection_status][:availability][:operator].present?) ? filter_params[:connection_status][:availability][:operator] : "")
    attr_options.merge!(:value => value, :id => "new_view_filter_mentor_availability_status")
    options = [
      ["common_text.prompt_text.Select".translate, ""],
      ["feature.admin_view.select_option.connection_slots_less_than_v1".translate(mentoring_connection: _mentoring_connection), AdminViewsHelper::QuestionType::HAS_LESS_THAN, class: "cjs_additional_text_box"],
      ["feature.admin_view.select_option.connection_slots_greater_than_v1".translate(mentoring_connection: _mentoring_connection), AdminViewsHelper::QuestionType::HAS_GREATER_THAN, class: "cjs_additional_text_box"]
    ]
    select_tag(name, options_for_select(options, value), attr_options)
  end

  def admin_view_availability_value_box(name, attr_options, filter_params)
    filter_present = filter_params.present? && filter_params[:connection_status].present? && filter_params[:connection_status][:availability].present?
    value = ((filter_params.present? && filter_params[:connection_status][:availability].present? && filter_params[:connection_status][:availability][:operator].present? && filter_params[:connection_status][:availability][:value].present?) ? filter_params[:connection_status][:availability][:value] : "")
    attr_options.merge!(:style => "") if (filter_present && filter_params[:connection_status][:availability][:operator].present?)
    text_field_tag(name, value, attr_options)
  end

  def admin_view_profile_score_list(name, attr_options, filter_params)
    value = ((filter_params.present? && filter_params[:profile].present? && filter_params[:profile][:score].present? && filter_params[:profile][:score][:operator].present?) ? filter_params[:profile][:score][:operator] : "")
    attr_options.merge!(:value => value, :id => "new_view_filter_profile_completeness_status")
    options = [
      ["common_text.prompt_text.Select".translate, ""],
      ["feature.admin_view.select_option.Less_than".translate, AdminViewsHelper::QuestionType::HAS_LESS_THAN, :class => "cjs_additional_text_box"],
      ["feature.admin_view.select_option.Greater_than".translate, AdminViewsHelper::QuestionType::HAS_GREATER_THAN, :class => "cjs_additional_text_box"]
    ]
    select_tag(name, options_for_select(options, value), attr_options)
  end

  def admin_view_mandatory_filter_list(name, attr_options, filter_params)
    value = filter_params.try(:[], :profile).try(:[], :mandatory_filter) || ""
    attr_options.merge!(value: value)
    options = [
      ["common_text.prompt_text.Select".translate, ""],
      ["feature.admin_view.select_option.answered_all_mandatory_questions".translate, AdminView::MandatoryFilterOptions::FILLED_ALL_MANDATORY_QUESTIONS],
      ["feature.admin_view.select_option.not_answered_all_mandatory_questions".translate, AdminView::MandatoryFilterOptions::NOT_FILLED_ALL_MANDATORY_QUESTIONS],
      ["feature.admin_view.select_option.answered_all_questions".translate, AdminView::MandatoryFilterOptions::FILLED_ALL_QUESTIONS],
      ["feature.admin_view.select_option.not_answered_all_question".translate, AdminView::MandatoryFilterOptions::NOT_FILLED_ALL_QUESTIONS]
    ]
    select_tag(name, options_for_select(options, value), attr_options)
  end

  def admin_view_profile_score_box(name, attr_options, filter_params)
    filter_present = filter_params.present? && filter_params[:profile].present? && filter_params[:profile][:score].present?
    value = ((filter_params.present? && filter_params[:profile][:score].present? && filter_params[:profile][:score][:operator].present? && filter_params[:profile][:score][:value].present?) ? filter_params[:profile][:score][:value] : "")
    show_text_box = (filter_present && filter_params[:profile][:score][:operator].present?)
    addon_options = {
      :type => "addon",
      :content => "%",
      :class => "cjs_input_hidden help-block #{show_text_box ? '' : 'hide'}"
    }
    attr_options.merge!(:style => "") if show_text_box
    attr_options.merge!(:id => "new_view_filter_profile_completeness_value")
    label_tag(name, "feature.admin_view.header.profile_completeness_value".translate, :for => "new_view_filter_profile_completeness_value", :class => "sr-only") +
    construct_input_group({}, addon_options) do
      text_field_tag(name, value, attr_options)
    end
  end

  def create_primary_container(&block)
    content_tag(:div, capture(&block), :class => "cjs_controls_enclosure col-sm-10 no-padding")
  end

  def create_sub_container(&block)
    content_tag(:div, capture(&block), :class => "cjs_add_one_more_div")
  end

  def generate_meeting_request_filters(filter_params)
    meeting_requests_present = filter_params.present? && filter_params[:connection_status].present? && filter_params[:connection_status][:meeting_requests].present?
    content = get_safe_string
    seq_number = 2
    requests_size = meeting_requests_present ? filter_params[:connection_status][:meeting_requests].size : 1
    full_content = create_primary_container do
      content = create_sub_container do
        params_to_be_sent = meeting_requests_present ? filter_params[:connection_status][:meeting_requests].delete(:request_1) : {:status => "", :operator => "", :value => "", :start_value => "", :end_value => ""}
        meeting_requests_container_box(1, requests_size, params_to_be_sent)
      end
      if meeting_requests_present
        filter_params[:connection_status][:meeting_requests].values.each do |filter_sub_hash|
          content += meeting_requests_container_box(seq_number, requests_size, filter_sub_hash)
          seq_number += 1
        end
      end
      content
    end
    full_content + content_tag(:div, add_one_more_link(:data => {:prefix => "[connection_status][meeting_requests]", :id => seq_number.to_s, :type => "request"}), :class => "col-sm-10 col-sm-offset-2 filter")
  end

  def connection_closed_type_options
    [
      ["common_text.prompt_text.Select".translate, ""],
      ["feature.admin_view.content.before".translate, AdminView::TimelineQuestions::Type::BEFORE, {'data-obj_name' => "cjs_last_connection_date"}],
      ["feature.admin_view.content.after".translate, AdminView::TimelineQuestions::Type::AFTER, {'data-obj_name' => "cjs_last_connection_date"}],
      ["feature.admin_view.content.date_range".translate, AdminView::TimelineQuestions::Type::DATE_RANGE, {'data-obj_name' => "cjs_last_connection_date_range"}],
      ["feature.admin_view.content.older_than".translate, AdminView::TimelineQuestions::Type::BEFORE_X_DAYS, {'data-obj_name' => "cjs_last_connection_days"}]
    ]
  end

  def generate_last_connection_on_filter(filter_params)
    details = ((filter_params.present? && filter_params[:connection_status].present? && filter_params[:connection_status][:last_closed_connection].present?) ? filter_params[:connection_status][:last_closed_connection] : {})
    type_options = connection_closed_type_options
    dom_scope = "admin_view[connection_status][last_closed_connection]"
    text_value = details.present? && [AdminView::TimelineQuestions::Type::BEFORE_X_DAYS].include?(details[:type].to_i) ? details[:days] : ""
    datepicker_value = details.present? && [AdminView::TimelineQuestions::Type::AFTER, AdminView::TimelineQuestions::Type::BEFORE].include?(details[:type].to_i) ? details[:date] : ""
    daterangepicker_value = if details.present? && [AdminView::TimelineQuestions::Type::DATE_RANGE].include?(details[:type].to_i)
      split_value = details[:date_range].split(DATE_RANGE_SEPARATOR)
      { start: DateTime.strptime(split_value.first, "date.formats.date_range".translate), end: DateTime.strptime(split_value.last, "date.formats.date_range".translate) }
    else
      {}
    end
    content_tag(:div, :class => "cjs_last_connection_enclosure") do
      label_tag("", "feature.admin_view.header.timeline_operator_label".translate, :class => "sr-only", for: "cjs_last_connection_type") +
      controls(class: "col-sm-5") do
        select_tag("#{dom_scope}[type]", options_for_select(type_options, details[:type]), class: "form-control", id: "cjs_last_connection_type")
      end +
      label_tag("", "feature.admin_view.header.timeline_days_label".translate, :class => "sr-only", for: "cjs_last_connection_days") +
      controls(class: "col-sm-5 cjs_input_container #{'hide' unless text_value.present?}", id: "cjs_last_connection_days_container") do
        text_field_tag("#{dom_scope}[days]", text_value, :class => "form-control", id: "cjs_last_connection_days") +
        content_tag(:span, "display_string.days".translate, :class => "help-block", id: "cjs_last_connection_days_label")
      end +
      label_tag("", "feature.admin_view.header.timeline_date_label".translate, class: "sr-only", for: "cjs_last_connection_date") +
      controls(class: "col-sm-5 cjs_input_container #{'hide' unless datepicker_value.present?}", id: "cjs_last_connection_date_container") do
        construct_input_group([ { type: "addon", icon_class: "fa fa-calendar" } ], []) do
          text_field_tag("#{dom_scope}[date]", datepicker_value, :class => "cjs_timeline_date_picker form-control", id: "cjs_last_connection_date", data: date_picker_options )
        end
      end +
      controls(class: "col-sm-5 cjs_input_container #{'hide' unless daterangepicker_value.present?}", id: "cjs_last_connection_date_range_container") do
        hidden_field_attrs = { id: "cjs_last_connection_date_range", class: "cjs_timeline_date_range_picker", label: "feature.admin_view.header.timeline_daterange_label".translate }
        construct_daterange_picker("#{dom_scope}[date_range]", daterangepicker_value, hidden_field_attrs: hidden_field_attrs, presets: [DateRangePresets::CUSTOM])
      end
    end
  end

  def meeting_request_status_options
    [
      ["common_text.prompt_text.Select".translate, ""],
      ["feature.admin_view.meeting_request.received".translate,
        AdminView::MeetingRequestStatus::RECEIVED],
      ["feature.admin_view.meeting_request.sent".translate,
        AdminView::MeetingRequestStatus::SENT],
      ["feature.admin_view.meeting_request.accepted".translate,
        AdminView::MeetingRequestStatus::ACCEPTED],
      ["feature.admin_view.meeting_request.pending".translate,
        AdminView::MeetingRequestStatus::PENDING]
    ]
  end

  def meeting_request_operator_options
    [
      ["common_text.prompt_text.Select".translate, ""],
      ["feature.admin_view.select_option.requests_with_value".translate, AdminViewsHelper::QuestionType::WITH_VALUE, :class => "cjs_additional_text_box"],
      ["feature.admin_view.select_option.requests_in_range".translate, AdminViewsHelper::QuestionType::BETWEEN, :class => "cjs_additional_range_text_box"]
    ]
  end

  def meeting_requests_container_box(prefix_id, requests_size, filter_params)
    content_tag(:div, class: "cjs_admin_views_container_box clearfix m-t-xs") do
      is_filter_operator_present = filter_params.present? && filter_params[:operator].present?
      value = is_filter_operator_present ? filter_params[:value] : ""
      start_value = is_filter_operator_present ? filter_params[:start_value] : ""
      end_value = is_filter_operator_present ? filter_params[:end_value] : ""
      label_tag("admin_view[connection_status][meeting_requests][request_#{prefix_id}][question]", "feature.admin_view.label.meeting_request_status".translate(:Meeting => _Meeting), :for => "admin_view_meeting_requests_#{prefix_id}_question", :class => "sr-only") +
      controls(class: "col-sm-2") do
        select_tag("admin_view[connection_status][meeting_requests][request_#{prefix_id}][question]",
        options_for_select(meeting_request_status_options, filter_params[:question]), :class => "form-control cjs_meeting_requests_type", :id => "admin_view_meeting_requests_#{prefix_id}_question")
      end +
      label_tag("admin_view[connection_status][meeting_requests][request_#{prefix_id}][operator]", "feature.admin_view.label.meeting_request_operator_label".translate(:meeting => _meeting), :for => "admin_view_meeting_requests_#{prefix_id}_operator", :class => "sr-only") +
      controls(class: "col-sm-2") do
        select_tag("admin_view[connection_status][meeting_requests][request_#{prefix_id}][operator]",
        options_for_select(meeting_request_operator_options, filter_params[:operator]), :class => "form-control cjs_meeting_requests_operator_type", :id => "admin_view_meeting_requests_#{prefix_id}_operator")
      end +
      controls(class: "col-sm-4") do
        construct_value_field(prefix_id, filter_params[:operator], value) +
        construct_range_field(prefix_id, filter_params[:operator], start_value, end_value)
      end +
      content_tag(:div, class: "m-l m-t-xs m-b-sm") do
        content_tag(:span, "display_string.AND".translate, :class => "inline-block m-r-xs #{"hide" if requests_size == prefix_id}") +
        content_tag(:span, get_icon_content('fa fa-trash') + set_screen_reader_only_content("display_string.Delete".translate), :class => "pointer cjs_delete_profile_question #{"hide" if prefix_id == 1}")
      end
    end
  end

  def generate_admin_view_timeline_filters(filter_params)
    content = get_safe_string
    seq_number = 2
    questions_size = (filter_params.present? && filter_params[:timeline].present?) ? filter_params[:timeline][:timeline_questions].size : 1
    full_content = create_primary_container do
      content = create_sub_container do
        params_to_be_sent = (filter_params.present? && filter_params[:timeline].present?) ? filter_params[:timeline][:timeline_questions].delete(:questions_1) : {:question => "", :operator => "", :value => ""}
        timeline_questions_container_box(1, questions_size, params_to_be_sent)
      end
      if filter_params.present? && filter_params[:timeline].present?
        filter_params[:timeline][:timeline_questions].each_pair do |key, filter_sub_hash|
          content += timeline_questions_container_box(seq_number, questions_size, filter_sub_hash)
          seq_number += 1
        end
      end
      content
    end
    full_content + content_tag(:div, add_one_more_link(:data => {:prefix => "[timeline][timeline_questions]", :id => seq_number.to_s, :type => "questions"}), :class => "col-sm-10 col-sm-offset-2 filter")
  end

  def timeline_question_options
    [
      ["common_text.prompt_text.Select".translate, ""],
      ["feature.admin_view.select_option.Join_date".translate,
        AdminView::TimelineQuestions::JOIN_DATE, :class => "cjs_additional_text_box"],
      ["feature.admin_view.select_option.Last_login_date".translate,
        AdminView::TimelineQuestions::LAST_LOGIN_DATE, class: "cjs_additional_text_box cjs_custom_text_picker"],
      ["feature.admin_view.select_option.terms_and_conditions".translate,
        AdminView::TimelineQuestions::TNC_ACCEPTED_ON, class: "cjs_additional_text_box cjs_custom_text_picker"],
      ["feature.admin_view.select_option.last_deactivated_at".translate,
        AdminView::TimelineQuestions::LAST_DEACTIVATED_AT, class: "cjs_additional_text_box cjs_custom_text_picker"]
    ]
  end

  def timeline_type_options
    [
      ["common_text.prompt_text.Select".translate, ""],
      ["feature.admin_view.content.never".translate, AdminView::TimelineQuestions::Type::NEVER],
      ["feature.admin_view.content.before".translate, AdminView::TimelineQuestions::Type::BEFORE],
      ["feature.admin_view.content.after".translate, AdminView::TimelineQuestions::Type::AFTER],
      ["feature.admin_view.content.date_range".translate, AdminView::TimelineQuestions::Type::DATE_RANGE],
      ["feature.admin_view.content.older_than".translate, AdminView::TimelineQuestions::Type::BEFORE_X_DAYS],
      ["feature.admin_view.label.in_last".translate, AdminView::TimelineQuestions::Type::IN_LAST_X_DAYS]
    ]
  end

  def timeline_questions_container_box(prefix_id, questions_size, filter_params)
    question_options = timeline_question_options
    type_options = timeline_type_options
    content_tag(:div, :class => "cjs_admin_views_container_box cjs_hidden_input_box_container clearfix m-t-xs timeline_units_enclosure") do
      question_present = filter_params.present? && filter_params[:question].present?
      value = question_present ? filter_params[:value] : ""
      text_value = [AdminView::TimelineQuestions::Type::NEVER, AdminView::TimelineQuestions::Type::BEFORE_X_DAYS, AdminView::TimelineQuestions::Type::IN_LAST_X_DAYS].include?(filter_params[:type].to_i) ? value : ""
      datepicker_value = [AdminView::TimelineQuestions::Type::AFTER, AdminView::TimelineQuestions::Type::BEFORE].include?(filter_params[:type].to_i) ? value : ""
      daterangepicker_value = if (filter_params[:type].to_i == AdminView::TimelineQuestions::Type::DATE_RANGE) && value.present?
        split_values = value.split(DATE_RANGE_SEPARATOR)
        { start: DateTime.strptime(split_values.first, "date.formats.date_range".translate), end: DateTime.strptime(split_values.last, "date.formats.date_range".translate) }
      else
        {}
      end
      dom_scope = "admin_view[timeline][timeline_questions][questions_#{prefix_id}]"
      label_tag("#{dom_scope}[question]", "feature.admin_view.header.timeline_option_label".translate, :for => "timeline_question_#{prefix_id}", :class => "sr-only") +
      controls(:class => "col-sm-3") do
        select_tag("#{dom_scope}[question]", options_for_select(question_options, filter_params[:question]),
        :class => "form-control cjs_timeline_questions cjs_show_input_field", :id => "timeline_question_#{prefix_id}")
      end +
      label_tag("#{dom_scope}[type]", "feature.admin_view.header.timeline_operator_label".translate, :for => "timeline_type_#{prefix_id}", :class => "sr-only") +
      controls(:class => "col-sm-3") do
        select_tag("#{dom_scope}[type]", options_for_select(type_options, filter_params[:type]),
          :class => "form-control cjs_timeline_type cjs_show_input_field", data: {question_id: prefix_id}, :id => "timeline_type_#{prefix_id}")
      end +
      controls(:class => "col-sm-5") do
        label_tag("#{dom_scope}[value]", "feature.admin_view.header.timeline_days_label".translate, :for => "timeline_questions_#{prefix_id}", :class => "sr-only") +
        text_field_tag("#{dom_scope}[value]", text_value, :class => "hide cjs_input_container cjs_timeline_text form-control",
          :id => "timeline_questions_#{prefix_id}", :autocomplete => "off") +
        label_tag("#{dom_scope}[date_questions]", "feature.admin_view.header.timeline_date_label".translate, :for => "date_questions_#{prefix_id}", :class => "sr-only") +
        construct_input_group([ { type: "addon", icon_class: "fa fa-calendar" } ], [], input_group_class: "cjs_input_container cjs_timeline_date_picker_container") do
          text_field_tag("date_questions_#{prefix_id}", datepicker_value,
            :class => "form-control cjs_timeline_date_picker cjs_remove_on_submit cjs_admin_view_date", :id => "date_questions_#{prefix_id}", data: date_picker_options)
        end +
        content_tag(:div, class: "cjs_input_container cjs_timeline_date_range_picker_container") do
          hidden_field_attrs = { class: "cjs_timeline_date_range_picker cjs_remove_on_submit", label: "feature.admin_view.header.timeline_daterange_label".translate }
          construct_daterange_picker("date_range_questions_#{prefix_id}", daterangepicker_value, hidden_field_attrs: hidden_field_attrs, presets: [DateRangePresets::CUSTOM])
        end +
        content_tag(:span, "display_string.days".translate, :class => "cjs_timeline_days help-block hide")
      end +
      content_tag(:div, class: "m-l m-t-xs m-b-sm") do
        content_tag(:span, "display_string.AND".translate, :class => "inline-block m-r-xs #{"hide" if questions_size == prefix_id}") +
        content_tag(:span, get_icon_content('fa fa-trash') + set_screen_reader_only_content("display_string.Delete".translate), :class => "pointer cjs_delete_profile_question #{"hide" if prefix_id == 1}")
      end
    end
  end

  def generate_admin_view_profile_questions(admin_view, profile_questions, filter_params)
    profile_question_ids = profile_questions.collect(&:id)
    content = get_safe_string
    profile_filters = []
    if filter_params.present?
      filter_params[:profile][:questions].each do |key, filter_sub_hash|
        is_question_present = filter_sub_hash.present? && profile_question_ids.include?(filter_sub_hash[:question].to_i)
        profile_filters << filter_sub_hash if is_question_present
      end
    end
    profile_filters << { question: "", operator: "", value: "" } if profile_filters.blank?
    full_content = create_primary_container do
      profile_filters.each_with_index do |filter_sub_hash, sequence_number|
        filter_sub_hash_content = profile_questions_container_box(admin_view, sequence_number + 1, profile_filters.size, profile_questions, filter_sub_hash)
        filter_sub_hash_content = create_sub_container { filter_sub_hash_content } if sequence_number.zero? # First row
        content += filter_sub_hash_content
      end
      content
    end

    full_content + content_tag(:div, add_one_more_link(data: { prefix: "[profile][questions]", id: (profile_filters.size + 1).to_s, type: "questions" }), class: "col-sm-10 col-sm-offset-2 filter")
  end

  def get_location_question_scope_options
    [
      ["feature.admin_view.select_option.City".translate, AdminView::LocationScope::CITY],
      ["feature.admin_view.select_option.State".translate, AdminView::LocationScope::STATE],
      ["feature.admin_view.select_option.Country".translate, AdminView::LocationScope::COUNTRY]
    ]
  end

  def profile_questions_container_box(admin_view, prefix_id, questions_size, profile_questions, filter_params)
    question_choices_ids, question_choices_texts = get_question_choices_for_select2(profile_questions, id_as_key: true)

    operator_options = [
      ["common_text.prompt_text.Select".translate, ""],
      ["feature.admin_view.select_option.Contains".translate, QuestionType::WITH_VALUE, :class => "cjs_additional_text_box cjs-show-non-choice-based"],
      ["feature.admin_view.select_option.Not_Contains".translate, QuestionType::NOT_WITH_VALUE, :class => "cjs_additional_text_box cjs-show-non-choice-based"],
      ["feature.admin_view.select_option.Answered_v1".translate, QuestionType::ANSWERED, :class => "cjs-show-file-manager cjs-show-choice-based cjs-show-non-choice-based cjs-show-location-based"],
      ["feature.admin_view.select_option.Not_Answered_v1".translate, QuestionType::NOT_ANSWERED, :class => "cjs-show-file-manager cjs-show-choice-based cjs-show-non-choice-based cjs-show-location-based"],
      ["feature.admin_view.select_option.In_v1".translate, QuestionType::IN, :class => "cjs_additional_text_box cjs-show-choice-based cjs-show-location-based"],
      ["feature.admin_view.select_option.Not_in_v1".translate, QuestionType::NOT_IN, :class => "cjs_additional_text_box cjs-show-choice-based cjs-show-location-based"],
      ["feature.admin_view.select_option.Matches".translate, QuestionType::MATCHES, :class => "cjs_additional_text_box cjs-show-choice-based cjs_show_match_text_box"]
    ]
    content_tag(:div, :class => "m-b-xs prof-ques-cont animated fadeInDown clearfix cjs_admin_views_container_box cjs_hidden_input_box_container") do
      value = filter_params[:operator].present? ? filter_params[:value] : ""
      label_tag("admin_view[profile][questions][questions_#{prefix_id}][question]", "feature.admin_view.header.select_profile_question_label".translate, :for => "admin_view_profile_questions_questions_#{prefix_id}_question", :class => "sr-only") +
      controls(class: "col-sm-3 cjs-profile-question-control") do
        select_tag("admin_view[profile][questions][questions_#{prefix_id}][question]",
          options_for_select([["common_text.prompt_text.Select".translate, ""]] + profile_questions.collect{|pq| [pq.send(*admin_view.profile_question_text_method), pq.id, class: "#{"cjs-file-manager-type-question" if pq.manager? || pq.file_type?} #{"cjs-location-type-question" if pq.location?} #{"cjs_date_question" if pq.date?} #{"cjs-choice-based-question" if pq.choice_or_select_type?}"]}, filter_params[:question]), :class => "form-control cjs-profile-question-selector", :id => "admin_view_profile_questions_questions_#{prefix_id}_question")
      end +
      label_tag("admin_view[profile][questions][questions_#{prefix_id}][operator]", "feature.admin_view.header.profile_question_operator_label".translate, :for => "admin_view_profile_questions_questions_#{prefix_id}_operator", :class => "sr-only") +
      controls(class: "col-sm-2 cjs-profile-question-operator-control") do
        select_tag("admin_view[profile][questions][questions_#{prefix_id}][operator]",
          options_for_select(operator_options, filter_params[:operator]), :class => "form-control cjs_show_profile_input_field", :id => "admin_view_profile_questions_questions_#{prefix_id}_operator", data: {qci: question_choices_ids.to_json, qct: question_choices_texts.to_json})
      end +
      label_tag("admin_view[profile][questions][questions_#{prefix_id}][scope]", "feature.admin_view.header.profile_question_scope_label".translate, :for => "admin_view_profile_questions_questions_#{prefix_id}_scope", :class => "sr-only") +
      controls(class: "col-sm-2 hide cjs-profile-question-location-scope-control") do
        select_tag("admin_view[profile][questions][questions_#{prefix_id}][scope]",
          options_for_select(get_location_question_scope_options, filter_params[:scope]), :class => "form-control cjs_input_hidden cjs-profile-question-location-scope-select", :id => "admin_view_profile_questions_questions_#{prefix_id}_scope")
      end +
      controls(class: "col-sm-4 cjs-profile-question-text-input-control") do
        label_tag("admin_view[profile][questions][questions_#{prefix_id}][value]", "feature.admin_view.header.answer_contains_label".translate, :for => "admin_view_profile_questions_questions_#{prefix_id}_value", :class => "sr-only cjs_input_hidden_label") +
        text_field_tag("admin_view[profile][questions][questions_#{prefix_id}][value]", value, :style => "#{"display:none" unless filter_params[:operator].in?([QuestionType::WITH_VALUE.to_s, QuestionType::IN.to_s, QuestionType::NOT_IN.to_s])}", :class => "cjs_input_hidden form-control", :id => "admin_view_profile_questions_questions_#{prefix_id}_value", :"data-remote-data-path" => locations_autocomplete_admin_views_path) +
        label_tag("admin_view[profile][questions][questions_#{prefix_id}][choice]", "feature.survey.survey_report.filters.label.select_value_label".translate, :for => "admin_view_profile_questions_questions_#{prefix_id}_choice", :class => "sr-only cjs_choices_hidden_label") +
        hidden_field_tag("admin_view[profile][questions][questions_#{prefix_id}][choice]", filter_params[:choice], :class => "cjs_choices_hidden no-padding form-control", :id => "admin_view_profile_questions_questions_#{prefix_id}_choice", :data => {:placeholder => "feature.connection.header.survey_response_filter.placeholder.select_choices".translate})
      end +

      profile_question_container_for_date_type(prefix_id, filter_params) +

      content_tag(:div, class: "m-l m-t-xs m-b-sm") do
        content_tag(:span, "display_string.AND".translate, :class => "inline-block m-r-xs #{"hide" if questions_size == prefix_id}") +
        content_tag(:span, get_icon_content('fa fa-trash') + set_screen_reader_only_content("display_string.Delete".translate), :class => "pointer cjs_delete_profile_question #{"hide" if prefix_id == 1}")
      end
    end
  end

  def profile_question_container_for_date_type(prefix_id, filter_params)
    operator, dom_scope, question_present = get_operator_domscope_and_question_presence(filter_params, prefix_id)
    content_tag(:div, class: "hide cjs_date_type_profile_question_container") do
      date_value = question_present ? filter_params[ProfileQuestionsHelper::DATE_VALUE] : ""
      number_of_days = question_present ? filter_params[ProfileQuestionsHelper::NUMBER_OF_DAYS] : ""
      text_value, datepicker_value, daterangepicker_value = get_date_values(operator, date_value, number_of_days)
      get_date_profile_question_selector(dom_scope, prefix_id, operator) +
      controls(class: "col-sm-4 cjs_profile_question_date_components hide") do
        get_date_profile_question_number_of_days_field(dom_scope, prefix_id, text_value) +
        get_date_profile_question_single_date_field(dom_scope, prefix_id, datepicker_value) +
        get_date_profile_question_date_range_picker(dom_scope, daterangepicker_value) +
        content_tag(:span, "display_string.days".translate, class: "cjs_profile_question_number_of_days_text help-block hide")
      end
    end
    
  end

  def get_operator_domscope_and_question_presence(filter_params, prefix_id)
    operator = filter_params["date_operator"]
    dom_scope = "admin_view[profile][questions][questions_#{prefix_id}]"
    question_present = filter_params.present? && filter_params[:question].present?
    [operator, dom_scope, question_present]
  end

  def get_date_values(operator, date_value, number_of_days)
    text_value = [AdminView::ProfileQuestionDateType::IN_LAST, AdminView::ProfileQuestionDateType::IN_NEXT].include?(operator) ? number_of_days : ""
    datepicker_value = get_datepicker_value(operator, date_value)
    daterangepicker_value = get_date_range_picker_value(operator, date_value)
    [text_value, datepicker_value, daterangepicker_value]
  end

  def get_datepicker_value(operator, date_value)
    if (operator == AdminView::ProfileQuestionDateType::AFTER)
      get_previous_or_next_date(initialize_date_range_for_filter(date_value)[:from_date], previous: true)
    elsif (operator == AdminView::ProfileQuestionDateType::BEFORE)
      get_previous_or_next_date(initialize_date_range_for_filter(date_value)[:to_date], next: true)
    else
      ""
    end
  end

  def get_previous_or_next_date(date_str, options = {})
    return date_str unless date_str.present?
    if options[:previous]
      (date_str.to_date - 1.day).to_s
    elsif options[:next]
      (date_str.to_date + 1.day).to_s
    else
      date_str
    end
  end

  def get_date_range_picker_value(operator, date_value)
    if (operator == AdminView::ProfileQuestionDateType::DATE_RANGE) && date_value.present?
      split_values = date_value.split(DATE_RANGE_SEPARATOR)
      start_value = DateTime.strptime(split_values.first, "date.formats.date_range".translate) if split_values.first.present?
      end_value = DateTime.strptime(split_values.second, "date.formats.date_range".translate) if split_values.second.present?
      { start: start_value, end: end_value }
    else
      {}
    end
  end

  def get_date_profile_question_selector(dom_scope, prefix_id, operator)
    label_tag("#{dom_scope}[date_operator]", "feature.admin_view.header.profile_question_operator_label".translate, for: "admin_view_profile_questions_questions_#{prefix_id}_date_operator", class: "sr-only") +
    controls(class: "col-sm-2") do
      select_tag("#{dom_scope}[date_operator]", options_for_select(operators_for_date_profile_question, operator), class: "form-control cjs_profile_question_date_operator", id: "admin_view_profile_questions_questions_#{prefix_id}_date_operator")
    end
  end

  def get_date_profile_question_number_of_days_field(dom_scope, prefix_id, text_value)
    label_tag("#{dom_scope}[#{ProfileQuestionsHelper::NUMBER_OF_DAYS}]", "feature.admin_view.header.date_profile_question_number_of_days_label".translate, for: "admin_view_profile_questions_questions_#{prefix_id}_number_of_days", class: "sr-only") +
    text_field_tag("#{dom_scope}[#{ProfileQuestionsHelper::NUMBER_OF_DAYS}]", text_value, class: "hide cjs_profile_question_number_of_days form-control",
      id: "admin_view_profile_questions_questions_#{prefix_id}_number_of_days", autocomplete: "off")
  end

  def get_date_profile_question_single_date_field(dom_scope, prefix_id, datepicker_value)
    label_tag("#{dom_scope}[single_date_value]", "feature.meeting_request.label.pick_a_date".translate, for: "admin_view_profile_questions_questions_#{prefix_id}_single_date_value", class: "sr-only") +
    construct_input_group([ { type: "addon", icon_class: "fa fa-calendar" } ], [], input_group_class: "cjs_profile_question_single_date_value hide") do
      text_field_tag("#{dom_scope}[single_date_value]", datepicker_value,
        class: "form-control cjs_profile_question_single_date_value_field cjs_remove_on_submit", data: date_picker_options)
    end
  end

  def get_date_profile_question_date_range_picker(dom_scope, daterangepicker_value)
    content_tag(:div, class: "cjs_profile_question_date_range_value hide") do
      hidden_field_attrs = { class: "#{ProfileQuestionsHelper::DATE_RANGE_PICKER_FOR_PROFILE_QUESTION}", label: "feature.meeting_request.label.pick_a_date".translate }
      construct_daterange_picker("#{dom_scope}[#{ProfileQuestionsHelper::DATE_VALUE}]", daterangepicker_value, hidden_field_attrs: hidden_field_attrs, presets: [DateRangePresets::CUSTOM])
    end
  end

  def operators_for_date_profile_question
    [
      ["common_text.prompt_text.Select".translate, "", class: "hide"],
      ["feature.admin_view.select_option.Answered_v1".translate, AdminView::ProfileQuestionDateType::FILLED],
      ["feature.admin_view.select_option.Not_Answered_v1".translate, AdminView::ProfileQuestionDateType::NOT_FILLED],
      ["feature.admin_view.content.before".translate, AdminView::ProfileQuestionDateType::BEFORE],
      ["feature.admin_view.content.after".translate, AdminView::ProfileQuestionDateType::AFTER],
      ["feature.admin_view.content.date_range".translate, AdminView::ProfileQuestionDateType::DATE_RANGE],
      ["feature.reports.content.in_last".translate, AdminView::ProfileQuestionDateType::IN_LAST],
      ["feature.admin_view.content.in_next".translate, AdminView::ProfileQuestionDateType::IN_NEXT]
    ]
  end

  def admin_view_tags_field(name, all_tags_names, filter_params)
    value = (filter_params.present? && filter_params[:others].present? && filter_params[:others][:tags].present?) ? filter_params[:others][:tags] : ""
    text_field_tag "admin_view[others][tags]", value, :class => "tag_list_input col-xs-12 no-padding", :input_tags => all_tags_names, title: "feature.admin_view.label.Have_tags".translate
  end

  def accordion_wrapper(&block)
    content_tag(:div, :class => "well square-well no-border has-below") do
      content_tag(:div, :class => ACCORDION_PANE_CONTENT_CLASS) do
        capture(&block)
      end
    end
  end

  def profile_accordion_collapse?(admin_view, profile_hash)
    profile_hash.present? && (profile_hash[:questions].keys.size > 1 ||
      profile_hash[:questions].first[1][:question].present? || profile_hash[:questions].first[1][:operator].present? ||
      (profile_hash[:questions].first[1][:value].present? && profile_hash[:questions].first[1][:operator].present?) ||
      (admin_view.is_program_view? && profile_hash[:score][:operator].present? && profile_hash[:score][:value].present?))
  end

  def timeline_accordion_collapse?(timeline_hash)
    timeline_hash.present? && (timeline_hash[:timeline_questions].keys.size > 1 ||
      (timeline_hash[:timeline_questions].first[1][:question].present? &&
              timeline_hash[:timeline_questions].first[1][:value].present?))
  end

  def member_status_accordion_collapse?(member_status_hash)
    member_status_hash.present? && member_status_hash[:state].present?
  end

  def other_accordion_collapse?(other_hash)
    other_hash.present? && other_hash[:tags].present?
  end

  def connection_status_collapse?(connection_status_hash, admin_view)
    connection_status_hash.present? && (
      connection_status_hash[:status].present? ||
      connection_status_hash[:draft_status].present? ||
      (connection_status_hash[:mentoring_model_preference].present? && admin_view.program.consider_mentoring_mode?)||
      (connection_status_hash[:last_closed_connection].present? && connection_status_hash[:last_closed_connection][:type].present?) ||
      (connection_status_hash[:availability].present? && connection_status_hash[:availability][:operator].present? && connection_status_hash[:availability][:value].present?) || (connection_status_hash[:rating].present? && connection_status_hash[:rating][:operator].present?) || (connection_status_hash[:mentoring_requests].present? && (connection_status_hash[:mentoring_requests][:mentees].present? || connection_status_hash[:mentoring_requests][:mentors].present?)) || (connection_status_hash[:meeting_requests].present? && (connection_status_hash[:meeting_requests][:mentees].present? || connection_status_hash[:meeting_requests][:mentors].present?)) || connection_status_hash[:meetingconnection_status].present?)
  end

  def populate_basic_info_columns(admin_view_columns, admin_view, optgroup)
    options_array = []
    custom_term_options = get_custom_term_options

    is_edit_view = admin_view_columns.present?
    is_program_view = admin_view.is_program_view?

    default_columns = is_program_view ? AdminViewColumn::Columns::ProgramDefaults.basic_information_columns(admin_view, custom_term_options) : AdminViewColumn::Columns::OrganizationDefaults.defaults(custom_term_options.merge(include_language: admin_view.languages_filter_enabled?))

    selected_columns_keys = is_edit_view ? admin_view_columns.select{|col| default_columns.keys.include?(col.column_key)}.collect(&:column_key) : default_columns.keys

    ordered_keys = selected_columns_keys + (default_columns.keys - selected_columns_keys)

    ordered_keys.each do |column_key|
      options_array << [default_columns[column_key][:title], admin_view_edit_column_mapper(column_key, optgroup)]
    end

    options_for_select(options_array, selected_columns_keys.map{|key| admin_view_edit_column_mapper(key, optgroup)})
  end

  def profile_question_key_generate(profile_question)
    if profile_question.location?
      [
        profile_question.id.to_s,
        [profile_question.id.to_s, AdminViewColumn::ScopedProfileQuestion::Location::CITY].join(AdminViewColumn::ID_SUBKEY_JOINER),
        [profile_question.id.to_s, AdminViewColumn::ScopedProfileQuestion::Location::STATE].join(AdminViewColumn::ID_SUBKEY_JOINER),
        [profile_question.id.to_s, AdminViewColumn::ScopedProfileQuestion::Location::COUNTRY].join(AdminViewColumn::ID_SUBKEY_JOINER)
      ]
    else
      [profile_question.id.to_s]
    end
  end

  def populate_profile_question_columns(profile_questions, admin_view_columns, admin_view, optgroup)
    local_abstractor = ->(pq, k, o, av) { [pq.location? ? AdminViewColumn.scoped_profile_question_text(av, pq, k) : pq.send(*av.profile_question_text_method), admin_view_edit_column_mapper(k, o)] } # just to avoid local code repetition
    options_array = []
    selected_column_keys = []
    (admin_view_columns.try(:custom) || []).each do |admin_view_column|
      key = admin_view_column.key
      selected_column_keys << key
      options_array << local_abstractor[admin_view_column.profile_question, key, optgroup, admin_view]
    end

    profile_questions.each do |profile_question|
      profile_question_key_generate(profile_question).each do |key|
        next if selected_column_keys.include?(key)
        options_array << local_abstractor[profile_question, key, optgroup, admin_view]
      end
    end

    options_for_select(options_array, selected_column_keys.map{|key| admin_view_edit_column_mapper(key, optgroup)})
  end

  def populate_matching_and_engagement_status_columns(admin_view_columns, admin_view, optgroup)
    is_edit_view = admin_view_columns.present?

    all_columns = AdminViewColumn::Columns::ProgramDefaults.matching_and_engagement_columns(get_custom_term_options)

    all_columns_keys = all_columns.keys

    all_columns_keys -= [AdminViewColumn::Columns::Key::AVAILABLE_SLOTS] if admin_view.program.project_based?
    all_columns_keys -= [AdminViewColumn::Columns::Key::NET_RECOMMENDED_COUNT] unless admin_view.program.mentor_recommendation_enabled?
    all_columns_keys -= AdminViewColumn::Columns::ProgramDefaults.meeting_request_defaults.keys unless admin_view.program.calendar_enabled?
    all_columns_keys -= AdminViewColumn::Columns::ProgramDefaults.mentoring_mode_column unless admin_view.program.consider_mentoring_mode?
    all_columns_keys -= AdminViewColumn::Columns::ProgramDefaults.ongoing_mentoring_dependent_columns unless admin_view.program.ongoing_mentoring_enabled?
    all_columns_keys -= AdminViewColumn::Columns::ProgramDefaults.coach_rating_column unless admin_view.program.coach_rating_enabled?
    all_columns_keys -= AdminViewColumn::Columns::ProgramDefaults.mentoring_request_for_mentors_defaults.keys unless admin_view.program.ongoing_mentoring_enabled? && admin_view.program.matching_by_mentee_alone?
    all_columns_keys -= AdminViewColumn::Columns::ProgramDefaults.mentoring_request_for_mentees_defaults.keys unless admin_view.program.ongoing_mentoring_enabled? && (admin_view.program.matching_by_mentee_alone? || admin_view.program.matching_by_mentee_and_admin?)

    selected_columns_keys = is_edit_view ? admin_view_columns.select{|column| all_columns_keys.include?(column.key)}.collect(&:key) : []

    ordered_keys = selected_columns_keys + (all_columns_keys - selected_columns_keys)

    return get_admin_view_column_options(ordered_keys, all_columns, selected_columns_keys, optgroup)
  end

  def populate_timeline_columns(admin_view_columns, admin_view, optgroup, ongoing_program)
    is_edit_view = admin_view_columns.present?

    all_columns = AdminViewColumn::Columns::ProgramDefaults.timeline_columns(get_custom_term_options)

    all_columns.delete(AdminViewColumn::Columns::Key::LAST_CLOSED_GROUP_TIME) unless ongoing_program

    selected_columns_keys = is_edit_view ? admin_view_columns.select{|column| all_columns.keys.include?(column.key)}.collect(&:key) : []

    ordered_keys = selected_columns_keys + (all_columns.keys - selected_columns_keys)

    return get_admin_view_column_options(ordered_keys, all_columns, selected_columns_keys, optgroup)
  end

  def populate_engagement_columns(admin_view_columns, optgroup)
    is_edit_view = admin_view_columns.present?

    all_columns = AdminViewColumn::Columns::OrganizationDefaults.engagement_columns

    selected_columns_keys = is_edit_view ? admin_view_columns.select{|column| all_columns.keys.include?(column.key)}.collect(&:key) : []

    ordered_keys = all_columns.keys

    return get_admin_view_column_options(ordered_keys, all_columns, selected_columns_keys, optgroup)
  end

  def get_admin_view_column_options(ordered_keys, all_columns, selected_columns_keys, optgroup)
    options_array = []
    ordered_keys.each do |column_key|
      options_array << [all_columns[column_key][:title], admin_view_edit_column_mapper(column_key, optgroup)]
    end

    options_for_select(options_array, selected_columns_keys.map{|key| admin_view_edit_column_mapper(key, optgroup)})
  end

  def admin_view_edit_column_mapper(key, optgroup)
    [optgroup, key].join(AdminViewColumn::COLUMN_SPLITTER)
  end

  def next_section_slider(options = {})
    content_tag :div, :class => "pull-right" do
      link_to "display_string.Next_raquo_html".translate, "#", :class => "btn btn-primary cjs_slider_button " + options[:class].to_s
    end
  end

  def member_sorted_program_roles(member, member_program_and_roles)
    content = ''.html_safe
      member_program_and_roles[member.id].each do |prog_and_role|
        rolenames_str = ' (' + prog_and_role[:role_names].join(', ') + ( prog_and_role[:user_suspended] ? " - #{'feature.admin_view.status.deactivated'.translate})" : ")" )
        content += content_tag(:div, '', :class => '') do
          content_tag(:b, link_to(prog_and_role[:program_name], program_root_path(:root => prog_and_role[:program_root])), :class =>'no-margin') +
          content_tag(:span, rolenames_str, :class =>'')
        end
      end
    content
  end

  def context_term(admin_view)
    admin_view.is_program_view? ? "feature.admin_view.content.Users".translate : "feature.admin_view.content.Members".translate
  end

  def admin_view_list_item(text, path)
    content_tag(:li, :class => "m-b-xs") do
      link_to text, path
    end
  end

  def render_action_buttons(form_object, options = {})
    render :partial => "admin_views/new_view_actions", :locals => options.merge(:form_object => form_object)
  end

  def admin_view_path_with_source(action, options = {})
    source_info = @set_source_info || options[:source_info] || params.to_unsafe_h.pick(:controller, :action, :id, :section)
    source_info.keep_if { |k, v| v.present? }

    admin_view = options.delete(:admin_view)
    params_to_send = options
    params_to_send.reverse_merge!(source_info: source_info) if source_info.present?

    case action
    when :new
      new_admin_view_path(params_to_send)
    when :edit
      edit_admin_view_path(admin_view, params_to_send)
    when :show
      admin_view_path(admin_view, params_to_send)
    end
  end

  def construct_value_field(prefix_id, operator, value)
    label_tag("admin_view[connection_status][meeting_requests][request_#{prefix_id}][value]", "feature.admin_view.header.answer_contains_label".translate, :for => "admin_view_meeting_requests_#{prefix_id}_value", :class => "sr-only") +
    text_field_tag("admin_view[connection_status][meeting_requests][request_#{prefix_id}][value]", value, :class => "form-control cjs_input_hidden #{'hide' if(!operator.present? || operator != AdminViewsHelper::QuestionType::WITH_VALUE.to_s)}", :id => "admin_view_meeting_requests_#{prefix_id}_value")
  end

  def construct_range_field(prefix_id, operator, start_value, end_value)
    is_range_operator_present = (!operator.present? || operator != AdminViewsHelper::QuestionType::BETWEEN.to_s)
    label_tag("admin_view[connection_status][meeting_requests][request_#{prefix_id}][start_value]", "feature.admin_view.header.answer_contains_label".translate, :for => "admin_view_meeting_requests_#{prefix_id}_start_value", :class => "sr-only") +
    controls(:class => "col-sm-4 p-l-0 p-r-0") do
      text_field_tag("admin_view[connection_status][meeting_requests][request_#{prefix_id}][start_value]", start_value, :class => "form-control cjs_input_start_range #{'hide' if is_range_operator_present}", :id => "admin_view_meeting_requests_#{prefix_id}_start_value")
    end +
    content_tag(:span, "display_string.and".translate, :class => "cjs-range-connector col-sm-2 #{'hide' if is_range_operator_present}") +
    label_tag("admin_view[connection_status][meeting_requests][request_#{prefix_id}][end_value]", "feature.admin_view.header.answer_contains_label".translate, :for => "admin_view_meeting_requests_#{prefix_id}_end_value", :class => "sr-only") +
    controls(:class => "col-sm-4 p-l-0 p-r-0") do
      text_field_tag("admin_view[connection_status][meeting_requests][request_#{prefix_id}][end_value]", end_value, :class => "form-control cjs_input_end_range #{'hide' if is_range_operator_present}", :id => "admin_view_meeting_requests_#{prefix_id}_end_value")
    end
  end

  def get_user_roles_for_add_to_program(program)
    content = get_safe_string

    program.roles.non_administrative.each do |role|
      content << content_tag(:label, :class => "checkbox inline m-r" ) do
        (check_box_tag "admin_view[role_names][]", role.name, false, {id: "admin_view_#{role.id}"}) + content_tag(:span, role.customized_term.term, :class => "cjs_toggle_content")
      end
    end
    choices_wrapper("display_string.Roles".translate, class: "m-t-xs cjs_roles_list") do
      content
    end
  end

  def campaign_back_url(source_info)
    if source_info[:id].present?
      edit_campaign_management_campaign_path(:id => source_info[:id])
    else
      new_campaign_management_campaign_path
    end
  end

  def collect_admin_views_hash(admin_views)
    admin_views.collect{ |av| { :id => av.id, :icon => av.favourite_image_path, :title => h(av.title) } }
  end

  def rating_options_list(name, attr_options, filter_params)
    value = ((filter_params.present? && filter_params[:connection_status].present? && filter_params[:connection_status][:rating].present? && filter_params[:connection_status][:rating][:operator].present?) ? filter_params[:connection_status][:rating][:operator] : "")
    attr_options.merge!(:value => value, :id => "new_view_filter_mentor_rating")
    options = [
      ["common_text.prompt_text.Select".translate, ''],
      ["feature.admin_view.coach_rating.less_than".translate, AdminViewsHelper::Rating::LESS_THAN, :class => "cjs_show_less_than_box"],
      ["feature.admin_view.coach_rating.greater_than".translate, AdminViewsHelper::Rating::GREATER_THAN, :class => "cjs_show_greater_than_box"],
      ["feature.admin_view.coach_rating.equal_to".translate, AdminViewsHelper::Rating::EQUAL_TO, :class => "cjs_equal_to_box"],
      ["feature.admin_view.coach_rating.not_rated".translate, AdminViewsHelper::Rating::NOT_RATED]
    ]
    select_tag(name, options_for_select(options, value), attr_options)
  end

  def admin_view_rating_value_dropdown(name, attr_options, filter_params, type)
    rating_filter_present = filter_params.present? && filter_params[:connection_status].present? && filter_params[:connection_status][:rating].present?
    value = ((rating_filter_present && filter_params[:connection_status][:rating][type.to_sym].present?) ? filter_params[:connection_status][:rating][type.to_sym] : "")
    attr_options.merge!(value: value, id: "admin_view_connection_status_mentor_#{type}_rating_value", "aria-label" => "feature.coach_rating.label.rating_value_label".translate(:Mentor => _Mentor))

    options = []
    options << [AdminViewsHelper::RatingOptions::ZERO, AdminViewsHelper::RatingOptions::ZERO] if type == AdminViewsHelper::Rating::GREATER_THAN
    options += [
      [AdminViewsHelper::RatingOptions::ONE, AdminViewsHelper::RatingOptions::ONE],
      [AdminViewsHelper::RatingOptions::TWO, AdminViewsHelper::RatingOptions::TWO],
      [AdminViewsHelper::RatingOptions::THREE, AdminViewsHelper::RatingOptions::THREE],
      [AdminViewsHelper::RatingOptions::FOUR, AdminViewsHelper::RatingOptions::FOUR],
    ]
    options << [AdminViewsHelper::RatingOptions::FIVE, AdminViewsHelper::RatingOptions::FIVE] unless type == AdminViewsHelper::Rating::GREATER_THAN
    select_tag(name, options_for_select(options, value), attr_options)
  end

  def get_admin_view_title(role, program, admin_view)
    title = "feature.admin_view.label.eligibility_view_title".translate(role_name: role.customized_term.pluralized_term, program_name: program.name)
    return title if program.organization.admin_views.where("id != #{admin_view.id.to_i} and title = '#{title}'").blank?
    counter = 0
    new_title = nil
    while 1
      counter += 1
      new_title = title + " " + counter.to_s
      return new_title if program.organization.admin_views.where("id != #{admin_view.id.to_i} and title = '#{new_title}'").blank?
    end
  end

  def get_note_for_actions_on_suspended
    note = "feature.admin_view.content.does_not_apply_for_suspended".translate(organization_name: @current_organization.name)
    content_tag(:p, "#{'display_string.Note_with_colon'.translate} #{note}", class: "text-muted")
  end

  def get_note_for_suspension(program_context, count = 1)
    if program_context.is_a?(Program)
      user_or_member = "display_string.user".translate(count: count)
      general_note = "feature.admin_view.content.user_deactivation_note".translate(user: user_or_member, program: _program)
      link_label = "feature.admin_view.content.deactivation_notification".translate
      mailer_template = UserSuspensionNotification
    else
      user_or_member = "display_string.member_v1".translate(count: count)
      general_note = "feature.admin_view.content.member_suspension_note_v1".translate(member: user_or_member)
      link_label = "feature.admin_view.content.suspension_notification".translate
      mailer_template = MemberSuspensionNotification
    end

    unless program_context.email_template_disabled_for_activity?(mailer_template)
      mailer_template_link = link_to(link_label, edit_mailer_template_path(mailer_template.mailer_attributes[:uid]))
      email_note = "feature.admin_view.content.suspension_deactivation_email_note_html".translate(user_or_member: user_or_member, notification_link: mailer_template_link)
    end

    note = email_note.present? ? "#{email_note} #{general_note}" : general_note
    return content_tag(:div, note.html_safe, class: "text-muted")
  end

  def render_advanced_options_choices(admin_view, role_type, request_type, options = {})
    filter_params = admin_view.filter_params_hash if admin_view.filter_params.present?
    selected_duration = filter_params.present? && filter_params[:connection_status].present? && filter_params[:connection_status][:advanced_options].present? && filter_params[:connection_status][:advanced_options][request_type].present? && filter_params[:connection_status][:advanced_options][request_type][role_type].present? ? filter_params[:connection_status][:advanced_options][request_type][role_type][:request_duration].to_i : AdminView::AdvancedOptionsType::EVER

    unless selected_duration == AdminView::AdvancedOptionsType::EVER
      selected_value = filter_params[:connection_status][:advanced_options][request_type][role_type][selected_duration.to_s]
      selected_duration = AdminView::AdvancedOptionsType::EVER unless selected_value.present?
    end

    request_in_last_value = (selected_duration == AdminView::AdvancedOptionsType::LAST_X_DAYS) ? selected_value : ""
    request_after_value = (selected_duration == AdminView::AdvancedOptionsType::AFTER) ? DateTime.localize(DateTime.strptime(selected_value, "date.formats.date_range".translate), format: :full_display_no_time) : ""
    request_before_value = (selected_duration == AdminView::AdvancedOptionsType::BEFORE) ? DateTime.localize(DateTime.strptime(selected_value, "date.formats.date_range".translate), format: :full_display_no_time) : ""

    request_after_hidden_value = (selected_duration == AdminView::AdvancedOptionsType::AFTER) ? selected_value : ""
    request_before_hidden_value = (selected_duration == AdminView::AdvancedOptionsType::BEFORE) ? selected_value : ""

    if options[:get_hidden_field_tags]
      return hidden_field_tag("admin_view[connection_status][advanced_options][#{request_type}][#{role_type}][#{AdminView::AdvancedOptionsType::LAST_X_DAYS}]", request_in_last_value, :id => "hidden_advanced_options_for_#{role_type.to_s}_#{request_type.to_s}_#{AdminView::AdvancedOptionsType::LAST_X_DAYS}") +
      hidden_field_tag("admin_view[connection_status][advanced_options][#{request_type}][#{role_type}][#{AdminView::AdvancedOptionsType::AFTER}]", request_after_hidden_value, :id => "hidden_advanced_options_for_#{role_type.to_s}_#{request_type.to_s}_#{AdminView::AdvancedOptionsType::AFTER}") +
      hidden_field_tag("admin_view[connection_status][advanced_options][#{request_type}][#{role_type}][#{AdminView::AdvancedOptionsType::BEFORE}]", request_before_hidden_value, :id => "hidden_advanced_options_for_#{role_type.to_s}_#{request_type.to_s}_#{AdminView::AdvancedOptionsType::BEFORE}") +
      hidden_field_tag("admin_view[connection_status][advanced_options][#{request_type}][#{role_type}][request_duration]", selected_duration, :id => "hidden_advanced_options_for_#{role_type.to_s}_#{request_type.to_s}_request_duration")
    else
      content_tag(:div, class: "cjs_nested_show_hide_container") do
        content_tag(:div, class: "cjs_show_hide_sub_selector") do
          content_tag(:label, radio_button_tag("admin_view[connection_status][advanced_options][#{request_type}][#{role_type}][request_duration]", AdminView::AdvancedOptionsType::LAST_X_DAYS, selected_duration == AdminView::AdvancedOptionsType::LAST_X_DAYS, class: 'cjs_advanced_options_radio_btn cjs_radio_last_days', data: {input_id_prefix: "cjs_input_in_last_"}) + "feature.admin_view.label.in_last".translate, class: "radio cjs_toggle_radio") +
          construct_input_group([],[{:type => "addon", :content => "display_string.days".translate, :class => "no-border no-background"}], {:input_group_class => "cjs_toggle_content #{'hide' unless request_in_last_value.present?}"}) do
            number_field_tag("admin_view[connection_status][advanced_options][#{request_type}][#{role_type}][#{AdminView::AdvancedOptionsType::LAST_X_DAYS}]", request_in_last_value, :class => "form-control cjs_input_advanced_options", :id => "cjs_input_in_last_#{role_type}_#{request_type}", :min => AdminView::MIN_LAST_X_DAYS_VALUE)
          end + content_tag(:label, "feature.admin_view.label.in_last".translate, :for => "cjs_input_in_last_#{role_type}_#{request_type}", :class => "sr-only")
        end +
        content_tag(:div, class: "cjs_show_hide_sub_selector") do
          content_tag(:label, radio_button_tag("admin_view[connection_status][advanced_options][#{request_type}][#{role_type}][request_duration]", AdminView::AdvancedOptionsType::AFTER, selected_duration == AdminView::AdvancedOptionsType::AFTER, class: 'cjs_advanced_options_radio_btn cjs_radio_after', data: {input_id_prefix: "cjs_input_after_"}) + "feature.admin_view.label.after".translate, class: "radio cjs_toggle_radio") +
          content_tag(:div, :class => "cjs_toggle_content #{'hide' unless request_after_value.present?}") do
            construct_input_group([ { type: "addon", icon_class: "fa fa-calendar" } ], []) do
              text_field_tag("admin_view[connection_status][advanced_options][#{request_type}][#{role_type}][#{AdminView::AdvancedOptionsType::AFTER}]", request_after_value, :class => "form-control cjs_input_advanced_options", :id => "cjs_input_after_#{role_type}_#{request_type}", data: date_picker_options)
            end
          end + content_tag(:label, "feature.admin_view.label.after".translate, :for => "cjs_input_after_#{role_type}_#{request_type}", :class => "sr-only")
        end +
        content_tag(:div, class: "cjs_show_hide_sub_selector") do
          content_tag(:label, radio_button_tag("admin_view[connection_status][advanced_options][#{request_type}][#{role_type}][request_duration]", AdminView::AdvancedOptionsType::BEFORE, selected_duration == AdminView::AdvancedOptionsType::BEFORE, class: 'cjs_advanced_options_radio_btn cjs_radio_before', data: {input_id_prefix: "cjs_input_before_"}) + "feature.admin_view.label.before".translate, class: "radio cjs_toggle_radio") +
          content_tag(:div, :class => "cjs_toggle_content #{'hide' unless request_before_value.present?}") do
            construct_input_group([ { type: "addon", icon_class: "fa fa-calendar" } ], []) do
              text_field_tag("admin_view[connection_status][advanced_options][#{request_type}][#{role_type}][#{AdminView::AdvancedOptionsType::BEFORE}]", request_before_value, :class => "form-control cjs_input_advanced_options", :id => "cjs_input_before_#{role_type}_#{request_type}", data: date_picker_options)
            end
          end + content_tag(:label, "feature.admin_view.label.before".translate, :for => "cjs_input_before_#{role_type}_#{request_type}", :class => "sr-only")
        end +
        horizontal_line(:class => "no-margin") +
        content_tag(:div, class: "cjs_show_hide_sub_selector has-above cjs_requests_ever") do
          content_tag(:label, radio_button_tag("admin_view[connection_status][advanced_options][#{request_type}][#{role_type}][request_duration]", AdminView::AdvancedOptionsType::EVER, selected_duration == AdminView::AdvancedOptionsType::EVER, class: 'cjs_advanced_options_radio_btn cjs_radio_ever') + "feature.admin_view.label.ever".translate(:program => _program), class: "radio cjs_toggle_radio")
        end
      end
    end
  end

  def get_caption_and_help_text(remove_flag)
    if remove_flag
      ["feature.admin_view.content.remove_tag_from_selected", "feature.admin_view.content.tags_will_be_removed_note"]
    else
      ["feature.admin_view.content.add_tag_to_selected", "feature.admin_view.content.tags_will_be_added_note"]
    end
  end

  def get_back_link(source_info)
    { label: get_back_link_label(source_info), link: source_info.present? ? url_for(source_info) : back_url(admin_view_all_users_path) }
  end

  def get_users_role_hash(program, users, group = nil)
    role_id_user_details_hash = {}
    program.roles.for_mentoring.each do |role|
      role_id_user_details_hash[role.id] = []
    end
    return role_id_user_details_hash unless users.present?
    required_user_ids_hash = users.includes(:member).map{ |user| [user.id, user.email_with_id_hash] }.to_h
    get_group_memberships_of_selected_users(group, required_user_ids_hash, role_id_user_details_hash) if group.present?
    compute_users_role_hash(program, users, required_user_ids_hash, role_id_user_details_hash)
    role_id_user_details_hash
  end

  def hide_for_multi_track_admin?(admin_view, options = {})
    hide = admin_view.is_organization_view? && wob_member.try(:admin_only_at_track_level?)
    options[:get_class] ? (hide ? "hide" : "") : hide
  end

  def customize_value_for_multi_track_admin(admin_view, value, customized_value = nil)
    hide_for_multi_track_admin?(admin_view) ? (customized_value.presence || "#{value}-multi-track-admin") : value
  end

  def get_adminview_second_level_title(title)
    content_tag(:div, class: "p-sm") do
      content_tag(:div, title, class: "light-gray-bg p-xs font-600")
    end
  end

  private

  def get_group_memberships_of_selected_users(group, required_user_ids_hash, role_id_user_details_hash)
    group.memberships.includes(:role, [user: :roles]).group_by(&:role).each do |role, memberships|
      memberships.each do |membership|
        user_name_with_email_hash = required_user_ids_hash.delete(membership.user_id)
        role_id_user_details_hash[role.id] << user_name_with_email_hash if user_name_with_email_hash.present?
      end
    end
  end

  def get_filters_for_admin_view_kendo_filter(dynamic_filter_params)
    filters = []
    filters << {field: AdminViewColumn::Columns::Key::STATE, operator: "eq", value: User::Status::ACTIVE} if dynamic_filter_params[:state].present?
    filters << {field: AdminViewColumn::Columns::Key::ROLES, operator: "eq", value: dynamic_filter_params[:role]} if dynamic_filter_params[:role].present?
    filters << {field: AdminViewColumn::Columns::Key::GROUPS, operator: "gt", value: 0} if dynamic_filter_params[:connected].present?
    filters << AdminView::MEMBERS_IN_SPECIFIED_PROGRAMS.call(wob_member.programs_to_add_users.collect(&:id).join(",")) if (dynamic_filter_params[:multi_track_admin].present? || wob_member.admin_only_at_track_level?)
    filters << AdminView::MEMBER_WITH_ONGOING_ENGAGEMENTS_FILTER_HSH if (dynamic_filter_params[:non_profile_field_filters] || []).map{|hsh|hsh[:field]}.include?(AdminViewColumn::Columns::Key::ORG_LEVEL_ONGOING_ENGAGEMENTS)
    filters
  end

  def compute_users_role_hash(program, users, required_user_ids_hash, role_id_user_details_hash)
    role_ids = program.roles.for_mentoring.order(get_role_sort_order).pluck(:id)
    role_references = RoleReference.where(role_id: role_ids, ref_obj_type: User.name, ref_obj_id: users.collect(&:id)).select(:ref_obj_id, :role_id).group_by(&:role_id)
    role_ids.each do |role_id|
      next unless role_references[role_id].present?
      role_references[role_id].collect(&:ref_obj_id).each do |user_id|
        user_name_with_email_hash = required_user_ids_hash.delete(user_id)
        role_id_user_details_hash[role_id] << user_name_with_email_hash if user_name_with_email_hash.present?
      end
    end
  end

  def get_role_sort_order
    "field(name, '#{RoleConstants::MENTOR_NAME}', '#{RoleConstants::STUDENT_NAME}', '#{RoleConstants::TEACHER_NAME}')"
  end

  def get_custom_term_options
    {program_title: _Programs, Meeting: _Meeting, Mentoring_Connection: _Mentoring_Connection, Mentoring_Connections: _Mentoring_Connections, Mentoring: _Mentoring, mentees: _mentees}
  end

  def get_ordered_managing_programs
    wob_member.programs_to_add_users.order(:position)
  end

  def initial_data_for_daterange_picker(date_range_hash)
    {
      start: valid_date?(date_range_hash[:from_date], get_date: true).presence,
      end: valid_date?(date_range_hash[:to_date], get_date: true).presence
    }
  end
end