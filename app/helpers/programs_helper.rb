module ProgramsHelper

  module Headers
    PROGRAM_DETAILS = 1
    PROGRAM_SETTINGS = 2
    PORTAL_DETAILS = 3
  end

  def link_box(icon, title, link, opts = {})
    icon_url = opts.delete(:absolute_img) ? icon : "icons/#{icon}"
    opts[:title] = title
    picture = (opts[:custom_icon] != nil && opts[:custom_icon]) ? image_tag(icon_url, :height => 50, :width => 50) : content_tag(:i, "", {:class => icon}).html_safe

    content_tag(:div, class: "link_box_icon pic-col-md-4 text-center height-105 m-l m-r") do
      anchor = picture + content_tag(:div, title, class: 'link-box-class')
      link_to anchor, link, opts
    end
  end

  def mentor_request_style_selection_first_time
    content_tag(:div, class: "cjs_show_hide_sub_selector", id: "cjs_mentor_request_style_first_time") do
      content_tag(:label, check_box_tag("program[mentor_request_style]", Program::MentorRequestStyle::NONE, true, :class => " vertical-align-text-bottom", id: "cjs_mentee_can_request_mentor") +  "program_settings_strings.label.mentee_requests.heading".translate(:Mentee => _Mentee, :mentor => _mentor), class: "checkbox") +
      (choices_wrapper("program_settings_strings.label.mentee_requests.heading".translate(:Mentee => _Mentee, :mentor => _mentor)) do
        content_tag(:label, radio_button_tag("program[mentor_request_style]",Program::MentorRequestStyle::MENTEE_TO_MENTOR, false, class: "vertical-align-text-bottom") + "program_settings_strings.label.mentee_requests.directly_to_mentor".translate(:Mentee => _Mentee, :mentor => _mentor), class: "m-l-md radio cjs_mentee_requests_mentor") +
        content_tag(:label, radio_button_tag("program[mentor_request_style]",Program::MentorRequestStyle::MENTEE_TO_ADMIN, false, class: "vertical-align-text-bottom") + "program_settings_strings.label.mentee_requests.thru_admin".translate(:Mentee => _Mentee, :admin => _admin), class: "m-l-md radio cjs_mentee_requests_mentor")
      end) +
      content_tag(:label, check_box_tag("program[enabled_features][]", FeatureName::OFFER_MENTORING, false, id: "cjs_mentor_offers_mentee") + "program_settings_strings.content.mentor_offers_to_mentee_v1".translate(:mentees => _mentees, :mentoring => _mentoring, :Mentors => _Mentors), class: "checkbox") +
      content_tag(:label, check_box_tag(nil, 1, true, id: "not_needed", class: "vertical-align-text-bottom", disabled: true) + "program_settings_strings.content.admin_assign_connection".translate(mentoring_connections: _mentoring_connections, :Admin => _Admin), class: "checkbox")
    end
  end

  def get_edit_terminology_link(role = nil)
    link_to_edit_terminology = link_to("display_string.Click_here".translate, edit_program_path(tab: ProgramsController::SettingsTabs::TERMINOLOGY))
    edit_link = [ "program_settings_strings.content.edit_terminology_html".translate(link_to_edit_terminology: link_to_edit_terminology) ]
    if role.present?
      current_third_role_term = role.customized_term.term
      edit_link << "program_settings_strings.content.current_term".translate(current_third_role_term: current_third_role_term)
    end
    edit_link.join(" ").html_safe
  end

  def get_role_removal_denial_flash(role)
    role_reference_types = role.role_references.pluck("DISTINCT ref_obj_type").map{ |type| type.to_s.demodulize.underscore.pluralize }.to_sentence(words_connector: ", ")
    associated_object_details = []
    associated_object_details << "program_settings_strings.content.role_tied_to_references".translate(role_reference_types: role_reference_types) unless role_reference_types.blank?
    editable_associated_admin_views = role.editable_associated_admin_views
    associated_object_details <<  ("program_settings_strings.content.role_tied_to_admin_views_v1".translate + content_tag(:ul, editable_associated_admin_views.inject(get_safe_string){|content, admin_view| content + content_tag('li', admin_view.title)})) unless editable_associated_admin_views.blank?
    content_tag(:div, "program_settings_strings.content.cannot_remove_role".translate(reason: associated_object_details.to_sentence).html_safe, class: "text-left")
  end


  def one_time_engagement_type_selection(program)
    career_based = program.career_based?
    content_tag(:div, class: "cjs_show_hide_sub_selector has-above-tiny", id: "cjs_carrer_based") do
      content_tag(:label, radio_button_tag("program[engagement_type]", Program::EngagementType::CAREER_BASED, career_based, class: "cjs_engagement_type") + "program_settings_strings.content.career_based".translate, class: "radio") +
      content_tag(:label, check_box_tag("program[engagement_type]", Program::EngagementType::CAREER_BASED_WITH_ONGOING, program.ongoing_mentoring_enabled? , :class => "attach-top cjs_select_ongoing_mentoring") + content_tag(:div, "program_settings_strings.content.ongoing_mentoring".translate(:Mentoring => _Mentoring), class: 'inline m-l-xs'), class: "m-l-md #{'hide' unless career_based} cjs_career_mentoring_options") +
      content_tag(:label, check_box_tag("program[enabled_features][]", FeatureName::CALENDAR, program.calendar_enabled?, :class => "attach-top cjs_select_one_time_mentoring") + content_tag(:div, "program_settings_strings.content.one_time_mentoring".translate(:Mentoring => _Mentoring), class: 'inline m-l-xs'), class: "m-l-md #{'hide' unless career_based} cjs_career_mentoring_options") +
      content_tag(:label, radio_button_tag("program[engagement_type]", Program::EngagementType::PROJECT_BASED, program.project_based?, class: "cjs_engagement_type") + "feature.program.content.project_based".translate, class: "radio")
    end
  end

  def mailer_templates_links_to_correct_for_disabling_calendar(program)
    mailer_templates_to_correct = program.mailer_templates.includes(:campaign_message).reject(&:is_valid_on_disabling_calendar?)
    links = []
    mailer_templates_to_correct.each do |mailer_template|
      next unless mailer_template.is_a_campaign_message_template? # handle only campaigns case, because others will be disabled
      campaign_message = mailer_template.campaign_message
      links << link_to(mailer_template.subject, edit_campaign_management_user_campaign_abstract_campaign_message_path(:user_campaign_id => campaign_message.campaign_id, :id => campaign_message.id), target: '_blank')
    end
    to_sentence_sanitize(links)
  end

  def get_error_message_while_disabling_calendar(program)
    errors = []
    errors << "flash_message.program_flash.close_pending_meeting_requests".translate(meeting: _meeting) if program.meeting_requests.active.exists?
    errors << "flash_message.program_flash.correct_mailer_templates_html".translate(meeting: _meeting, mails: mailer_templates_links_to_correct_for_disabling_calendar(program)) unless program.does_not_have_mailer_templates_with_calendar_tags?
    safe_join(["display_string.Please".translate, to_sentence_sanitize(errors), "flash_message.program_flash.to_disable_one_time_mentoring".translate(mentoring: _mentoring)], " ")
  end

  def one_time_setting_radio_button(form, program, attr, tags, values = [true, false], opts = {})
    # In case of an incorrect submit while creating a program, we need to display the current user settings
    # yet allow the user to edit the one-time setting attributes.
    opts[:onchange] ||= []
    aria_label = opts[:label_text] || "display_string.Options".translate
    dup_program = program.new_record? ? program : Program.find(program.id)
    if dup_program.send(attr).nil?
      choices_wrapper(aria_label, class: 'buttons clearfix') do
        content = get_safe_string
        tags.each_with_index do |tag, i|
          content += content_tag(:label, :class => "radio") do
            form.radio_button(attr, values[i], :checked => program.send(attr) == values[i], :onchange => opts[:onchange][i]) +
                     content_tag(:span, tag)
          end
        end
        content + content_tag(:span, get_icon_content("fa fa-info-circle") + "feature.program.content.cannot_change_afterwards".translate, :class => "small help-block")
      end
    else
      # Depending on the boolean value returned by program.send(), we decide on the label to be rendered.
      tag_to_be_rendered = tags[0];
      tags.each_with_index do |tag, i|
        if (program.send(attr) == values[i])
          tag_to_be_rendered = tag;
        end
      end

      content_tag(:span, tag_to_be_rendered, :class => 'radio_label disabled', :id => "#{attr}") +
        tooltip("#{attr}", "feature.program.content.setting_cannot_be_changed".translate)
    end
  end

  # Renders a quick link
  # Args:
  #   name: Name of the link
  #   url_or_method: where to point to
  #   class_name: class name to be applied to the link
  #   new_items_count: # of new items for this quicklink (for inbox, mem.req, mentor req etc.). If the count > 0, a class 'new_msg' is applied to the link to show it with distinction.
  def quick_link(name, url_or_method, icon_class = nil, new_items_count = nil, options = {})
    display_name = name.blank? ? "" : name.html_safe
    add_badge = (new_items_count && new_items_count > 0)
    content_tag(:li, :class => "list-group-item #{'no-padding no-border' if options[:notification_icon_view]}") do
      content = get_safe_string
      content += get_icon_content("#{icon_class} #{'media-left p-t-xxs' if options[:notification_icon_view]}") if icon_class
      if options.delete(:js)
        content += link_to_function(display_name, url_or_method, options)
        content += ' ' + link_to_function(new_items_count, url_or_method, class: 'badge badge-danger') if add_badge
      elsif options[:notification_icon_view]
        link_content = get_safe_string
        link_content += content_tag(:div, :class => "media-body p-l-xxs") do
          content_tag(:div, display_name, :class => "cui_pending_requests_dropdown_text_container pull-left") + (add_badge ? content_tag(:div, new_items_count, class: 'badge badge-danger pull-right m-t-xs m-l-xs') : get_safe_string)
        end
        content += link_content
        content = link_to(content, url_or_method, options)
      else
        content += link_to(display_name, url_or_method, options)
        content += get_safe_string + link_to(new_items_count, url_or_method, class: 'badge badge-danger') if add_badge
      end
      content.html_safe
    end
  end

  # Renders program settings page tabs
  #
  # ==== Params
  # <tt>cur_tab</tt>  : the currently selected tab under ProgramsController::SettingsTabs.
  #
  def program_settings_tabs(cur_tab, customized_terms = {})
    tabs_to_show = allowed_tabs
    tabs = []
    ProgramsController::SettingsTabs.all.each do |tab|
      next unless tabs_to_show.include?(tab)

      tabs << {
        :label => ProgramsController::SettingsTabs.get_label(tab, customized_terms),
        :url => edit_program_path(:tab => tab),
        :active => (tab == cur_tab)}
    end

    inner_tabs(tabs)
  end

  def hide_if_external_auth(auth_config = @auth_config, &block)
    unless auth_config && !auth_config.indigenous?
      yield
    end
  end

  # Show switch back link if the current_user's chronus user is not the same as
  # the logged in chronus user.
  def link_to_switch_back_from_wob
    if wob_member != current_member
      # WOB - Show switch back link.
      link_to "feature.profile.actions.switch_back_from_wob".translate(member_name: current_member.name(:name_only => true)), exit_wob_path, :method => :post
    end
  end

  def display_wob_banner
    if working_on_behalf? && @current_organization.has_feature?(FeatureName::WORK_ON_BEHALF)
      back_url = link_to_switch_back_from_wob
      wob_text = "feature.profile.header.working_on_behalf".translate(user_name: wob_member.name)
      render(:partial => "layouts/wob_banner", :locals => {:back_url => back_url, :wob_text => wob_text})
    end
  end

  def get_send_request_badge_count(past_requests_count, can_connect_with_a_mentor)
    past_requests_count.zero? && current_user.can_connect_with_mentor_and_has_slots?(can_connect_with_a_mentor) && current_user.groups.active.blank? ? 1 : 0
  end

  def list_of_feedback_permitted_actions
    return false unless wob_member

    is_mentor = current_user ? current_user.is_mentor? : wob_member.is_mentor?

    case controller_name
    when "programs"
      (action_name == "search") || (action_name == "show") || (action_name == "manage")
    when "users"
      (action_name == "index" && (params[:view].blank? || params[:view] == "mentors")) ||
        (action_name == "index" && params[:view] == "mentees" && is_mentor)
    when "members"
      action_name == "show"
    when "mentor_requests"
      action_name == "new"
    when "articles"
      (action_name == "new") || (action_name == "edit") || (action_name == "index" && params[:search])
    when "qa_questions"
      (action_name == "index" && params[:search])
    when "themes"
      action_name == "index"
    when "groups"
      action_name == "index"
    else
      false
    end
  end

  def propose_group_settings(role)
    program = role.program
    can_propose_groups = role.has_permission_name?(RolePermission::PROPOSE_GROUPS)

    content = get_safe_string

    return controls do
      content += content_tag(:label, :class => "checkbox") do
        check_box_tag("program[send_group_proposals][]", role.id, can_propose_groups, class: "toggle_checkboxes cjs_group_proposals_parent", id: "program_send_group_proposals_#{role.id}") + program.term_for(CustomizedTerm::TermType::ROLE_TERM, role.name).term
      end
      content += render_group_proposal_approval_options(role, can_propose_groups)
      content
    end
  end

  def render_group_proposal_approval_options(role, can_propose_groups)
    get_admin_approval_needed_radio_button(role, can_propose_groups) + get_no_approval_needed_radio_button(role, can_propose_groups)
  end

  def get_admin_approval_needed_radio_button(role, can_propose_groups)
    content_tag(:label, :class => "radio iconcol-md-offset-1") do
      radio_button_tag("program[group_proposal_approval][#{role.id}]", true, role.needs_approval_to_create_circle? && can_propose_groups, class: "cjs_group_proposals_child cjs_approval_needed", id: "propose_needs_approval_#{role.name}_yes") + "program_settings_strings.content.admin_approval_required".translate(Admin: _Admin)
    end
  end

  def get_no_approval_needed_radio_button(role, can_propose_groups)
    has_groups_proposed_by_role = Group.has_groups_proposed_by_role(role)
    
    content_tag(:label, :class => "radio iconcol-md-offset-1") do
      radio_button_tag("program[group_proposal_approval][#{role.id}]", false, !role.needs_approval_to_create_circle? && can_propose_groups, class: "cjs_group_proposals_child cjs_no_approval_needed", id: "propose_needs_approval_#{role.name}_no", disabled: has_groups_proposed_by_role) + "program_settings_strings.content.no_approval_required".translate + get_disabled_help_text_for_no_approval_group_proposal(has_groups_proposed_by_role)
    end
  end

  def get_disabled_help_text_for_no_approval_group_proposal(has_groups_proposed_by_role)
    has_groups_proposed_by_role ? content_tag(:div, "program_settings_strings.content.no_approval_disabled_tooltip".translate(groups: _mentoring_connections), class: "text-muted small") : ""
  end

  def role_join_settings(role)
    join_settings_hash = get_join_settings_hash(role)
    boxes_content = get_safe_string

    return controls do
      join_settings_hash.each do |key, val|
        box_class = val[:boxtype] == "radiobox" ? "radio " : "checkbox "
        boxes_content += content_tag(:label, :class => box_class + val[:label_class].to_s) do
          get_radio_or_checkbox(key, val, role)
        end
      end
      choices_wrapper("program_settings_strings.content.joining_option".translate) do
        boxes_content + "program_settings_strings.content.admins_can_always_invite".translate(admins: _Admins)
      end
    end + hidden_field_tag("program[join_settings][#{role.name}][]")
  end

  def get_user_ids_from_mentor_list(mentors_list)
    mentors_list.collect{|m| m[:user].id}.compact.join(",")
  end

  def get_quick_connect_title(options = {})
    append_icon = true
    case options[:recommendations_view]
    when AbstractPreference::Source::ADMIN_RECOMMENDATIONS
      recommendation_title = "feature.explicit_preference.label.admin_recommendations_home_page_label".translate(administrator: _Admin.downcase)
    when AbstractPreference::Source::SYSTEM_RECOMMENDATIONS
      recommendation_title = "feature.explicit_preference.label.sytem_recommendations_home_page_label_v2".translate(mentor: _Mentor)
    when AbstractPreference::Source::EXPLICIT_PREFERENCES_RECOMMENDATIONS
      recommendation_title, append_icon = get_quick_connect_title_for_explicit_recommendations
    else
      recommendation_title = "feature.mentor_recommendation.header.banner.recommendation_text".translate(Mentor: _Mentor)
    end
    recommendation_title = append_text_to_icon("fa fa-fw fa-users m-r-xs", recommendation_title) if append_icon
    recommendation_title_content = content_tag(:span, recommendation_title, class: "recommendation_title_text")
    content_tag(:div, class: 'gray-bg h5 p-b-sm m-b-0 m-t-sm') do
      recommendation_title_content
    end
  end

  def get_quick_connect_title_for_explicit_recommendations
    mobile_title = append_text_to_icon("fa fa-fw fa-users m-r-xs", "feature.explicit_preference.label.explicit_preferences_recommendations_home_page_label_mobile".translate)
    title = append_text_to_icon("fa fa-fw fa-users m-r-xs", "feature.explicit_preference.label.explicit_preferences_recommendations_home_page_label".translate)
    [append_home_page_explicit_preferences_button(title, mobile_title), false]
  end

  def get_preference_based_mentor_lists_recommendations_title
    title = append_text_to_icon("fa fa-fw fa-users m-r-xs", "feature.implicit_preference.mentors_lists.popular_categories".translate)
    if current_user.can_configure_explicit_preferences?
      append_home_page_explicit_preferences_button(title, title)
    else
      title
    end
  end

  def append_home_page_explicit_preferences_button(title, mobile_title)
    personalize_button_web = link_to(append_text_to_icon("fa fa-sliders", "feature.explicit_preference.label.personalize".translate), "javascript:void(0)", class: "btn btn-primary btn-outline btn-xs cjs_show_explicit_preference_popup_recommendations pull-right")
    personalize_button_mobile = link_to(get_icon_content("fa fa-sliders", {class: "fa fa-sliders fa-lg m-r-0"}), "javascript:void(0)", class: "btn btn-primary btn-outline btn-xs cjs_show_explicit_preference_popup_recommendations pull-right")
    content_tag(:span, mobile_title + personalize_button_mobile, class: "visible-xs") + content_tag(:span, title + personalize_button_web, class: "hidden-xs")
  end

  def slick_carousel_navigation_buttons(options = {})
    link_to(get_icon_content("fa fa-chevron-left no-margins") + set_screen_reader_only_content("display_string.previous".translate), "javascript:void(0)", class: "btn btn-xs btn-default pull-left #{options[:prev_button_class]}") +
    link_to(get_icon_content("fa fa-chevron-right no-margins") + set_screen_reader_only_content("display_string.next".translate), "javascript:void(0)", class: "btn btn-xs btn-default pull-right #{options[:next_button_class]}")
  end

  def member_details_in_banner(member, src, match_score, options = {})
    delete_button = get_safe_string
    delete_button_block = get_safe_string
    can_see_match_score = @current_program.allow_user_to_see_match_score?(current_user)
    if options[:delete_button]
      delete_button = link_to("javascript:void(0)", class: "pull-right m-r hidden-xs remove-mentor-request btn btn-sm btn-white") do
        append_text_to_icon("fa fa-times", "display_string.Remove".translate)
      end
      delete_button_block = link_to("javascript:void(0)", class: "visible-xs m-t-sm remove-mentor-request btn btn-sm btn-white btn-block") do
        append_text_to_icon("fa fa-times", "display_string.Remove".translate)
      end
    end

    mentor_user = member.user_in_program(@current_program)
    position_text = options[:position] ? get_position_div(options[:position]) : get_safe_string

    quick_info = content_tag(:div, quick_connect_mentor_info(mentor_user, current_user, @current_program, :from_quick_connect => options[:from_quick_connect]))

    match_score_info = can_see_match_score ? display_match_score(match_score, options.merge!({in_listing: true, mentor_id: mentor_user.id, src: src})) : get_safe_string

    content = delete_button
    image_options = {class: "img-circle table-bordered"}
    member_picture_options = { size: :medium,  no_name: true, dont_link: options[:no_link], item_link: (options[:no_link] ? nil :member_path(member, :src => src)) }
    content += content_tag(:div) do
      position_text +
      content_tag(:div) do
        content_tag(:div, class: 'media-left') do
          if options[:show_favorite_ignore_links]
            options.merge!({in_listing: true, mentor_id: mentor_user.id, src: src})
            render_show_favorite_links(options) + render_ignore_preference_link(options)
          else 
            get_safe_string
          end + 
          member_picture_v3(member, member_picture_options, image_options)
        end +
        content_tag(:div, class: 'media-body') do
          content_tag(:h3, link_to_user(member, content_text: member.name(name_only: true), params: { src: src }, no_link: options[:no_link], no_hovercard: options[:no_hovercard]),
            class: "m-t-0 m-b-sm") + quick_info + match_score_info
        end
      end
    end
    content += delete_button_block
    content += javascript_tag( %Q[jQuery(document).ready(function(){IgnorePreference.ignoreProfile("#{mentor_user.id}");});]) if options[:show_favorite_ignore_links] && src != 'quick_connect_box'
    return content_tag(:div, class: "clearfix") do
      content.html_safe
    end
  end

  def get_matched_tags_content(current_user, mentor_user, match_score, options = {})
    matched_content_with_link = get_safe_string
    program_questions_for_user = current_user.get_visibile_match_config_profile_questions_for(mentor_user)
    match_details_content = options[:matched_content] || get_match_details_for_display(current_user, mentor_user, program_questions_for_user, options)[0]
    matched_content_with_link += content_tag(:div, content_tag(:a, append_text_to_icon("fa fa-tags fa-lg text-navy m-r", match_details_content) + get_icon_content("fa fa-angle-double-right fa-lg m-l-xs text-info font-600"), class: "cjs_show_match_details small font-bold cui_quick_connect_no_border_link", data: {url: match_details_user_path(id: mentor_user.id, show_match_config_matches: options[:show_match_config_matches], src: options[:recommendations_view])}), class: "cui_margin_correction") if show_compatibility_link?(true, match_details_content.present?, match_score)
    matched_content_with_link
  end

  def get_matched_preferences_label(matched_count, total_count, mentor_ignored, options = {})
    if mentor_ignored
      content_tag(:div, content_tag(:h4, content_tag(:span, "feature.user.label.ignored".translate, class: "text-muted"), class: "no-margins"))
    elsif options[:show_no_match_label]
      content_tag(:div, content_tag(:h4, content_tag(:span, "feature.user.label.not_a_match".translate, class: "text-muted"), class: "no-margins"))
    elsif matched_count == 0
      content_tag(:div, content_tag(:h4, content_tag(:span, "feature.explicit_preference.label.no_matched_preferences_label".translate, class: "text-muted"), class: "no-margins"))
    else
      get_explicit_preferences_matched_label(matched_count, total_count, options)
    end
  end

  def get_explicit_preferences_matched_label(matched_count, total_count, options)
    if options[:quick_connect]
      content_tag(:span, "feature.explicit_preference.label.matched_preferences_label".translate(count: content_tag(:span, matched_count, class: "h5 font-600"), total_count: content_tag(:span, total_count, class: "h5 font-600")).html_safe)
    else
      content = content_tag(:strong, "feature.explicit_preference.label.matched_preferences_label".translate(count: matched_count, total_count: total_count))
      content = append_text_to_icon("fa fa-thumbs-up", content,{container_class: "fa-circle", container_stack_class: "fa-2x", icon_stack_class: "fa-stack-1x", stack_class: "fa-small"}) if options[:with_icon]
      content_tag(:div, content, class: "text-navy")
    end
  end

  def get_show_match_lable_value(match_score)
    match_score.present? && match_score.zero?
  end

  def get_links_for_banner(mentor_user, mentors_score, options = {})
    actions = []
    analytics_param = options[:analytics_param] || EngagementIndex::Src::SendRequestOrOffers::QUICK_CONNECT_BOX
    dropdown_title = options[:quick_connect] ? append_text_to_icon("fa fa-user-plus", "common_text.Connect".translate.upcase) : append_text_to_icon("fa fa-users", "common_text.Connect".translate)
    if mentor_user.present?
      action_options = {
        prevent_zero_match_connection: !current_user.can_connect_to_mentor?(mentor_user, mentors_score),
        analytics_param: analytics_param
      }
      connection_request_action_hash = get_request_mentoring_action_hash(current_user, mentor_user, action_options)
      actions << connection_request_action_hash if connection_request_action_hash.present?
      meeting_request_action_hash = get_request_meeting_action_hash(current_user, mentor_user, action_options)
      actions << meeting_request_action_hash if meeting_request_action_hash.present?

      if options[:show_send_message] && show_send_message_link?(mentor_user, current_user)
        actions << {
          label: append_text_to_icon("fa fa-envelope", "feature.user.label.send_message".translate)
        }.merge(get_send_message_link(mentor_user, current_user, receiver_id: mentor_user.member_id, src: analytics_param, listing_page: true))
      end

      if actions.size == 1
        actions.first[:label] = dropdown_title
        dropdown_title = nil
      end
    end
    return actions, dropdown_title
  end

  def get_position_div(number)
    text = get_position_text(number)
    content_tag(:div, class: "col-xs-3 p-l-0 p-r-0 m-t-xxs") do
      content_tag(:h3, text, class: "position-div") +
      content_tag(:div, get_icon_content("fa fa-arrows m-r-0 pointer cjs_sortable_handler"), class: "text-muted m-l-xs")
    end
  end

  def get_position_text(number)
    case number
    when 1
      "feature.mentor_recommendation.position.one".translate
    when 2
      "feature.mentor_recommendation.position.two".translate
    when 3
      "feature.mentor_recommendation.position.three".translate
    when 4
      "feature.mentor_recommendation.position.four".translate
    when 5
      "feature.mentor_recommendation.position.five".translate
    when 6
      "feature.mentor_recommendation.position.six".translate
    when 7
      "feature.mentor_recommendation.position.seven".translate
    when 8
      "feature.mentor_recommendation.position.eight".translate
    when 9
      "feature.mentor_recommendation.position.nine".translate
    when 10
      "feature.mentor_recommendation.position.ten".translate
    else
      number.to_s
    end
  end

  def welcome_user_profile_question_ids(user, question_types)
    user.program.profile_questions_for(user.role_names, {:default => false, :skype => user.program.organization.skype_enabled?, user: user}).select{ |pqs| question_types.include?(pqs.question_type) }.collect(&:id)
  end

  def get_experience_for_welcome_widget(experience)
    experience_job_title = experience.job_title.present? ? experience.job_title : ""
    experience_company = experience.company
    experience_job_title.present? ? raw("#{experience_job_title}, #{experience_company}") : raw("#{experience_company}")
  end

  def get_experience_for_quick_connect(experience, options = {})
    experience_job_title = experience.job_title.present? ? (options[:from_quick_connect] ? "#{content_tag(:div, experience.job_title, :class => "whitespace-nowrap truncate-with-ellipsis")} " : "#{content_tag(:span, experience.job_title)} " ) : ""
    experience_company = options[:from_quick_connect] ? content_tag(:div, experience.company, :class => "whitespace-nowrap truncate-with-ellipsis") : content_tag(:strong, experience.company)
    raw("#{experience_job_title}#{experience_company}")
  end

  def quick_connect_mentor_info(user, viewing_user, program, options = {})
    experience_question_ids = options[:welcome_widget] ? welcome_user_profile_question_ids(user, [ProfileQuestion::Type::EXPERIENCE, ProfileQuestion::Type::MULTI_EXPERIENCE]) : quick_connect_profile_question_ids(user, viewing_user, program, [ProfileQuestion::Type::EXPERIENCE, ProfileQuestion::Type::MULTI_EXPERIENCE])
    experiences = user.profile_answers.select("experiences.company, experiences.job_title, experiences.current_job, experiences.end_year").joins(:experiences).where("profile_answers.profile_question_id IN (?)", experience_question_ids).order("experiences.end_year desc")
    if experiences.present?
      current_experiences = experiences.where("experiences.current_job = ?", true)
      experience = current_experiences.present? ? current_experiences.first : experiences.first
      if options[:welcome_widget]
        get_experience_for_welcome_widget(experience)
      else
        get_experience_for_quick_connect(experience, options)
      end
    else
      location_question_ids = options[:welcome_widget] ? welcome_user_profile_question_ids(user, [ProfileQuestion::Type::LOCATION]) : quick_connect_profile_question_ids(user, viewing_user, program, [ProfileQuestion::Type::LOCATION])
      location = user.profile_answers.select("locations.full_address").joins(:location).where("profile_answers.profile_question_id IN (?)", location_question_ids).order("profile_answers.created_at desc").first
      if location.present?
        options[:from_quick_connect] ? content_tag(:div, location.full_address, :class => "whitespace-nowrap truncate-with-ellipsis") : location.full_address
      else
        options[:from_quick_connect] ? content_tag(:div, "feature.profile.content.member_since_date".translate(date: DateTime.localize(user.member.created_at, format: :full_month_year)), :class => "whitespace-nowrap truncate-with-ellipsis") : ""
      end
    end
  end

  def quick_connect_profile_question_ids(user, viewing_user, program, question_types)
    conditions = ["(role_questions.private = :everyone)"]
    params = {everyone: RoleQuestion::PRIVACY_SETTING::ALL}

    if viewing_user.is_mentor?
      conditions << "(role_question_privacy_settings.setting_type = :role_type AND role_question_privacy_settings.role_id = :mentor_role_id)"
      params[:role_type] = RoleQuestionPrivacySetting::SettingType::ROLE
      params[:mentor_role_id] = program.get_role(RoleConstants::MENTOR_NAME).id
    end

    if viewing_user.connected_with?(user)
      conditions << "(role_question_privacy_settings.setting_type = :connected_members_type)"
      params[:connected_members_type] = RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS
    end
    conditions = conditions.join(" OR ")

    question_ids = program.role_questions_for(RoleConstants::MENTOR_NAME, user: viewing_user)
    question_ids = question_ids.joins('LEFT OUTER JOIN role_question_privacy_settings ON role_question_privacy_settings.role_question_id = role_questions.id').where(conditions, params) unless viewing_user.is_admin?
    question_ids.joins(:profile_question).where("profile_questions.question_type IN (?)", question_types).pluck(:profile_question_id)
  end

  def render_message_warnings_popup(warnings, show_limit = 5)
    if warnings.present?
      messages = warnings.values[0,show_limit].map { |h| h[:object] }
      delta = warnings.size - show_limit
      render "programs/warning_messages_popup", show_more: delta, messages: messages
    end
  end

  def fetch_primary_home_tab(program, user)
    if program.mentoring_connections_v2_enabled? && user.primary_home_tab == Program::RA_TABS::CONNECTION_ACTIVITY
      Program::RA_TABS::ALL_ACTIVITY
    else
      user.primary_home_tab
    end
  end

  def match_score_label(match_score, for_admin = false, ignored = false)
    if ignored
      "feature.user.label.ignored".translate
    elsif match_score && match_score.zero? && !for_admin
      "feature.user.label.not_a_match".translate
    elsif match_score
      match_score.to_s + "%"
    else
      "display_string.NA".translate
    end
  end

  def display_home_page_group_logo(group, user)
    group_users = group.members
    if group_users.size == 2
      other_user = (group_users - [user]).first
      member_picture_v3 other_user.member, {:size => :large, :no_name => true}, {:class => "photo img-circle"}
    else
      content_tag(:div, :class => "member_box medium") do
        image_tag(group.logo_url, :class => 'photo group_logo img-circle', :size => "75x75")
      end
    end
  end

  def get_inactivity_tracking_description
    content = "program_settings_strings.content.inactivity_tracking_desc".translate(mentoring_connection: _mentoring_connection, mentoring_connections: _mentoring_connections, program: _program, admins: _admins)
    if @current_program.feedback_survey.present?
      content += " #{'program_settings_strings.content.survey_configurable_html'.translate(survey_link: link_to('display_string.here'.translate, survey_survey_questions_path(@current_program.feedback_survey)))}"
    end
    content += " #{'program_settings_strings.content.auto_terminate_desc'.translate(mentoring_connections: _mentoring_connections, admins: _Admins)}"
    content.html_safe
  end

  def get_feedback_survey_options
    @current_program.surveys.of_engagement_type.map {|survey| [survey.name, survey.id]} + [["feature.survey.action.Create_a_New".translate, "new"]]
  end

  def get_program_tabs(program, my_all_connections_count, src, options = {})
    can_show_connection_activity = !program.mentoring_connections_v2_enabled? && my_all_connections_count.present? && my_all_connections_count > 0
    tabs = []
    tabs << {url: get_program_ra_path(src: src, per_page: options[:per_page]), tab_order: Program::RA_TABS::ALL_ACTIVITY, div_suffix: "all"}
    tabs << {url: get_program_ra_path(:my => 1, src: src, per_page: options[:per_page]), tab_order: Program::RA_TABS::MY_ACTIVITY, div_suffix: "my"}
    tabs << {url: get_program_ra_path(:connection => 1, src: src, per_page: options[:per_page]), tab_order: Program::RA_TABS::CONNECTION_ACTIVITY, div_suffix: "conn"} if can_show_connection_activity
    tabs
  end

  def email_theme_overrride_select_default_color(color)
    content_tag(:div, class: "control-group has-above") do
      content_tag(:div, class: "controls") do
        content_tag(:label, class: "checkbox") do
          check_box_tag(nil, nil, (color == EmailTheme::DEFAULT_PRIMARY_COLOR), class: "cui-use-chronus-default has-next", id: "chronus-default-color") + "program_settings_strings.label.user_chronus_default_email_colour_v1".translate
        end
      end
    end + javascript_tag(%Q[ProgramSettings.useChronusDefaultColor();])
  end

  def render_header_alert(header_alert_content)
    return unless header_alert_content
    content_tag(:div, :id => "header_alert") do
      content_tag(:div, :class => "centered_inner_content") do
        header_alert_content
      end
    end
  end

  def home_page_widget_group_logo(group, options = {})
    content_tag(:div, class: 'member_box medium cui_spinner') do
      image_tag(group.logo_url, :class => "photo group_logo img-circle #{options[:img_class]}", :size => options[:size] || "75x75")
    end
  end

  def allowed_tabs
    tabs_to_show = []
    tabs_to_show << ProgramsController::SettingsTabs::GENERAL
    tabs_to_show << ProgramsController::SettingsTabs::TERMINOLOGY if super_console?
    tabs_to_show << ProgramsController::SettingsTabs::MEMBERSHIP
    tabs_to_show << ProgramsController::SettingsTabs::CONNECTION if @current_program.engagement_enabled?
    tabs_to_show << ProgramsController::SettingsTabs::MATCHING  if @current_program.matching_enabled?
    tabs_to_show << ProgramsController::SettingsTabs::FEATURES if @current_organization.standalone? || super_console?
    tabs_to_show << ProgramsController::SettingsTabs::PERMISSIONS
    tabs_to_show << ProgramsController::SettingsTabs::SECURITY if @current_organization.standalone?
    ## The below code should be removed when get rid of organization types.
    tabs_to_show -= [ProgramsController::SettingsTabs::FEATURES, ProgramsController::SettingsTabs::PERMISSIONS] if @current_organization.basic_type? && !super_console?
    tabs_to_show
  end

  def can_show_requests_notification_header_icon?(program, current_user)
    return false unless program.present? && current_user.present? && (current_user.is_mentor? || current_user.is_student?)
    ((program.only_career_based_ongoing_mentoring_enabled? && (program.matching_by_mentee_alone? || (program.mentor_offer_enabled? && program.mentor_offer_needs_acceptance?) || (program.matching_by_mentee_and_admin? && current_user.is_student?))) || program.calendar_enabled? || current_user.can_be_shown_meetings_listing? || (program.project_based? && current_user.can_be_shown_project_request_quick_link?))
  end

  def can_show_resources_header_icon?(program, current_user)
    return false unless program.present? && current_user.present?
    program.resources_enabled? && current_user.accessible_resources({admin_view: current_user.is_admin?}).exists?
  end

  def get_new_program_wizard_view_headers
    wizard_info = ActiveSupport::OrderedHash.new
    wizard_info[Headers::PROGRAM_DETAILS] = { label: "feature.program.content.tab_captions.program_details".translate(program: _Program) }
    wizard_info[Headers::PROGRAM_SETTINGS] = { label: "feature.program.content.tab_captions.program_settings".translate(program: _Program) }
    wizard_info[Headers::PORTAL_DETAILS] = {label: "feature.program.content.tab_captions.portal_details".translate(program: _Program)} if @current_organization.standalone?
    wizard_info
  end

  def render_zero_match_score_settings(form)
    content = get_safe_string
    actions = []
    actions << render_prevent_manager_matching_setting(form)
    actions << render_past_mentor_matching_setting(form)
    actions.reject!(&:blank?)

    if actions.present?
      label = content_tag(:div, "program_settings_strings.content.show_zero_scores_if".translate, class: "false-label control-label")
      content += control_group do
        label + controls { raw(actions.join()) }
      end
    end
    content
  end

  def get_mentoring_mode_for_ga(program)
    return unless program
    mentoring_mode = []
    if program.project_based?
      mentoring_mode << "Circles"
    elsif program.ongoing_mentoring_enabled?
      mentoring_mode << get_ongoing_mentoring_mode_for_ga(program)
    end
    if program.calendar_enabled?
      mentoring_mode << "Flash"
    end
    mentoring_mode.join(" ")
  end

  def get_connection_limit_help_text(program)
    program.matching_by_admin_alone? && !program.mentor_offer_enabled? ? "program_settings_strings.content.default_max_connections_limit_help_text.admin_match".translate(mentees: _mentees) : "program_settings_strings.content.default_max_connections_limit_help_text.self_match".translate(mentees: _mentees)
  end

  def get_data_hash_for_banner_logo(program_or_organization, file_name, program_asset_type)
    get_data_hash_for_dropzone(program_or_organization.id, program_asset_type, file_name: file_name, uploaded_class: ProgramAsset.name, accepted_types: PICTURE_CONTENT_TYPES, class_list: "p-t-xxs", max_file_size: ProgramAsset::MAX_SIZE[program_asset_type])
  end

  def render_help_text_for_max_connections_limit(program, options = {})
    help_text = "feature.profile.content.connections_limit_helptext_v5".translate(mentees: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term_downcase)
    help_text +=  if options[:from_member_profile] && !program.allow_mentor_update_maxlimit?
                    "feature.profile.content.connections_limit_helptext_hint".translate(mentors: _mentors, program: _program, default_limit: program.default_max_connections_limit)
                  elsif options[:from_first_visit]
                    "feature.profile.content.connections_limit_help_text_first_time".translate
                  else
                    ""
                  end
    content_tag :p, help_text, class: "help-block m-t-0 col-sm-10 no-padding text-muted"
  end

  def render_max_connections_limit(form_object, program, options = {})
    text_field_id = options[:text_field_id] || "max_connections_limit"

    control_group(class: options[:wrapper_class]) do
      (form_object.label :max_connections_limit, User.human_attribute_name(:max_connections_limit), for: text_field_id, class: "control-label col-sm-2") +
      controls(class: "col-sm-10") do
        (form_object.text_field :max_connections_limit, class: "form-control", id: text_field_id) +
        render_help_text_for_max_connections_limit(program, options)
      end
    end
  end

  def render_add_role_without_approval_help_text(role, to_add_role)
    embed_icon(TOOLTIP_IMAGE_CLASS, '', id: "auto_approval_for_#{role.name}_help_icon") +
    tooltip("auto_approval_for_#{role.name}_help_icon", "program_settings_strings.content.auto_role_approval_help_text".translate(current_role: role.customized_term.term_downcase, to_add_role: to_add_role.customized_term.term_downcase, admin: _admin), true)
  end

  def get_project_requests_quick_link(program, new_project_requests_count)
    return unless program.project_based? && current_user.can_be_shown_project_request_quick_link?
    quick_link("quick_links.program.project_requests".translate(mentoring_connection: h(_Mentoring_Connections)), project_requests_path(from_quick_link: true, src: EngagementIndex::Src::BrowseMentors::HEADER_NAVIGATION), "fa fa-user-plus fa-fw p-r-md", new_project_requests_count, { notification_icon_view: true, class: "normal-white-space break-word-all" })
  end

  def get_tabs_for_listing(label_tab_mapping, active_tab, data)
    label_tab_mapping.map do |label, tab|
      get_tab_for_listing(label, tab == active_tab, { url: data[:url], data[:param_name] => tab })
    end
  end

  def get_tab_for_listing(label, active, data)
    {
      label: content_tag(:span, label),
      url: "javascript:void(0)",
      active: active,
      tab_class: "cjs_common_report_tab",
      link_options: { data: data }
    }
  end

  private

  #returns radiobox if val[:boxtype] == "radiobox"
  #returns checkbox otherwise
  def get_radio_or_checkbox(key, val, role)
    return radio_button_tag("program[join_settings][#{role.name}][]", key, val[:checked], val[:options]) + val[:text] + val[:link_text] if val[:boxtype] == "radiobox"
    return check_box_tag("program[join_settings][#{role.name}][]", key, val[:checked], val[:options]) + val[:text]+ val[:link_text]
  end

  def get_ongoing_mentoring_mode_for_ga(program)
    if program.self_match?
      "Self Match"
    elsif program.admin_match?
      "Admin Match"
    end
  end

  def text_eligibility_rules(role)
    if role.admin_view.nil? #admin view related to this role does not exist
      return "program_settings_strings.content.set_eligibility_rules".translate
    else
      return "program_settings_strings.content.edit_eligibility_rules".translate
    end
  end

  def render_prevent_manager_matching_setting(form)
    return unless current_program.organization.manager_enabled? && current_program.role_questions.collect(&:question_type).include?(ProfileQuestion::Type::MANAGER)
    render_manager_matching(form) + render_manager_matching_level
  end

  def render_manager_matching(form)
    content_tag(:label, class: "checkbox pull-left") do
      form.check_box(:prevent_manager_matching) +
      "program_settings_strings.content.prevent_manager_matching_v1".translate(Mentor: _Mentor, mentees: _mentees) +
      "program_settings_strings.content.restrict_up_to".translate
    end
  end

  def render_new_community_item_content(item_hash)
    item_content = get_community_item_icon_content(item_hash[:klass], {:class => "m-b"}) +
    content_tag(:div, class: "height-94") do
      get_new_community_item_link_html(item_hash)
    end
    item_content
  end

  def get_community_item_icon_content(klass, options = {})
    content_tag(:span, class: "fa-stack fa-lg fa-2x #{options[:class]} #{get_new_community_item_icon_color(klass)}") do
      get_icon_content("fa fa-circle fa-stack-2x") +
      get_icon_content("fa #{get_new_community_item_icon_class(klass)} fa-stack-1x fa-inverse")
    end
  end

  def get_new_community_item_icon_class(klass)
    if klass == Article.to_s
      "fa-file-text"
    elsif klass == Topic.to_s
      "fa-comment"
    elsif klass == QaQuestion.to_s
      "fa-question"
    elsif klass == Forum.to_s
      "fa-comments"
    end
  end

  def get_new_community_item_icon_color(klass)
    if klass == Article.to_s
      "text-success"
    elsif klass == Topic.to_s || klass == Forum.to_s
      "text-navy"
    else
      "text-warning"
    end
  end

  def get_new_community_item_link_html(item_hash)
    if item_hash[:klass] == Article.to_s
      link_to(content_tag(:i, "", class: "fa fa-plus-circle fa-fw m-r-xxs") + "feature.article.action.write_new".translate(Article: _Article), new_article_path(src: EngagementIndex::Src::MENTORING_COMMUNITY_WIDGET))
    elsif item_hash[:klass] == QaQuestion.to_s
      link_to(content_tag(:i, "", class: "fa fa-plus-circle fa-fw m-r-xxs") + "feature.question_answers.action.ask_new_question".translate, qa_questions_path(add_new_question: true, src: EngagementIndex::Src::MENTORING_COMMUNITY_WIDGET))
    end
  end

  def get_community_item_klass(item_object)
    if item_object.is_a?(Article)
      Article.to_s
    elsif item_object.is_a?(Topic)
      Topic.to_s
    elsif item_object.is_a?(QaQuestion)
      QaQuestion.to_s
    elsif item_object.is_a?(Forum)
      Forum.to_s
    end
  end

  def render_manager_matching_level
    content_tag(:label, class: "font-noraml") do
      content_tag(:div, class: "col-sm-4 no-padding") do
        text_field_tag "program[manager_matching_level]", current_program.manager_matching_level, class: "form-control inline m-l-xs pull-left"
      end +
      content_tag(:span, "program_settings_strings.content.levels".translate, class: "p-xxs p-l-sm p-r-sm m-t-xxs pull-left")
    end
  end

  def render_past_mentor_matching_setting(form)
    return unless current_program.ongoing_mentoring_enabled?
    content_tag(:label, class: "checkbox m-t-xs") do
      form.check_box(:prevent_past_mentor_matching) +
      "program_settings_strings.content.show_zero_scores_for_past_connections".translate(Mentor: _Mentor, mentee: _mentee)
    end +
    content_tag(:div, "program_settings_strings.content.matching_help_text_html".translate(link: link_to("program_settings_strings.content.match_config".translate, match_configs_path)), class: "text-muted")
  end

  def render_mentor_request_style_change_disabled_alert(mentor_request_style_disabled, multiple_existing_groups_note_html, pending_mentor_requests_count)
    return unless mentor_request_style_disabled.present?

    content_tag(:div, class: "help-block") do
      multiple_existing_groups_note_html.presence || "program_settings_strings.content.mentor_request_style_change_disabled_html".translate(mentoring: _mentoring, count: pending_mentor_requests_count, link: mentor_requests_path(list: AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::NOT_ANSWERED], filter: AbstractRequest::Filter::ALL))
    end
  end

  def get_join_settings_hash(role)
    join_settings_hash = { RoleConstants::JoinSetting::APPLY_TO_JOIN => {
      checked: role.can_show_apply_to_join_ticked?(current_program),
      text: "program_settings_strings.content.apply_to_join".translate,
      options: { class: "toggle_checkboxes cjs_apply_to_join_parent", id: "apply_to_join_#{role.name}" }
    } }

    join_admin_approved_hash = { RoleConstants::JoinSetting::MEMBERSHIP_REQUEST => {
      checked: role.membership_request?,
      text: "program_settings_strings.content.admin_approval_required".translate(Admin: _Admin),
      options: { class: "cjs_membership_request cjs_apply_to_join_child", id: "membership_request_#{role.name}" },
      label_class: "iconcol-md-offset-1",
      boxtype: "radiobox"
    } }

    join_eligibility_rules_hash = { RoleConstants::JoinSetting::ELIGIBILITY_RULES => {
      checked: role.eligibility_rules?,
      text: "#{'program_settings_strings.content.eligibility_rule_based_approval'.translate} ",
      options: { class: "cjs_apply_to_join_child cjs_join_directly_with_eligibility", id: "join_eligibility_rules_#{role.name}" },
      label_class: "iconcol-md-offset-1",
      boxtype: "radiobox",
      link_text: link_to(text_eligibility_rules(role), "javascript:void(0)", id: "eligibility_rules_link_#{role.id}", onclick: "AdminViews.showPopup('#{path_eligibility_rules(role)}') ")
    } }

    join_directly_hash = { RoleConstants::JoinSetting::JOIN_DIRECTLY => {
      checked: role.join_directly?,
      text: "program_settings_strings.content.join_directly_v1".translate,
      options: { class: "cjs_apply_to_join_child cjs_join_directly", id: "join_directly_#{role.name}" },
      label_class: "iconcol-md-offset-1",
      boxtype: "radiobox"
    } }

    join_directly_only_with_sso_hash = { RoleConstants::JoinSetting::JOIN_DIRECTLY_ONLY_WITH_SSO => {
      checked: role.join_directly_only_with_sso?,
      text: "program_settings_strings.content.join_directly_with_sso_v1".translate,
      options: { class: "cjs_apply_to_join_child cjs_join_directly_sso", id: "join_directly_only_with_sso_#{role.name}" },
      label_class: "iconcol-md-offset-1",
      boxtype: "radiobox"
    } }

    auth_configs = AuthConfig.classify(@current_organization.auth_configs)
    join_settings_hash.merge!(join_admin_approved_hash)
    join_settings_hash.merge!(join_eligibility_rules_hash) if current_program.membership_eligibility_rules_enabled?
    join_settings_hash.merge!(join_directly_hash) if auth_configs[:default].present?
    join_settings_hash.merge!(join_directly_only_with_sso_hash) if auth_configs[:custom].present?
    join_settings_hash.merge!(join_settings_invite_hash(role.name))
  end

  def join_settings_invite_hash(role_name)
    non_admin_role_list = current_program.roles_without_admin_role
    invite_hash = {}
    atleast_one_role_can_invite = false

    non_admin_role_list.each do |non_admin_role|
      can_invite = non_admin_role.can_invite_role?(role_name)
      atleast_one_role_can_invite ||= can_invite
      invite_hash.merge!("#{non_admin_role.name}_invite" => {
        checked: can_invite,
        text: "program_settings_strings.content.allow_role_to_invite".translate(role: non_admin_role.customized_term.pluralized_term),
        options: { class: "cjs_program_membership_setting_child", id: "#{non_admin_role.name}_can_invite_#{role_name}" },
        label_class: "iconcol-md-offset-1"
      } )
    end

    return { RoleConstants::JoinSetting::INVITATION => {
      checked: atleast_one_role_can_invite,
      text: "program_settings_strings.content.invited_by_others".translate,
      options: { class: "cjs_program_membership_setting_parrent", id: "invitation_#{role_name}" }
    } }.merge(invite_hash)
  end

  def zero_match_score_message_label
    label = "program_settings_strings.content.zero_match_score_message_v1".translate(mentors: _mentors)
    label += " #{embed_icon(TOOLTIP_IMAGE_CLASS, '', id: 'not_a_match_help_text')}"
    label.html_safe
  end
end