module MembershipRequestsHelper
  include CommonControllerUsages
  include AuthenticationExtensions

  #
  # Possible outputs:
  # 1. [] --> In case there are no instructions to be shown in the required position
  # 2. [["mentor", mentor_instruction]] --> In case there is only mentor instruction in the required position
  # 3. [["student", student_instruction]] --> In case there is only student instruction in the required position
  # 4. [["mentor", mentor_instruction], [nil, student_instruction]] --> In case both the instructions are to be shown in
  #     the given position
  #
  def get_instructions_for_roles(role_names, position, program = @current_program)
    instructions = []
    mentor_instruction = program.membership_instruction_for_mentors
    mentor_role = role_names.include?(RoleConstants::MENTOR_NAME)
    student_role = role_names.include?(RoleConstants::STUDENT_NAME)
    if mentor_role && !mentor_instruction.content.blank? && mentor_instruction.position == position
      instructions << [_mentors, mentor_instruction]
    end

    student_instruction = program.membership_instruction_for_students
    if student_role && !student_instruction.content.blank? && student_instruction.position == position
      instructions << [(mentor_role ? nil : _mentees), student_instruction]
    end
    instructions
  end

  def response_actions(req, _user)
    if req.pending?
      render(:partial => "membership_requests/response_actions", :locals => { :membership_request => req })
    end
  end

  def get_page_action_for_join_instruction
    {label: "feature.profile_customization.content.update_join_instructions".translate, class: "btn btn-primary btn-large", js: %Q[jQueryShowQtip(null, null, '#{get_instruction_form_membership_request_instructions_path}')]}
  end

  def membership_request_status(req, _user)
    return if req.pending?
    status_str = get_status_string(req)
    accepted_as = content_tag(:div, "feature.membership_request.label.as_role".translate(role: req.accepted_as_str)) if req.accepted? && req.accepted_as
    status_info = content_tag(:div) do
      "#{accepted_as}".html_safe +
      "feature.membership_request.label.by_person_on_time".translate(person: h(req.closed_by.name),
        on_time: formatted_time_in_words(req.closed_at, :on_str => true).html_safe).html_safe
    end
    profile_field_container_wrapper(status_str, status_info, :heading_tag => :h4, :class=>"m-t-xs m-b-xs")
  end

  def listing_display_name(membership_request, viewer_member)
    member = membership_request.member
    if member.present?
      if membership_request.user.present?
        display_name = link_to_user(member, params: { root: membership_request.program.root } )
      elsif viewer_member.admin? && (!member.dormant? || @current_organization.org_profiles_enabled?)
        display_name = link_to_user(member, params: { organization_level: true } )
      end
    end
    display_name ||= "#{h(membership_request.name)} (#{mail_to(h(membership_request.email))})".html_safe
  end

  def membership_user_info_for_listing(membership_request, viewer_member, program)
    td_text = "".html_safe
    values = [membership_request.first_name, membership_request.last_name, mail_to(membership_request.email)]
    if membership_request.member.present?
      if membership_request.user.present?
        values = values[0..1].map{|v| link_to_user(membership_request.member, :content_text => v, :params => {:root => program.root})} + [values[2]]
      elsif viewer_member.admin?
        values = values[0..1].map{|v| link_to_user(membership_request.member, :content_text => v, :params => {:organization_level => true})} + [values[2]]
      end
    end
    values.each do |value|
      td_text += content_tag(:td, value)
    end
    td_text
  end

  def get_membership_question_id(detail)
    question = ProfileQuestion.find(detail[:id])
    if question.education?
      "#edu_cur_list_#{question.id}"
    elsif question.experience?
      "#exp_cur_list_#{question.id}"
    elsif question.publication?
      "#publication_cur_list_#{question.id}"
    elsif question.manager?
      "#manager_cur_list_#{question.id}"
    elsif question.ordered_options_type?
      "#profile_answers_#{question.id}_0"
    else
      "#profile_answers_#{question.id}"
    end
  end

  def get_membership_request_title_header(membership_request_questions, sort_param, sort_order, list)
    header_th = "".html_safe
    membership_request_questions.each do |question|
      next if question.default_type?
      html_options = {}
      _header_id = "header_#{question.id}"
      key = "question-#{question.id}"
      order = (sort_param == key) ? sort_order : "both"
      sort_options = {
        :class => "sort_#{order} pointer cjs_sortable_element truncate-with-ellipsis whitespace-nowrap",
        :data => { :sort => key }
      }
      html_options.merge!(sort_options)

      trunc_text, _truncated = truncate_html(h(question.question_text), :max_length => 40, :status => true)
      header_th += content_tag(:th, trunc_text, html_options.deep_merge(data: {toggle: "tooltip", title: h(question.question_text)}))
    end
    membership_request_status_header(list) + header_th
  end

  def membership_request_status_header(list_type)
    header_th = "".html_safe
    columns = Array(get_membership_request_status_header_columns(list_type))
    html_options = {
      :class => "truncate-with-ellipsis whitespace-nowrap",
    }
    columns.each do |column|
      header_th += content_tag(:th, column, html_options.merge(data: {toggle: "tooltip", title: column}))
    end
    header_th
  end

  def membership_user_info_header(sort_param, sort_order)
    header_th = "".html_safe
    html_options = {}
    sort_fields = [
      {:field => "first_name", :label => "activerecord.attributes.member.first_name".translate},
      {:field => "last_name", :label => "activerecord.attributes.member.last_name".translate},
      {:field => "email", :label => "activerecord.attributes.member.email".translate}
    ]

    sort_fields.each do |field_data|
      key = field_data[:field]
      order = (sort_param == key) ? sort_order : "both"
      sort_options = {
        :class => "sort_#{order} pointer cjs_sortable_element truncate-with-ellipsis whitespace-nowrap",
        :data => { :sort => key }
      }
      html_options.merge!(sort_options)
      header_th += content_tag(:th, field_data[:label], html_options.deep_merge({data: {toggle: "tooltip", title: field_data[:label]}}))
    end
    header_th
  end

  def membership_request_status_row_values(request, list_type)
    td_text = "".html_safe
    return td_text if list_type == MembershipRequest::FilterStatus::PENDING
    values = [request.closed_by.name, formatted_time_in_words(request.closed_at).html_safe]
    if request.accepted?
      values << request.accepted_as_str
    elsif request.rejected?
      values << chronus_auto_link(request.response_text)
    end
    values.each_with_index do |value, index|
      td_text += content_tag(:td, value, :id => "answer_#{request.id}_status_#{index}")
    end
    td_text
  end

  def get_membership_request_row_values(request, membership_request_questions, list_type)
    td_text = "".html_safe
    all_answers = request.profile_answers.includes([:educations, :experiences, :publications, :answer_choices]).group_by(&:profile_question_id)
    membership_request_questions.each do |question|
      next if question.default_type?
      options = question.text_question? ? { truncate_size: 30 } : {}
      formated_answer = format_membership_request_answers(question, all_answers, options)
      td_text << content_tag(:td, formated_answer, :id => "answer_#{request.id}_#{question.id}")
    end
    membership_request_status_row_values(request, list_type) + td_text
  end

  def format_membership_request_answers(question, all_answers, options = {})
    if all_answers[question.id].present?
      answer = [get_user_answer(all_answers[question.id][0], question)]
      options.merge!(for_csv: false)
      format_user_answers(answer, [] , question, options)
    end
  end

  def membership_requests_bulk_actions(tab)
    bulk_actions = []
    common_options = { url: "javascript:void(0);" }

    if tab == MembershipRequest::FilterStatus::PENDING
      common_options[:class] = "cjs_membership_request_bulk_update"
      bulk_actions << common_options.merge(icon: 'fa fa-check m-r-xxs', label: "feature.membership_request.label.accept".translate, data: { url: new_bulk_action_membership_requests_path(status: MembershipRequest::Status::ACCEPTED) } )
      bulk_actions << common_options.merge(icon: 'fa fa-envelope m-r-xxs', label: "display_string.Send_Message".translate, class: "cjs_bulk_send_message", data: { url: new_bulk_admin_message_admin_messages_path } )
      bulk_actions << common_options.merge(icon: 'fa fa-times m-r-xxs', label: "feature.membership_request.label.reject".translate, data: { url: new_bulk_action_membership_requests_path(status: MembershipRequest::Status::REJECTED) } )
      bulk_actions << common_options.merge(icon: 'fa fa-trash m-r-xxs', label: "feature.membership_request.label.ignore".translate, data: { url: new_bulk_action_membership_requests_path } )
    end

    common_options[:class] = "cjs_membership_request_export"
    bulk_actions << common_options.merge(icon: 'fa fa-file-pdf-o m-r-xxs', label: "feature.membership_request.label.export_as_pdf".translate, data: { url: export_membership_requests_path(format: :js, tab: tab), ajax: true } )
    bulk_actions << common_options.merge(icon: 'fa fa-file-excel-o m-r-xxs', label: "feature.membership_request.label.export_as_csv".translate, data: { url: export_membership_requests_path(format: :csv, tab: tab) } )

    dropdown_buttons_or_button(bulk_actions, dropdown_title: 'display_string.Actions'.translate, is_not_primary: true, embed_icon: true, primary_btn_class: "btn-white")
  end

  def membership_requests_export_form
    form_tag "javascript:void(0)", id: "membership_requests_export_form" do
      hidden_field_tag :membership_request_ids, nil, id: nil, class: "membership_request_ids"
    end
  end

  def membership_requests_listing_non_filter_params(processed_data = {}, items_per_page = nil)
    non_filter_params = {}

    non_filter_params[:sort] = processed_data[:sort_field] if processed_data[:sort_field].present?
    non_filter_params[:order] = processed_data[:sort_order] if processed_data[:sort_order].present?
    non_filter_params[:items_per_page] = items_per_page if items_per_page.present?
    non_filter_params
  end

  def membership_requests_listing_filter_params(processed_data = {})
    processed_data[:filters].present? ? {filters: processed_data[:filters]} : {}
  end

  def display_membership_instruction(instruction_content, is_empty_form = false)
    instruction_text = if instruction_content.present?
      sanitize(auto_link(textilize(instruction_content)))
    elsif is_empty_form
      "join_now_page.no_questions_to_answer".translate
    else
      "#{'join_now_page.common_instruction'.translate} #{'join_now_page.common_instruction_help_text'.translate}"
    end

    content_tag(:div, class: "alert alert-info") do
      append_text_to_icon("fa fa-info-circle", instruction_text, media_padding_with_icon: true)
    end
  end

  def construct_role_options(roles, allow_multiple_roles)
    role_name_term_mapping = RoleConstants.program_roles_mapping(@current_program, roles: roles)

    choices_wrapper("display_string.Roles".translate, id: "apply_for") do
      role_content = ""
      single_role = roles && roles.length == 1
      roles.each do |role|
        role_content += construct_role_radio_button(role.name, role_name_term_mapping[role.name], role, single_role)
      end
     # Showing only 'mentor & mentee' option, not all combinations
      if !single_role && allow_multiple_roles
        display_content = [role_name_term_mapping[RoleConstants::MENTOR_NAME], role_name_term_mapping[RoleConstants::STUDENT_NAME]].to_sentence
        role_content += construct_role_radio_button([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME].join(COMMON_SEPARATOR), display_content)
      end
      role_content.html_safe
    end
  end

  def verified_using_sso_text
    return unless new_user_authenticated_externally?

    user_name = session_import_data_name
    user_email = session_import_data_email || (session[:new_custom_auth_user][:is_uid_email] && session[:new_custom_auth_user][@current_organization.id])
    return if user_name.blank? && user_email.blank?

    auth_config = new_user_external_auth_config
    content_tag(:fieldset, class: "") do
      control_group(class: "clearfix") do
        inner_content = content_tag(:div, "display_string.verified_as".translate, class: "control-label false-label col-sm-2")
        inner_content +
          controls(class: "col-sm-10 form-control-static") do
            content_tag(:div, class: "media") do
              uid_content = get_safe_string
              uid_content += content_tag(:span, image_tag(auth_config.logo_url, size: "21x21"), class: "media-left") if auth_config.logo_url.present?
              uid_content + content_tag(:span, user_name.presence || user_email, class: "media-body p-t-1")
            end
          end
      end
    end
  end

  def get_checkbox_data_for_membership_request(membership_request)
    content_tag(:label, "feature.mentor_request.content.select_this_label_v1".translate, for: "ct_membership_request_checkbox_#{membership_request.id}", class: "sr-only") +
    check_box_tag("membership_request_checkbox_#{membership_request.id}", membership_request.id, false, class: "cjs_membership_request_record", id: "ct_membership_request_checkbox_#{membership_request.id}", data: { member_id: membership_request.member_id })
  end

  def get_tabs_for_membership_requests_listing(active_tab)
    label_tab_mapping = {
      "feature.membership_request.label.pending".translate => MembershipRequest::FilterStatus::PENDING,
      "feature.membership_request.label.accepted".translate => MembershipRequest::FilterStatus::ACCEPTED,
      "feature.membership_request.label.rejected".translate => MembershipRequest::FilterStatus::REJECTED
    }
    get_tabs_for_listing(label_tab_mapping, active_tab, url: membership_requests_path, param_name: :tab)
  end

  private

  def construct_role_radio_button(value, display_content, role = nil, single_role = false)
    role_description = role.is_a?(Role) && role.description && role.description.html_safe

    content_tag(:label, class: "radio m-b-md") do
      concat radio_button_tag "roles", value, single_role, class: "cjs_signup_role #{'hide' if single_role}"
      concat display_role_content(@current_organization, role, role_description, display_content)
    end
  end

  def get_status_string(request)
    {
      MembershipRequest::Status::ACCEPTED => content_tag(:span, "feature.membership_request.label.accepted".translate, :class => 'cui_acceptance_info font-600'),
      MembershipRequest::Status::REJECTED => content_tag(:span, "feature.membership_request.label.rejected".translate, :class => 'cui_rejection_info font-600'),
    }[request.status].html_safe
  end

  def get_membership_request_status_header_columns(list_type)
    case list_type
    when "accepted"
      [
        "feature.membership_request.label.accepted_by".translate,
        "feature.membership_request.label.accepted_on".translate,
        "feature.membership_request.label.accepted_role".translate
      ]
    when "rejected"
      [
        "feature.membership_request.label.rejected_by".translate,
        "feature.membership_request.label.rejected_on".translate,
        "feature.membership_request.label.rejection_reason".translate
      ]
    end
  end
end