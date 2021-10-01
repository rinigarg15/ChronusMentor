module CampaignManagement::CampaignsHelper
  class Tab
    CAMPAIGNS = 0
    CAMPAIGN_MESSAGES = 1

    def self.all
      [CAMPAIGNS, CAMPAIGN_MESSAGES]
    end
  end

  def campaign_columns(for_active_state=true, show_analytics=true)
    if for_active_state
      time_field = "enabled_at"
      time_title = "feature.campaign.fields.enabled_on".translate
    else
      time_field = "created_at"
      time_title = "feature.campaign.fields.created_on".translate
    end
    columns = [{ field: "title", width: show_analytics ? "50%" : "80%", headerTemplate: campaign_header_template("feature.campaign.fields.title".translate), encoded: false}]
    
    analytics_columns = [{field: "total_sent", width: "10%", headerTemplate: campaign_header_template("feature.campaign.fields.emails_sent".translate) }.merge(column_format(:centered)),
                         { field: "open_rate", width: "10%", headerTemplate: campaign_header_template("feature.campaign.fields.open_rate".translate) }.merge(column_format(:centered, :numeric)),
                         { field: "click_rate", width: "10%", headerTemplate: campaign_header_template("feature.campaign.fields.click_rate".translate)  }.merge(column_format(:centered, :numeric))]

    columns += analytics_columns if show_analytics
    columns << { field: time_field, width: "20%", headerTemplate: campaign_header_template(time_title) }.merge(column_format(:centered, :date))
  end


  def campaign_message_columns(campaign)
    fields = [
      { field: "title", width: campaign_message_title_width(campaign), headerTemplate: "feature.campaign_message.kendo.fields.title".translate, encoded: false, sortable: false},
      { field: "schedule", width: "20%", headerTemplate: "feature.campaign_message.kendo.fields.schedule".translate, encoded: false, sortable: false}.merge(column_format(:centered))]
    analytics = [ 
      { field: "total_sent", width: "10%", headerTemplate: "feature.campaign_message.kendo.fields.sent".translate, encoded: false, sortable: false}.merge(column_format(:centered)),
      { field: "open_rate", width: "10%", headerTemplate: "feature.campaign.fields.open_rate".translate, encoded: false, sortable: false}.merge(column_format(:centered, :numeric)),
      { field: "click_rate", width: "10%", headerTemplate: "feature.campaign.fields.click_rate".translate, encoded: false, sortable: false}.merge(column_format(:centered, :numeric))]
    fields += analytics unless campaign.drafted?
    actions = { field: "actions", width: "20%", headerTemplate: "feature.campaign_message.kendo.fields.actions".translate , sortable: false, encoded: false }.merge(column_format(:centered))
    fields << actions unless campaign.stopped?
    fields
  end

  def campaign_message_title_width(campaign)
    case campaign.state
    when CampaignManagement::AbstractCampaign::STATE::ACTIVE
      "30%"
    when CampaignManagement::AbstractCampaign::STATE::DRAFTED
      "60%"
    when CampaignManagement::AbstractCampaign::STATE::STOPPED
      "50%"
    end
  end

  def campaign_fields(for_active_state=true, show_analytics=true)
    time_field = for_active_state ? {enabled_at: { type: :date }} : {created_at: { type: :date }}
    analytics = {
                  open_rate: { type: :number },
                  click_rate: { type: :number },
                  total_sent: { type: :number }
                }
    fields = {
                id: { type: :string },
                title: { type: :string }  
              }
    fields.merge!(analytics) if show_analytics
    fields.merge(time_field)
  end

  def campaign_message_fields(campaign)
    analytics = {
      total_sent: { type: :number },
      open_rate: { type: :number },
      click_rate: { type: :number }
    }

    fields = {
      id: { type: :string },
      title: { type: :string },
      schedule: { type: :string }
    }

    campaign.drafted? ? fields : fields.merge(analytics)
  end


  def campaign_header_template(title)
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

  def campaign_message_actions_control(campaign_message)
    campaign = campaign_message.campaign
    action_links = []
    action_links << link_to(get_icon_content("text-default fa fa-pencil") + "display_string.Edit".translate, edit_campaign_management_user_campaign_abstract_campaign_message_path(:user_campaign_id => campaign.id, :id => campaign_message.id), :id => "edit-campaign-link-#{campaign_message.id}", :class => "cjs-edit-campaign-link btn btn-xs btn-white", :data => {:title => "feature.campaign.edit".translate, :toggle => "tooltip"})
    if campaign_message.is_duration_editable?
      confirmation_message = if campaign.drafted?
        "feature.campaign_message.kendo.delete_confirmation".translate
      elsif campaign_message.is_last_message? && campaign.active?
        "feature.campaign_message.kendo.delete_last_confirmation".translate
      else
        "feature.campaign_message.kendo.delete_confirmation_v1".translate
      end
      action_links << link_to(get_icon_content("text-default fa fa-trash") + "display_string.Delete".translate, "#",
              :id => "delete-campaign-message-link-#{campaign_message.id}",
              :class => "cjs_campaign_message_ajax_action cjs_campaign_stop_actions btn btn-xs btn-white",
              :data => {:title => "feature.campaign_message.delete".translate, :toggle => "tooltip", :path => campaign_management_user_campaign_abstract_campaign_message_path(id: campaign_message.id, :user_campaign_id => campaign.id, format: :js), method: :delete, :confirm => confirmation_message,
                        :details_path => get_details_path(campaign), track_ga: campaign.is_survey_campaign?, type: get_campaign_survey_type(campaign)})
    else
      action_links << link_to(get_icon_content("text-default fa fa-trash")  + "display_string.Delete".translate, "#",
              :id => "delete-campaign-message-link-#{campaign_message.id}",
              :class => "cjs_campaign_stop_actions disabled_link  btn btn-xs btn-white",
              :data => {:title => "feature.program_invitations.content.default_message_tip".translate, :toggle => "tooltip"})
    end
    render_button_group(action_links, :grid_class => "text-center cjs-cm-message-actions")
  end

  def get_details_path(campaign)
    case campaign.type
    when CampaignManagement::AbstractCampaign::TYPE::USER
      details_campaign_management_user_campaign_path(campaign)
    when CampaignManagement::AbstractCampaign::TYPE::PROGRAMINVITATION
      invite_users_path
    when CampaignManagement::AbstractCampaign::TYPE::SURVEY
      reminders_survey_path(campaign.survey)
    end
  end

  def campaign_title_link(campaign, link_data)
    link_to(details_campaign_management_user_campaign_path(campaign), link_data) do
      campaign.title
    end
  end


  def campaign_details_action(campaign)
    link_data = {
      class: "cjs_campaign_analytics_link",
      id: "cjs_campaign_analytics_#{campaign.id}",
      data: {
        user_campaign_id: campaign.id,
        path: details_campaign_management_user_campaign_path(campaign, format: :js)
      }
    }
    content_tag :div do
      title = content_tag(:span, campaign_title_link(campaign, link_data))
      title << content_tag(:span, " (#{"feature.campaign.tag.emails_v1".translate(count: campaign.emails_count)})", :class => "dim")
      title
    end
  end

  def campaign_message_link(campaign_message)
    content_tag :div do
      link_to(edit_campaign_management_user_campaign_abstract_campaign_message_path(user_campaign_id: campaign_message.campaign.id, id: campaign_message.id), class: "cjs_campaign_analytics_link") do
        campaign_message.email_template.subject
      end
    end
  end

  def initialize_campaigns_kendo_script(current_state, tour_taken, lessThanIE9, show_analytics)
    for_active_state = (CampaignManagement::AbstractCampaign::STATE::ACTIVE == current_state)
    empty_message = if for_active_state
      click_here_link = link_to("feature.campaign.kendo.click_here".translate, new_campaign_management_user_campaign_path, class: "cjs_ga_initiated_creation_directly")
      "feature.campaign.kendo.empty_message_html".translate(link: click_here_link)
    else
      "feature.campaign.kendo.no_campaigns_yet_message".translate
    end
    options = {
      columns: campaign_columns(for_active_state, show_analytics),
      fields: campaign_fields(for_active_state, show_analytics),
      dataSource: campaign_management_user_campaigns_path(state: current_state, format: :json),
      messages: {
        emptyMessage: empty_message
      },
      grid_id: "cjs_campaigns_kendogrid",
      tour_taken: tour_taken,
      path: one_time_flags_path(format: :js),
      message_tag: OneTimeFlag::Flags::TourTags::CAMPAIGN_TOUR_TAG,
      lessThanIE9: lessThanIE9,
      serverPaging: false,
      serverFiltering: false,
      serverSorting: true,
      sortable: true,
      pageable: false,
      filterable: false
    }
    javascript_tag "CampaignsKendo.initializeKendo(#{options.to_json})"
  end

  def initialize_campaign_messages_kendo_script(campaign, tour_taken, lessThanIE9)
    link_options = campaign.is_survey_campaign? ? {class: "cjs_new_reminder_button", data: {type: get_survey_type_for_ga(@survey)}} : {}
    click_here_link = link_to("feature.campaign_message.kendo.click_here".translate, new_campaign_management_user_campaign_abstract_campaign_message_path(:user_campaign_id => campaign.id), link_options)
    empty_message = "feature.campaign_message.kendo.empty_campaign_message_html".translate(link: click_here_link)
    options = {
      columns: campaign_message_columns(campaign),
      fields: campaign_message_fields(campaign),
      dataSource: campaign_management_user_campaign_abstract_campaign_messages_path(user_campaign_id: campaign.id, format: :json),
      messages: {
        emptyMessage: empty_message
      },
      grid_id: "cjs_campaign_messages_kendogrid",
      tour_taken: tour_taken,
      path: one_time_flags_path(format: :js),
      message_tag: OneTimeFlag::Flags::TourTags::CAMPAIGN_DETAILS_TOUR_TAG,
      lessThanIE9: lessThanIE9,
      is_featured: campaign.featured?,
      campaign_state: campaign.state,
      serverPaging: false,
      serverFiltering: false,
      serverSorting: false,
      sortable: false,
      pageable: false,
      filterable: false
    }
    javascript_tag "CampaignsKendo.initializeKendo(#{options.to_json})"
  end

  def campaign_tabs(presenter)
    content = []
    content_tag :ul, class: "nav nav-tabs h5 no-margins" do
      campaign_all_tabs(presenter).map do |state, title|
        content << (content_tag :li, class: state == presenter.target_state ? "ct_active active" : "" do
          link_to title, campaign_management_user_campaigns_path(state: state), id: "cjs_campaigns_state_#{state}"
        end)
      end
      safe_join(content)
    end
  end

  def campaign_all_tabs(presenter)
    [ 
      [CampaignManagement::AbstractCampaign::STATE::DRAFTED, "feature.campaign.tabs.drafted".translate(count: presenter.drafted)],
      [CampaignManagement::AbstractCampaign::STATE::ACTIVE, "feature.campaign.tabs.active".translate(count: presenter.active)],
      [CampaignManagement::AbstractCampaign::STATE::STOPPED, "feature.campaign.tabs.stopped".translate(count: presenter.disabled)]
    ]
  end

  def campaign_message_from_options(program = current_program)
    options_array = [[program.name, nil]]
    program.admin_users.active.each do |admin|
      options_array << [admin.name(:name_only => true), admin.id]
    end
    return options_array
  end

  def render_campaign_message_sender(sender_id, program = current_program)
    if admin = program.admin_users.active.where(id: sender_id).first
      admin.name(:name_only => true)
    else
      program.name
    end
  end

  def campaign_management_widget_view(current_tab, campaign, campaign_message = nil)
    @skip_rounded_white_box_for_content = true
    content = get_safe_string
    CampaignManagement::CampaignsHelper::Tab.all.each do |tab|
      bg_class = "bg-waterhighlight"
      if tab < current_tab
        bg_class = "bg-darkgrey"
      elsif tab == current_tab
        bg_class = "bg-white"
      end
      tab_content = set_campaign_labels(tab, campaign, campaign_message)
      content += campaign_tab_content(tab_content, bg_class)
    end
    content_tag(:div, :class => "", :id => 'campaign_management_tab_bar', :style => "position:relative;") do
      content
    end + javascript_tag(%Q[CampaignManagement.adjustTopBar();])

  end

  def set_campaign_labels(tab, campaign, campaign_message)
    tab_with_link = {}
    if !campaign.new_record?
      tab_with_link = {
        CampaignManagement::CampaignsHelper::Tab::CAMPAIGNS => link_to( "feature.campaigns.header.CAMPAIGN_INFORMATION".translate, edit_campaign_management_user_campaign_path(campaign)),
        CampaignManagement::CampaignsHelper::Tab::CAMPAIGN_MESSAGES => link_to("feature.campaigns.header.CAMPAIGN_EMAIL".translate, new_campaign_management_user_campaign_abstract_campaign_message_path(campaign))
      }
    end
    tab_without_link = {
      CampaignManagement::CampaignsHelper::Tab::CAMPAIGNS => "feature.campaigns.header.CAMPAIGN_INFORMATION".translate,
      CampaignManagement::CampaignsHelper::Tab::CAMPAIGN_MESSAGES => "feature.campaigns.header.CAMPAIGN_EMAIL".translate
    }

    if campaign.new_record?
      return tab_without_link[tab]
    else
      return tab_with_link[tab]
    end
  end

  def campaign_tab_content(content, bg_class)
    content_tag(:div, :class => "parallelogram text-center #{bg_class}") do
      content_tag(:p, content)
    end
  end

  def fetch_placeholders(all_tags, program)
    placeholders_hash = []
    all_tags.keys.collect(&:to_s).each do |tag|
      hash = {}
      hash[:value] = "{{"+ tag + "}}"
      hash[:name]  = "<b>" + all_tags[tag.to_sym][:name].call(program) + "</b> <br />" + hash[:value] if all_tags[tag.to_sym][:name].present?
      hash[:label] = all_tags[tag.to_sym][:description].call(program)
      placeholders_hash << hash
    end
    placeholders_hash.to_json
  end

  def get_campaign_message_type(campaign)
    case campaign.type
    when "CampaignManagement::ProgramInvitationCampaign"
      CampaignManagement::ProgramInvitationCampaignMessage
    when "CampaignManagement::UserCampaign"
      CampaignManagement::UserCampaignMessage
    when "CampaignManagement::SurveyCampaign"
      CampaignManagement::SurveyCampaignMessage
    end
  end

  def get_campaign_message_tour_tag(campaign)
    case campaign.type
    when "CampaignManagement::ProgramInvitationCampaign"
      OneTimeFlag::Flags::TourTags::CAMPAIGN_PROGRAM_INVITATION_TOUR_TAG
    when "CampaignManagement::UserCampaign"
      OneTimeFlag::Flags::TourTags::CAMPAIGN_MESSAGE_TOUR_TAG
    when "CampaignManagement::SurveyCampaign"
      OneTimeFlag::Flags::TourTags::CAMPAIGN_SURVEY_REMINDER_TOUR_TAG
    end
  end

  def get_disable_link(campaign)
    {
      :label => get_icon_content("text-default fa fa-eye-slash") + "feature.campaign.stop".translate,
      :url => "javascript:void(0);",
      :method => :get,
      :class => "disable_campaign_action",
      :data => {:url => disable_campaign_management_user_campaign_path(campaign)}
    }
  end

  def get_clone_link(campaign)
    {
      :label => "feature.campaign.duplicate".translate,
      :url => "javascript:void(0);",
      :btn_class_name => "cjs_cm_clone_popup",
      :data => {:url => clone_popup_campaign_management_user_campaign_path(campaign)}
    }
  end

  def get_delete_link(campaign)
    {
      :label => get_icon_content("text-default fa fa-trash")  + set_screen_reader_only_content("display_string.delete".translate) + "feature.campaign.delete".translate,
      :border_top => !campaign.stopped?,
      :class => "delete_user_campaign_action",
      :data => {:toggle => "modal", :target => "#modal_delete_user_campaign_action"}
    }
  end

  def get_start_link(campaign)
    {
      :label => "feature.campaigns.label.start_campaign".translate,
      :url => start_campaign_management_user_campaign_path(campaign),
      :btn_class_name => "start_user_campaign_action",
      :disabled => campaign.campaign_messages.empty?,
      :method => :patch
    }
  end

  def get_drop_down_array(campaign)
    drop_down_array = []
    if campaign.stopped?
      drop_down_array << get_clone_link(campaign)
    else
      drop_down_array << {:label => "feature.campaign_message.index.create_new".translate, :url => new_campaign_management_user_campaign_abstract_campaign_message_path(campaign)}
      drop_down_array << {:label => get_icon_content("fa fa-pencil") + "feature.campaign.edit".translate, :url => edit_campaign_management_user_campaign_path(campaign)}
      drop_down_array << get_disable_link(campaign) if campaign.active?
    end
    drop_down_array << get_delete_link(campaign)
  end

  def campaign_message_schedule_text(campaign_message)
    content_tag :span, :class => "cui_campaign_message_schedule" do
      days = campaign_message.duration
      campaign = campaign_message.campaign
      if days.zero?
        campaign_message_schedule_text_for_zero(campaign)
      else
        if campaign.is_survey_campaign?
          campaign.for_engagement_survey? ? "feature.campaigns.content.schedule_text_days_for_survey_reminders".translate(count: days) : "feature.campaigns.content.schedule_text_days_for_meeting_survey_reminders".translate(count: days, meeting: _meeting)
        else
          "feature.campaigns.content.schedule_text_days_v1".translate(count: days)
        end
      end
    end
  end

  def campaign_message_schedule_text_for_zero(campaign)
    case campaign.type
    when "CampaignManagement::ProgramInvitationCampaign"
      "feature.campaigns.content.sent_immediately".translate
    when "CampaignManagement::UserCampaign"
      "feature.campaigns.content.schedule_text_same_day".translate
    when "CampaignManagement::SurveyCampaign"
      if campaign.for_engagement_survey?
        "feature.campaigns.content.schedule_text_same_day_for_survey_reminder".translate
      else
        "feature.campaigns.content.schedule_text_same_day_meeting_survey_reminder_email".translate(meeting: _meeting)
      end
    end
  end

  def get_class_for_add_email(campaign, is_new_record)
    if campaign.is_user_campaign? && is_new_record
      campaign.drafted? ? "cjs_ga_add_email_draft_state" : "cjs_ga_add_email_active_state"
    end
  end

  def invalid_duration_message(campaign, campaign_message_type)
    if campaign.is_program_campaign?
      "feature.campaign_message.invalid_duration".translate(min: campaign_message_type::CAMPAIGN_MESSAGE_DURATION_MIN_IN_DAYS, max: campaign_message_type::CAMPAIGN_MESSAGE_DURATION_MAX_IN_DAYS)
    else
      "feature.campaign_message.invalid_duration_v2".translate(min: campaign_message_type::CAMPAIGN_MESSAGE_DURATION_MIN_IN_DAYS)
    end
  end

  def campaign_message_schedule_help_text(campaign)
    case campaign.type
    when "CampaignManagement::ProgramInvitationCampaign"
      "feature.campaigns.content.schedule_description_invitation_email".translate
    when "CampaignManagement::UserCampaign"
      "feature.campaigns.content.schedule_description_user_campaign_email_v1".translate
    when "CampaignManagement::SurveyCampaign"
      campaign.for_engagement_survey? ? "feature.campaigns.content.schedule_description_survey_reminder_email".translate : "feature.campaigns.content.schedule_description_meeting_survey_reminder_email".translate(meeting: _meeting)
    end
  end

  def get_campaign_survey_type(campaign)
    campaign.is_survey_campaign? ? get_survey_type_for_ga(campaign.survey) : ""
  end

  def campaigns_call_to_action(link_text, link_url, button_class="button-large")
    render(partial: "/mailers/call_to_action.html.erb", locals: {link_text: link_text, link_url: link_url, button_class: button_class})
  end

  def get_campaign_email_subjects_with_zero_duration(campaign)
    email_subjects = campaign.campaign_messages.where(duration: 0).collect {|msg| msg.email_template.subject}
    return [email_subjects.map { |subject| "\"#{subject}\"" }.join(", "), email_subjects.size]
  end

end
