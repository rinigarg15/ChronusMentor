module ProgramInvitationsHelper
  KENDO_GRID_ID = "cjs_program_invitation_listing_kendogrid"
  DEFAULT_PAGE_SIZE = 30

  module BulkActionType
    RESEND = 1
    DELETE = 2
  end


  def program_invitation_listing_columns
    [
      { title: get_primary_checkbox_for_kendo_grid, field: "check_box", width: "2%", encoded: false, sortable: false, filterable: false },
      { field: "sent_to", width: "20%", headerTemplate: program_invitation_header_template(ProgramInvitation.kendo_headers["sent_to"]), encoded: false},
      { field: "sent_on", width: "15%", headerTemplate: program_invitation_header_template(ProgramInvitation.kendo_headers["sent_on"]) }.merge(column_format(:centered, :datetime)),
      { field: "expires_on", width: "15%", headerTemplate: program_invitation_header_template(ProgramInvitation.kendo_headers["expires_on"])  }.merge(column_format(:centered, :datetime)),
      { field: "roles_name", width: "12%", headerTemplate: program_invitation_header_template(ProgramInvitation.kendo_headers["roles_name"]), encoded: false}.merge(column_format(:centered)),
      { field: "sender", width: "12%", headerTemplate: program_invitation_header_template(ProgramInvitation.kendo_headers["sender"]), encoded: false }.merge(column_format(:centered)),
      { field: "statuses", width: "12%", headerTemplate: ProgramInvitation.kendo_headers["statuses"], sortable: false, encoded:false }.merge(column_format(:centered))
    ]
  end

  def program_invitation_listing_fields
    {
      id: { type: :string },
      sent_to: { type: :string },
      sent_on: { type: :date },
      expires_on: { type: :date },
      roles_name: { type: :string },
      sender: { type: :string },
      statuses: { type: :string}
    }
  end

  def can_invite_in_other_languages?(user)
    user.is_admin? && user.program.languages_enabled_and_has_multiple_languages_for_everyone?
  end

  # For teh checkboxes to work, pass a hash with keys :posted_as and :displayed_as
  def kendo_convert_status_array_to_checkbox_hash(arr)
    #use element as it is or extract values if the individual element are hashes
    arr.map do |ele|
      {
        displayed_as: ele.is_a?(Hash)? ele[:display_value] : ele,
        posted_as: ele.is_a?(Hash)? ele[:post_value] : ele
      }
    end
  end

  def status_checkboxes
    I18n.t("feature.program_invitations.kendo.filters.checkboxes.statuses").values
  end

  def customized_role_names(program)
    roles = program.roles.collect{|x| x.customized_term.term }
    roles << "feature.program_invitations.kendo.filters.checkboxes.roles.allow_roles".translate
  end

  #in the filter roles displayed as "customized_term" and posted to controller as (role)"name"
  def kendo_convert_role_names_array_to_checkbox_hash(program)
    roles = program.roles.map do |ele|
      {
        :displayed_as => ele.customized_term.term,
        :posted_as => ele.name
      }
    end
    roles << {
      :displayed_as => "feature.program_invitations.kendo.filters.checkboxes.roles.allow_roles".translate,
      :posted_as => "feature.program_invitations.kendo.filters.checkboxes.roles.allow_roles".translate
    }
  end

  def construct_options(program)
    {
      columns: program_invitation_listing_columns,
      fields: program_invitation_listing_fields,
      dataSource: program_invitations_path(format: :json, :other_invitations => params[:other_invitations]),
      grid_id: KENDO_GRID_ID,
      selectable: false,
      serverPaging: true,
      serverFiltering: true,
      serverSorting: true,
      sortable: true,
      pageable: {
        messages: {
          display: 'feature.program_invitations.kendo.pageable_message'.translate,
          empty: "feature.program_invitations.content.no_invitations".translate
        }
      },
      pageSize: DEFAULT_PAGE_SIZE,
      filterable: {
        messages: {
          info: '',
          filter: 'feature.program_invitations.kendo.filters.button_text.filter'.translate,
          clear: 'feature.program_invitations.kendo.filters.button_text.clear'.translate
        }
      },
      fromPlaceholder: 'display_string.From'.translate,
      toPlaceholder: 'display_string.To'.translate,
      checkbox_fields: [:statuses, :roles_name],
      checkbox_values: {
        :statuses => kendo_convert_status_array_to_checkbox_hash(status_checkboxes),
        :roles_name => kendo_convert_role_names_array_to_checkbox_hash(program)
      },
      simple_search_fields: [:sent_to, :sender],
      date_fields: [:sent_on, :expires_on]
    }
  end

  def initialize_program_invitation_listing_kendo_script(program, total_count, apply_pending_filter = false)
    options = construct_options(program)
    options.merge!({filter: {filters: [{field: "statuses", operator: "eq", value: "feature.program_invitations.kendo.filters.checkboxes.statuses.pending".translate}]}}) if apply_pending_filter
    #show only pending invitations for dashboard link
    javascript_tag %Q[CommonSelectAll.initializeSelectAll(#{total_count}, #{KENDO_GRID_ID}); CampaignsKendo.initializeKendo(#{options.to_json});]
  end

  def program_invitation_header_template(title)
    "#{title}<span class='non-sorted'></span>"
  end

  def column_format(*components)
    classes = []
    classes << "text-center" if components.include?(:centered)
    formats = {
      headerAttributes: { class: classes.join(' ') },
      attributes: { class: classes.join(' ') }
    }
    display_format =
      if components.include?(:numeric)
        "{0:p1}"
      elsif components.include?(:datetime)
        "{0:#{"feature.campaign.kendo.datetime_format".translate}}"
      elsif components.include?(:date)
        "{0:#{"feature.campaign.kendo.date_format".translate}}"
      end
    formats.merge!(format: display_format) if display_format.present?
    formats
  end

  def program_invitation_sender(program_invitation)
    deleted_user = content_tag(:i, "feature.program_invitations.label.deleted_user".translate)
    program_invitation.user.nil? ? j(deleted_user) : program_invitation.user.name(:name_only => true)
  end

  def program_invitation_recipient(program_invitation)
    if program_invitation.use_count > 0 && program_invitation.invitee_already_member?
      #only if accepted by a user mail id (not a group mail id)
      email = program_invitation.sent_to
      program = program_invitation.program
      member = program.organization.members.find_by(email: email)
      user = member.user_in_program(program)
      profile_link = link_to_user user, :class => "cjs-tool-tip", :content_text => program_invitation.sent_to, :data => {:desc => email}
      profile_link
    else
      recipient_email = content_tag(:span, program_invitation.sent_to, :class => "cjs-tool-tip", :data => {:desc => program_invitation.sent_to})
      recipient_email
    end
  end

  def days_since_sent(invite)
    days = invite.days_since_sent
    "feature.program_invitations.label.invited_x_days_ago".translate(count: days)
  end

  def message_of(invite)
    if invite.message.present?
      invite.message
    else
      # Invites need not have a message. And older invites do not have messages because the 'message' column was introduced later.
      content_tag(:i, "feature.mentor_offer.content.no_message".translate, :class => 'empty')
    end
  end

  def invites_path_for_filter
    link_to 'feature.program_invitations.header.invite_members'.translate, invite_users_path(:from => current_user.role_names)
  end

  def invitations_page_tabs_html
    tabs = invitations_page_tabs
    content_tag :ul, class: "nav nav-tabs h5 no-margins cui_program_invitation_tabs" do
      tabs.map do |tab_params|
        content_tag :li, class: tab_params[:active] ? "ct_active active" : "" do
          link_to tab_params[:label], tab_params[:url]
        end
      end.join.html_safe
    end.html_safe
  end

  def invitations_page_tabs
    tabs = [{
      :label => "feature.program_invitations.label.send_invites".translate,
      :url => new_program_invitation_path(:from => current_user.role_names),
      :active => (controller_name == 'program_invitations' && params[:action] == 'new')
    }, {
      :label => "feature.program_invitations.label.awaiting_acceptance".translate,
      :url => program_invitations_path,
      :active => (controller_name == 'program_invitations' && params[:action] == 'index' && !params[:other_invitations])
    }]

    if (@other_invitations.count > 0) || @current_program.non_admin_role_can_send_invite?
      tabs << {
          :label => "feature.program_invitations.label.view_other_invitations".translate,
          :url => view_other_invitations_path,
          :active => (controller_name == 'program_invitations' && params[:action] == 'index' && params[:other_invitations])
        }
    end
    return tabs
  end

  def can_user_invite_both_roles(user, role)
    [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME].include?(role) && user.can_invite_mentors? && user.can_invite_students?
  end

  def invitation_role(program_invitation)
    scope = program_invitation.roles
    scope = scope.order("roles.name #{@role_dir}") if defined?(@role_dir)
    role = RoleConstants.human_role_string(scope.map(&:name), :program => @current_program)
    program_invitation.role_type == ProgramInvitation::RoleType::ASSIGN_ROLE ? role : raw(content_tag(:i, "feature.program_invitations.content.allow_user_to_choose".translate(role: role)))
  end

  def invitation_status(program_invitation)
    if program_invitation.use_count > 0
      return "feature.program_invitations.kendo.filters.checkboxes.statuses.accepted".translate
    elsif program_invitation.expired?
      return content_tag(:span, "feature.program_invitations.kendo.filters.checkboxes.statuses.expired".translate, :class => "red")
    end
    get_highest_event_type_for_program_invitation_emails_sent(program_invitation)
  end

  def invitation_status_progressbar(program_invitation)
    j(render :partial => "program_invitations/progress_bar")
  end

  def get_highest_event_type_for_program_invitation_emails_sent(program_invitation)
    program_invitation_campaign_emails_ids = program_invitation.emails.pluck(:id)
    if !program_invitation_campaign_emails_ids.any?
      return "feature.program_invitations.kendo.filters.checkboxes.statuses.pending".translate
    end

    events = program_invitation.event_logs.pluck(:event_type)
    if !events.any?
      return "feature.program_invitations.kendo.filters.checkboxes.statuses.sent".translate
    end
    ProgramInvitation.process_invitation_events(events)
  end

  def get_user_role_options(program, user, options = {})
    non_admin_roles = program.roles.non_administrative.select{|role| Permission.exists_with_name?("invite_#{role.name.pluralize}") && user.send("can_invite_#{role.name.pluralize}?")}
    admin_roles = user.is_admin? ? program.roles.administrative.select{|role| Permission.exists_with_name?("invite_#{role.name.pluralize}") && user.send("can_invite_#{role.name.pluralize}?")} : []
    can_allow_roles_to_choose = non_admin_roles.size > 1
    content_tag(:div, class: "cjs_nested_show_hide_container cjs_roles_list #{options[:container_class]}",) do
      content_tag(:div, class: "cjs_show_hide_sub_selector has-above", id: "cjs_assign_roles") do
        content = []
        checkbox_content = []
        content << content_tag(:label, radio_button_tag('role', 'assign_roles', !can_allow_roles_to_choose, class: 'cjs_role_name_radio_btn') + "feature.program_invitations.content.assign_roles_to_users".translate, class: "radio cjs_toggle_radio #{'hide' unless can_allow_roles_to_choose}")
        if (non_admin_roles + admin_roles).present?
          (non_admin_roles + admin_roles).each do |role|
            checkbox_content << content_tag(:label, :class => "checkbox font-noraml m-l m-r #{'hide iconcol-md-offset-1' if can_allow_roles_to_choose} cjs_toggle_content" ) do
              check_box_tag("assign_roles[]", role.name, false, id: "assign_roles_add_#{role.name}_#{user.id}") + content_tag(:span, RoleConstants.human_role_string([role.name], program: program))
            end
          end
          content << choices_wrapper("display_string.Roles".translate){checkbox_content.join(" ").html_safe}
        else
          content << "feature.program_invitations.label.no_roles_to_invite".translate(program: _program)
        end
        content.join(" ").html_safe
      end +
      (content_tag(:div, class: "cjs_show_hide_sub_selector has-above", id: "cjs_allow_roles") do
        content = []
        checkbox_content = []
        content << content_tag(:label, radio_button_tag('role', 'allow_roles', false, :class => 'cjs_role_name_radio_btn') + "feature.program_invitations.content.allow_users_to_select_roles".translate + content_tag(:span, "display_string.non_admin_in_brackets".translate, class: "dim"), class: "radio cjs_toggle_radio")
        non_admin_roles.each do |role|
          checkbox_content << content_tag(:label, :class => "checkbox font-noraml m-l m-r hide iconcol-md-offset-1 cjs_toggle_content" ) do
            check_box_tag("allow_roles[]", role.name, false, id: "allow_roles_invite_#{role.name}_#{user.id}") + content_tag(:span, RoleConstants.human_role_string([role.name], program: program))
          end
        end
        content << choices_wrapper("display_string.Roles".translate){checkbox_content.join(" ").html_safe}
        content.join(" ").html_safe
      end if can_allow_roles_to_choose)
    end
  end

  def program_invitation_checkbox(id)
    content_tag(:input, "", type: "checkbox", class: "cjs_select_all_record cjs_program_invitation_checkbox cjs_select_all_checkbox_#{id}", id: "cjs_program_invitation_checkbox_#{id}", value: "#{id}") + label_tag("cjs_program_invitation_checkbox_#{id}", "#{id}", class: 'sr-only')
  end

  def program_invitation_bulk_actions
    bulk_actions = [
      { label: get_icon_content("fa fa-refresh") +  "feature.program_invitations.action.resend".translate, url: "javascript:void(0);", id: "cjs_resend_invitations", data: { type: BulkActionType::RESEND } },
      { label: get_icon_content("fa fa-trash") + "feature.campaign_message.delete".translate, url: "javascript:void(0);", id: "cjs_delete_invitations", data: { type: BulkActionType::DELETE } },
      { label: get_icon_content("fa fa-download") + "feature.admin_view.action.Export_to_csv".translate, url: "javascript:void(0);", id: "cjs_program_invitations_export_csv" }
    ]
    bulk_actions.each{ |action| action[:data].reverse_merge!(url: bulk_confirmation_view_program_invitations_path) if action[:data].present? }
    get_kendo_bulk_actions_box(bulk_actions)
  end

  def get_bulk_action_partial_for_program_invitation(bulk_action_type)
    case bulk_action_type
    when BulkActionType::RESEND
      render partial: "program_invitations/bulk_resend"
    when BulkActionType::DELETE
      render partial: "program_invitations/bulk_destroy"
    end
  end

  def render_invitation_emails(resend_emails)
    content = get_safe_string + content_tag(:span, resend_emails.first(ProgramInvitationsController::MAX_EMAILS_FOR_VIEW).join(COMMON_SEPARATOR))
    if resend_emails.size > ProgramInvitationsController::MAX_EMAILS_FOR_VIEW
      remaining_invites = resend_emails[ProgramInvitationsController::MAX_EMAILS_FOR_VIEW..-1].join(COMMON_SEPARATOR)
      with_more_content = content_tag(:span, get_safe_string + " #{'display_string.and'.translate} " + link_to("display_string.more_with_count".translate(count: resend_emails.size - ProgramInvitationsController::MAX_EMAILS_FOR_VIEW), "javascript: void(0)"), class: "cjs_show_and_hide_toggle_sub_selector cjs_show_and_hide_toggle_show")
      remaining_content = content_tag(:span, (get_safe_string + COMMON_SEPARATOR + remaining_invites), class: "cjs_show_and_hide_toggle_sub_selector cjs_show_and_hide_toggle_content hide")
      content += content_tag(:span, with_more_content + remaining_content, class: "cjs_show_and_hide_toggle_container")
    end
    content
  end

end
