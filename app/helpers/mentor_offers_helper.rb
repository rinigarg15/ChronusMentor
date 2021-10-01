module MentorOffersHelper
  def get_mentor_offer_filters(user)
    filter = {}
    filter[:all] = user.is_admin?
    filter[:by_me] = user.is_mentor?
    filter[:to_me] = user.is_student?
    filter
  end

  def mentor_offers_bulk_actions(is_manage_view=false)
    bulk_actions = [
      {:label => get_icon_content("fa fa-envelope") + "feature.mentor_request.action.send_message_to_sender".translate(count: 2), :url => "javascript:void(0)", :class => "cjs_bulk_action_mentor_offers", :id => "cjs_send_message_to_senders",
      :data => {:url => new_bulk_admin_message_admin_messages_path }}
    ]
    bulk_actions << {:label => get_icon_content("fa fa-envelope") + "feature.mentor_request.action.send_message_to_recipient".translate(count: 2), :url => "javascript:void(0)", :class => "cjs_bulk_action_mentor_offers", :id => "cjs_send_message_to_recipients",
      :data => {:url => new_bulk_admin_message_admin_messages_path }}
    bulk_actions << {:label => get_icon_content("fa fa-ban") + "feature.mentor_offer.action.close_offers".translate, :url => "javascript:void(0)", :class => "cjs_bulk_action_mentor_offers", :id => "cjs_close_requests",
      :data => {:url => fetch_bulk_actions_mentor_offers_path, :offer_status => MentorOffer::Status::CLOSED, is_manage_view: is_manage_view }} if @filter_params["status"] == MentorOffer::Status::STATE_TO_STRING[MentorOffer::Status::PENDING]
    bulk_actions << {:label => get_icon_content("fa fa-download") + "feature.mentor_offer.action.export_as_csv".translate, :url =>  export_mentor_offers_path(format: :csv, status: @filter_params["status"]), :class => "cjs_mentor_offer_export"}
    build_dropdown_button("display_string.Actions".translate, bulk_actions, :btn_class => "cur_page_info", :btn_group_btn_class => "btn-white btn no-vertical-margins", :is_not_primary => true)
  end

  def mentor_offers_actions(mentor_offer, is_manage_view)
    actions = []
    actions << {label: get_icon_content("fa fa-envelope") + "feature.mentor_request.action.send_message_to_sender".translate(count: 1), url: "javascript:void(0)", data: {url: new_bulk_admin_message_admin_messages_path, user: mentor_offer.mentor_id }, class: "cjs_send_message_to_sender cjs_individual_action_mentor_offers"}
    actions << {label: get_icon_content("fa fa-envelope") + "feature.mentor_request.action.send_message_to_recipient".translate(count: 1), url: "javascript:void(0)", data: {url: new_bulk_admin_message_admin_messages_path, user: mentor_offer.student_id }, class: "cjs_send_message_to_recipient cjs_individual_action_mentor_offers"}
    if mentor_offer.pending?
      actions << {label: get_icon_content("fa fa-ban") + "feature.mentor_offer.label.close".translate, js: "", class: "cjs_close_offer cjs_individual_action_mentor_offers", url: 'javascript:void(0)', data: {url: fetch_bulk_actions_mentor_offers_path, offer_status: MentorOffer::Status::CLOSED, mentor_offer: mentor_offer.id, is_manage_view: is_manage_view}}
    end
    return actions
  end

  def mentor_offers_actions_end_user(mentor_offer, received_offers_view, filter_params, options = {})
    actions = []
   # actions_for_mentor_offers_listing
     if received_offers_view && mentor_offer.pending?
       url_params = { mentor_offer: {status: MentorOffer::Status::ACCEPTED} }
       actions << {label: get_icon_content("fa fa-check") + "feature.mentor_offer.label.accept".translate, url: mentor_offer_path(mentor_offer, url_params), method: :patch, data: { disable_with: "display_string.Please_Wait".translate }}
       actions << {label: get_icon_content("fa fa-times") + "display_string.Decline".translate, js: "jQuery('#modal_mentor_offer_reject_withdraw_link_#{mentor_offer.id}').modal('show')", class: "mentor_offer_reject_withdraw_link_#{mentor_offer.id}"}
     elsif mentor_offer.accepted? && (group = mentor_offer.group).present?
       actions << {label: get_icon_content("fa fa-users") + 'feature.mentor_request.action.go_to_mentoring_area_v1'.translate(Mentoring_Area: _Mentoring_Connection), url: group_path(group)}
     elsif mentor_offer.pending?
       actions << {label: get_icon_content("fa fa-undo") + 'feature.mentor_offer.label.withdraw'.translate, :class => "mentor_offer_reject_withdraw_link_#{mentor_offer.id}", :js => "jQuery('#modal_mentor_offer_reject_withdraw_link_#{mentor_offer.id}').modal('show')"} if (filter_params[:filter_field] == AbstractRequest::Filter::BY_ME) || current_user.can_offer_mentoring?
     end
   return actions
  end

   def get_tabs_for_mentor_offers_listing(active_tab)
    label_tab_mapping = {
      "feature.meeting_request.label.pending".translate => MentorOffer::Status::STATE_TO_STRING[MentorOffer::Status::PENDING],
      "feature.meeting_request.label.accepted".translate => MentorOffer::Status::STATE_TO_STRING[MentorOffer::Status::ACCEPTED],
      "feature.meeting_request.label.declined".translate => MentorOffer::Status::STATE_TO_STRING[MentorOffer::Status::REJECTED],
      "feature.meeting_request.label.withdrawn".translate => MentorOffer::Status::STATE_TO_STRING[MentorOffer::Status::WITHDRAWN],
      "feature.meeting_request.label.closed".translate => MentorOffer::Status::STATE_TO_STRING[MentorOffer::Status::CLOSED]
    }
    get_tabs_for_listing(label_tab_mapping, active_tab, url: manage_mentor_offers_path, param_name: :status)
  end
end