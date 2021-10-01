module AdminActionsHelper

  def admin_panel_actions(profile_user = @profile_user, program = program_context)
    actions_sets = [
      [
        find_mentor_admin_panel_action(profile_user, program),
        wob_admin_panel_action(profile_user, program)
      ],
      [
        view_or_edit_profile_admin_panel_action(profile_user, @edit_view),
        download_profile_admin_panel_action(profile_user)
      ],
      [
        resend_signup_instructions_admin_panel_action(profile_user, program)
      ],
      [
        change_roles_admin_panel_action(profile_user),
        suspend_or_reactivate_admin_panel_action(profile_user),
        remove_admin_panel_action(profile_user)
      ]
    ]

    actions_sets.map(&:compact!)
    actions_sets.select!(&:present?)

    get_actions(actions_sets) { |action| action }
  end

  def member_admin_panel_actions(profile_member = @profile_member)
    actions = [
      invite_to_program_member_admin_panel_action(profile_member),
      add_to_program_member_admin_panel_action(profile_member),
      add_to_program_as_admin_member_admin_panel_action(profile_member),
      suspend_or_reactivate_member_admin_panel_action(profile_member),
      remove_member_admin_panel_action(profile_member)
    ]
    actions.compact.collect { |action| admin_panel_actions_wrapper(action) }
  end

  def group_panel_actions(group)
    user_is_only_owner = current_user.is_only_owner_of?(group)
    actions_sets = [
      [
        make_available_panel_action(group, user_is_only_owner),
        accept_and_mark_available_panel_action(group, user_is_only_owner),
        publish_group_panel_action(group),
        edit_group_profile_action(group),
        assign_template_panel_action(group, user_is_only_owner)
      ],
      [
        project_requests_panel_action(group),
        manage_members_panel_action(group),
        add_remove_owners_panel_action(group),
        allow_stop_user_requests_panel_action(group)
      ],
      [
        close_group_panel_action(group, label_class: "text-default", source: "profile"),
        reactivate_group_panel_action(group),
        discard_group_panel_action(group, user_is_only_owner),
        reject_project_panel_action(group, user_is_only_owner),
        withdraw_group_panel_action(group)
      ]
    ]

    actions_sets.map(&:compact!)
    actions_sets.select!(&:present?)
    get_actions(actions_sets) { |action| render_action_for_dropdown_button(action) }
  end

  def add_remove_owners_panel_action(group, options = {})
    if group.project_based? && current_user.can_manage_or_own_group?(group) && !(group.drafted? || group.closed? || group.rejected?)
      {
        label: append_text_to_icon("fa fa-user-plus text-default", "feature.connection.action.update_owners".translate),
        js: %Q[jQueryShowQtip(null, null, "#{fetch_owners_group_path(group, format: :js, view: options[:view], from_index: options[:from_index])}", {})]
      }
    end
  end

  def allow_stop_user_requests_panel_action(group)
    if group.program.allows_users_to_apply_to_join_in_project? && group.active?
      {
        label: append_text_to_icon("fa fa-gear text-default", "feature.connection.content.allow_or_stop_user_requests".translate),
        js: %Q[jQueryShowQtip(null, null, "#{edit_join_settings_group_path(group)}", {})],
        id: "edit_join_settings_link_#{group.id}"
      }
    end
  end

  def close_group_panel_action(group, options = {})
    return unless group.active?
    {
      label: append_text_to_icon("fa fa-ban #{options[:label_class]}", "feature.connection.action.Close_Connection_v1".translate(Mentoring_Connection: _Mentoring_Connection)),
      js: %Q[jQueryShowQtip(null, null, "#{fetch_terminate_group_path(group, src: options[:source])}", {})],
      id: "terminate_link_#{group.id}"
    }
  end

  private

  def get_actions(actions_sets)
    actions = []
    actions_sets.each_with_index do |actions_set, index|
      actions += actions_set.collect { |action| admin_panel_actions_wrapper(yield(action)) }
      actions << content_tag(:li, horizontal_line(class: "m-t-xs m-b-xs")) if actions_sets.size != (index + 1)
    end
    actions
  end

  def admin_panel_actions_wrapper(action_content)
    content_tag :li, class: "admin_panel_action list-group-item no-borders" do
      action_content
    end
  end

  def find_mentor_admin_panel_action(profile_user, program)
    if program.ongoing_mentoring_enabled? && profile_user.is_student? && !program.project_based?
      user_limit_reached = profile_user.connection_limit_as_mentee_reached?
      action_enabled = !user_limit_reached && !profile_user.suspended?
      tooltip_text =
        if user_limit_reached
          "feature.profile.content.max_conn_limit_reached".translate(mentees: _mentees)
        elsif profile_user.suspended?
          "feature.profile.content.user_inactive_v1".translate(user_name: profile_user.name)
        end
      tooltip_options = { data: { toggle: "tooltip", title: tooltip_text } } if tooltip_text.present?

      content_tag(:span, { class: "text-muted" }.merge!(tooltip_options || {})) do
        link_to_if(action_enabled, append_text_to_icon("fa fa-users text-default", "feature.profile.actions.find_a_mentor".translate(a_mentor: _a_Mentor)),
          matches_for_student_users_path(student_name: profile_user.name_with_email, src: "students_profile"))
      end
    end
  end

  def wob_admin_panel_action(profile_user, program)
    return if current_user == profile_user
    return if working_on_behalf?
    return unless current_user.can_work_on_behalf? && program.has_feature?(FeatureName::WORK_ON_BEHALF)
    return if profile_user.member.admin? && !current_member.admin?

    wob_icon_with_text = append_text_to_icon("fa fa-user-secret text-default", "feature.profile.label.wob".translate)
    content = link_to(wob_icon_with_text, work_on_behalf_user_path(profile_user),
      method: :post, data: { disable_with: wob_icon_with_text }, id: "wob_link")
    content << tooltip("wob_link", "feature.profile.content.wob_help_text_html".translate(user_name: content_tag(:b, profile_user.name)))
  end

  def view_or_edit_profile_admin_panel_action(profile_user, edit_view)
    user_name = profile_user.name(name_only: true)
    profile_member = profile_user.member

    label, url =
      if edit_view
        ["feature.profile.actions.view_users_profile".translate(user_name: user_name), member_path(profile_member)]
      else
        ["feature.profile.actions.edit_users_profile".translate(user_name: user_name), edit_member_path(profile_member)]
      end
    link_to(append_text_to_icon("fa fa-user text-default", label), url, id: "side_edit_profile_link")
  end

  def download_profile_admin_panel_action(profile_user)
    return if current_user == profile_user

    content = link_to(append_text_to_icon("fa fa-download text-default", "feature.profile.content.download_as_pdf".translate), member_path(profile_user.member, format: :pdf),
      id: "download_pdf_link", target: "_blank", class: "cjs_external_link")
    content << tooltip("download_pdf_link", "feature.profile.content.download_as_pdf_help_html".translate(user_name: content_tag(:b, profile_user.name)))
  end

  def resend_signup_instructions_admin_panel_action(profile_user, program)
    return if profile_user == current_user

    # An admin view object is needed here to send the request to resend_signup_instructions
    # So, here we are using the default, all users admin view. Please note that, any admin view can be used
    # Only restriction is that, it should be a program level admin view.
    all_users_view = program.admin_views.find_by(default_view: AbstractView::DefaultType::ALL_USERS)
    resend_signup_instructions_url = resend_signup_instructions_admin_view_path(all_users_view, admin_view: { users: profile_user.id.to_s }, from: AdminViewsController::REFERER::MEMBER_PATH)
    link_to(append_text_to_icon("fa fa-retweet text-default", "feature.profile.actions.resend_signup_instructions".translate), resend_signup_instructions_url,
      method: :post, data: { confirm: resend_signup_confirmation(profile_user) } )
  end

  def resend_signup_confirmation(user)
    content = get_safe_string
    unless user.requires_signup?
      content << ("feature.profile.content.user_already_signed_up_html".translate(User: user.name, organization: @current_organization.name, already_signed_up: content_tag(:b, "feature.profile.content.already_signed_up".translate)) + '<br/>'.html_safe)
    end
    content << email_notification_consequences_on_action_html(ResendSignupInstructions, div_class: "m-t-xs", with_count: true, count: 1)
  end

  def change_roles_admin_panel_action(profile_user)
    if current_user.can_manage_user_states? && profile_user.member.active?
      link_to(append_text_to_icon("fa fa-pencil text-default", "quick_links.side_pane.change_user_roles".translate), "javascript:void(0)", id: "change_roles_link",
        class: "remote-popup-link", data: { url: fetch_change_roles_user_path(profile_user), size: 600 } )
    end
  end

  def suspend_or_reactivate_admin_panel_action(profile_user)
    return if profile_user == current_user
    return unless current_user.can_manage_user_states?

    allowed_aasm_events = profile_user.aasm.events.map(&:name)
    user_name = content_tag(:b, profile_user.name)

    if allowed_aasm_events.include?(:suspend) && current_user.can_remove_or_suspend?(profile_user)
      content = link_to(append_text_to_icon("fa fa-times text-default", "feature.profile.actions.deactivate_membership".translate), "javascript:void(0)", id: "suspend_link_#{profile_user.id}",
        data: { target: "#modal_suspend_link_#{profile_user.id}", toggle: "modal" } )
      content << tooltip("suspend_link_#{profile_user.id}", "feature.profile.content.suspend_membership_tooltip_v1_html".translate(user_name: user_name, program: _program))
      content << render(partial: "users/suspend_user", locals: { profile_user: profile_user } )
    elsif allowed_aasm_events.include?(:activate) && profile_user.suspended?
      reactivate_label = append_text_to_icon("fa fa-check text-default", "feature.profile.actions.Reactivate_Membership".translate)

      if profile_user.member.suspended?
        content = content_tag(:span, reactivate_label, class: "text-muted", id: "cjs_reactivate_link")
        content << tooltip("cjs_reactivate_link", "feature.profile.content.suspended_member_reactivation_tooltip_v1_html".translate(user_name: user_name, programs: _programs, organization_name: @current_organization.name))
      else
        content = link_to(reactivate_label, change_user_state_user_path(profile_user, new_state: User::Status::ACTIVE), method: :post, id: "reactivate_user_link",
          data: { confirm: "feature.profile.content.reactivate_confirm_v1_html".translate(contextual_msg: email_notification_consequences_on_action_html(UserActivationNotification, div_enclose: false, with_count: true, count: 1)) } )
        content << tooltip("reactivate_user_link", "feature.profile.content.reactivate_tooltip_v1_html".translate(user_name: user_name, program: _program))
      end
    end
  end

  def remove_admin_panel_action(profile_user)
    return unless current_user.can_remove_or_suspend?(profile_user)

    content = link_to(append_text_to_icon("fa fa-trash text-default", "feature.profile.label.remove_user".translate(user_name: profile_user.name)), "javascript:void(0)", id: "remove_link_#{profile_user.id}",
      data: { target: "#modal_remove_link_#{profile_user.id}", toggle: "modal" } )
    content << tooltip("remove_link_#{profile_user.id}", "feature.profile.content.remove_user_tooltip_html".translate(user_name: content_tag(:b, profile_user.name), program: _program))
    content << render(partial: "users/remove_user", locals: { profile_user: profile_user } )
  end

  def invite_to_program_member_admin_panel_action(profile_member)
    return if profile_member.suspended? || profile_member.admin?

    link_to(append_text_to_icon("fa fa-envelope text-default", "feature.profile.actions.invite_to_prog".translate(program: _Program)), "javascript:void(0)",
      id: "invite_user_to_program", js: true, data: { target: "#modal_invite_user_to_program", toggle: "modal" } )
  end

  def add_to_program_member_admin_panel_action(profile_member)
    return if profile_member.suspended? || profile_member.admin?

    content = link_to(append_text_to_icon("fa fa-plus text-default", "feature.profile.actions.add_to_prog".translate(program: _Program)), "javascript:void(0)",
      id: "add_user_to_program", js: true, data: { target: "#modal_add_user_to_program", toggle: "modal" } )
    content << tooltip("add_user_to_program", "feature.profile.content.add_user_tooltip".translate(program: _program))
    content << render(partial: 'members/add_member_to_program', locals: { member: profile_member } )
  end

  def add_to_program_as_admin_member_admin_panel_action(profile_member)
    return if profile_member.suspended? || profile_member.admin?

    content = link_to(append_text_to_icon("fa fa-user-plus text-default", "feature.profile.actions.add_user_as_admin".translate(admin: _Admin)), "javascript:void(0)",
      id: "add_user_to_program_as_admin", js: true, data: { target: "#modal_add_user_to_program_as_admin", toggle: "modal" } )
    content << tooltip("add_user_to_program_as_admin", "feature.profile.content.add_user_as_admin_tooltip".translate(admin: _Admin))
    content << render(partial: 'members/add_member_to_program_as_admin', locals: { member: profile_member } )
  end

  def suspend_or_reactivate_member_admin_panel_action(profile_member)
    member_name = content_tag(:b, profile_member.name)

    if profile_member.suspended?
      content = link_to(append_text_to_icon("fa fa-check text-default", "feature.profile.actions.Reactivate_Membership".translate), update_state_member_path(profile_member),
        method: :patch, data: { confirm: get_reactivate_member_confirmation(profile_member) }, id: "reactivate_membership_link")
      content << tooltip("reactivate_membership_link", "feature.profile.content.reactivate_organization_html".translate(member: member_name))
    elsif wob_member.can_remove_or_suspend?(profile_member)
      content = link_to(append_text_to_icon("fa fa-times text-default", "feature.profile.actions.suspend_membership".translate), "javascript:void(0)",
        id: "suspend_membership_link", data: { target: "#modal_suspend_membership_link", toggle: "modal" } )
      content << tooltip("suspend_membership_link", "feature.profile.content.suspend_membership_org_tooltip_html".translate(name: member_name))
      content << render(partial: "members/suspend_member", locals: { member: profile_member } )
    end
  end

  def remove_member_admin_panel_action(profile_member)
    return unless wob_member.can_remove_or_suspend?(profile_member)

    content = link_to(append_text_to_icon("fa fa-trash text-default", "feature.profile.label.remove_user".translate(user_name: profile_member.name)), "javascript:void(0)",
      id: "remove_member_link", data: { target: "#modal_remove_member_link", toggle: "modal" } )
    content << tooltip("remove_member_link", "feature.profile.content.remove_user_tooltip_html".translate(user_name: content_tag(:b, profile_member.name), program: @current_organization.name))
    content << render(partial: "members/remove_member", locals: { member: profile_member } )
  end

  def get_reactivate_member_confirmation(profile_member)
    message = get_safe_string
    message << "feature.profile.content.confirm_reactivate_membership".translate(member: profile_member.name)
    message << tag(:br)
    message << email_notification_consequences_on_action_html(MemberActivationNotification, organization_or_program: @current_organization, div_enclose: false, with_count: true, count: 1)
  end

  def make_available_panel_action(group, user_is_only_owner)
    return if user_is_only_owner
    if current_program.project_based? && group.drafted?
      {
        label: append_text_to_icon("fa fa-check-square text-default", "feature.connection.action.Make_Available".translate(Mentoring_Connection: _Mentoring_Connection)),
        js: %Q[jQueryShowQtip(null, null, "#{fetch_bulk_actions_groups_path(individual_action: true, src: "profile", bulk_action: { group_ids: [group.id], action_type: Group::BulkAction::MAKE_AVAILABLE})}", {})]
      }
    end
  end

  def accept_and_mark_available_panel_action(group, user_is_only_owner)
    return if user_is_only_owner || !group.proposed?
    {
      label: append_text_to_icon("fa fa-check-square text-default", "feature.connection.action.accept_and_mark_available".translate),
      js: %Q[jQueryShowQtip(null, null, "#{fetch_bulk_actions_groups_path(individual_action: true, src: "profile", bulk_action: { group_ids: [group.id], action_type: Group::BulkAction::ACCEPT_PROPOSAL})}", {})],
      id: "accept_and_mark_available_#{group.id}"
    }
  end

  def publish_group_panel_action(group)
    if (group.drafted? && !group.project_based?) || group.pending?
      {
        label: append_text_to_icon('fa fa-check-square text-default', "feature.connection.action.Publish_Connection_v1".translate(Mentoring_Connection: _Mentoring_Connection)),
        js: %Q[jQueryShowQtip(null, null, "#{fetch_publish_group_path(group, src: "profile")}", {})],
        id: "publish_group_#{group.id}"
      }
    end
  end

  def edit_group_profile_action(group)
    if !group.closed? && current_program.connection_profiles_enabled?
      {
        label: append_text_to_icon("fa fa-pencil-square-o text-default", "quick_links.side_pane.edit_mentoring_connection_profile".translate(mentoring_connection: _Mentoring_Connection)),
        url: edit_answers_group_path(group),
        id: "edit_answers_#{group.id}"
      }
    end
  end

  def project_requests_panel_action(group)
    if current_program.project_based? && group.open? && (pending_requests_count = group.active_project_requests.size) > 0
      {
        label: append_text_to_icon("fa fa-user-plus text-default", "quick_links.side_pane.requests_to_join".translate) + content_tag(:span, pending_requests_count, class: "pull-right badge badge-danger"),
        url: ProjectRequest.get_project_request_path_for_privileged_users(current_user, filters: { project: group.name }, from_quick_link: true, from_profile: true)
      }
    end
  end

  def manage_members_panel_action(group)
    if !group.closed? && !group.proposed? && current_user.can_manage_members_of_group?(group)
      {
        label: append_text_to_icon("fa fa-user-plus text-default", "feature.connection.action.manage_members_v1".translate),
        js: %Q[jQueryShowQtip(null, null, "#{edit_group_path(group, src: "profile")}", {})],
        id: "update_members_link_#{group.id}"
      }
    end
  end

  def assign_template_panel_action(group, user_is_only_owner)
    return if user_is_only_owner
    if current_program.mentoring_connections_v2_enabled? && !group.proposed? && !group.published?
      {
        label: append_text_to_icon("fa fa-check-square-o text-default", "feature.connection.action.Assign_Template_v1".translate(Mentoring_Connection: _Mentoring_Connection)),
        js: %Q[jQueryShowQtip(null, null, "#{fetch_bulk_actions_groups_path(individual_action: true, src: "profile", bulk_action: { group_ids: [group.id], action_type: Group::BulkAction::ASSIGN_TEMPLATE})}", {})]
      }
    end
  end

  def reactivate_group_panel_action(group)
    return unless group.closed?
    {
      label: append_text_to_icon("fa fa-check text-default", "feature.connection.action.Reactivate_Connection_v1".translate(Mentoring_Connection: _Mentoring_Connection)),
      js: %Q[jQueryShowQtip(null, null, "#{fetch_reactivate_group_path(group, src: GroupsController::ReactivationSrc::PROFILE)}", {})],
      id: "reactivate_link_#{group.id}"
    }
  end

  def discard_group_panel_action(group, user_is_only_owner)
    return if user_is_only_owner || !group.drafted?
    {
      label: append_text_to_icon("fa fa-trash text-default", "feature.connection.action.Discard_Connection_v1".translate(Mentoring_Connection: _Mentoring_Connection)),
      js: %Q[jQueryShowQtip(null, null, "#{fetch_discard_group_path(group, src: "profile")}", {})],
      id: "discard_group_#{group.id}"
    }
  end

  def reject_project_panel_action(group, user_is_only_owner)
    return if user_is_only_owner || !group.proposed?
    {
      label: append_text_to_icon("fa fa-ban text-default", "feature.connection.action.reject".translate(Mentoring_Connection: _Mentoring_Connection)),
      js: %Q[jQueryShowQtip(null, null, "#{fetch_bulk_actions_groups_path(src: "profile", bulk_action: { group_ids: [group.id], action_type: Group::BulkAction::REJECT_PROPOSAL})}", {})],
      id: "reject_project_proposal_#{group.id}"
    }
  end

  def withdraw_group_panel_action(group)
    return unless group.pending?
    {
      label: append_text_to_icon("fa fa-undo text-default", "feature.connection.action.Withdraw_Connection_v1".translate(Mentoring_Connection: _Mentoring_Connection)),
      js: %Q[jQueryShowQtip(null, null, "#{fetch_withdraw_group_path(group, src: "profile")}", {})],
      id: "withdraw_project_proposal_#{group.id}"
    }
  end
end