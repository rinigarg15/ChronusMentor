module ScrapsHelper
  include AbstractMessagesHelper
  def get_scrap_reply_periods
    [
      ["app_constant.n_days".translate(count: 1), 1.day],
      ["app_constant.n_days".translate(count: 2), 2.days],
      ["app_constant.n_days".translate(count: 3), 3.days],
      ["app_constant.n_days".translate(count: 4), 4.days],
      ["app_constant.a_week".translate, 1.week]
    ]
  end
  def get_scrap_header_content(scrap)
    sibling_messages = (@scraps_siblings_index.present? && @scraps_siblings_index[scrap.root_id]) || scrap.siblings
    preload_hash = @preloaded.present? ? {preloaded: true, viewable_scraps_hash: @viewable_scraps_hash, unread_scraps_hash: @unread_scraps_hash, deleted_scraps_hash: @deleted_scraps_hash} : {}
    from_details = get_from_details(scrap, wob_member, {from_scrap: true, siblings: sibling_messages}.merge(preload_hash))
    sibling_has_attachment = @scraps_attachments.present? ? @scraps_attachments[scrap.root_id] : scrap.sibling_has_attachment?(wob_member) 
    last_created_at = @scraps_last_created_at.present? ? @scraps_last_created_at[scrap.root_id] : scrap.last_message_can_be_viewed(wob_member).created_at 
    attachment_with_date = content_tag(:span, (sibling_has_attachment ? get_icon_content("fa fa-paperclip text-default") : "") + DateTime.localize(last_created_at, format: :abbr_short_no_year), :class => "pull-right") 
    from_content = content_tag(:div, :class => "col-xs-8 no-padding") do content_tag(:span, "#{'feature.mentoring_model.label.from'.translate} ", :class => "cjs-scrap-from #{'font-600 cjs-unread-scrap' if from_details[:unread]}") + content_tag(:span, get_safe_string + from_details[:names])
    end 

    subject_content = content_tag(:div, :class => "cjs-scrap-subject #{'font-600' if from_details[:unread]}") do content_tag(:span, "#{'feature.mentoring_model.label.subject'.translate} ") + scrap.formatted_subject
    end

    attachment_with_date_for_mobile = content_tag(:div, attachment_with_date, :class => "col-xs-4 no-padding small #{hidden_on_web}") 
    attachment_with_date_for_web = content_tag(:div, attachment_with_date, :class => "col-xs-4 no-padding #{hidden_on_mobile}") 

    render(:partial => "common/header_collage", :locals => {member_pictures: from_details[:pictures]}) +
    content_tag(:div, :class=>"media-body") do
      content_tag(:div,:class => "cjs-scrap-details") do 
        content_tag(:div, from_content + attachment_with_date_for_mobile + attachment_with_date_for_web, :class => "clearfix p-b-xxs") + subject_content
      end
    end 
  end

  def get_scrap_reply_delete_buttons(scrap, viewing_member, preloaded_options={}, options={})
    other_options = {}
    other_options[:reply_action] = %Q[Discussions.loadReply("#{scrap.id}", "#{reply_scrap_path(scrap, format: :js, home_page: "#{options[:home_page]}")}", "#{options[:home_page]}");]
    other_options[:delete_action] = scrap_path(scrap, home_page: options[:home_page])
    other_options[:additional_class] = "scrap-actions"
    other_options[:remote] = true
    get_reply_delete_buttons(scrap, viewing_member, preloaded_options, other_options)
  end

  def get_unread_scraps_count_label(member, group_or_meeting, for_dropdown_content = false, options = {})
    unread_scraps_count = options[:badge_count] || member.scrap_inbox_unread_count(group_or_meeting)
    content_tag(:span, unread_scraps_count, :class => "rounded label label-danger cjs_unread_scraps_count #{ for_dropdown_content ? 'pull-right m-t-3' : 'cui_count_label' }") if unread_scraps_count > 0
  end
end
