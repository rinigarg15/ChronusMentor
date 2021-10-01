require_relative './../../test_helper.rb'

class AdminViewsHelperTest < ActionView::TestCase
  include TranslationsService
  include KendoHelper
  include SurveysHelper

  def test_admin_view_section_title
    string = admin_view_section_title(1, "Enter Title")
    assert_match /Step 1: Enter Title/, string

    string = admin_view_section_title(1, "Enter Title", desc: "Hello World")
    set_response_text(string)

    assert_select "small", :text => "Hello World"
  end

  def test_profile_accordion_collapse
    prog_admin_view = programs(:albers).admin_views.default.find_by(default_view: AbstractView::DefaultType::ALL_USERS)
    profile_hash = {:questions => {:question_1 => {:operator => "", :value => ""}}, :score => {:operator => "", :value => ""}}
    assert_false profile_accordion_collapse?(prog_admin_view, profile_hash)

    profile_hash = {:questions => {:question_1 => {:operator => 1, :value => "Sample"}}, :score => {:operator => "", :value => ""}}
    assert profile_accordion_collapse?(prog_admin_view, profile_hash)

    profile_hash = {:questions => {:question_1 => {:operator => 1, :value => "Sample"}, :question_2 => {:operator => 1, :value => "Sample"}}, :score => {:operator => "", :value => ""}}
    assert profile_accordion_collapse?(prog_admin_view, profile_hash)

    profile_hash = {:questions => {:question_1 => {:operator => "", :value => ""}}, :score => {:operator => "", :value => ""}}
    assert_false profile_accordion_collapse?(prog_admin_view, profile_hash)

    profile_hash = {:questions => {:question_1 => {:operator => "", :value => ""}}, :score => {:operator => "12", :value => "hello"}}
    assert profile_accordion_collapse?(prog_admin_view, profile_hash)
  end

  def test_get_campaign_for_select2
    campaign = cm_campaigns(:active_campaign_1)
    campaign_id_hash = {campaign_id: campaign.id}
    assert_equal campaign_id_hash, get_campaign_for_select2(campaign)
    resource = create_resource
    campaign_id_hash = {}
    assert_equal campaign_id_hash, get_campaign_for_select2(resource)
    resource = Resource.new
    campaign_id_hash = {}
    assert_equal campaign_id_hash, get_campaign_for_select2(resource)
  end

  def test_timeline_accordion_collapse
    timeline_hash = {:timeline_questions => {:question_1 => {}}}
    assert_false timeline_accordion_collapse?(timeline_hash)

    timeline_hash = {:timeline_questions => {:question_1 => {:question => 1, :value => "Sample"}}}
    assert timeline_accordion_collapse?(timeline_hash)

    timeline_hash = {:timeline_questions => {:question_1 => {:question => 1, :value => "Sample"}, :question_2 => {:question => 1, :value => "Sample"}}}
    assert timeline_accordion_collapse?(timeline_hash)
  end

  def test_member_status_accordion_collapse
    assert_false member_status_accordion_collapse?({})

    member_status_hash = {state: {}}
    assert_false member_status_accordion_collapse?(member_status_hash)

    member_status_hash = {state: {"0" => 0, "1" => 1}}
    assert member_status_accordion_collapse?(member_status_hash)
  end

  def test_other_accordion_collapse
    other_hash = {}
    assert_false other_accordion_collapse?(other_hash)

    other_hash = {:tags => "sample"}
    assert other_accordion_collapse?(other_hash)
  end

  def test_connection_status_collapse
    admin_view = AdminView.first
    connection_status_hash = {:status => "", :draft_status => "", :availability => {:operator => "", :value => ""}}
    assert_false connection_status_collapse?(connection_status_hash, admin_view)

    connection_status_hash = {:status => "sample", :availability => {:operator => "", :value => ""}}
    assert connection_status_collapse?(connection_status_hash, admin_view)

    connection_status_hash = {:status => "", :availability => {:operator => "sample", :value => ""}}
    assert_false connection_status_collapse?(connection_status_hash, admin_view)

    connection_status_hash = {:status => "", :availability => {:operator => "", :value => "sample"}}
    assert_false connection_status_collapse?(connection_status_hash, admin_view)

    connection_status_hash = {:status => "", :availability => {:operator => "sample", :value => "sample"}}
    assert connection_status_collapse?(connection_status_hash, admin_view)

    connection_status_hash = {:status => "", :draft_status => "sample", :availability => {:operator => "", :value => ""}}
    assert connection_status_collapse?(connection_status_hash, admin_view)

    connection_status_hash = {:status => "", :draft_status => "", :availability => {:operator => "", :value => ""}, last_closed_connection: {}}
    assert_false connection_status_collapse?(connection_status_hash, admin_view)

    connection_status_hash = {:status => "", :draft_status => "", :availability => {:operator => "", :value => ""}, last_closed_connection: {type: AdminView::TimelineQuestions::Type::BEFORE}}
    assert connection_status_collapse?(connection_status_hash, admin_view)

    connection_status_hash = {:rating => ""}
    assert_false connection_status_collapse?(connection_status_hash, admin_view)

    connection_status_hash = {:rating => {:operator => ""}}
    assert_false connection_status_collapse?(connection_status_hash, admin_view)

    connection_status_hash = {:rating => {:operator => AdminViewsHelper::Rating::LESS_THAN}}
    assert connection_status_collapse?(connection_status_hash, admin_view)

    connection_status_hash = {:status => "", :availability => {:operator => "sample", :value => ""}, :mentoring_requests => {:mentees => "1", :mentors => ""}}
    assert connection_status_collapse?(connection_status_hash, admin_view)

    connection_status_hash = {:status => "", :availability => {:operator => "sample", :value => ""}, :mentoring_requests => {:mentees => "", :mentors => "1"}}
    assert connection_status_collapse?(connection_status_hash, admin_view)

    connection_status_hash = {:status => "", :availability => {:operator => "sample", :value => ""}, :mentoring_requests => {:mentees => "", :mentors => ""}}
    assert_false connection_status_collapse?(connection_status_hash, admin_view)

    connection_status_hash = {:status => "", :availability => {:operator => "sample", :value => ""}, :meeting_requests => {:mentees => "1", :mentors => ""}}
    assert connection_status_collapse?(connection_status_hash, admin_view)

    connection_status_hash = {:status => "", :availability => {:operator => "sample", :value => ""}, :meeting_requests => {:mentees => "", :mentors => ""}}
    assert_false connection_status_collapse?(connection_status_hash, admin_view)

    connection_status_hash = {:status => "", :availability => {:operator => "sample", :value => ""}, :meeting_requests => {:mentees => "", :mentors => "1"}}
    assert connection_status_collapse?(connection_status_hash, admin_view)

    connection_status_hash = {:status => "", :availability => {:operator => "sample", :value => ""}, :meetingconnection_status => ""}
    assert_false connection_status_collapse?(connection_status_hash, admin_view)

    connection_status_hash = {:status => "", :availability => {:operator => "sample", :value => ""}, :meetingconnection_status => "1"}
    assert connection_status_collapse?(connection_status_hash, admin_view)
  end

  def test_find_filter_params_for_survey_user_status
    filter_params_hash = {:survey=> {:user=>{:survey_id => "12", :users_status => "1"}}}
    filter_params = find_filter_params_for_survey_user_status(filter_params_hash)
    assert_equal_hash(filter_params, {:survey_id => "12", :users_status => "1"})

    filter_params_hash = {:survey=> {:user=>{:survey_id => "", :users_status => ""}}}
    filter_params = find_filter_params_for_survey_user_status(filter_params_hash)
    assert_equal_hash(filter_params, {:users_status => "", :survey_id => ""})
  end

  def test_admin_view_mandatory_filter_list
    assert_select_helper_function_block "select[class=\"form-control\"][id=\"mandatory_filter_html_id\"][name=\"admin_view[profile][mandatory_filter]\"][value=\"\"]", admin_view_mandatory_filter_list("admin_view[profile][mandatory_filter]", {class: "form-control", id: "mandatory_filter_html_id"}, {}) do
        assert_select "option[selected=\"selected\"][value=\"\"]", text: "Select..."
        assert_select "option[value=\"filled_all_mandatory_questions\"]", text: "Answered all mandatory questions"
        assert_select "option[value=\"not_filled_all_mandatory_questions\"]", text: "Not answered all mandatory questions"
        assert_select "option[value=\"filled_all_questions\"]", text: "Answered all questions"
        assert_select "option[value=\"not_filled_all_questions\"]", text: "Not answered all questions"
    end
    assert_select_helper_function_block "select[class=\"form-control\"][id=\"mandatory_filter_html_id\"][name=\"admin_view[profile][mandatory_filter]\"][value=\"not_filled_all_mandatory_questions\"]", admin_view_mandatory_filter_list("admin_view[profile][mandatory_filter]", {class: "form-control", id: "mandatory_filter_html_id"}, {profile: {mandatory_filter: AdminView::MandatoryFilterOptions::NOT_FILLED_ALL_MANDATORY_QUESTIONS}}) do
      assert_select "option[value=\"\"]", text: "Select..."
      assert_select "option[value=\"filled_all_mandatory_questions\"]", text: "Answered all mandatory questions"
      assert_select "option[selected=\"selected\"][value=\"not_filled_all_mandatory_questions\"]", text: "Not answered all mandatory questions"
      assert_select "option[value=\"filled_all_questions\"]", text:"Answered all questions"
      assert_select "option[value=\"not_filled_all_questions\"]", text: "Not answered all questions"
    end
  end

  def test_filter_params_for_survey_questions_present
    filter_params_hash = {:survey=> {:survey_questions=>{:questions_1 =>{:survey_id => "12", :question => "468", :operator => AdminViewsHelper::QuestionType::WITH_VALUE.to_s, :value => "d", :choice => ""}, :questions_2 => {:survey_id => "12", :question => "468", :operator => AdminViewsHelper::QuestionType::WITH_VALUE.to_s, :value => "e", :choice => ""}}}}
    assert_equal true, filter_params_for_survey_questions_present(filter_params_hash)

    filter_params_hash = {:survey=> {:survey_questions=>{}}}
    assert_equal false, filter_params_for_survey_questions_present(filter_params_hash)
  end

  def test_calculate_rows_size
    filter_params_hash = {:survey=> {:survey_questions=>{:questions_1 =>{:survey_id => "12", :question => "468", :operator => "3", :value => "d", :choice => ""}, :questions_2 => {:survey_id => "12", :question => "468", :operator => AdminViewsHelper::QuestionType::WITH_VALUE.to_s, :value => "e", :choice => ""}}}}
    question_size = calculate_rows_size(filter_params_hash)
    assert_equal question_size, 2

    filter_params_hash = {:survey=> {:survey_questions=>{:questions_1 =>{:survey_id => "12", :question => "468", :operator => AdminViewsHelper::QuestionType::WITH_VALUE.to_s, :value => "d", :choice => ""}}}}
    question_size = calculate_rows_size(filter_params_hash)

    filter_params_hash = {:survey=> {:survey_questions=>{}}}
    question_size = calculate_rows_size(filter_params_hash)
    assert_equal question_size, 1
  end

  def test_get_processed_filter_params
    surveys = programs(:albers).surveys
    filter_params =  {:survey => {:survey_questions =>{:questions_1 => {:survey_id =>surveys(:two).id, :question=>"answers#{common_questions(:q2_name).id}", :operator => AdminViewsHelper::QuestionType::WITH_VALUE.to_s, :value => "", :choice =>"communication"}, :questions_2 =>{ :survey_id =>surveys(:two).id, :question =>"answers#{common_questions(:q2_name).id}", :operator => AdminViewsHelper::QuestionType::NOT_WITH_VALUE.to_s, :value =>"", :choice =>""}, :questions_3 =>{:survey_id =>surveys(:two).id, :question =>"answers#{common_questions(:q2_from).id}", :operator => AdminViewsHelper::QuestionType::NOT_WITH_VALUE.to_s, :value =>"", :choice =>""}}}}
    processed_filter_params = get_processed_filter_params(filter_params, surveys)
    assert_equal filter_params, processed_filter_params

    filter_params =  {:survey => {:survey_questions =>{:questions_1 => {:survey_id =>"", :question=>"", :operator => AdminViewsHelper::QuestionType::WITH_VALUE.to_s, :value => "", :choice =>"communication"}, :questions_2 =>{ :survey_id =>surveys(:two).id, :question =>"answers#{common_questions(:q2_name).id}", :operator => AdminViewsHelper::QuestionType::NOT_WITH_VALUE.to_s, :value =>"", :choice =>""}, :questions_3 =>{:survey_id =>surveys(:two).id, :question =>"answers#{common_questions(:q2_from).id}", :operator => AdminViewsHelper::QuestionType::NOT_WITH_VALUE.to_s, :value =>"", :choice =>""}}}}
    processed_filter_params = get_processed_filter_params(filter_params, surveys)
    assert_equal processed_filter_params, {:survey => {:survey_questions =>{:questions_2 =>{ :survey_id =>surveys(:two).id, :question =>"answers#{common_questions(:q2_name).id}", :operator => AdminViewsHelper::QuestionType::NOT_WITH_VALUE.to_s, :value =>"", :choice =>""}, :questions_3 =>{:survey_id =>surveys(:two).id, :question =>"answers#{common_questions(:q2_from).id}", :operator => AdminViewsHelper::QuestionType::NOT_WITH_VALUE.to_s, :value =>"", :choice =>""}}}}

    filter_params =  {:survey => {:survey_questions =>{:questions_1 => {:survey_id =>"", :question=>"", :operator => AdminViewsHelper::QuestionType::WITH_VALUE.to_s, :value => "", :choice =>"communication"}, :questions_2 =>{ :survey_id =>"", :question =>"", :operator => AdminViewsHelper::QuestionType::NOT_WITH_VALUE.to_s, :value =>"", :choice =>""}}}}
    processed_filter_params = get_processed_filter_params(filter_params, surveys)
    assert_equal processed_filter_params, {:survey => {:survey_questions =>{}}}
  end

  def test_survey_questions_for_the_survey_filter
    surveys = programs(:albers).surveys
    filter_params_hash = {:survey_id => surveys(:two).id, :question => "468", :operator => AdminViewsHelper::QuestionType::WITH_VALUE.to_s, :value => "d"}
    survey_questions = survey_questions_for_the_survey_filter(surveys, filter_params_hash)
    assert_equal surveys(:two).get_questions_in_order_for_report_filters, survey_questions

    filter_params_hash = {:survey_id => "", :question => "468", :operator => "contains", :value => "d"}
    survey_questions = survey_questions_for_the_survey_filter(surveys, filter_params_hash)
    assert_equal [], survey_questions
  end

  def test_render_admin_view_info
    campaign = cm_campaigns(:active_campaign_1)
    program = Program.find(campaign.program_id)
    admin_view = AdminView.find_by(title: "All Users")
    view_info_hash = {id: admin_view.id, title: "All Users"}
    assert_equal view_info_hash, render_admin_view_info(campaign, program)
    resource = create_resource
    create_resource_publication(resource: resource, admin_view_id: admin_view.id)
    assert_equal view_info_hash, render_admin_view_info(resource, program)
  end

  def test_get_bulk_actions_box
    admin_view = AdminView.first
    action_box_output = get_bulk_actions_box(admin_view)
    assert_select_helper_function "a[id=\"cjs_send_message\"][class=\"\"][title=\"\"]", action_box_output, {text: "Send Message"} do
      assert_select "i.fa.fa-fw.fa-envelope-o.fa.fw.m-r-xs"
    end
    assert_select_helper_function "a[id=\"cjs_invite_to_program\"][class=\"\"][title=\"\"]", action_box_output, {text: "Invite to Program"} do
      assert_select "i.fa.fa-fw.fa-envelope.fa-fw.m-r-xs"
    end
    assert_select_helper_function "a[id=\"cjs_add_to_program\"][class=\"\"][title=\"\"]", action_box_output, {text: "Add to Program"} do
      assert_select "i.fa.fa-fw.fa-plus.fa-fw.m-r-xs"
    end
    assert_select_helper_function "li[class=\"divider\"]", action_box_output
    assert_select_helper_function "a[id=\"cjs_reactivate_member_membership\"][class=\"\"][title=\"\"]", action_box_output, {text: "Reactivate Membership"} do
      assert_select "i.fa.fa-fw.fa-check.fa-fw.m-r-xs"
    end
    assert_select_helper_function "a[id=\"cjs_suspend_member_membership\"][class=\"\"][title=\"\"]", action_box_output, {text: "Suspend Membership"} do
      assert_select "i.fa.fa-fw.fa-times.fa-fw.m-r-xs"
    end
    assert_select_helper_function "a[id=\"cjs_remove_member\"][class=\"\"][title=\"\"]", action_box_output, {text: "Remove Member"} do
      assert_select "i.fa.fa-fw.fa-trash.fa-fw.m-r-xs"
    end

    admin_view = programs(:albers).admin_views.first
    action_box_output = get_bulk_actions_box(admin_view, member_tagging_enabled: true)
    assert_select_helper_function "a[id=\"cjs_remove_tags\"][class=\"\"][title=\"\"]", action_box_output, {text: "Remove Tags"} do
      assert_select "i.fa.fa-fw.fa-minus-circle.fa-fw.m-r-xs"
    end

    admin_view = programs(:pbe).admin_views.first
    action_box_output = get_bulk_actions_box(admin_view)
    circle_name = admin_view.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term_downcase
    assert_select_helper_function "a[id=\"cjs_add_to_circle\"][class=\"\"][title=\"\"]", action_box_output, {text: "Add to #{circle_name}"} do
      assert_select "i.fa.fa-fw.fa-plus.fa-fw.m-r-xs"
    end

    action_box_output = get_bulk_actions_box(AdminView.first, member: members(:ram))
    assert_select_helper_function "a[id=\"cjs_send_message\"][class=\"\"][title=\"\"]", action_box_output, {text: "Send Message", count: 0} do
      assert_select "i.fa.fa-fw.fa-envelope-o.fa.fw.m-r-xs"
    end
    assert_select_helper_function "a[id=\"cjs_invite_to_program\"][class=\"\"][title=\"\"]", action_box_output, {text: "Invite to Program"} do
      assert_select "i.fa.fa-fw.fa-envelope.fa-fw.m-r-xs"
    end
    assert_select_helper_function "a[id=\"cjs_add_to_program\"][class=\"\"][title=\"\"]", action_box_output, {text: "Add to Program"} do
      assert_select "i.fa.fa-fw.fa-plus.fa-fw.m-r-xs"
    end
    assert_select_helper_function "li[class=\"divider\"]", action_box_output, count: 0
    assert_select_helper_function "a[id=\"cjs_reactivate_member_membership\"][class=\"\"][title=\"\"]", action_box_output, {text: "Reactivate Membership", count: 0} do
      assert_select "i.fa.fa-fw.fa-check.fa-fw.m-r-xs"
    end
    assert_select_helper_function "a[id=\"cjs_suspend_member_membership\"][class=\"\"][title=\"\"]", action_box_output, {text: "Suspend Membership", count: 0} do
      assert_select "i.fa.fa-fw.fa-times.fa-fw.m-r-xs"
    end
    assert_select_helper_function "a[id=\"cjs_remove_member\"][class=\"\"][title=\"\"]", action_box_output, {text: "Remove Member", count: 0} do
      assert_select "i.fa.fa-fw.fa-trash.fa-fw.m-r-xs"
    end
  end

  def test_timeline_question_options
    assert_equal_unordered [
        ["Select...", ""],
        ["Join date", 2, {:class=>"cjs_additional_text_box"}],
        ["Last login date", 1, {:class=>"cjs_additional_text_box cjs_custom_text_picker"}],
        ["T&C accepted date", 3, {:class=>"cjs_additional_text_box cjs_custom_text_picker"}],
        ["Last deactivated date", 5, { class: "cjs_additional_text_box cjs_custom_text_picker" }]
      ], timeline_question_options
  end

  def test_timeline_type_options
    assert_equal_unordered [["Select...", ""], ["Never", 1], ["Before", 2], ["Older than", 3],
      ["After", 4], ["Date Range", 5], ["In last", 6]], timeline_type_options
  end

  def test_get_back_link_label_no_source_info
    source_info = nil
    assert_equal "Views", get_back_link_label(source_info)
  end

  def test_get_back_link_label_for_bulk_match
    source_info = {controller: "bulk_matches"}
    assert_equal "Bulk Match", get_back_link_label(source_info)
  end

  def test_admin_view_page_actions
    program = programs(:albers)
    self.expects(:current_program).at_least(0).returns(programs(:albers))

    all_users_view = program.admin_views.where(default_view: AbstractView::DefaultType::ALL_USERS).first
    assert_false all_users_view.editable?
    actions = admin_view_page_actions(all_users_view)
    assert_equal 1, actions.size
    assert_equal_hash( { label: "Update View", url: edit_admin_view_path(all_users_view) }, actions[0])

    all_users_view.stubs(:editable?).returns(true)
    actions = admin_view_page_actions(all_users_view)
    assert_equal 2, actions.size
    assert_equal_hash( { label: "Update View", url: edit_admin_view_path(all_users_view) }, actions[0])
    assert_equal "Delete View", actions[1][:label]

    admin_view = AbstractView.where(default_view: AbstractView::DefaultType::NEVER_CONNECTED_MENTEES).first
    assert admin_view.editable?
    assert admin_view.default_view_for_match_report?
    actions = admin_view_page_actions(admin_view)
    assert_equal 1, actions.size
  end

  def test_get_update_admin_view_confirm_text
    program = programs(:albers)

    available_mentors_view = program.admin_views.where(default_view: AbstractView::DefaultType::AVAILABLE_MENTORS).first
    assert_equal "This view is pinned to <a href=\"/match_reports\">Admin Match Report</a>. Updating this view will update the Match Report. Alternatively, you can <a href=\"/admin_views/new\">create a new view</a>. Do you want to continue?", get_update_admin_view_confirm_text(available_mentors_view)

    all_mentors_view = program.admin_views.where(default_view: AbstractView::DefaultType::MENTORS).first
    assert program.program_events.where(admin_view_id: all_mentors_view.id).blank?
    assert all_mentors_view.metrics.blank?
    assert CampaignManagement::CampaignProcessor.instance.campaign_using_admin_view(all_mentors_view).blank?
    assert_equal "", get_update_admin_view_confirm_text(all_mentors_view)

    MatchReportAdminView.where(admin_view: all_mentors_view).destroy_all
    assert_equal "", get_update_admin_view_confirm_text(all_mentors_view)

    all_users_view = program.admin_views.where(default_view: AbstractView::DefaultType::ALL_USERS).first
    birthday_event = program_events(:birthday_party)
    ror_event = program_events(:ror_meetup)
    events = [birthday_event, ror_event]
    campaigns = [cm_campaigns(:active_campaign_1), cm_campaigns(:active_campaign_2), cm_campaigns(:disabled_campaign_1), cm_campaigns(:disabled_campaign_2), cm_campaigns(:disabled_campaign_3), cm_campaigns(:disabled_campaign_4)]
    content = get_update_admin_view_confirm_text(all_users_view)
    assert_match /#{link_to("Admin Dashboard", management_report_path)}/, content
    assert_match /Updating this view will update the dashboard and campaign target audience./, content
    assert_match /And, you have to update the event guest list in respective event page separately incase you want the same changes on event guest list as well./, content
    assert_match /#{link_to("create a new view", new_admin_view_path)}/, content
    events.each { |event| assert_match /#{link_to(event.title, program_event_path(event))}/, content }
    campaigns.each { |campaign| assert_match /#{link_to(campaign.title, details_campaign_management_user_campaign_path(campaign))}/, content }
    assert_match /Do you want to continue\?/, content

    birthday_event.update_column(:admin_view_id, all_mentors_view.id)
    ror_event.update_column(:admin_view_id, all_mentors_view.id)
    ProgramEvent.stubs(:upcoming).returns(ProgramEvent.where(id: birthday_event.id))
    content = get_update_admin_view_confirm_text(all_mentors_view)
    assert_equal "This view is pinned to #{link_to(birthday_event.title, program_event_path(birthday_event))} event. And, you have to update the event guest list in respective event page separately incase you want the same changes on event guest list as well. Alternatively, you can #{link_to('create a new view', new_admin_view_path)}. Do you want to continue?", content
  end

  def test_get_delete_admin_view_action_hash
    program = programs(:albers)
    self.expects(:current_program).at_least(0).returns(programs(:albers))

    available_mentors_view = program.admin_views.where(default_view: AbstractView::DefaultType::AVAILABLE_MENTORS).first
    action_hash = get_delete_admin_view_action_hash(available_mentors_view)
    assert_equal "<div class='m-b'>This view is pinned to the <a href=\"/match_reports\">Match Report</a>. Deleting this view will update the match report.</div>Are you sure you want to delete this view ?", action_hash[:data][:confirm]
    
    all_mentors_view = program.admin_views.where(default_view: AbstractView::DefaultType::MENTORS).first
    action_hash = get_delete_admin_view_action_hash(all_mentors_view)
    assert_equal "Delete View", action_hash[:label]
    assert_equal "/admin_views/#{all_mentors_view.id}", action_hash[:url]
    assert_equal :delete, action_hash[:method]
    assert_equal "<div class='m-b'>The bulk match has been created for this view. This will dis-associate all mentoring connections created in the bulk match. The mentoring connections will still remain outside of bulk match.</div>Are you sure you want to delete this view ?", action_hash[:data][:confirm]
    assert_nil action_hash[:js]

    all_mentors_view.stubs(:is_program_view?).returns(false)
    action_hash = get_delete_admin_view_action_hash(all_mentors_view)
    assert_equal "Delete View", action_hash[:label]
    assert_equal "/admin_views/#{all_mentors_view.id}", action_hash[:url]
    assert_equal :delete, action_hash[:method]
    assert_equal "Are you sure you want to delete this view ?", action_hash[:data][:confirm]
    assert_nil action_hash[:js]

    MatchReportAdminView.where(admin_view: all_mentors_view).destroy_all
    action_hash = get_delete_admin_view_action_hash(all_mentors_view)
    assert_equal "Are you sure you want to delete this view ?", action_hash[:data][:confirm]

    all_users_view = program.admin_views.where(default_view: AbstractView::DefaultType::ALL_USERS).first
    campaigns = [cm_campaigns(:active_campaign_1), cm_campaigns(:active_campaign_2), cm_campaigns(:disabled_campaign_1), cm_campaigns(:disabled_campaign_2), cm_campaigns(:disabled_campaign_3), cm_campaigns(:disabled_campaign_4)]
    action_hash = get_delete_admin_view_action_hash(all_users_view)
    assert_equal "Delete View", action_hash[:label]
    assert_match /alert\(/, action_hash[:js]
    assert_match /The delete operation could not be completed as the campaigns/, action_hash[:js]
    campaigns.each { |campaign| assert_match /#{campaign.title}/, action_hash[:js] }
    assert_match /are dependent on this view./, action_hash[:js]
    assert_nil action_hash[:url] || action_hash[:method] || action_hash[:data]
  end

  def test_admin_view_path_with_source
    bulk_match = bulk_matches(:bulk_match_1)
    admin_view = programs(:albers).admin_views.first

    send_params = { controller: "bulk_matches", action: "new" }
    stub_request_parameters(send_params)
    assert_equal new_admin_view_path(source_info: send_params), admin_view_path_with_source(:new)
    assert_equal admin_view_path(admin_view, source_info: send_params), admin_view_path_with_source(:show, admin_view: admin_view)
    assert_equal edit_admin_view_path(admin_view, source_info: send_params), admin_view_path_with_source(:edit, admin_view: admin_view)
    
    send_params = { controller: "bulk_matches", action: "new", section: "section" }
    stub_request_parameters(send_params)
    assert_equal new_admin_view_path(source_info: send_params), admin_view_path_with_source(:new)
    assert_equal admin_view_path(admin_view, source_info: send_params), admin_view_path_with_source(:show, admin_view: admin_view)
    assert_equal edit_admin_view_path(admin_view, source_info: send_params), admin_view_path_with_source(:edit, admin_view: admin_view)

    @set_source_info = {controller: "bulk_matches", action: "edit", id: bulk_match.id}
    assert_equal new_admin_view_path(source_info: @set_source_info), admin_view_path_with_source(:new)
    assert_equal admin_view_path(admin_view, source_info: @set_source_info), admin_view_path_with_source(:show, admin_view: admin_view)
    assert_equal edit_admin_view_path(admin_view, source_info: @set_source_info), admin_view_path_with_source(:edit, admin_view: admin_view)
  end

  def test_format_publication_answer
    pub_fields = ["Title"]
    assert_dom_equal(%Q{Title}, format_publication_answer(pub_fields))

    pub_fields = ["Title", "Publisher"]
    assert_dom_equal(%Q{Title, Publisher}, format_publication_answer(pub_fields))

    pub_fields = ["Title", "Publisher", "August 21, 2013"]
    assert_dom_equal(%Q{Title, Publisher, August 21, 2013}, format_publication_answer(pub_fields))

    pub_fields = ["Title", "Publisher", "August 21, 2013", "http://publisher.url"]
    assert_dom_equal(%Q{<a href=\"http://publisher.url\" target=\"_blank\">Title</a>, Publisher, August 21, 2013}, format_publication_answer(pub_fields))

    pub_fields = ["Title", "Publisher", "August 21, 2013", "http://publisher.url", "Authors", "Description"]
    assert_dom_equal(%Q{<a href=\"http://publisher.url\" target=\"_blank\">Title</a>, Publisher, August 21, 2013, Authors}, format_publication_answer(pub_fields))
  end

  def test_format_manager_answer
    manager_fields = ["First name", "Last name", "email"]
    assert_dom_equal(%Q{First name Last name (<a href=\"mailto:email\">email</a>)}, format_manager_answer(manager_fields))
  end

  def test_populate_row
    @current_program = programs(:albers)
    admin_view = @current_program.admin_views.first
    admin_view_columns = admin_view.admin_view_columns
    user = users(:f_mentor)
    user_id = user.id
    user_name = user.name(name_only: true)

    self.expects(:working_on_behalf?).once.returns(false)
    row_value = populate_row(user, admin_view_columns, {}, {}, is_program_view: true)
    assert_equal (admin_view_columns.size + 2), row_value.size
    assert_select_helper_function "input.cjs_admin_view_record#ct_admin_view_checkbox_#{user_id}", row_value["check_box"], type: "checkbox", value: "#{user_id}"
    assert_select_helper_function "label.sr-only", row_value["check_box"], for:"ct_admin_view_checkbox_#{user_id}", text: "Select #{user_name}"
    assert_select_helper_function_block "div", row_value["actions"] do
      assert_select "a[href=?]", work_on_behalf_user_path(user) do
        assert_select "i.fa-user-secret"
        assert_select "span.sr-only", text: "Click to work on behalf of #{user_name}."
      end
      assert_select "a[href=?]", edit_member_path(user) do
        assert_select "i.fa-pencil"
        assert_select "span.sr-only", text: "Edit #{user_name}'s profile"
      end
    end

    profile_answers_hash = Member.prepare_answer_hash([user])
    admin_view.admin_view_columns.destroy_all
    admin_view.admin_view_columns.create!(column_key: "first_name")
    admin_view.admin_view_columns.create!(column_key: "email")
    admin_view.admin_view_columns.create!(column_key: "state")
    row_value = populate_row(members(:f_mentor), admin_view_columns, profile_answers_hash, { organization: programs(:org_primary) } )
    assert_equal 4, row_value.size
    assert_not_nil row_value["check_box"]
    assert_nil row_value["actions"]
    assert_match "Good unique", row_value["first_name"]
    assert_match "robert@example.com", row_value["email"]
    assert_match "Active", row_value["state"]
  end

  def test_generate_roles_list
    @current_organization = programs(:org_primary)
    program = programs(:albers)
    filter_params = {:roles_and_status => {role_filter_1: {type: :include, :roles =>["user"]}}}
    content_1 = generate_roles_list("admin_view[roles_and_status][role_filter_1][roles]", program)
    assert_match /<select name=\"admin_view\[roles_and_status\]\[role_filter_1\]\[roles\]\[\]\" id=\"cjs_new_view_filter_roles_0\" class=\"form-control new_view_filter_roles no-padding no-border\" multiple=\"multiple\" disabled=\"disabled\">/, content_1
    assert_match /value=\"admin\">Administrator/, content_1
    assert_match /value=\"mentor\">Mentor/, content_1
    assert_match /value=\"student\">Student/, content_1
    assert_match /value=\"user\">User/, content_1
  end

  def test_options_for_connection_status_filter_category_select
    assert_equal [["Select...", ""], ["Never connected", AdminView::ConnectionStatusCategoryKey::NEVER_CONNECTED], ["Currently connected", AdminView::ConnectionStatusCategoryKey::CURRENTLY_CONNECTED], ["Currently not connected", AdminView::ConnectionStatusCategoryKey::CURRENTLY_UNCONNECTED], ["Currently connected for first time", AdminView::ConnectionStatusCategoryKey::FIRST_TIME_CONNECTED], ["Connected (currently or in the past)", AdminView::ConnectionStatusCategoryKey::CONNECTED_CURRENTLY_OR_PAST], ["Advanced filters", AdminView::ConnectionStatusCategoryKey::ADVANCED_FILTERS]], options_for_connection_status_filter_category_select
  end

  def test_options_for_connection_status_filter_type_select
    program = programs(:albers)
    assert_equal [["Select...", ""], ["Number of ongoing mentoring connections", AdminView::ConnectionStatusTypeKey::ONGOING], ["Number of past mentoring connections", AdminView::ConnectionStatusTypeKey::CLOSED], ["Number of ongoing or past mentoring connections", AdminView::ConnectionStatusTypeKey::ONGOING_OR_CLOSED], ["Number of drafted mentoring connections", AdminView::ConnectionStatusTypeKey::DRAFTED]], options_for_connection_status_filter_type_select(program: program)
  end

  def test_options_for_connection_status_filter_operator_select
    assert_equal [["Select...", ""], ["Less than", AdminView::ConnectionStatusOperatorKey::LESS_THAN], ["Equals to", AdminView::ConnectionStatusOperatorKey::EQUALS_TO], ["Greater than", AdminView::ConnectionStatusOperatorKey::GREATER_THAN]], options_for_connection_status_filter_operator_select
  end

  def test_generate_connection_status_filter_object_select
    program = programs(:albers)
    select_box_base_name = "admin_view[connection_status][status_filters][status_filter_0]"
    content = generate_connection_status_filter_object_select(select_box_base_name, AdminView::ConnectionStatusFilterObjectKey::CATEGORY)
    assert_select_helper_function "label.sr-only", content, for: "cjs-connection-status-filter-category-0", text: "Select  status filter category"
    assert_select_helper_function "select#cjs-connection-status-filter-category-0.form-control.cjs-connection-status-filter-category[name=\"admin_view[connection_status][status_filters][status_filter_0][category]\"]", content, disabled: "disabled"
    content = generate_connection_status_filter_object_select(select_box_base_name, AdminView::ConnectionStatusFilterObjectKey::TYPE, program: program)
    assert_select_helper_function "label.sr-only", content, for: "cjs-connection-status-filter-type-0", text: "Select  status filter type"
    assert_select_helper_function "select#cjs-connection-status-filter-type-0.form-control.cjs-connection-status-filter-type[name=\"admin_view[connection_status][status_filters][status_filter_0][type]\"]", content, disabled: "disabled"
    content = generate_connection_status_filter_object_select(select_box_base_name, AdminView::ConnectionStatusFilterObjectKey::OPERATOR)
    assert_select_helper_function "label.sr-only", content, for: "cjs-connection-status-filter-operator-0", text: "Select  status filter operator"
    assert_select_helper_function "select#cjs-connection-status-filter-operator-0.form-control.cjs-connection-status-filter-operator[name=\"admin_view[connection_status][status_filters][status_filter_0][operator]\"]", content, disabled: "disabled"
  end

  def test_generate_connection_status_filter_count_value_text_box
    select_box_base_name = "admin_view[connection_status][status_filters][status_filter_0]"
    content = generate_connection_status_filter_count_value_text_box(select_box_base_name, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE)
    assert_select_helper_function "label.sr-only", content, for: "cjs-connection-status-filter-countvalue-0", text: "Enter count value"
    assert_select_helper_function "input#cjs-connection-status-filter-countvalue-0.form-control.cjs-connection-status-filter-countvalue.cjs-connection-status-category-dependent-visibility[name=\"admin_view[connection_status][status_filters][status_filter_0][countvalue]\"]", content, disabled: "disabled"
  end

  def test_generate_mentoring_mode_list
    current_program = programs(:albers)
    filter_params = {:connection_status => {:mentoring_model_preference => "2"}}

    content_1 = generate_mentoring_mode_list("admin_view[connection_status][mentoring_model_preference]", current_program, {})
    content_2 = generate_mentoring_mode_list("admin_view[connection_status][mentoring_model_preference]", current_program, filter_params)

    assert_match /<select name=\"admin_view\[connection_status\]\[mentoring_model_preference\]\" id=\"new_view_engagement_models\" class=\"form-control\">/, content_1
    assert_match /<option selected=\"selected\" value=\"\">Select.../, content_1
    assert_match /<option value=\"1\">Ongoing Mentoring/, content_1
    assert_match /<option value=\"2\">One-time Mentoring/, content_1
    assert_match /<option value=\"3\">Ongoing and One-time Mentoring/, content_1

    assert_match /<select name=\"admin_view\[connection_status\]\[mentoring_model_preference\]\" id=\"new_view_engagement_models\" class=\"form-control\">/, content_2
    assert_match /<option value=\"\">Select.../, content_2
    assert_match /<option value=\"1\">Ongoing Mentoring/, content_2
    assert_match /<option selected=\"selected\" value=\"2\">One-time Mentoring/, content_2
    assert_match /<option value=\"3\">Ongoing and One-time Mentoring/, content_2
  end

  def test_generate_mentoring_mode_list_options
    current_program = programs(:albers)
    generated_content = generate_mentoring_mode_list_options(current_program)
    assert_match "Ongoing Mentoring", generated_content[1][0]
    assert_match "One-time Mentoring", generated_content[2][0]
    assert_match "Ongoing and One-time Mentoring", generated_content[3][0]
    assert_equal User::MentoringMode::ONGOING, generated_content[1][1].to_i
    assert_equal User::MentoringMode::ONE_TIME, generated_content[2][1].to_i
    assert_equal User::MentoringMode::ONE_TIME_AND_ONGOING, generated_content[3][1].to_i
  end

  def test_get_user_roles_for_add_to_program
    program = programs(:albers)
    program.roles.find_by(name: RoleConstants::STUDENT_NAME).customized_term.update_attributes!(:term => "Super Student")
    html_content = to_html(get_user_roles_for_add_to_program(program))
    assert_select html_content, "div.cjs_roles_list" do
      assert_select "label", :count => 1, :text => "Super Student" do
        assert_select "input[type=checkbox][value=student]", :count => 1
      end
      assert_select "input[type=checkbox][value=mentor]", :count => 1
      assert_select "input[type=checkbox][value=user]", :count => 1
      assert_no_select "input[type=checkbox][value=admin]"
    end
  end

  def test_connection_closed_type_options
    assert_equal_unordered [["Select...", ""], ["Before", 2, {"data-obj_name"=>"cjs_last_connection_date"}], ["After", 4, {"data-obj_name"=>"cjs_last_connection_date"}], ["Date Range", 5, {"data-obj_name"=>"cjs_last_connection_date_range"}], ["Older than", 3, {"data-obj_name"=>"cjs_last_connection_days"}]], connection_closed_type_options
  end

  def test_collect_admin_views_hash
    program = programs(:albers)
    admin_views = program.admin_views
    collection = collect_admin_views_hash(admin_views)
    all_users_view = admin_views.find_by(default_view: AbstractView::DefaultType::ALL_USERS)
    available_mentors = admin_views.find_by(default_view: AbstractView::DefaultType::AVAILABLE_MENTORS)

    assert_equal_hash( { id: all_users_view.id, icon: "fa fa-star", title: "All Users" }, collection.first)
    assert_equal_hash( { id: available_mentors.id, icon: "fa fa-star-o", title: "Available Mentors" }, collection.last)
  end

  def test_generate_last_connection_on_filter
    content = set_response_text(generate_last_connection_on_filter({}))
    assert_select "div.cjs_last_connection_enclosure" do
      assert_select "label", text: "Select timeline operator", class: "hide"
      assert_select "label", text: "Select number of days for timeline filter", class: "hide"
      assert_select "label", text: "Select timeline date", class: "hide"
      assert_select "label", text: "Select timeline date range", class: "hide"
      assert_select "select#cjs_last_connection_type", name: "admin_view[connection_status][last_closed_connection][type]" do
        assert_select "option", text: "Select..."
        assert_select "option", text: "Before"
        assert_select "option", text: "Older than"
        assert_select "option", text: "After"
        assert_select "option", text: "Date Range"
      end
      assert_select "input", name: "admin_view[connection_status][last_closed_connection][days]", id: "cjs_last_connection_days", class: "hide"
      assert_select "input.cjs_timeline_date_picker", name: "admin_view[connection_status][last_closed_connection][date]", id: "cjs_last_connection_date", class: "hide"
      assert_select "input.cjs_timeline_date_range_picker", name: "admin_view[connection_status][last_closed_connection][date_range]", id: "cjs_last_connection_date_range", class: "hide"
      assert_select "span#cjs_last_connection_days_label", text: "days", class: "hide"
    end

    content = set_response_text(generate_last_connection_on_filter({connection_status: {last_closed_connection: {type: AdminView::TimelineQuestions::Type::BEFORE_X_DAYS, days: 12, date: "not-needed 1", date_range: "not-needed 2"}}}))
    assert_select "div.cjs_last_connection_enclosure" do
      assert_select "label", text: "Select timeline operator", class: "hide"
      assert_select "label", text: "Select number of days for timeline filter", class: "hide"
      assert_select "label", text: "Select timeline date", class: "hide"
      assert_select "label", text: "Select timeline date range", class: "hide"
      assert_select "select#cjs_last_connection_type", name: "admin_view[connection_status][last_closed_connection][type]" do
        assert_select "option", text: "Select..."
        assert_select "option", text: "Before"
        assert_select "option", text: "Older than", selected: 'selected'
        assert_select "option", text: "After"
        assert_select "option", text: "Date Range"
      end
      assert_select "input", name: "admin_view[connection_status][last_closed_connection][days]", id: "cjs_last_connection_days", value: "12"
      assert_select "span#cjs_last_connection_days_label", text: "days"
      assert_select "input.cjs_timeline_date_picker", name: "admin_view[connection_status][last_closed_connection][date]", id: "cjs_last_connection_date", class: "hide", value: ""
      assert_select "input.cjs_timeline_date_range_picker", name: "admin_view[connection_status][last_closed_connection][date_range]", id: "cjs_last_connection_date_range", class: "hide", value: ""
    end

    content = set_response_text(generate_last_connection_on_filter({connection_status: {last_closed_connection: {type: AdminView::TimelineQuestions::Type::BEFORE, days: 12, date: "not-needed 1", date_range: "not-needed 2"}}}))
    assert_select "div.cjs_last_connection_enclosure" do
      assert_select "label", text: "Select timeline operator", class: "hide"
      assert_select "label", text: "Select number of days for timeline filter", class: "hide"
      assert_select "label", text: "Select timeline date", class: "hide"
      assert_select "label", text: "Select timeline date range", class: "hide"
      assert_select "select#cjs_last_connection_type", name: "admin_view[connection_status][last_closed_connection][type]" do
        assert_select "option", text: "Select..."
        assert_select "option", text: "Before"
        assert_select "option", text: "Older than", selected: 'selected'
        assert_select "option", text: "After"
        assert_select "option", text: "Date Range"
      end
      assert_select "input", name: "admin_view[connection_status][last_closed_connection][days]", id: "cjs_last_connection_days", class: "hide", value: ""
      assert_select "span#cjs_last_connection_days_label", text: "days", class: "hide"
      assert_select "input.cjs_timeline_date_picker", name: "admin_view[connection_status][last_closed_connection][date]", id: "cjs_last_connection_date", value: "not-needed 1"
      assert_select "input.cjs_timeline_date_range_picker", name: "admin_view[connection_status][last_closed_connection][date_range]", id: "cjs_last_connection_date_range", class: "hide", value: ""
    end

    content = set_response_text(generate_last_connection_on_filter({connection_status: {last_closed_connection: {type: AdminView::TimelineQuestions::Type::DATE_RANGE, days: 12, date: "not-needed 1", date_range: "01/01/2002#{DATE_RANGE_SEPARATOR}01/01/2003"}}}))
    assert_select "div.cjs_last_connection_enclosure" do
      assert_select "label", text: "Select timeline operator", class: "hide"
      assert_select "label", text: "Select number of days for timeline filter", class: "hide"
      assert_select "label", text: "Select timeline date", class: "hide"
      assert_select "label", text: "Select timeline date range", class: "hide"
      assert_select "select#cjs_last_connection_type", name: "admin_view[connection_status][last_closed_connection][type]" do
        assert_select "option", text: "Select..."
        assert_select "option", text: "Before"
        assert_select "option", text: "Older than", selected: 'selected'
        assert_select "option", text: "After"
        assert_select "option", text: "Date Range"
      end
      assert_select "input", name: "admin_view[connection_status][last_closed_connection][days]", id: "cjs_last_connection_days", class: "hide", value: ""
      assert_select "span#cjs_last_connection_days_label", text: "days", class: "hide"
      assert_select "input.cjs_timeline_date_picker", name: "admin_view[connection_status][last_closed_connection][date]", id: "cjs_last_connection_date",class: "hide", value: "not-needed 1"
      assert_select "input.cjs_timeline_date_range_picker", name: "admin_view[connection_status][last_closed_connection][date_range]", id: "cjs_last_connection_date_range", value: "not-needed 2"
    end
  end

  def test_rating_options_list
    list1 = rating_options_list('name', {:test => 'test', :value => '1'}, nil)
    list2 = rating_options_list('name', {:test => 'test', :value => '1'}, {})
    list3 = rating_options_list('name', {:test => 'test', :value => '1'}, {:connection_status => {}})
    list4 = rating_options_list('name', {:test => 'test', :value => '1'}, {:connection_status => { :rating => {}}})
    list5 = rating_options_list('name', {:test => 'test', :value => '1'}, {:connection_status => { :rating => {:operator => "greater_than"}}})
    expected_result = "<select name=\"name\" id=\"new_view_filter_mentor_rating\" test=\"test\" value=\"\"><option selected=\"selected\" value=\"\">Select...</option>\n<option class=\"cjs_show_less_than_box\" value=\"less_than\">Less than</option>\n<option class=\"cjs_show_greater_than_box\" value=\"greater_than\">Greater than</option>\n<option class=\"cjs_equal_to_box\" value=\"equal_to\">Equal to</option>\n<option value=\"not_rated\">Not Rated yet</option></select>"
    assert_equal expected_result, list1
    assert_equal expected_result, list2
    assert_equal expected_result, list3
    assert_equal expected_result, list4
    assert_equal "<select name=\"name\" id=\"new_view_filter_mentor_rating\" test=\"test\" value=\"greater_than\"><option value=\"\">Select...</option>\n<option class=\"cjs_show_less_than_box\" value=\"less_than\">Less than</option>\n<option class=\"cjs_show_greater_than_box\" selected=\"selected\" value=\"greater_than\">Greater than</option>\n<option class=\"cjs_equal_to_box\" value=\"equal_to\">Equal to</option>\n<option value=\"not_rated\">Not Rated yet</option></select>", list5
  end

  def test_admin_view_rating_value_dropdown_for_less_than_type
    list1 = admin_view_rating_value_dropdown('name', {:test => 'test', :value => '1'}, nil, "less_than")
    list2 = admin_view_rating_value_dropdown('name', {:test => 'test', :value => '1'}, {}, "less_than")
    list3 = admin_view_rating_value_dropdown('name', {:test => 'test', :value => '1'}, {:connection_status => {}}, "less_than")
    list4 = admin_view_rating_value_dropdown('name', {:test => 'test', :value => '1'}, {:connection_status => { :rating => {}}}, "less_than")
    list5 = admin_view_rating_value_dropdown('name', {:test => 'test', :value => '1'}, {:connection_status => { :rating => {:less_than => 2}}}, "less_than")

    expected_result = "<select name=\"name\" id=\"admin_view_connection_status_mentor_#{AdminViewsHelper::Rating::LESS_THAN}_rating_value\" test=\"test\" value=\"\" aria-label=\" Rating Value\"><option value=\"1\">1</option>\n<option value=\"2\">2</option>\n<option value=\"3\">3</option>\n<option value=\"4\">4</option>\n<option value=\"5\">5</option></select>"
    assert_equal expected_result, list1
    assert_equal expected_result, list2
    assert_equal expected_result, list3
    assert_equal expected_result, list4
    assert_equal "<select name=\"name\" id=\"admin_view_connection_status_mentor_#{AdminViewsHelper::Rating::LESS_THAN}_rating_value\" test=\"test\" value=\"2\" aria-label=\" Rating Value\"><option value=\"1\">1</option>\n<option selected=\"selected\" value=\"2\">2</option>\n<option value=\"3\">3</option>\n<option value=\"4\">4</option>\n<option value=\"5\">5</option></select>", list5
  end

  def test_admin_view_rating_value_dropdown_for_greater_than_type
    list1 = admin_view_rating_value_dropdown('name', {:test => 'test', :value => '1'}, nil, "greater_than")
    list2 = admin_view_rating_value_dropdown('name', {:test => 'test', :value => '1'}, {}, "greater_than")
    list3 = admin_view_rating_value_dropdown('name', {:test => 'test', :value => '1'}, {:connection_status => {}}, "greater_than")
    list4 = admin_view_rating_value_dropdown('name', {:test => 'test', :value => '1'}, {:connection_status => { :rating => {}}}, "greater_than")
    list5 = admin_view_rating_value_dropdown('name', {:test => 'test', :value => '1'}, {:connection_status => { :rating => {:greater_than => 2}}}, "greater_than")

    expected_result = "<select name=\"name\" id=\"admin_view_connection_status_mentor_#{AdminViewsHelper::Rating::GREATER_THAN}_rating_value\" test=\"test\" value=\"\" aria-label=\" Rating Value\"><option value=\"0\">0</option>\n<option value=\"1\">1</option>\n<option value=\"2\">2</option>\n<option value=\"3\">3</option>\n<option value=\"4\">4</option></select>"
    assert_equal expected_result, list1
    assert_equal expected_result, list2
    assert_equal expected_result, list3
    assert_equal expected_result, list4
    assert_equal "<select name=\"name\" id=\"admin_view_connection_status_mentor_#{AdminViewsHelper::Rating::GREATER_THAN}_rating_value\" test=\"test\" value=\"2\" aria-label=\" Rating Value\"><option value=\"0\">0</option>\n<option value=\"1\">1</option>\n<option selected=\"selected\" value=\"2\">2</option>\n<option value=\"3\">3</option>\n<option value=\"4\">4</option></select>", list5
  end

  def test_admin_view_rating_value_dropdown_for_equal_to_type
    list1 = admin_view_rating_value_dropdown('name', {:test => 'test', :value => '1'}, nil, "equal_to")
    list2 = admin_view_rating_value_dropdown('name', {:test => 'test', :value => '1'}, {}, "equal_to")
    list3 = admin_view_rating_value_dropdown('name', {:test => 'test', :value => '1'}, {:connection_status => {}}, "equal_to")
    list4 = admin_view_rating_value_dropdown('name', {:test => 'test', :value => '1'}, {:connection_status => { :rating => {}}}, "equal_to")
    list5 = admin_view_rating_value_dropdown('name', {:test => 'test', :value => '1'}, {:connection_status => { :rating => {:equal_to => 2}}}, "equal_to")

    expected_result = "<select name=\"name\" id=\"admin_view_connection_status_mentor_#{AdminViewsHelper::Rating::EQUAL_TO}_rating_value\" test=\"test\" value=\"\" aria-label=\" Rating Value\"><option value=\"1\">1</option>\n<option value=\"2\">2</option>\n<option value=\"3\">3</option>\n<option value=\"4\">4</option>\n<option value=\"5\">5</option></select>"
    assert_equal expected_result, list1
    assert_equal expected_result, list2
    assert_equal expected_result, list3
    assert_equal expected_result, list4
    assert_equal "<select name=\"name\" id=\"admin_view_connection_status_mentor_#{AdminViewsHelper::Rating::EQUAL_TO}_rating_value\" test=\"test\" value=\"2\" aria-label=\" Rating Value\"><option value=\"1\">1</option>\n<option selected=\"selected\" value=\"2\">2</option>\n<option value=\"3\">3</option>\n<option value=\"4\">4</option>\n<option value=\"5\">5</option></select>", list5
  end

  def test_get_table_headers_json
    program = programs(:albers)
    @admin_view = program.admin_views.first
    columns = @admin_view.admin_view_columns
    assert columns.size > 0

    self.expects(:get_choices_map_for_admin_view).with(columns).once.returns({})
    self.expects(:get_kendo_filterable_options).times(columns.size).returns({})
    output = JSON.parse(get_table_headers_json(columns))
    assert_equal columns.size + 2, output.size
    assert_primary_checkbox_in_header(output[0])
    assert_equal_hash( { "title" => "Actions", "field" => "actions", "encoded" => false, "sortable" => false, "filterable" => false, width: Kendo::ACTIONS_WIDTH }, output[1])
    assert_equal_hash({"headerTemplate"=>"<span class=\" cjs_kendo_title_header\">Member ID</span>", "field"=>"member_id", "encoded"=>false, "filterable"=>{}, "width"=>"200px"}, output[2])
  end

  def test_get_table_headers_json_organization_level
    organization = programs(:org_primary)
    @admin_view = organization.admin_views.first
    columns = @admin_view.admin_view_columns
    assert columns.size > 0

    self.expects(:get_choices_map_for_admin_view).with(columns).once.returns({})
    self.expects(:get_kendo_filterable_options).times(columns.size).returns({})
    output = JSON.parse(get_table_headers_json(columns))
    assert_equal columns.size + 1, output.size
    assert_primary_checkbox_in_header(output[0])
    assert_equal_hash({"headerTemplate"=>"<span class=\" cjs_kendo_title_header\">Member ID</span>", "field"=>"member_id", "encoded"=>false, "filterable"=>{}, "width"=>"200px"}, output[1])
  end

  def test_get_choices_map_for_admin_view
    @current_program = programs(:albers)
    @current_organization = @current_program.organization
    @admin_view = @current_program.admin_views.first
    columns = @admin_view.admin_view_columns + [get_tmp_language_column(@admin_view)] + [get_tmp_mentoring_mode_column(@admin_view)]
    organization_languages(:hindi).update_column(:title, "Org-Hindi")

    self.expects(:super_console?).twice.returns(false)
    self.expects(:program_context).twice.returns(@current_program)
    self.expects(:wob_member).twice.returns(members(:f_admin))
    Organization.any_instance.stubs(:language_settings_enabled?).returns(true)

    choices_map = get_choices_map_for_admin_view(columns)
    roles_array = [
      { title: "Administrator", value: RoleConstants::ADMIN_NAME },
      { title: "Mentor", value: RoleConstants::MENTOR_NAME },
      { title: "Student", value: RoleConstants::STUDENT_NAME },
      { title: "User", value: "user" }
    ]
    states_array = [
      { title: "Unpublished", value: User::Status::PENDING },
      { title: "Deactivated", value: User::Status::SUSPENDED },
      { title: "Active", value: User::Status::ACTIVE }
    ]
    mentoring_modes_array = [
      {title: "Ongoing Mentoring", value: User::MentoringMode::ONGOING },
      {title: "One-time Mentoring", value: User::MentoringMode::ONE_TIME },
      {title: "Ongoing and One-time Mentoring", value: User::MentoringMode::ONE_TIME_AND_ONGOING }
    ]
    languages_array = [
      { title: "English", value: 0 },
      { title: "Org-Hindi", value: 1 },
      { title: "Telugu", value: 2 }
    ]
    assert_equal roles_array, choices_map[AdminViewColumn::Columns::Key::ROLES]
    assert_equal states_array, choices_map[AdminViewColumn::Columns::Key::STATE]
    assert_equal languages_array, choices_map[AdminViewColumn::Columns::Key::LANGUAGE]
    assert_equal mentoring_modes_array, choices_map[AdminViewColumn::Columns::Key::MENTORING_MODE]

    non_choice_based_column_keys = columns.collect(&:column_key) - [AdminViewColumn::Columns::Key::ROLES, AdminViewColumn::Columns::Key::STATE, AdminViewColumn::Columns::Key::LANGUAGE, AdminViewColumn::Columns::Key::MENTORING_MODE]
    assert non_choice_based_column_keys.present?
    non_choice_based_column_keys.each { |column_key| assert_nil choices_map[column_key] }
  end

  def test_get_choices_map_for_admin_view_for_multi_track_admin
    @current_organization = programs(:org_primary)
    @admin_view = @current_organization.admin_views.find_by(default_view: AbstractView::DefaultType::LICENSE_COUNT)
    columns = @admin_view.admin_view_columns
    member = members(:f_student)

    self.stubs(:wob_member).returns(member)
    member.stubs(:admin_only_at_track_level?).returns(true)
    self.expects(:get_ordered_managing_programs).returns(Program.where(id: member.programs.first))

    choices_map = get_choices_map_for_admin_view(columns)
    assert_equal [{title: programs(:albers).name, value: programs(:albers).id}], choices_map[AdminViewColumn::Columns::Key::PROGRAM_USER_ROLES]

    member.stubs(:admin_only_at_track_level?).returns(false)

    choices_map = get_choices_map_for_admin_view(columns)
    assert_equal_unordered @current_organization.programs.collect{ |program| {title: program.name, value: program.id} }, choices_map[AdminViewColumn::Columns::Key::PROGRAM_USER_ROLES]
  end

  def test_hide_for_multi_track_admin
    @current_organization = programs(:org_primary)
    @admin_view = @current_organization.admin_views.find_by(default_view: AbstractView::DefaultType::LICENSE_COUNT)
    member = members(:f_student)

    self.stubs(:wob_member).returns(member)
    member.stubs(:admin_only_at_track_level?).returns(true)

    assert hide_for_multi_track_admin?(@admin_view)
    assert_equal "hide", hide_for_multi_track_admin?(@admin_view, get_class: true)

    member.stubs(:admin_only_at_track_level?).returns(false)
    
    assert_false hide_for_multi_track_admin?(@admin_view)
    assert_equal "", hide_for_multi_track_admin?(@admin_view, get_class: true)

    member.stubs(:admin_only_at_track_level?).returns(true)
    @admin_view.stubs(:is_organization_view?).returns(false)

    assert_false hide_for_multi_track_admin?(@admin_view)
    assert_equal "", hide_for_multi_track_admin?(@admin_view, get_class: true)
  end

  def test_customize_value_for_multi_track_admin
    @current_organization = programs(:org_primary)
    @admin_view = @current_organization.admin_views.find_by(default_view: AbstractView::DefaultType::LICENSE_COUNT)

    self.stubs(:hide_for_multi_track_admin?).returns(true)

    assert_equal "value-multi-track-admin", customize_value_for_multi_track_admin(@admin_view, "value")
    assert_equal "customized_value", customize_value_for_multi_track_admin(@admin_view, "value", "customized_value")

    self.stubs(:hide_for_multi_track_admin?).returns(false)
    assert_equal "value", customize_value_for_multi_track_admin(@admin_view, "value")
  end

  def test_get_formatted_admin_view_kendo_filter_multi_track_admin
    member = members(:f_admin)
    self.stubs(:wob_member).returns(member)

    assert_equal ({filters: [], logic: "and"}), get_formatted_admin_view_kendo_filter(multi_track_admin: false)

    assert_equal ({filters: [{"field" => "program_user_roles", "operator" => "eq", "value" => member.programs_to_add_users.collect(&:id).join(",")}], logic: "and"}), get_formatted_admin_view_kendo_filter(multi_track_admin: true)

    member.stubs(:admin_only_at_track_level?).returns(true)
    assert_equal ({filters: [{"field" => "program_user_roles", "operator" => "eq", "value" => member.programs_to_add_users.collect(&:id).join(",")}], logic: "and"}), get_formatted_admin_view_kendo_filter(some_param: true)    
  end

  def test_get_choices_map_for_admin_view_organization_level_with_profile_questions
    @current_organization = programs(:org_primary)
    @admin_view = @current_organization.admin_views.first
    member = members(:f_admin)
    self.stubs(:wob_member).returns(member)

    select_type_question = create_question(
      question_type: ProfileQuestion::Type::ORDERED_OPTIONS,
      question_text: "Select Preference",
      question_choices: ["a/b","a.'b'","a.\"b\"", "a b","a\\b"],
      options_count: 2
    )

    qc_ids_hash = {}
    choice_based_question_columns = [select_type_question, profile_questions(:single_choice_q), profile_questions(:mentor_file_upload_q)].collect do |question|
      question.question_choices.each{|qc| qc_ids_hash[qc.text] = qc.id.to_s}
      @admin_view.admin_view_columns.create!(profile_question_id: question.id)
    end
    [profile_questions(:string_q), profile_questions(:education_q), profile_questions(:experience_q)].collect do |question|
      question.question_choices.each{|qc| qc_ids_hash[qc.text] = qc.id.to_s}
      @admin_view.admin_view_columns.create!(profile_question_id: question.id)
    end

    choices_map = get_choices_map_for_admin_view(@admin_view.admin_view_columns)
    program_user_roles_choices_array = @current_organization.programs.ordered.collect do |program|
      { title: program.name, value: program.id }
    end
    states_choices_array = [
      { title: "Active", value: Member::Status::ACTIVE },
      { title: "Suspended", value: Member::Status::SUSPENDED },
      { title: "Dormant", value: Member::Status::DORMANT }
    ]

    choice_based_question_columns_results = []
    choice_based_question_columns_results << [
      { title: "a/b", value: qc_ids_hash["a/b"] },
      { title: "a.&#39;b&#39;", value: qc_ids_hash["a.'b'"] },
      { title: "a.&quot;b&quot;", value: qc_ids_hash["a.\"b\""] },
      { title: "a b", value: qc_ids_hash["a b"] },
      { title: "a\\b", value: qc_ids_hash["a\\b"] }
    ]
    choice_based_question_columns_results << [
      { title: "opt_1", value: qc_ids_hash["opt_1"] },
      { title: "opt_2", value: qc_ids_hash["opt_2"] },
      { title: "opt_3", value: qc_ids_hash["opt_3"] }
    ]
    choice_based_question_columns_results << [
      { title: "Filled", value: true },
      { title: "Not Filled", value: false }
    ]
    assert_equal states_choices_array, choices_map[AdminViewColumn::Columns::Key::STATE]
    assert_equal program_user_roles_choices_array, choices_map[AdminViewColumn::Columns::Key::PROGRAM_USER_ROLES]
    choice_based_question_columns_results.each_with_index do |expected_result, index|
      assert_equal expected_result, choices_map["column#{choice_based_question_columns[index].id}"]
    end
    assert_equal 5, choices_map.select { |_, v| v.present? }.size
  end

  def test_get_admin_view_title
    @current_organization = programs(:org_primary)
    @current_program = programs(:albers)
    role = @current_program.roles.find_by(name: "mentor")
    title = get_admin_view_title(role, @current_program, AdminView.new)
    assert_equal "Eligible Mentors for Albers Mentor Program", title
    av1 = @current_organization.admin_views.create!(title: title, description: "des1", filter_params: "filter_param1")
    title1 = get_admin_view_title(role, @current_program, AdminView.new)
    assert_equal "Eligible Mentors for Albers Mentor Program 1", title1
    av2 = @current_organization.admin_views.create(title: title1, description: "des2", filter_params: "filter_param2")
    title2 = get_admin_view_title(role, @current_program, AdminView.new)
    assert_equal "Eligible Mentors for Albers Mentor Program 2", title2
    av3 = @current_organization.admin_views.create(title: title2, description: "des3", filter_params: "filter_param3")
    title3 = get_admin_view_title(role, @current_program, AdminView.new)
    assert_equal "Eligible Mentors for Albers Mentor Program 3", title3
    #need to write more test
  end

  def test_get_note_for_actions_on_suspended
    @current_organization = programs(:org_primary)
    assert_equal "<p class=\"text-muted\">Note: This action does not apply for users suspended in #{@current_organization.name}.</p>", get_note_for_actions_on_suspended
  end

  def test_get_note_for_suspension
    program = programs(:albers)
    organization = program.organization

    content = get_note_for_suspension(program)
    assert_match /deactivation notification/, content
    assert_match /mailer_templates\/#{UserSuspensionNotification.mailer_attributes[:uid]}\/edit/, content
    assert_match /Please note that the user will not be able to participate in any more activities in this program./, content

    program.stubs(:email_template_disabled_for_activity?).returns(true)
    content = get_note_for_suspension(program, 5)
    assert_no_match(/deactivation notification/, content)
    assert_no_match(/mailer_templates\/#{UserSuspensionNotification.mailer_attributes[:uid]}\/edit/, content)
    assert_match /Please note that the users will not be able to participate in any more activities in this program./, content

    content = get_note_for_suspension(organization, 5)
    assert_match /suspension notification/, content
    assert_match /mailer_templates\/#{MemberSuspensionNotification.mailer_attributes[:uid]}\/edit/, content
    assert_match /Please note that the members will not be able to participate in any more activities and their membership requests will also be ignored./, content

    organization.stubs(:email_template_disabled_for_activity?).returns(true)
    content = get_note_for_suspension(organization, 1)
    assert_no_match(/suspension notification/, content)
    assert_no_match(/mailer_templates\/#{MemberSuspensionNotification.mailer_attributes[:uid]}\/edit/, content)
    assert_match /Please note that the member will not be able to participate in any more activities and their membership requests will also be ignored./, content
  end

  def test_add_users_dropdown
    assert_equal [
      {:label => "feature.admin_view.action.Add_Users".translate, :url => new_user_path},
      {:label => "feature.admin_view.action.Invite_Users".translate, :url =>  invite_users_path}
    ], add_users_dropdown
  end

  def test_get_options_for_meeting_connection_status
    assert_equal [["Select...", ""], ["Not connected (Not part of any  request which is accepted)", 1], ["Connected (Part of at least one  request which is accepted)", 2]], get_options_for_meeting_connection_status
  end

  def test_generate_connection_status_request_filter_for_meeting_connection_status
    name = "admin_view[connection_status][meetingconnection_status]"
    filter_params = {:connection_status => {:meetingconnection_status => "1", :advanced_options => {:meetingconnection_status => {:both => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}}}}
    role_type = :both
    request_type = :meetingconnection_status

    assert_equal "<div class=\"col-sm-8 col-md-5\"><select name=\"admin_view[connection_status][meetingconnection_status]\" id=\"new_view_filter_both_meetingconnection_status\" value=\"1\" class=\"form-control cjs_requests_filter\"><option value=\"\">Select...</option>\n<option selected=\"selected\" value=\"1\">Not connected (Not part of any  request which is accepted)</option>\n<option value=\"2\">Connected (Part of at least one  request which is accepted)</option></select></div><div class=\"col-sm-2 m-t-sm\"><span id=\"selected_option_text_for_both_meetingconnection_status\" class=\"cjs_advanced_option_link_text\">In last 10 days</span><a class=\"hide cjs_advanced_option_link\" id=\"advanced_options_for_both_meetingconnection_status\" href=\"javascript:void(0)\">(Change)</a></div>", generate_connection_status_request_filter(name, filter_params, role_type, request_type)
  end

  def test_generate_connection_status_request_filter_for_mentor_recommendation
    name = "admin_view[connection_status][mentor_recommendations][mentees]"
    filter_params = {:connection_status => {:mentor_recommendations => {mentees: "1"}, :advanced_options => {:mentor_recommendations => {:mentees => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}}}}
    role_type = :mentees
    request_type = :mentor_recommendations
    content =  generate_connection_status_request_filter(name, filter_params, role_type, request_type)
    assert_select_helper_function_block "div.col-sm-8.col-md-5", content do
      assert_select "select#new_view_filter_mentees_mentor_recommendations.cjs_requests_filter[name=\"admin_view[connection_status][mentor_recommendations][mentees]\"]" do
        assert_select "option[value=\"1\"]", text: "Received mentor recommendations"
        assert_select "option[value=\"2\"]", text: "Not received mentor recommendations"
      end
    end
    assert_select_helper_function_block "div.col-sm-2.m-t-sm", content do
      assert_select "span#selected_option_text_for_mentees_mentor_recommendations.cjs_advanced_option_link_text", text: "In last 10 days"
      assert_select "a.cjs_advanced_option_link.hide#advanced_options_for_mentees_mentor_recommendations", text: "(Change)"
    end
  end

  def test_get_adminview_second_level_title
    assert_select_helper_function_block "div.p-sm", get_adminview_second_level_title("Title") do
      assert_select "div.light-gray-bg.p-xs.font-600"
    end
  end

  def test_get_selected_duration_and_value
    filter_params = {:connection_status => {:meetingconnection_status => "1", :advanced_options => {:meetingconnection_status => {:both => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}}}}
    role_type = :both
    request_type = :meetingconnection_status

    request_duration, selected_value = get_selected_duration_and_value(filter_params, role_type, request_type)

    assert_equal "1", request_duration
    assert_equal "10", selected_value
  end

  def test_get_advanced_options_link_text
    assert_equal "(Change)", get_advanced_options_link_text("1", "10")
    assert_equal "(Advanced options)", get_advanced_options_link_text("1", "")
    assert_equal "(Advanced options)", get_advanced_options_link_text("", "10")
  end

  def test_get_selected_advanced_option_text
    assert_equal "In last 10 days", get_selected_advanced_option_text(AdminView::AdvancedOptionsType::LAST_X_DAYS.to_s, "10")
    assert_nil get_selected_advanced_option_text(AdminView::AdvancedOptionsType::EVER.to_s, "10")
    assert_equal "Before 01/12/2015", get_selected_advanced_option_text(AdminView::AdvancedOptionsType::BEFORE.to_s, "01/12/2015")
    assert_equal "After 01/12/2015", get_selected_advanced_option_text(AdminView::AdvancedOptionsType::AFTER.to_s, "01/12/2015")
  end

  def test_generate_connection_status_request_filter
    name = "admin_view[connection_status][meeting_requests][mentors]"
    filter_params = {:connection_status => {:meeting_requests => {:mentors => "1", :mentees => ""}, :advanced_options => {:meeting_requests => {:mentors => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}}}}
    role_type = :mentors
    request_type = :meeting_requests
    assert_equal "<div class=\"col-sm-8 col-md-5\"><select name=\"admin_view[connection_status][meeting_requests][mentors]\" id=\"new_view_filter_mentors_meeting_requests\" value=\"1\" class=\"form-control cjs_requests_filter\"><option value=\"\">Select...</option>\n<option selected=\"selected\" value=\"1\">Received  requests</option>\n<option value=\"2\">Received  requests that are pending action</option>\n<option value=\"3\">Not received any  requests</option>\n<option value=\"4\">Received  requests and rejected at least one request</option>\n<option value=\"5\">Received  requests and closed at least one request</option></select></div><div class=\"col-sm-2 m-t-sm\"><span id=\"selected_option_text_for_mentors_meeting_requests\" class=\"cjs_advanced_option_link_text\">In last 10 days</span><a class=\"hide cjs_advanced_option_link\" id=\"advanced_options_for_mentors_meeting_requests\" href=\"javascript:void(0)\">(Change)</a></div>", generate_connection_status_request_filter(name, filter_params, role_type, request_type)

    request_type = :mentoring_requests
    name = "admin_view[connection_status][mentoring_requests][mentors]"
    assert_equal "<div class=\"col-sm-8 col-md-5\"><select name=\"admin_view[connection_status][mentoring_requests][mentors]\" id=\"new_view_filter_mentors_mentoring_requests\" value=\"\" class=\"form-control cjs_requests_filter\"><option selected=\"selected\" value=\"\">Select...</option>\n<option value=\"1\">Received  requests</option>\n<option value=\"2\">Received  requests that are pending action</option>\n<option value=\"3\">Not received any  requests</option>\n<option value=\"4\">Received  requests and rejected at least one request</option>\n<option value=\"5\">Received  requests and closed at least one request</option></select></div><div class=\"col-sm-2 m-t-sm\"><span id=\"selected_option_text_for_mentors_mentoring_requests\" class=\"cjs_advanced_option_link_text\"></span><a class=\"hide cjs_advanced_option_link\" id=\"advanced_options_for_mentors_mentoring_requests\" href=\"javascript:void(0)\">(Advanced options)</a></div>", generate_connection_status_request_filter(name, filter_params, role_type, request_type)
  end

  def test_options_for_mentoring_request_filter
    assert_equal [["Select...", ""], ["Sent  requests", 1], ["Sent  requests that are pending action", 2], ["Not sent any  requests", 3]], options_for_mentoring_request_filter(:mentees)

    assert_equal [["Select...", ""], ["Received  requests", 1], ["Received  requests that are pending action", 2], ["Not received any  requests", 3], ["Received  requests and rejected at least one request", 4], ["Received  requests and closed at least one request", 5]], options_for_mentoring_request_filter(:mentors)
  end

  def test_options_for_meeting_request_filter
    assert_equal [["Select...", ""], ["Sent  requests", 1], ["Sent  requests that are pending action", 2], ["Not sent any  requests", 3]], options_for_meeting_request_filter(:mentees)

    assert_equal [["Select...", ""], ["Received  requests", 1], ["Received  requests that are pending action", 2], ["Not received any  requests", 3], ["Received  requests and rejected at least one request", 4], ["Received  requests and closed at least one request", 5]], options_for_meeting_request_filter(:mentors)
  end

  def test_populate_basic_info_columns
    program = programs(:albers)
    admin_view = program.admin_views.first
    assert_equal "<option selected=\"selected\" value=\"basic_info:member_id\">Member ID</option>\n<option selected=\"selected\" value=\"basic_info:first_name\">First Name</option>\n<option selected=\"selected\" value=\"basic_info:last_name\">Last Name</option>\n<option selected=\"selected\" value=\"basic_info:email\">Email</option>\n<option selected=\"selected\" value=\"basic_info:roles\">Roles</option>\n<option selected=\"selected\" value=\"basic_info:state\">Status</option>", populate_basic_info_columns([], admin_view, AdminViewColumn::ColumnsGroup::BASIC_INFO)
    assert_equal "<option selected=\"selected\" value=\"basic_info:member_id\">Member ID</option>\n<option selected=\"selected\" value=\"basic_info:first_name\">First Name</option>\n<option selected=\"selected\" value=\"basic_info:last_name\">Last Name</option>\n<option value=\"basic_info:email\">Email</option>\n<option value=\"basic_info:roles\">Roles</option>\n<option value=\"basic_info:state\">Status</option>", populate_basic_info_columns(admin_view.admin_view_columns.first(3), admin_view, AdminViewColumn::ColumnsGroup::BASIC_INFO)

    organization = program.organization
    admin_view = organization.admin_views.first
    assert_equal "<option selected=\"selected\" value=\"basic_info:member_id\">Member ID</option>\n<option selected=\"selected\" value=\"basic_info:first_name\">First Name</option>\n<option selected=\"selected\" value=\"basic_info:last_name\">Last Name</option>\n<option selected=\"selected\" value=\"basic_info:email\">Email</option>\n<option selected=\"selected\" value=\"basic_info:state\">Status</option>\n<option selected=\"selected\" value=\"basic_info:program_user_roles\"></option>\n<option selected=\"selected\" value=\"basic_info:last_suspended_at\">Last Suspended On</option>", populate_basic_info_columns([], admin_view, AdminViewColumn::ColumnsGroup::BASIC_INFO)
  end

  def test_get_location_question_scope_options
    assert_equal [["City", "city"], ["State", "state"], ["Country", "country"]], get_location_question_scope_options
  end

  def test_profile_question_key_generate
    location_profile_question = ProfileQuestion.where(question_type: ProfileQuestion::Type::LOCATION).first
    assert_equal ["#{location_profile_question.id}", "#{location_profile_question.id}-city", "#{location_profile_question.id}-state", "#{location_profile_question.id}-country"], profile_question_key_generate(location_profile_question)
    profile_question = ProfileQuestion.first
    assert_equal ["#{profile_question.id}"], profile_question_key_generate(profile_question)
  end

  def test_populate_profile_question_columns
    program = programs(:albers)
    admin_view = program.admin_views.first
    profile_questions = program.profile_questions_for(RoleConstants::MENTOR_NAME, default: false, skype: true)
    assert_equal "<option value=\"profile:3\">Location</option>
<option value=\"profile:3-city\">Location (City)</option>
<option value=\"profile:3-state\">Location (State)</option>
<option value=\"profile:3-country\">Location (Country)</option>
<option value=\"profile:4\">Phone</option>
<option value=\"profile:5\">Skype ID</option>
<option value=\"profile:6\">Education</option>
<option value=\"profile:7\">Work</option>
<option value=\"profile:8\">About Me</option>
<option value=\"profile:9\">Gender</option>
<option value=\"profile:10\">Industry</option>
<option value=\"profile:11\">Career path/Specializations</option>
<option value=\"profile:12\">Expertise</option>
<option value=\"profile:15\">Total work experience</option>
<option value=\"profile:16\">Language</option>
<option value=\"profile:17\">Ethnicity</option>
<option value=\"profile:#{profile_questions(:string_q).id}\">What is your name</option>
<option value=\"profile:#{profile_questions(:single_choice_q).id}\">What is your name</option>
<option value=\"profile:#{profile_questions(:multi_choice_q).id}\">What is your name</option>
<option value=\"profile:#{profile_questions(:private_q).id}\">What is your favorite location stop</option>
<option value=\"profile:#{profile_questions(:mentor_file_upload_q).id}\">Upload your Resume</option>
<option value=\"profile:#{profile_questions(:education_q).id}\">Current Education</option>
<option value=\"profile:#{profile_questions(:multi_education_q).id}\">Entire Education</option>
<option value=\"profile:#{profile_questions(:experience_q).id}\">Current Experience</option>
<option value=\"profile:#{profile_questions(:multi_experience_q).id}\">Work Experience</option>
<option value=\"profile:#{profile_questions(:publication_q).id}\">Current Publication</option>
<option value=\"profile:#{profile_questions(:multi_publication_q).id}\">New Publication</option>
<option value=\"profile:#{profile_questions(:manager_q).id}\">Current Manager</option>
<option value=\"profile:#{profile_questions(:date_question).id}\">Date Question</option>", populate_profile_question_columns(profile_questions, admin_view.admin_view_columns.includes(:profile_question), admin_view, AdminViewColumn::ColumnsGroup::PROFILE)

    organization = programs(:org_primary)
    admin_view = organization.admin_views.first
    profile_questions = organization.profile_questions.reorder(:id)
    assert_equal "<option value=\"profile:3\">Location</option>
<option value=\"profile:3-city\">Location (City)</option>
<option value=\"profile:3-state\">Location (State)</option>
<option value=\"profile:3-country\">Location (Country)</option>
<option value=\"profile:4\">Phone</option>
<option value=\"profile:5\">Skype ID</option>
<option value=\"profile:6\">Education</option>
<option value=\"profile:7\">Work</option>
<option value=\"profile:8\">About Me</option>
<option value=\"profile:9\">Gender</option>
<option value=\"profile:10\">Industry</option>
<option value=\"profile:11\">Career path/Specializations</option>
<option value=\"profile:12\">Expertise</option>
<option value=\"profile:13\">Career path interests</option>
<option value=\"profile:14\">Industry interests</option>
<option value=\"profile:15\">Total work experience</option>
<option value=\"profile:16\">Language</option>
<option value=\"profile:17\">Ethnicity</option>
<option value=\"profile:#{profile_questions(:string_q).id}\">What is your name</option>
<option value=\"profile:#{profile_questions(:single_choice_q).id}\">What is your name</option>
<option value=\"profile:#{profile_questions(:multi_choice_q).id}\">What is your name</option>
<option value=\"profile:#{profile_questions(:private_q).id}\">What is your favorite location stop</option>
<option value=\"profile:#{profile_questions(:student_string_q).id}\">What is your hobby</option>
<option value=\"profile:#{profile_questions(:student_single_choice_q).id}\">What is your hobby</option>
<option value=\"profile:#{profile_questions(:student_multi_choice_q).id}\">What is your hobby</option>
<option value=\"profile:#{profile_questions(:mentor_file_upload_q).id}\">Upload your Resume</option>
<option value=\"profile:#{profile_questions(:education_q).id}\">Current Education</option>
<option value=\"profile:#{profile_questions(:multi_education_q).id}\">Entire Education</option>
<option value=\"profile:#{profile_questions(:experience_q).id}\">Current Experience</option>
<option value=\"profile:#{profile_questions(:multi_experience_q).id}\">Work Experience</option>
<option value=\"profile:#{profile_questions(:publication_q).id}\">Current Publication</option>
<option value=\"profile:#{profile_questions(:multi_publication_q).id}\">New Publication</option>
<option value=\"profile:#{profile_questions(:manager_q).id}\">Current Manager</option>
<option value=\"profile:#{profile_questions(:date_question).id}\">Date Question</option>", populate_profile_question_columns(profile_questions, admin_view.admin_view_columns.includes(:profile_question), admin_view, AdminViewColumn::ColumnsGroup::PROFILE)
  end

  def test_populate_timeline_columns
    program = programs(:albers)
    admin_view = program.admin_views.first

    assert_equal "<option value=\"timeline:last_seen_at\">Last Logged In</option>\n<option value=\"timeline:terms_and_conditions_accepted\">T&amp;C Accepted On</option>\n<option value=\"timeline:last_closed_group_time\">Last Mentoring Connection Closed On</option>\n<option value=\"timeline:created_at\">Joined On</option>\n<option value=\"timeline:last_deactivated_at\">Last Deactivated On</option>", populate_timeline_columns([], admin_view, AdminViewColumn::ColumnsGroup::TIMELINE, program.ongoing_mentoring_enabled?)

    assert_equal "<option selected=\"selected\" value=\"timeline:created_at\">Joined On</option>\n<option value=\"timeline:last_seen_at\">Last Logged In</option>\n<option value=\"timeline:terms_and_conditions_accepted\">T&amp;C Accepted On</option>\n<option value=\"timeline:last_closed_group_time\">Last Mentoring Connection Closed On</option>\n<option value=\"timeline:last_deactivated_at\">Last Deactivated On</option>", populate_timeline_columns(admin_view.admin_view_columns, admin_view, AdminViewColumn::ColumnsGroup::TIMELINE, program.ongoing_mentoring_enabled?)

    assert_equal "<option value=\"timeline:last_seen_at\">Last Logged In</option>\n<option value=\"timeline:terms_and_conditions_accepted\">T&amp;C Accepted On</option>\n<option value=\"timeline:created_at\">Joined On</option>\n<option value=\"timeline:last_deactivated_at\">Last Deactivated On</option>", populate_timeline_columns([], admin_view, AdminViewColumn::ColumnsGroup::TIMELINE, false)
  end

  def test_populate_matching_and_engagement_status_columns
    program = programs(:albers)
    admin_view = program.admin_views.first

    assert_equal "<option value=\"matching_and_engagement:groups\">Ongoing Mentoring Connections</option>\n<option value=\"matching_and_engagement:closed_groups\">Closed Mentoring Connections</option>\n<option value=\"matching_and_engagement:drafted_groups\">Drafted Mentoring Connections</option>\n<option value=\"matching_and_engagement:available_slots\">Mentoring Connection slots</option>\n<option value=\"matching_and_engagement:mentoring_requests_sent_v1\">Mentoring requests sent</option>\n<option value=\"matching_and_engagement:mentoring_requests_received_v1\">Mentoring requests received</option>\n<option value=\"matching_and_engagement:mentoring_requests_sent_and_pending_v1\">Mentoring requests sent &amp; pending action</option>\n<option value=\"matching_and_engagement:mentoring_requests_received_and_pending_v1\">Mentoring requests received &amp; pending action</option>\n<option value=\"matching_and_engagement:mentoring_requests_received_and_rejected\">Mentoring requests received &amp; rejected</option>\n<option value=\"matching_and_engagement:mentoring_requests_received_and_closed\">Mentoring requests received &amp; closed</option>", populate_matching_and_engagement_status_columns([], admin_view, AdminViewColumn::ColumnsGroup::MATCHING_AND_ENGAGEMENT)

    admin_view.program.enable_feature(FeatureName::COACH_RATING, true)
    assert_match /rating/, populate_matching_and_engagement_status_columns(admin_view.admin_view_columns, admin_view, AdminViewColumn::ColumnsGroup::MATCHING_AND_ENGAGEMENT)

    admin_view.program.enable_feature(FeatureName::CALENDAR, true)
    assert_match /meeting_requests_received_v1/, populate_matching_and_engagement_status_columns(admin_view.admin_view_columns, admin_view, AdminViewColumn::ColumnsGroup::MATCHING_AND_ENGAGEMENT)

    admin_view.program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    assert_match /mentoring_mode/, populate_matching_and_engagement_status_columns(admin_view.admin_view_columns, admin_view, AdminViewColumn::ColumnsGroup::MATCHING_AND_ENGAGEMENT)

    assert_false admin_view.program.mentor_recommendation_enabled?
    assert_nil populate_matching_and_engagement_status_columns(admin_view.admin_view_columns, admin_view, AdminViewColumn::ColumnsGroup::MATCHING_AND_ENGAGEMENT).match(/net_recommended_count/)
    admin_view.program.enable_feature(FeatureName::MENTOR_RECOMMENDATION, true)
    assert_match /matching_and_engagement\:net_recommended_count/, populate_matching_and_engagement_status_columns(admin_view.admin_view_columns, admin_view, AdminViewColumn::ColumnsGroup::MATCHING_AND_ENGAGEMENT)
  end

  def test_populate_engagement_columns
    admin_view = programs(:albers).organization.admin_views.first
    assert_equal "<option value=\"engagement:ongoing_engagements\">Ongoing Engagements</option>\n<option value=\"engagement:closed_engagements\">Closed Engagements</option>", populate_engagement_columns([], AdminViewColumn::ColumnsGroup::ORG_LEVEL_ENGAGEMENT)

    admin_view.admin_view_columns.create!(:admin_view => admin_view, :column_key => "ongoing_engagements")

    assert_equal "<option selected=\"selected\" value=\"engagement:ongoing_engagements\">Ongoing Engagements</option>\n<option value=\"engagement:closed_engagements\">Closed Engagements</option>", populate_engagement_columns(admin_view.reload.admin_view_columns, AdminViewColumn::ColumnsGroup::ORG_LEVEL_ENGAGEMENT)
  end

  def test_get_admin_view_column_options
    admin_view = programs(:albers).organization.admin_views.first
    assert_equal "<option value=\"engagement:ongoing_engagements\">Ongoing Engagements</option>\n<option value=\"engagement:closed_engagements\">Closed Engagements</option>", get_admin_view_column_options(["ongoing_engagements", "closed_engagements"], {"ongoing_engagements"=>{:title=>"Ongoing Engagements"}, "closed_engagements"=>{:title=>"Closed Engagements"}},[], AdminViewColumn::ColumnsGroup::ORG_LEVEL_ENGAGEMENT)

    admin_view.admin_view_columns.create!(:admin_view => admin_view, :column_key => "ongoing_engagements")

    assert_equal "<option selected=\"selected\" value=\"engagement:ongoing_engagements\">Ongoing Engagements</option>\n<option value=\"engagement:closed_engagements\">Closed Engagements</option>", get_admin_view_column_options(["ongoing_engagements", "closed_engagements"], {"ongoing_engagements"=>{:title=>"Ongoing Engagements"}, "closed_engagements"=>{:title=>"Closed Engagements"}},["ongoing_engagements"], AdminViewColumn::ColumnsGroup::ORG_LEVEL_ENGAGEMENT)
  end

  def test_fetch_active_and_closed_engagements_map
    members = programs(:albers).organization.members
    options = {}
    admin_view = programs(:org_primary).admin_views.first
    admin_view_columns = admin_view.reload.admin_view_columns
    
    assert_equal_hash({:ongoing_engagements_map=>{}, :closed_engagements_map=>{}}, fetch_active_and_closed_engagements_map(members, admin_view_columns, options))

    admin_view.admin_view_columns.create!(:admin_view => admin_view, :column_key => "ongoing_engagements")
    admin_view_columns = admin_view.reload.admin_view_columns

    assert_equal_hash({:ongoing_engagements_map=>{members(:f_student).id => 2, members(:f_mentor).id=>3, members(:robert).id => 1, members(:mkr_student).id => 1, members(:student_1).id=>1, members(:student_2).id => 3, members(:student_3).id=>1, members(:mentor_1).id=>2, members(:not_requestable_mentor).id => 2, members(:no_mreq_student).id => 1, members(:no_mreq_mentor).id=>1}, :closed_engagements_map=>{}}, fetch_active_and_closed_engagements_map(members, admin_view_columns, options))

    create_group(:program => programs(:albers), :expiry_time => 4.months.from_now, :mentors => [users(:f_mentor)],:students => [users(:mkr_student)], :status => Group::Status::CLOSED, :closed_at => Time.now, :closed_by => users(:f_admin), :global => true, :termination_mode => Group::TerminationMode::ADMIN, :closure_reason_id => Group.first.get_auto_terminate_reason_id)
    admin_view.admin_view_columns.create!(:admin_view => admin_view, :column_key => "closed_engagements")
    admin_view_columns = admin_view.reload.admin_view_columns
    
    assert_equal_hash({:ongoing_engagements_map=>{members(:f_student).id => 2, members(:f_mentor).id=>3, members(:robert).id => 1, members(:mkr_student).id => 1, members(:student_1).id=>1, members(:student_2).id=>3, members(:student_3).id=>1, members(:mentor_1).id=>2, members(:not_requestable_mentor).id=>2, members(:no_mreq_student).id=>1, members(:no_mreq_mentor).id=>1}, :closed_engagements_map=>{members(:f_mentor).id=>1, members(:mkr_student).id=>1, members(:student_4).id=>1, members(:requestable_mentor).id=>1}}, fetch_active_and_closed_engagements_map(members, admin_view_columns, options))
  end

  def test_admin_view_edit_column_mapper
    assert_equal "optgroup:key", admin_view_edit_column_mapper("key", "optgroup")
  end

  def test_render_advanced_options_choices
    admin_view = AdminView.first
    role_type = :mentors
    request_type = :meeting_requests
    filter_params = {:connection_status => {:advanced_options => {:meeting_requests => {:mentors => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}}}}
    admin_view.stubs(:filter_params_hash).returns(filter_params)

    content = render_advanced_options_choices(admin_view, role_type, request_type)
    set_response_text(content)
    assert_select "div.cjs_nested_show_hide_container" do
      assert_select "div.cjs_show_hide_sub_selector", count: 4
      assert_select "div.cjs_show_hide_sub_selector" do
        assert_select "label.cjs_toggle_radio", count: 4
        assert_select "input.cjs_advanced_options_radio_btn", count: 4
        assert_select "input.cjs_input_advanced_options", count: 3
        assert_select "input#admin_view_connection_status_advanced_options_meeting_requests_mentors_request_duration_1[value='1']", count: 1
        assert_select "input#admin_view_connection_status_advanced_options_meeting_requests_mentors_request_duration_3[value='3']", count: 1
        assert_select "input#admin_view_connection_status_advanced_options_meeting_requests_mentors_request_duration_2[value='2']", count: 1
        assert_select "input#admin_view_connection_status_advanced_options_meeting_requests_mentors_request_duration_4[value='4']", count: 1
        assert_select "label", text: "In last", count: 2
        assert_select "label", text: "After", count: 2
        assert_select "label", text: "Before", count: 2
        assert_select "label", text: "Ever (Since the beginning of the program)", count: 1
      end
    end
  end

  def test_render_admin_view_check_box_or_radio_button
    admin_view = admin_views(:admin_views_1)
    filter_params = ActiveSupport::HashWithIndifferentAccess.new({"member_status"=>{"state" => {"0" => "0"}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}}})
    admin_view.stubs(:filter_params_hash).returns(filter_params)
    assert_equal '<input type="checkbox" name="admin_view[member_status][state][0]" id="admin_view_member_status_state_0" value="0" checked="checked" />Active', render_admin_view_check_box_or_radio_button(admin_view, "admin_view[member_status][state][#{Member::Status::ACTIVE}]", Member::Status::ACTIVE, 'Active', filter_params, :checkbox => true)
    assert_equal '<input type="radio" name="admin_view[member_status][user_state]" id="admin_view_member_status_user_state_0" value="0" />All Members', render_admin_view_check_box_or_radio_button(admin_view, "admin_view[member_status][user_state]", AdminView::UserState::IGNORE_USER_STATUS, 'All Members', filter_params, :radio => true, :key_param => :user_state)
    assert_equal '<input type="checkbox" name="admin_view[member_status][state][0]" id="admin_view_member_status_state_0" value="3" />Dormant', render_admin_view_check_box_or_radio_button(admin_view, "admin_view[member_status][state][#{Member::Status::ACTIVE}]", Member::Status::DORMANT, 'Dormant', filter_params, :checkbox => true)
    filter_params = ActiveSupport::HashWithIndifferentAccess.new({"member_status"=>{"state" => {"0" => "0"}, "user_state"=>"#{AdminView::UserState::IGNORE_USER_STATUS}"}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}}})
    admin_view.stubs(:filter_params_hash).returns(filter_params)
    assert_equal '<input type="radio" name="admin_view[member_status][user_state]" id="admin_view_member_status_user_state_0" value="0" checked="checked" />All Members', render_admin_view_check_box_or_radio_button(admin_view, "admin_view[member_status][user_state]", AdminView::UserState::IGNORE_USER_STATUS, 'All Members', filter_params, :radio => true, :key_param => :user_state)
  end

  def test_generate_admin_view_profile_questions_for_new_view
    admin_view = admin_views(:admin_views_1)
    profile_questions = admin_view.organization.profile_questions

    # Case 1: New admin view create should display one row in profile filters.
    content = generate_admin_view_profile_questions(admin_view, profile_questions, {})
    set_response_text(content)
    assert_select "div.cjs_add_one_more_div", count: 1
    assert_select "div.cjs_hidden_input_box_container", count: 1

    # Case 2: Admin view with all questions in filter_params_hash[:profile] present.
    first_question_id = profile_questions.first.id
    last_question_id = profile_questions.last.id
    filter_params = {
      profile: {
        questions: {
          question_1: {
            question: "#{first_question_id}", operator: "4", value: ""
          },
          question_2: {
            question: "#{last_question_id}", operator: "4", value: ""
          }
        }
      }
    }
    content = generate_admin_view_profile_questions(admin_view, profile_questions, filter_params)
    set_response_text(content)
    assert_select "div.cjs_add_one_more_div", count: 1
    assert_select "div.cjs_hidden_input_box_container", count: 2

    # Case 3: Admin view with few questions in filter_params_hash[:profile] deleted.
    profile_questions.last.destroy
    content = generate_admin_view_profile_questions(admin_view, profile_questions.reload, filter_params)
    set_response_text(content)
    assert_select "div.cjs_add_one_more_div", count: 1
    assert_select "div.cjs_hidden_input_box_container", count: 1
  end

  def test_get_mentoring_connection_customized_terms
    org = programs(:org_primary)
    assert_equal ["a mentoring connection", "mentoring connections"], get_mentoring_connection_customized_terms(org)
  end

  def test_get_formatted_admin_view_kendo_filter
    member = members(:f_admin)
    self.stubs(:wob_member).returns(member)

    assert_equal_hash({}, get_formatted_admin_view_kendo_filter({}))
    assert_equal_hash({filters: [{field: AdminViewColumn::Columns::Key::STATE, operator: "eq", value: User::Status::ACTIVE}], logic: "and"}, get_formatted_admin_view_kendo_filter({state: User::Status::ACTIVE}))
    assert_equal_hash({filters: [{field: AdminViewColumn::Columns::Key::STATE, operator: "eq", value: User::Status::ACTIVE}, {field: AdminViewColumn::Columns::Key::GROUPS, operator: "gt", value: 0}], logic: "and"}, get_formatted_admin_view_kendo_filter(connected: "true", state: User::Status::ACTIVE))
    assert_equal_hash({filters: [AdminView::MEMBER_WITH_ONGOING_ENGAGEMENTS_FILTER_HSH], :logic=>"and"}, get_formatted_admin_view_kendo_filter(non_profile_field_filters: [AdminView::MEMBER_WITH_ONGOING_ENGAGEMENTS_FILTER_HSH]))
  end

  def test_initial_data_for_daterange_picker
    Timecop.freeze
    assert_equal_hash ({"start"=>Date.current, "end"=>Date.tomorrow}), (self.send(:initial_data_for_daterange_picker, {from_date: Date.current, to_date: Date.tomorrow}))
    assert_equal_hash ({"start"=>Date.current, "end"=>nil}), (self.send(:initial_data_for_daterange_picker, {from_date: Date.current, to_date: "invalid"}))
    assert_equal_hash ({"start"=>nil, "end"=>Date.tomorrow}), (self.send(:initial_data_for_daterange_picker, {from_date: nil, to_date: Date.tomorrow}))
    Timecop.return
  end

  def test_profile_questions_container_box_for_date_profile
    profile_questions = [profile_questions(:date_question)]

    content = profile_questions_container_box(AdminView.new, 1, 1, profile_questions, {"date_value" => "01/01/2012 - 02/02/2013 - custom", "date_operator" => "after" })
    assert_select_helper_function_block "div.cjs_date_type_profile_question_container.hide", content do
      assert_select_helper_function "label", content
      assert_select_helper_function "select.cjs_profile_question_date_operator", content
      assert_select_helper_function "div.cjs_profile_question_date_components.hide", content
      assert_select_helper_function "input.cjs_profile_question_single_date_value_field", content, value: "January 01, 2012"
    end

    content = profile_questions_container_box(AdminView.new, 1, 1, profile_questions, {"date_operator" => "in_next", "number_of_days" => 2 })
    assert_select_helper_function_block "div.cjs_date_type_profile_question_container.hide", content do
      assert_select_helper_function "label", content
      assert_select_helper_function "select.cjs_profile_question_date_operator", content
      assert_select_helper_function "div.cjs_profile_question_date_components.hide", content
      assert_select_helper_function "input.cjs_profile_question_number_of_days", content, value: "2"
    end
    
    content = profile_questions_container_box(AdminView.new, 1, 1, profile_questions, {"date_value" => "01/01/2012 - 02/02/2013 - custom", "date_operator" => "after" })
    assert_select_helper_function_block "div.cjs_date_type_profile_question_container.hide", content do
      assert_select_helper_function "label", content
      assert_select_helper_function "select.cjs_profile_question_date_operator", content
      assert_select_helper_function "div.cjs_profile_question_date_components.hide", content
      assert_select_helper_function "input.cjs_daterange_picker_start", content, value: "January 01, 2012"
      assert_select_helper_function "input.cjs_daterange_picker_end", content, value: "February 02, 2013"
    end
  end

  def test_operators_for_date_profile_question
    assert_equal [["Select...", "", {class: "hide"}], ["Filled", "filled"], ["Not Filled", "not_filled"], ["Before", "before"], ["After", "after"], ["Date Range", "date_range"], ["In Last", "in_last"], ["In Next", "in_next"]], operators_for_date_profile_question
  end

  def test_check_dynamic_filter_params_if_columns_not_present
    assert_equal [], check_dynamic_filter_params_if_columns_not_present({}, [])
    assert_equal [], check_dynamic_filter_params_if_columns_not_present({state: User::Status::ACTIVE, connected: true}, [AdminViewColumn::Columns::Key::STATE, AdminViewColumn::Columns::Key::GROUPS])
    assert_equal [AdminViewColumn::Columns::Key::STATE], check_dynamic_filter_params_if_columns_not_present({state: User::Status::ACTIVE, connected: true}, [AdminViewColumn::Columns::Key::ROLES, AdminViewColumn::Columns::Key::GROUPS])
    assert_equal [AdminViewColumn::Columns::Key::STATE, AdminViewColumn::Columns::Key::GROUPS], check_dynamic_filter_params_if_columns_not_present({state: User::Status::ACTIVE, connected: true}, [AdminViewColumn::Columns::Key::ROLES])
    assert_equal [AdminViewColumn::Columns::Key::ROLES], check_dynamic_filter_params_if_columns_not_present({role: User::Status::ACTIVE, connected: true}, [AdminViewColumn::Columns::Key::STATE, AdminViewColumn::Columns::Key::GROUPS])
  end

  def test_get_missing_dynamic_filter_columns_text
    assert_equal "Status column is not selected for display. click_here_text to add it to the view to see the filtered results", get_missing_dynamic_filter_columns_text([AdminViewColumn::Columns::Key::STATE], "click_here_text")
    assert_equal "Status and Ongoing Mentoring Connections columns are not selected for display. click_here_text to add them to the view to see the filtered results", get_missing_dynamic_filter_columns_text([AdminViewColumn::Columns::Key::STATE, AdminViewColumn::Columns::Key::GROUPS], "click_here_text")
  end

  def test_generate_program_role_state_filter_common
    assert_equal ["some_base_name[some_object_name]", "cjs-program-role-state-filter-some_object_name-parent-0-child-0"], generate_program_role_state_filter_common("some_base_name", "some_object_name")   
  end

  def test_generate_program_role_state_filter_object_select
    assert_match %Q[id="cjs-program-role-state-filter-state-parent-0-child-0"], generate_program_role_state_filter_object_select("some_base_name", AdminView::ProgramRoleStateFilterObjectKey::STATE, organization: programs(:org_primary))
    assert_match %Q[id="cjs-program-role-state-filter-program-parent-0-child-0"], generate_program_role_state_filter_object_select("some_base_name", AdminView::ProgramRoleStateFilterObjectKey::PROGRAM, organization: programs(:org_primary))
    assert_match %Q[id="cjs-program-role-state-filter-role-parent-0-child-0"], generate_program_role_state_filter_object_select("some_base_name", AdminView::ProgramRoleStateFilterObjectKey::ROLE, organization: programs(:org_primary))
  end

  def test_get_back_link
    source_info = { action: "bulk_match", controller: "bulk_matches" }
    expected_back_link = { label: "Bulk Match", link: url_for(source_info) }
    assert_equal expected_back_link, get_back_link(source_info)

    expected_back_link = { label: "Views", link: "back_link" }
    assert_equal expected_back_link, get_back_link(nil)
  end

  def test_get_users_role_hash
    program = programs(:pbe)
    users = program.mentor_users.limit(1)
    user = users.first
    user_details = { nameEmail: user.name_with_email, userId: user.id, nameEmailForDisplay: h(user.name_with_email) }
    roles = program.roles.for_mentoring
    expected_hash = {}
    roles.each do |role|
      expected_hash[role.id] = []
    end
    assert_equal expected_hash, get_users_role_hash(program, nil)
    user.add_role(RoleConstants::STUDENT_NAME)
    user.add_role(RoleConstants::TEACHER_NAME)
    priority_role_id = user.roles.order("field(name, 'mentor', 'student', 'teacher')").first.id
    expected_hash[priority_role_id] = [user_details]
    assert_equal expected_hash, get_users_role_hash(program, users)
    group = groups(:proposed_group_1)
    teacher_role = program.get_role(RoleConstants::TEACHER_NAME)
    group.add_and_remove_custom_users!(teacher_role, [user])
    expected_hash[priority_role_id] = []
    expected_hash[teacher_role.id] = [user_details]
    assert_equal expected_hash, get_users_role_hash(program, users, group)
  end

  def test_get_program_role_state_active_action
    filter_params = {}
    assert_equal 0, get_program_role_state_active_action(filter_params)
    filter_params = HashWithIndifferentAccess.new({"program_role_state" => {"all_members" => true}})
    assert_equal 0, get_program_role_state_active_action(filter_params)
    filter_params = HashWithIndifferentAccess.new({"program_role_state" => {}})
    assert_not_equal 0, get_program_role_state_active_action(filter_params)
    filter_params = HashWithIndifferentAccess.new({"program_role_state" => {"all_members" => true, "inclusion" => "exclude"}})
    assert_equal 0, get_program_role_state_active_action(filter_params)

    filter_params = HashWithIndifferentAccess.new({"program_role_state" => {"inclusion" => "include", "filter_conditions" => {"parent_filter" => {"child_filter" => {"state" => ["active"], "program" => [], "role" => []}}}}})
    assert_equal 1, get_program_role_state_active_action(filter_params)
    filter_params = HashWithIndifferentAccess.new({"program_role_state" => {"inclusion" => "include", "filter_conditions" => {"parent_filter" => {"child_filter" => {"state" => ["active"], "program" => [], "role" => ["mentor"]}}}}})
    assert_not_equal 1, get_program_role_state_active_action(filter_params)

    filter_params = HashWithIndifferentAccess.new({"program_role_state" => {"inclusion" => "exclude", "filter_conditions" => {"parent_filter" => {"child_filter" => {"state" => ["active"], "program" => [], "role" => []}}}}})
    assert_equal 2, get_program_role_state_active_action(filter_params)
    filter_params = HashWithIndifferentAccess.new({"program_role_state" => {"inclusion" => "exclude", "filter_conditions" => {"parent_filter" => {"child_filter" => {"state" => ["active"], "program" => [], "role" => ["mentor"]}}}}})
    assert_not_equal 2, get_program_role_state_active_action(filter_params)

    filter_params = HashWithIndifferentAccess.new({"program_role_state" => {"inclusion" => "exclude", "filter_conditions" => {"parent_filter" => {"child_filter" => {"state" => ["active"], "program" => ["3"], "role" => []}}}}})
    assert_equal 3, get_program_role_state_active_action(filter_params)
    filter_params = HashWithIndifferentAccess.new({"program_role_state" => {"inclusion" => "exclude", "filter_conditions" => {"parent_filter" => {"child_filter" => {"state" => ["active"], "program" => [], "role" => ["mentor"]}}}}})
    assert_equal 3, get_program_role_state_active_action(filter_params)
    filter_params = HashWithIndifferentAccess.new({"program_role_state" => {"inclusion" => "exclude", "filter_conditions" => {"parent_filter" => {"child_filter" => {"state" => ["active"], "program" => [], "role" => []}}}}})
    assert_not_equal 3, get_program_role_state_active_action(filter_params)
  end

  private

  def _Mentoring
    "Mentoring"
  end

  def _Mentoring_Connection
    "Mentoring Connection"
  end

  def _Mentoring_Connections
    "Mentoring Connections"
  end

  def _program
    "program"
  end

  def _Admin
    "Admin"
  end

  def _Mentees
    "Students"
  end

  def _mentor
    "mentor"
  end

  def _mentoring_connections
    "mentoring connections"
  end

  def assert_primary_checkbox_in_header(options)
    assert_equal "<input type='checkbox' id='cjs_admin_view_primary_checkbox'></input><label class='sr-only' for='cjs_admin_view_primary_checkbox'>Select Fields to Display</label>", options["title"]
    assert_equal "check_box", options["field"]
    assert_false options["encoded"]
    assert_false options["sortable"]
    assert_false options["filterable"]
  end

  def back_url(_path)
    "back_link"
  end
end