module MentorRequestsHelper
  def render_exp(member)
    _first_experience = member.experiences.first
    _text = _first_experience ? [_first_experience.job_title, _first_experience.company] : []
    truncate(_text.reject(&:blank?).join(", ").strip_html, :length => 60)
  end

  def name_auto_complete(object, method, rand_id, tag_options = {}, completion_options = {})
    default_options = {
      :id => "choice_#{rand_id}",
      :class => "form-control cjs_mentor_name",
      :name => "preferred_mentor_ids[]",
      :label => "auto_complete",
      :placeholder => "feature.preferred_mentoring.label.type_name_html".translate(Mentor: _Mentor),
      :autocomplete => "off"
    }

    default_completion_options = {
      :min_chars => 3,
      :param_name => 'search',
      :url => auto_complete_for_name_users_path(:format => :json, :preferred => true, :role => RoleConstants::MENTOR_NAME)
    }
    text_field_with_auto_complete(object, method, default_options.merge(tag_options), default_completion_options.merge(completion_options))
  end

  def selected_mentor_box
    content_tag(:div, :class => "cjs_selected_preference width3 hide well well-small bg-dark no-margin") do
      a = link_to('x', "javascript:void(0);", :class => "large pull-right has-above cjs_hide_selected")
      pic_with_name = content_tag(:div, '', :class =>"pic-col-md-offset-1 strong cjs_name_holder")
      a += content_tag(:div, content_tag(:div, content_tag(:div) ,:class => 'pic-col-md-1 cjs_pic_holder')+pic_with_name, :class => 'cjs_pic_with_name_holder')
    end
  end

  def suggested_users(favorites, recommended_users)
    hash = {}

    if favorites
      favorites.each do |f|
        hash[f.favorite.id] = f.favorite
      end
    end

    if recommended_users
      recommended_users.each do |u|
        hash[u.id] = u
      end
    end

    return hash
  end

  def dropdown_cell_recommendation(favorite, options = {})
    hide_class = ""
    if options[:mentor_users] && options[:mentor_users].include?(favorite)
      hide_class = "hide"
    end
    match_array = options[:match_array]
    member = favorite.member
    additional_class = options[:class].presence || "list-group-item pointer"
    tag = options[:tag].present? ? options[:tag].to_sym : :li
    content_tag(tag, class: "cjs_mentor_result #{hide_class} #{additional_class}", id: "dropdown-#{favorite.id}") do
      member_details_in_banner(member, "", match_array[favorite.id], { no_link: true, no_hovercard: true } )
    end
  end

  def actions_for_mentor_requests_listing(mentor_request,options={})
    actions = get_actions_for_mentor_requests_listing(mentor_request, options)
    return dropdown_buttons_or_button(actions, {dropdown_title: actions.size > 1 ? 'display_string.Actions'.translate : nil}.merge(options))
  end

  def get_actions_for_mentor_requests_listing(mentor_request, options={})
    actions = []
    student = mentor_request.student
    mentor =  mentor_request.mentor
    group = mentor_request.group

    if mentor_request.accepted? && group
      actions << {:label => get_icon_content('fa fa-users') + 'feature.mentor_request.action.go_to_mentoring_area_v1'.translate(:Mentoring_Area => _Mentoring_Connection), :url => group_path(group)}
    end
    if options[:is_mentor_action]
      if mentor_request.active?
        url_params = { :mentor_request => {:status => AbstractRequest::Status::ACCEPTED}, :src => options[:source].to_s }
        accept_button_text = [EngagementIndex::Src::AcceptMentorRequest::USER_PROFILE_PAGE, EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE].include?(options[:source]) ? "display_string.Accept".translate : 'feature.profile.content.accept_request'.translate
        if @current_program.allow_one_to_many_mentoring? && @existing_connections_of_mentor.any?
          actions << {:label => get_icon_content('fa fa-check ') + accept_button_text, :js => "jQuery('#modal_assign_link_#{mentor_request.id}').modal('show')"}
        else
          actions << {:label => get_icon_content('fa fa-check ') + accept_button_text, :url => mentor_request_path(mentor_request, url_params), :method => :patch, :class => "cjs_disable_accept_mentor_request_link cjs_disable_mentor_request_link button display_buttons accpt_rjct_btn #{options[:accept_button_class] || ''}"}
        end
        reject_button_text = [EngagementIndex::Src::AcceptMentorRequest::USER_PROFILE_PAGE, EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE].include?(options[:source]) ? "display_string.Decline".translate : 'feature.profile.content.decline_request'.translate
        actions << {:label => get_icon_content('fa fa-close ') + reject_button_text, :js => "jQuery('#modal_mentor_request_reject_or_withdraw_link_#{mentor_request.id}').modal('show')", class: "cjs_disable_mentor_request_link" }
      end
    else
      if current_program.allow_mentee_withdraw_mentor_request? && mentor_request.active?
        actions << {:label => get_icon_content('fa fa-undo') + 'feature.mentor_request.action.withdraw_request'.translate, :js => "jQuery('#modal_mentor_request_reject_or_withdraw_link_#{mentor_request.id}').modal('show')"}
      end
      if mentor_request.active? && @current_program.matching_by_mentee_alone?
        actions << {:label => get_icon_content('fa fa-envelope ') + 'display_string.Send_Message'.translate, :url => get_send_message_link(mentor, current_user, :receiver_id => mentor.member.id, src: EngagementIndex::Src::MessageUsers::MENTOR_REQUEST_LISTING_PAGE) } if show_send_message_link?(mentor)
      end
    end
    return actions
  end

  def get_filters
    filter = {}
    filter[:by_me] = current_user.can_send_mentor_request?
    filter[:all] = current_user.can_manage_mentor_requests?
    if current_program.matching_by_mentee_alone?
      filter[:to_me] = current_user.is_mentor?  && ( filter[:by_me] || current_user.is_admin? )
    end
    return filter
  end

  def mentor_requests_bulk_actions(from_manage=false)
    bulk_actions = [
      {:label => get_icon_content("fa fa-envelope") + "feature.mentor_request.action.send_message_to_sender".translate(count: 2), :url => "javascript:void(0)", :class => "cjs_bulk_action_mentor_requests", :id => "cjs_send_message_to_senders",
      :data => {:url => new_bulk_admin_message_admin_messages_path }}
    ]
    if @current_program.matching_by_mentee_alone?
      bulk_actions << {:label => get_icon_content("fa fa-envelope") + "feature.mentor_request.action.send_message_to_recipient".translate(count: 2), :url => "javascript:void(0)", :class => "cjs_bulk_action_mentor_requests", :id => "cjs_send_message_to_recipients",
        :data => {:url => new_bulk_admin_message_admin_messages_path }} 
      bulk_actions << {:label => get_icon_content("fa fa-ban") + "feature.mentor_request.action.close_requests".translate, :url => "javascript:void(0)", :class => "cjs_bulk_action_mentor_requests", :id => "cjs_close_requests",
        :data => {:url => from_manage ? fetch_bulk_actions_mentor_requests_path(from_manage: true) : fetch_bulk_actions_mentor_requests_path, :request_type => AbstractRequest::Status::CLOSED }} if @list_field == "active"
      bulk_actions << {:label => get_icon_content("fa fa-file-text") + "feature.mentor_request.action.export_as_csv".translate, :url => "javascript:void(0)", :class => "cjs_mentor_request_export",
        :data => {:url => export_mentor_requests_path(format: :csv, list: @list_field)}}
    end
    build_dropdown_button("display_string.Actions".translate, bulk_actions, :btn_class => "cur_page_info", :btn_group_btn_class => "btn-white btn no-vertical-margins", :is_not_primary => true)
  end

  def mentor_requests_export_form
    form_tag 'javascript:void(0)', id: "mentor_requests_export_form" do
      hidden_field_tag :mentor_request_ids
    end
  end

  def get_tabs_for_mentor_requests_listing(active_tab)
    label_tab_mapping = {
      'feature.mentor_request.status.Pending'.translate => MentorRequest::Filter::ACTIVE,
      'feature.mentor_request.status.Accepted'.translate => MentorRequest::Filter::ACCEPTED,
      'feature.mentor_request.status.Rejected'.translate => MentorRequest::Filter::REJECTED,
    }
    label_tab_mapping.merge!('feature.mentor_request.status.Withdrawn'.translate => MentorRequest::Filter::WITHDRAWN) if @current_program.allow_mentee_withdraw_mentor_request?
    label_tab_mapping.merge!('feature.mentor_request.status.closed'.translate => MentorRequest::Filter::CLOSED) if @current_program.matching_by_mentee_alone?
    get_tabs_for_listing(label_tab_mapping, active_tab, url: manage_mentor_requests_path, param_name: :tab)
  end

  def mentor_request_reject_reasons(program)
    reasons = ['feature.mentor_request.status.Rejected'.translate]
    reasons << 'feature.mentor_request.status.Withdrawn'.translate if program.allow_mentee_withdraw_mentor_request?
    reasons << 'feature.mentor_request.status.closed'.translate if program.matching_by_mentee_alone?
    return reasons
  end

  def mentor_request_reject_tile_tooltip
    reasons = mentor_request_reject_reasons(@current_program)
    "feature.mentor_request.content.requests_dropped".translate(mentoring: _Mentoring, rejected_withdrawn_and_closed: reasons.to_sentence(:last_word_connector => " #{'display_string.and'.translate} "))
  end

  def render_meeting_recommendation(form, form_id, mentor_request, modal_id)
    mentor = mentor_request.mentor
    student = mentor_request.student
    return unless mentor_request.can_convert_to_meeting_request?

    render partial: "mentor_requests/recommend_meeting", locals: { form: form, form_id: form_id, mentor_request: mentor_request, modal_id: modal_id }
  end

  def user_name_search_filter_for_mentor_request(title, field_name)
    ibox("", header_content: content_tag(:b, title), content_class: "p-t-0") do
      label_tag(:search_filters, title, :for => "search_filters_#{field_name}", :class => 'sr-only') +
      text_field(:search_filters, field_name, :value => nil, :class => "form-control input-sm")
    end
  end

  def get_mentor_requests_export_options(program)
    return [] unless program.matching_by_mentee_and_admin?
    [
      { label: "feature.membership_request.label.export_as_csv".translate, class: "cjs-common-reports-export-ajax", url: manage_mentor_requests_path(export: :csv) },
      { label: "feature.membership_request.label.export_as_pdf".translate, class: "cjs-common-reports-export-ajax", url: manage_mentor_requests_path(export: :pdf) }
    ]
  end
end
