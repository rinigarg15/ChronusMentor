  require_relative './../test_helper'
class CampaignManagement::CampaignsHelperTest < ActionView::TestCase

  def test_campaign_message_from_options
    CampaignManagement::UserCampaignsController.expects(:current_program).at_least(0).returns(programs(:albers))
    current_user_is :f_admin
    options = campaign_message_from_options(programs(:albers))
    assert_equal 3, options.count
    assert_equal ["Albers Mentor Program", nil], options[0]
    assert_equal ["Freakin Admin", 1], options[1]
    assert_equal ["Kal Raman", 6], options[2]
  end

  def test_fetch_placeholders
    placeholders = fetch_placeholders(ChronusActionMailer::Base.mailer_attributes[:tags][:campaign_tags], programs(:albers))
    placeholders_count = JSON.parse(placeholders).count
    assert_equal 11, placeholders_count
    placeholders = fetch_placeholders(ChronusActionMailer::Base.mailer_attributes[:tags][:program_invitation_campaign_tags], programs(:albers))
    placeholders_count = JSON.parse(placeholders).count
    assert_equal 8, placeholders_count
    placeholders = fetch_placeholders(ChronusActionMailer::Base.mailer_attributes[:tags][:engagement_survey_campaign_tags], programs(:albers))
    placeholders_count = JSON.parse(placeholders).count
    assert_equal 5, placeholders_count
  end

  def test_render_campaign_message_sender_normal_case
    program = programs(:albers)
    admin = users(:f_admin)
    name = render_campaign_message_sender(admin.id, program)
    assert_equal "Freakin Admin", name
  end

  def test_render_campaign_message_sender_if_user_deleted
    program = programs(:albers)
    name = render_campaign_message_sender(1_000_142, program)
    assert_equal "Albers Mentor Program", name
  end

  def test_campaign_message_columns_and_fields_values
    campaign = cm_campaign_messages(:campaign_message_1).campaign
    self.stubs(:campaign_message_title_width).with(campaign).times(3).returns("something")
    expected_campaign_message_columns = [
      { field: "title", width: "something", headerTemplate: "Email", encoded: false, sortable: false},
      { field: "open_rate", width: "10%", headerTemplate: "Open Rate", encoded: false, sortable: false, headerAttributes: {:class=>"text-center"}, attributes: {:class=>"text-center"}, format: "{0:p1}"},
      { field: "click_rate", width: "10%", headerTemplate: "Click Rate", encoded: false, sortable: false, headerAttributes: {:class=>"text-center"}, attributes: {:class=>"text-center"}, format: "{0:p1}"},
      { field: "total_sent", width: "10%", headerTemplate: "Sent", encoded: false, sortable: false, headerAttributes: {:class=>"text-center"}, attributes: {:class=>"text-center"}},
      { field: "schedule", width: "20%", headerTemplate: "Schedule", encoded: false, sortable: false, headerAttributes: {:class=>"text-center"}, attributes: {:class=>"text-center"}},
      { field: "actions", width: "20%", headerTemplate: "Actions", sortable: false, encoded: false, headerAttributes: {:class=>"text-center"}, attributes: {:class=>"text-center"}}
    ];
    assert_equal_unordered expected_campaign_message_columns, campaign_message_columns(campaign)

    expected_campaign_message_fields = {
      id: { type: :string },
      title: { type: :string },
      total_sent: { type: :number },
      open_rate: { type: :number },
      click_rate: { type: :number },
      schedule: { type: :string }
    };
    assert_equal expected_campaign_message_fields, campaign_message_fields(campaign)

    campaign.stubs(:drafted?).returns(true)
    expected_campaign_message_columns = [
      { field: "title", width: "something", headerTemplate: "Email", encoded: false, sortable: false},
      { field: "schedule", width: "20%", headerTemplate: "Schedule", encoded: false, sortable: false, headerAttributes: {:class=>"text-center"}, attributes: {:class=>"text-center"}},
      { field: "actions", width: "20%", headerTemplate: "Actions", sortable: false, encoded: false, headerAttributes: {:class=>"text-center"}, attributes: {:class=>"text-center"}}
    ];
    assert_equal_unordered expected_campaign_message_columns, campaign_message_columns(campaign)

    expected_campaign_message_fields = {
      id: { type: :string },
      title: { type: :string },
      schedule: { type: :string }
    };
    assert_equal expected_campaign_message_fields, campaign_message_fields(campaign)

    campaign.stubs(:drafted?).returns(false)
    campaign.stubs(:stopped?).returns(true)

    expected_campaign_message_columns = [
      { field: "title", width: "something", headerTemplate: "Email", encoded: false, sortable: false},
      { field: "open_rate", width: "10%", headerTemplate: "Open Rate", encoded: false, sortable: false, headerAttributes: {:class=>"text-center"}, attributes: {:class=>"text-center"}, format: "{0:p1}"},
      { field: "click_rate", width: "10%", headerTemplate: "Click Rate", encoded: false, sortable: false, headerAttributes: {:class=>"text-center"}, attributes: {:class=>"text-center"}, format: "{0:p1}"},
      { field: "total_sent", width: "10%", headerTemplate: "Sent", encoded: false, sortable: false, headerAttributes: {:class=>"text-center"}, attributes: {:class=>"text-center"}},
      { field: "schedule", width: "20%", headerTemplate: "Schedule", encoded: false, sortable: false, headerAttributes: {:class=>"text-center"}, attributes: {:class=>"text-center"}}
    ];
    assert_equal_unordered expected_campaign_message_columns, campaign_message_columns(campaign)

    expected_campaign_message_fields = {
      id: { type: :string },
      title: { type: :string },
      total_sent: { type: :number },
      open_rate: { type: :number },
      click_rate: { type: :number },
      schedule: { type: :string }
    };
    assert_equal expected_campaign_message_fields, campaign_message_fields(campaign)
  end

  def test_campaign_message_title_width
    campaign = cm_campaigns(:active_campaign_1)

    assert_equal "30%", campaign_message_title_width(campaign)

    campaign.stubs(:state).returns(CampaignManagement::AbstractCampaign::STATE::DRAFTED)
    assert_equal "60%", campaign_message_title_width(campaign)

    campaign.stubs(:state).returns(CampaignManagement::AbstractCampaign::STATE::STOPPED)
    assert_equal "50%", campaign_message_title_width(campaign)
  end

  def test_campaign_columns_and_fields_values
    expected_campaign_columns = [
      { field: "title", width: "50%", headerTemplate: "Campaign Name<span class='non-sorted'></span>", encoded: false},
      { field: "open_rate", width: "10%", headerTemplate: "Open Rate<span class='non-sorted'></span>", headerAttributes: {:class=>"text-center"}, attributes: {:class=>"text-center"}, format: "{0:p1}"},
      { field: "click_rate", width: "10%", headerTemplate: "Click Rate<span class='non-sorted'></span>", headerAttributes: {:class=>"text-center"}, attributes: {:class=>"text-center"}, format: "{0:p1}"},
      { field: "total_sent", width: "10%", headerTemplate: "Emails Sent<span class='non-sorted'></span>", headerAttributes: {:class=>"text-center"}, attributes: {:class=>"text-center"}},
      { field: "enabled_at", width: "20%", headerTemplate: "Started On<span class='non-sorted'></span>", headerAttributes: {:class=>"text-center"}, attributes: {:class=>"text-center"}, format: "{0:MMM dd, yyyy}"}
    ];
    assert_equal_unordered campaign_columns, expected_campaign_columns

    expected_campaign_fields = {
      id: { type: :string },
      title: { type: :string },
      open_rate: { type: :number },
      click_rate: { type: :number },
      total_sent: { type: :number },
      enabled_at: { type: :date }
    };
    assert_equal campaign_fields, expected_campaign_fields

    expected_campaign_columns = [
      { field: "title", width: "50%", headerTemplate: "Campaign Name<span class='non-sorted'></span>", encoded: false},
      { field: "open_rate", width: "10%", headerTemplate: "Open Rate<span class='non-sorted'></span>", headerAttributes: {:class=>"text-center"}, attributes: {:class=>"text-center"}, format: "{0:p1}"},
      { field: "click_rate", width: "10%", headerTemplate: "Click Rate<span class='non-sorted'></span>", headerAttributes: {:class=>"text-center"}, attributes: {:class=>"text-center"}, format: "{0:p1}"},
      { field: "total_sent", width: "10%", headerTemplate: "Emails Sent<span class='non-sorted'></span>", headerAttributes: {:class=>"text-center"}, attributes: {:class=>"text-center"}},
      { field: "created_at", width: "20%", headerTemplate: "Created On<span class='non-sorted'></span>", headerAttributes: {:class=>"text-center"}, attributes: {:class=>"text-center"}, format: "{0:MMM dd, yyyy}"}
    ];
    assert_equal_unordered campaign_columns(false), expected_campaign_columns

    expected_campaign_fields = {
      id: { type: :string },
      title: { type: :string },
      open_rate: { type: :number },
      click_rate: { type: :number },
      total_sent: { type: :number },
      created_at: { type: :date }
    };

    assert_equal campaign_fields(false), expected_campaign_fields

    expected_campaign_columns = [
      { field: "title", width: "80%", headerTemplate: "Campaign Name<span class='non-sorted'></span>", encoded: false},
      { field: "created_at", width: "20%", headerTemplate: "Created On<span class='non-sorted'></span>", headerAttributes: {:class=>"text-center"}, attributes: {:class=>"text-center"}, format: "{0:MMM dd, yyyy}"}
    ];
    assert_equal_unordered campaign_columns(false, false), expected_campaign_columns

    expected_campaign_fields = {
      id: { type: :string },
      title: { type: :string },
      created_at: { type: :date }
    };

    assert_equal campaign_fields(false, false), expected_campaign_fields
  end

  def test_campaign_message_schedule_text
    campaign_message = cm_campaign_messages(:campaign_message_1)

    campaign_message.duration = 1
    assert_equal "<span class=\"cui_campaign_message_schedule\">Sent after a day</span>", campaign_message_schedule_text(campaign_message)

    campaign_message.duration = 0
    assert_equal "<span class=\"cui_campaign_message_schedule\">Sent the same day</span>", campaign_message_schedule_text(campaign_message)

    campaign_message.duration = 5
    assert_equal "<span class=\"cui_campaign_message_schedule\">Sent after 5 days</span>", campaign_message_schedule_text(campaign_message)

    scm = CampaignManagement::SurveyCampaignMessage.first
    scm.duration = 5
    CampaignManagement::SurveyCampaign.any_instance.stubs(:for_engagement_survey?).returns(false)
    assert_equal "<span class=\"cui_campaign_message_schedule\">5 days after the meeting has passed</span>", campaign_message_schedule_text(scm)

    CampaignManagement::SurveyCampaign.any_instance.stubs(:for_engagement_survey?).returns(true)
    assert_equal "<span class=\"cui_campaign_message_schedule\">5 days after the survey is overdue</span>", campaign_message_schedule_text(scm)
  end

  def test_campaign_tab_content
    bg_class = "some_back_ground_class"
    content = "some tab content"
    content_in_tag = content_tag(:p, content)
    assert_equal content_tag(:div, content_in_tag, :class => "parallelogram text-center #{bg_class}"), campaign_tab_content(content, bg_class)
  end

  def test_campaign_message_link
    campaign_message = cm_campaign_messages(:campaign_message_1)
    link = link_to("Campaign Message - Subject1", "/campaign_management/user_campaigns/#{campaign_message.campaign.id}/abstract_campaign_messages/#{campaign_message.id}/edit", :class => "cjs_campaign_analytics_link")
    assert_equal content_tag(:div, link), campaign_message_link(campaign_message)
  end

  def test_campaign_details_action_should_return_details_tag_with_email_count
    campaign = cm_campaigns(:active_campaign_1)
    link_data = {
      class: "cjs_campaign_analytics_link",
      id: "cjs_campaign_analytics_#{campaign.id}",
      data: {
        user_campaign_id: campaign.id,
        path: "/campaign_management/user_campaigns/#{campaign.id}/details.js"
      }
    }
    title_link = link_to("Campaign1 Name","/campaign_management/user_campaigns/#{campaign.id}/details", link_data)

    campaign.expects(:emails_count).returns(1)
    title = content_tag(:span, title_link)
    title << content_tag(:span, " (1 email)", :class => "dim")
    assert_equal content_tag(:div, title), campaign_details_action(campaign)

    campaign.expects(:emails_count).returns(3)
    title = content_tag(:span, title_link)
    title << content_tag(:span, " (3 emails)", :class => "dim")
    assert_equal content_tag(:div, title), campaign_details_action(campaign)

    campaign.expects(:emails_count).returns(0)
    title = content_tag(:span, title_link)
    title << content_tag(:span, " (no email)", :class => "dim")
    assert_equal content_tag(:div, title), campaign_details_action(campaign)
  end

  def test_set_campaign_labels
    campaign = cm_campaigns(:active_campaign_1)
    campaign_message = campaign.campaign_messages.first

    assert_equal link_to("CAMPAIGN INFORMATION", "/campaign_management/user_campaigns/#{campaign.id}/edit"), set_campaign_labels(0, campaign, campaign_message)
    assert_equal link_to("CAMPAIGN EMAIL", "/campaign_management/user_campaigns/#{campaign.id}/abstract_campaign_messages/new"), set_campaign_labels(1, campaign, campaign_message)

    campaign = CampaignManagement::AbstractCampaign.new
    campaign_message = CampaignManagement::AbstractCampaignMessage.new
    assert_equal "CAMPAIGN INFORMATION", set_campaign_labels(0, campaign, campaign_message)
    assert_equal "CAMPAIGN EMAIL", set_campaign_labels(1, campaign, campaign_message)
  end

  def test_campaign_management_widget_view
    content = content_tag(:div, content_tag(:p, "CAMPAIGN INFORMATION"), :class => "parallelogram text-center bg-white")
    content += content_tag(:div, content_tag(:p, "CAMPAIGN EMAIL"), :class => "parallelogram text-center bg-waterhighlight")
    assert_match content, campaign_management_widget_view(0, CampaignManagement::AbstractCampaign.new)

    content = content_tag(:div, content_tag(:p, "CAMPAIGN INFORMATION"), :class => "parallelogram text-center bg-darkgrey")
    content += content_tag(:div, content_tag(:p, "CAMPAIGN EMAIL"), :class => "parallelogram text-center bg-white")
    assert_match content, campaign_management_widget_view(1, CampaignManagement::AbstractCampaign.new)
  end

  def test_get_delete_link
    campaign = cm_campaigns(:active_campaign_1)
    output = get_delete_link(campaign)
    expected_output = {:label=>"<i class=\"text-default fa fa-trash fa-fw m-r-xs\"></i>#{set_screen_reader_only_content("display_string.delete".translate)}Delete",
     :border_top=>true,
     :class=>"delete_user_campaign_action",
     :data=>{:toggle=>"modal", :target=>"#modal_delete_user_campaign_action"}}
    assert_equal expected_output, output

    campaign = cm_campaigns(:cm_campaigns_3)
    output = get_delete_link(campaign)
    expected_output = {:label=>"<i class=\"text-default fa fa-trash fa-fw m-r-xs\"></i>#{set_screen_reader_only_content("display_string.delete".translate)}Delete",
     :border_top=>true,
     :class=>"delete_user_campaign_action",
     :data=>{:toggle=>"modal", :target=>"#modal_delete_user_campaign_action"}}
    assert_equal expected_output, output
  end

  # TODO: Separate the test cases

  def test_initialize_campaign_messages_kendo_script
    campaign = cm_campaigns(:active_campaign_1)

    assert_equal 6, campaign_message_columns(campaign).count
    assert_equal 6, campaign_message_fields(campaign).count

    expected_options = {
      columns: campaign_message_columns(campaign),
      fields: campaign_message_fields(campaign),
      dataSource: "/campaign_management/user_campaigns/#{campaign.id}/abstract_campaign_messages.json",
      messages: {
        emptyMessage: "There are no emails created yet. <a href=\"/campaign_management/user_campaigns/#{campaign.id}/abstract_campaign_messages/new\">Click here</a> to create one"
      },
      grid_id: "cjs_campaign_messages_kendogrid",
      tour_taken: false,
      path: "/one_time_flags.js",
      message_tag: OneTimeFlag::Flags::TourTags::CAMPAIGN_DETAILS_TOUR_TAG,
      lessThanIE9: false,
      is_featured: false,
      campaign_state: 0,
      serverPaging: false,
      serverFiltering: false,
      serverSorting: false,
      sortable: false,
      pageable: false,
      filterable: false
    }
    expected_output = javascript_tag "CampaignsKendo.initializeKendo(#{expected_options.to_json})"
    assert_equal expected_output, initialize_campaign_messages_kendo_script(campaign, false, false)
  end

  def test_initialize_campaigns_kendo_script
    assert_equal 5, campaign_columns.count
    assert_equal 6, campaign_fields.count

    expected_options = {
      columns: campaign_columns,
      fields: campaign_fields,
      dataSource: "/campaign_management/user_campaigns.json?state=0",
      messages: {
        emptyMessage: "There are no campaigns yet. <a class=\"cjs_ga_initiated_creation_directly\" href=\"/campaign_management/user_campaigns/new\">Click here</a> to create one"
      },
      grid_id: "cjs_campaigns_kendogrid",
      tour_taken: false,
      path: "/one_time_flags.js",
      message_tag: OneTimeFlag::Flags::TourTags::CAMPAIGN_TOUR_TAG,
      lessThanIE9: false,
      serverPaging: false,
      serverFiltering: false,
      serverSorting: true,
      sortable: true,
      pageable: false,
      filterable: false
    }
    expected_output = javascript_tag "CampaignsKendo.initializeKendo(#{expected_options.to_json})"
    assert_equal expected_output, initialize_campaigns_kendo_script(0, false, false, true)

    expected_options = {
      columns: campaign_columns(false),
      fields: campaign_fields(false),
      dataSource: "/campaign_management/user_campaigns.json?state=1",
      messages: {
        emptyMessage: "feature.campaign.kendo.no_campaigns_yet_message".translate
      },
      grid_id: "cjs_campaigns_kendogrid",
      tour_taken: false,
      path: "/one_time_flags.js",
      message_tag: OneTimeFlag::Flags::TourTags::CAMPAIGN_TOUR_TAG,
      lessThanIE9: false,
      serverPaging: false,
      serverFiltering: false,
      serverSorting: true,
      sortable: true,
      pageable: false,
      filterable: false
    }
    expected_output = javascript_tag "CampaignsKendo.initializeKendo(#{expected_options.to_json})"
    assert_equal expected_output, initialize_campaigns_kendo_script(1, false, false, true)

    campaign_columns2 = campaign_columns(false, false)
    campaign_fields2 = campaign_fields(false, false)

    assert_equal 2, campaign_columns2.count
    assert_equal 3, campaign_fields2.count

    expected_options2 = {
      columns: campaign_columns2,
      fields: campaign_fields2,
      dataSource: "/campaign_management/user_campaigns.json?state=2",
      messages: {
        emptyMessage: "feature.campaign.kendo.no_campaigns_yet_message".translate
      },
      grid_id: "cjs_campaigns_kendogrid",
      tour_taken: false,
      path: "/one_time_flags.js",
      message_tag: OneTimeFlag::Flags::TourTags::CAMPAIGN_TOUR_TAG,
      lessThanIE9: false,
      serverPaging: false,
      serverFiltering: false,
      serverSorting: true,
      sortable: true,
      pageable: false,
      filterable: false
    }
    expected_output2 = javascript_tag "CampaignsKendo.initializeKendo(#{expected_options2.to_json})"
    assert_equal expected_output2, initialize_campaigns_kendo_script(2, false, false, false)

    expected_options2[:dataSource] = "/campaign_management/user_campaigns.json?state=1"
    expected_output2 = javascript_tag "CampaignsKendo.initializeKendo(#{expected_options2.to_json})"
    assert_equal expected_output2, initialize_campaigns_kendo_script(1, false, false, false)
  end

  def test_column_format
    column_format = {:headerAttributes=>{:class=>"text-center"},
      :attributes=>{:class=>"text-center"},
      :format=>"{0:MMM dd, yyyy}"
    }
    assert_equal column_format, column_format(:centered, :date)

    column_format = {
      :headerAttributes=>{:class=>""},
      :attributes=>{:class=>""},
      :format=>"{0:p1}"
    }
    assert_equal column_format, column_format(:numeric)
  end

  def test_details_campaign_message_analytics
    campaign_message = cm_campaign_messages(:campaign_message_1)
    campaign = campaign_message.campaign
    assert_equal 6, campaign_message_columns(campaign).count
    assert_equal 6, campaign_message_fields(campaign).count
    assert_equal 3, campaign_message.emails.count
    assert_equal ((2* 1.0) / 3), campaign_message.event_rate(CampaignManagement::EmailEventLog::Type::OPENED)
    assert_equal ((1* 1.0) / 3), campaign_message.event_rate(CampaignManagement::EmailEventLog::Type::CLICKED)
  end

  def test_get_disable_link
    campaign = cm_campaigns(:active_campaign_1)
    hash = get_disable_link(campaign)
    assert_equal disable_campaign_management_user_campaign_path(campaign), hash[:data][:url]
  end

  def test_get_clone_link
    campaign = cm_campaigns(:active_campaign_1)
    assert_equal clone_popup_campaign_management_user_campaign_path(campaign), get_clone_link(campaign)[:data][:url]
  end

  def test_get_start_link
    campaign = cm_campaigns(:active_campaign_1)
    assert_equal start_campaign_management_user_campaign_path(campaign), get_start_link(campaign)[:url]
  end

  def test_get_drop_down_array
    campaign = cm_campaigns(:active_campaign_1)
    self.stubs(:get_disable_link).returns({label: "something"}).once
    self.stubs(:get_delete_link).returns({label: "something else"}).times(2)
    array = get_drop_down_array(campaign)
    assert_equal 4, array.size
    assert_equal ["Add New Email", "<i class=\"fa fa-pencil fa-fw m-r-xs\"></i>Edit", "something", "something else"], array.collect{|h| h[:label]}

    campaign.stubs(:stopped?).returns(true)
    self.stubs(:get_clone_link).returns({label: "else"}).once
    array = get_drop_down_array(campaign)
    assert_equal 2, array.size
    assert_equal ["else", "something else"], array.collect{|h| h[:label]}
  end

  def test_get_details_path
    uc = CampaignManagement::UserCampaign.first
    assert_equal details_campaign_management_user_campaign_path(uc), get_details_path(uc)
    pc = CampaignManagement::ProgramInvitationCampaign.first
    assert_equal invite_users_path, get_details_path(pc)
    sc = CampaignManagement::SurveyCampaign.first
    assert_equal reminders_survey_path(sc.survey), get_details_path(sc)
  end

  def test_get_campaign_message_type
    uc = CampaignManagement::UserCampaign.first
    pc = CampaignManagement::ProgramInvitationCampaign.first
    sc = CampaignManagement::SurveyCampaign.first
    assert_equal CampaignManagement::UserCampaignMessage, get_campaign_message_type(uc)
    assert_equal CampaignManagement::ProgramInvitationCampaignMessage, get_campaign_message_type(pc)
    assert_equal CampaignManagement::SurveyCampaignMessage, get_campaign_message_type(sc)
  end

  def test_campaign_message_schedule_text_for_zero
    uc = CampaignManagement::UserCampaign.first
    pc = CampaignManagement::ProgramInvitationCampaign.first
    sc = CampaignManagement::SurveyCampaign.first
    assert_equal "feature.campaigns.content.sent_immediately".translate, campaign_message_schedule_text_for_zero(pc)
    assert_equal "feature.campaigns.content.schedule_text_same_day".translate, campaign_message_schedule_text_for_zero(uc)
    sc.stubs(:for_engagement_survey?).returns(true)
    assert_equal "feature.campaigns.content.schedule_text_same_day_for_survey_reminder".translate, campaign_message_schedule_text_for_zero(sc)
    sc.stubs(:for_engagement_survey?).returns(false)
    assert_equal "feature.campaigns.content.schedule_text_same_day_meeting_survey_reminder_email".translate(meeting: "meeting"), campaign_message_schedule_text_for_zero(sc)
  end

  def test_invalid_duration_message
    c = CampaignManagement::UserCampaign.first
    pc = CampaignManagement::ProgramInvitationCampaign.first
    assert_equal "feature.campaign_message.invalid_duration_v2".translate(min: CampaignManagement::UserCampaignMessage::CAMPAIGN_MESSAGE_DURATION_MIN_IN_DAYS), invalid_duration_message(c, CampaignManagement::UserCampaignMessage)
    assert_equal "feature.campaign_message.invalid_duration".translate(min: CampaignManagement::ProgramInvitationCampaignMessage::CAMPAIGN_MESSAGE_DURATION_MIN_IN_DAYS, max: CampaignManagement::ProgramInvitationCampaignMessage::CAMPAIGN_MESSAGE_DURATION_MAX_IN_DAYS), invalid_duration_message(pc, CampaignManagement::ProgramInvitationCampaignMessage)
  end

  def test_campaign_message_schedule_help_text
    uc = CampaignManagement::UserCampaign.first
    pc = CampaignManagement::ProgramInvitationCampaign.first
    sc = CampaignManagement::SurveyCampaign.first
    assert_equal "feature.campaigns.content.schedule_description_user_campaign_email_v1".translate, campaign_message_schedule_help_text(uc)
    assert_equal "feature.campaigns.content.schedule_description_invitation_email".translate, campaign_message_schedule_help_text(pc)
    assert_equal "feature.campaigns.content.schedule_description_meeting_survey_reminder_email".translate(meeting: 'meeting'), campaign_message_schedule_help_text(sc)
    sc.stubs(:for_engagement_survey?).returns(true)
    assert_equal "feature.campaigns.content.schedule_description_survey_reminder_email".translate, campaign_message_schedule_help_text(sc)
  end

  def test_get_campaign_survey_type
    assert_equal "", get_campaign_survey_type(CampaignManagement::UserCampaign.first)
    sc = CampaignManagement::SurveyCampaign.first
    sc.stubs(:survey).returns('survey')
    self.stubs(:get_survey_type_for_ga).with('survey').returns('something')
    assert_equal "something", get_campaign_survey_type(sc)
  end

  def test_campaigns_call_to_action
    html_content = to_html(campaigns_call_to_action("some text", "some_url", "some-class"))
    assert_select html_content, "table.mobile-button-container" do
      assert_select "table.responsive-table" do
        assert_select "a.some-class[href=some_url]", "some text →"
      end
    end
  end

  def test_get_campaign_email_subjects_with_zero_duration
    campaign = cm_campaigns(:active_campaign_1)
    email_subjects, email_count = get_campaign_email_subjects_with_zero_duration(campaign)
    assert_equal "\"Campaign Message - Subject1\"", email_subjects
    assert_equal 1, email_count
  end

  private

  def _meeting
    'meeting'
  end
end
