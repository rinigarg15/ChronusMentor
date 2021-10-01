require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/groups_helper"
require_relative "./../../../app/helpers/mentoring_models_helper"

class GroupsHelperTest < ActionView::TestCase
  include MentoringModelsHelper
  MENTOR_NAME = "Mentor"
  STUDENT_NAME = "Student"

  def setup
    super
    helper_setup
  end

  def test_group_status_rows
    group = groups(:mygroup)
    closure_reason = group.program.permitted_closure_reasons.first

    group.program.update_attribute(:auto_terminate_reason_id, closure_reason.id)
    assert_nil group_status_rows(group)

    group.terminate!(users(:ram), 'My termination_reason', closure_reason.id)
    SecureRandom.stubs(:hex).returns(1)
    contents = group_status_rows(group)
    assert_equal_hash({ label: "Closed by", content: link_to_user(users(:ram)) }, contents[0])
    assert_equal_hash({ label: "Closed on", content: formatted_time_in_words(group.closed_at, :no_ago => false) }, contents[1])
    assert_equal_hash({ label: "Reason", content: closure_reason.reason }, contents[2])

    group.stubs(:closed_by).returns(nil)
    contents = group_status_rows(group)
    assert_equal_hash({ label: "Closed by", content: "Administrator" }, contents[0])
    assert_equal_hash({ label: "Closed on", content: formatted_time_in_words(group.closed_at, :no_ago => false) }, contents[1])
    assert_equal_hash({ label: "Reason", content: closure_reason.reason }, contents[2])

    group.update_column(:status, Group::Status::INACTIVE)
    group.auto_terminate_due_to_inactivity!
    contents = group_status_rows(group)
    assert_equal_hash({ label: "Closed by", content: "Auto closed" }, contents[0])
    assert_equal_hash({ label: "Closed on", content: formatted_time_in_words(group.closed_at, :no_ago => false) }, contents[1])
    assert_equal_hash({ label: "Reason", content: closure_reason.reason }, contents[2])
  end

  def test_get_tab_box
    filter_params = { search_filters: { "a" => { "a1" => 1, "a2" => 2 } }, member_filters: "y", connection_questions: "b", sub_filter: "v", member_profile_filters: "s" }

    counts = {
      closed: 24,
      ongoing: 23,
      drafted: 0
    }
    settings = {
      show_drafted_tab: true
    }
    content = get_tab_box(Group::Status::CLOSED, Group::View::DETAILED, counts, settings, nil)
    assert_select_helper_function "li", content, count: 3
    assert_select_helper_function "li.ct_active.active", content, count: 1
    assert_select_helper_function_block "li#drafted_tab", content do
      assert_select "a[href=?]", groups_path(filter_params.merge(tab: Group::Status::DRAFTED, view: Group::View::DETAILED)), text: "Drafted (0)"
      assert_select "span#cjs_drafted_count", text: "0"
    end
    assert_select_helper_function_block "li#ongoing_tab", content do
      assert_select "a[href=?]", groups_path(filter_params.merge(tab: Group::Status::ACTIVE, view: Group::View::DETAILED)), text: "Ongoing (23)"
      assert_select "span#cjs_ongoing_count", text: "23"
    end
    assert_select_helper_function_block "li#closed_tab.ct_active.active", content do
      assert_select "a[href=?]", groups_path(filter_params.merge(tab: Group::Status::CLOSED, view: Group::View::DETAILED)), text: "Closed (24)"
      assert_select "span#cjs_closed_count", text: "24"
    end

    counts.merge!(
      drafted: 1,
      proposed: 11,
      pending: 3,
      open: 5,
      rejected: 7,
      withdrawn: 9
    )
    settings.merge!(
      show_drafted_tab: false,
      show_proposed_tab: true,
      show_open_tab: true,
      show_pending_tab: true,
      show_rejected_tab: true,
      show_withdrawn_tab: true,
      show_closed_tab: false
    )
    content = get_tab_box(Group::Status::REJECTED, Group::View::LIST, counts, settings, "my")
    assert_select_helper_function "li", content, count: 6
    assert_select_helper_function "li.ct_active.active", content, count: 1
    assert_select_helper_function_block "li#proposed_tab", content do
      assert_select "a[href=?]", groups_path(filter_params.merge(tab: Group::Status::PROPOSED, view: Group::View::LIST, show: "my")), text: "Proposed (11)"
      assert_select "span#cjs_proposed_count", text: "11"
    end
    assert_select_helper_function_block "li#pending_tab", content do
      assert_select "a[href=?]", groups_path(filter_params.merge(tab: Group::Status::PENDING, view: Group::View::LIST, show: "my")), text: "Available (3)"
      assert_select "span#cjs_pending_count", text: "3"
    end
    assert_select_helper_function_block "li#open_tab", content do
      assert_select "a[href=?]", groups_path(filter_params.merge(tab: Group::Status::ACTIVE, view: Group::View::LIST, show: "my")), text: "Open (5)"
      assert_select "span#cjs_open_count", text: "5"
    end
    assert_select_helper_function_block "li#closed_tab", content do
      assert_select "a[href=?]", groups_path(filter_params.merge(tab: Group::Status::CLOSED, view: Group::View::LIST, show: "my")), text: "Closed (24)"
      assert_select "span#cjs_closed_count", text: "24"
    end
    assert_select_helper_function_block "li#rejected_tab.ct_active.active", content do
      assert_select "a[href=?]", groups_path(filter_params.merge(tab: Group::Status::REJECTED, view: Group::View::LIST, show: "my")), text: "Rejected (7)"
      assert_select "span#cjs_rejected_count", text: "7"
    end
    assert_select_helper_function_block "li#withdrawn_tab", content do
      assert_select "a[href=?]", groups_path(filter_params.merge(tab: Group::Status::WITHDRAWN, view: Group::View::LIST, show: "my")), text: "Withdrawn (9)"
      assert_select "span#cjs_withdrawn_count", text: "9"
    end
  end

  def test_get_member_pictures
    self.stubs(:current_user).returns(users(:f_mentor))
    group = groups(:mygroup)
    member = members(:f_mentor)
    member_pictures = get_member_pictures(group)
    assert_match "<a href=\"/members/3?src=fn\"><div id=\"\" class=\"image_with_initial inline image_with_initial_dimensions_tiny profile-picture-white_and_grey profile-font-styles table-bordered thick-border img-circle m-l-n-xs \" title=\"Good unique name\">GN</div></a>\n", member_pictures.first
    create_profile_picture(member)
    users(:f_mentor).reload
    pictures = get_member_pictures(group)
    assert_select_helper_function_block "a", pictures.first do
      assert_select "img", alt: "Good unique name", src: member.picture_url(:small)
    end 
  end

  def test_group_creation_email_notification_consequences_html
    stub_current_program(programs(:albers))
    assert_equal email_notification_consequences_for_multiple_mailers_html([GroupCreationNotificationToMentor, GroupCreationNotificationToStudents, GroupCreationNotificationToCustomUsers]), group_creation_email_notification_consequences_html
    assert_equal email_notification_consequences_on_action_html(GroupPublishedNotification, div_enclose: true, div_class: "m-b-sm", with_count: true, count: 7), group_creation_email_notification_consequences_html(program: programs(:pbe), count: 7)
  end

  def test_email_notification_consequences_in_group_manage_members_html
    Group::Status.all.each do |status|
      group = Group.where(status: status).first
      next if group.active? || group.pending?
      stub_current_program(group.program)
      assert_equal get_safe_string, email_notification_consequences_in_group_manage_members_html(group)
    end
    active_group = Group.where(status: Group::Status::ACTIVE).first
    stub_current_program(active_group.program)
    # both enable (case 1 1)
    active_group.program.mailer_template_enable_or_disable(GroupMemberAdditionNotificationToNewMember, true)
    active_group.program.mailer_template_enable_or_disable(GroupMemberRemovalNotificationToRemovedMember, true)
    assert_select_helper_function_block "div.m-b-sm.hide.cjs_member_update_info", email_notification_consequences_in_group_manage_members_html(active_group), text: "An email will be sent to the users who were added or removed in the mentoring connection." do
      assert_select "a[href=?]", edit_mailer_template_path(GroupMemberAdditionNotificationToNewMember.mailer_attributes[:uid], src: GA_TRACKER_READ_SYSEMAIL), text: "added"
      assert_select "a[href=?]", edit_mailer_template_path(GroupMemberRemovalNotificationToRemovedMember.mailer_attributes[:uid], src: GA_TRACKER_READ_SYSEMAIL), txet: "removed"
    end
    # case 1 0
    active_group.program.mailer_template_enable_or_disable(GroupMemberAdditionNotificationToNewMember, true)
    active_group.program.mailer_template_enable_or_disable(GroupMemberRemovalNotificationToRemovedMember, false)
    assert_select_helper_function_block "div.m-b-sm.hide.cjs_member_update_info", email_notification_consequences_in_group_manage_members_html(active_group), text: "An email is usually sent to the users if you complete this action, but has been disabled for the case when a user gets removed and enabled only for the case when a user gets added." do
      assert_select "a[href=?]", edit_mailer_template_path(GroupMemberAdditionNotificationToNewMember.mailer_attributes[:uid], src: GA_TRACKER_READ_SYSEMAIL), text: "added"
      assert_select "a[href=?]", edit_mailer_template_path(GroupMemberRemovalNotificationToRemovedMember.mailer_attributes[:uid], src: GA_TRACKER_READ_SYSEMAIL), txet: "removed"
    end
    # case 0 1
    active_group.program.mailer_template_enable_or_disable(GroupMemberAdditionNotificationToNewMember, false)
    active_group.program.mailer_template_enable_or_disable(GroupMemberRemovalNotificationToRemovedMember, true)
    assert_select_helper_function_block "div.m-b-sm.hide.cjs_member_update_info", email_notification_consequences_in_group_manage_members_html(active_group), text: "An email is usually sent to the users if you complete this action, but has been disabled for the case when a user gets added and enabled only for the case when a user gets removed." do
      assert_select "a[href=?]", edit_mailer_template_path(GroupMemberAdditionNotificationToNewMember.mailer_attributes[:uid], src: GA_TRACKER_READ_SYSEMAIL), text: "added"
      assert_select "a[href=?]", edit_mailer_template_path(GroupMemberRemovalNotificationToRemovedMember.mailer_attributes[:uid], src: GA_TRACKER_READ_SYSEMAIL), txet: "removed"
    end
    # case 0 0
    active_group.program.mailer_template_enable_or_disable(GroupMemberAdditionNotificationToNewMember, false)
    active_group.program.mailer_template_enable_or_disable(GroupMemberRemovalNotificationToRemovedMember, false)
    assert_select_helper_function_block "div.m-b-sm.hide.cjs_member_update_info", email_notification_consequences_in_group_manage_members_html(active_group), text: "An email is usually sent to the users who were added or removed in the mentoring connection, but has been disabled. No email will be sent." do
      assert_select "a[href=?]", edit_mailer_template_path(GroupMemberAdditionNotificationToNewMember.mailer_attributes[:uid], src: GA_TRACKER_READ_SYSEMAIL), text: "added"
      assert_select "a[href=?]", edit_mailer_template_path(GroupMemberRemovalNotificationToRemovedMember.mailer_attributes[:uid], src: GA_TRACKER_READ_SYSEMAIL), txet: "removed"
    end
    pending_group = Group.where(status: Group::Status::PENDING).first
    stub_current_program(pending_group.program)
    pending_group.program.mailer_template_enable_or_disable(PendingGroupAddedNotification, true)
    pending_group.program.mailer_template_enable_or_disable(PendingGroupRemovedNotification, true)
    assert_select_helper_function_block "div.m-b-sm.hide.cjs_member_update_info", email_notification_consequences_in_group_manage_members_html(pending_group), text: "An email will be sent to the users who were added or removed in the mentoring connection." do
      assert_select "a[href=?]", edit_mailer_template_path(PendingGroupAddedNotification.mailer_attributes[:uid], src: GA_TRACKER_READ_SYSEMAIL), text: "added"
      assert_select "a[href=?]", edit_mailer_template_path(PendingGroupRemovedNotification.mailer_attributes[:uid], src: GA_TRACKER_READ_SYSEMAIL), txet: "removed"
    end
  end

  def test_get_url_for_group_actions_form
    group_id = groups(:mygroup).id
    assert_equal "/groups/#{group_id}.js?ga_src=ga_src&src=member_groups", get_url_for_group_actions_form("member_groups", :destroy, {id: group_id, ga_src: "ga_src"})
    assert_equal "/groups/#{group_id}?src=profile", get_url_for_group_actions_form("profile", :destroy, {id: group_id, ga_src: "ga_src"})
    assert_equal "/groups/#{group_id}.js", get_url_for_group_actions_form("", :destroy, {id: group_id})

    assert_equal "/groups/update_bulk_actions.js?src=member_groups", get_url_for_group_actions_form("member_groups", :update_bulk_actions)
    assert_equal "/groups/update_bulk_actions?src=profile", get_url_for_group_actions_form("profile", :update_bulk_actions)
    assert_equal "/groups/update_bulk_actions.js", get_url_for_group_actions_form("", :update_bulk_actions)
  end

  def test_groups_sort_fields
    # sort_fields_for_my_connections_view
    sort_fields = groups_sort_fields(true)
    expected_sort_fields = [
      {:field => "active",        :order => :desc,   :label => "Recently active"},
      {:field => "activity",        :order => :desc,  :label => "Most active"},
      {:field => "connected_time",  :order => :desc,   :label => "Recently connected"},
      {:field => "expiry_time",        :order => :asc,   :label => "Expiration time"}]
    assert_equal expected_sort_fields, sort_fields

    # sort_fields_for_admin_view
    sort_fields = groups_sort_fields(false)
    expected_sort_fields = [
      {:field => "connected_time",  :order => :desc,   :label => "Recently connected"},
      {:field => "activity",        :order => :desc,  :label => "Most active"},
      {:field => "activity",        :order => :asc,   :label => "Least active"},
      {:field => "active",        :order => :desc,   :label => "Recently active"},
      {:field => "expiry_time",        :order => :asc,   :label => "Expiration time"}]
    assert_equal expected_sort_fields, sort_fields
    @is_pending_connections_view = true
    sort_fields = groups_sort_fields(false)
    expected_sort_fields = [
      {:field => "active",        :order => :desc,   :label => "Recently active"},
      {:field => "pending_at",        :order => :desc,   :label => "Available Since"}
    ]
    assert_equal expected_sort_fields, sort_fields
    @is_pending_connections_view = false
    @is_proposed_connections_view = true
    sort_fields = groups_sort_fields(false)
    expected_sort_fields = [
      {:field => "created_at", :order => :desc,   :label => "Proposed date (recent first)"},
      {:field => "created_at", :order => :asc,  :label => "Proposed date (oldest first)"}
    ]
    assert_equal expected_sort_fields, sort_fields

    @is_pending_connections_view = false
    @is_proposed_connections_view = false
    @is_rejected_connections_view = true
    sort_fields = groups_sort_fields(false)
    expected_sort_fields = [
      {:field => "created_at", :order => :desc,   :label => "Proposed date (recent first)"},
      {:field => "created_at", :order => :asc,  :label => "Proposed date (oldest first)"},
      {:field => "closed_at", :order => :desc,  :label => "Rejected date (recent first)"},
      {:field => "closed_at", :order => :asc,  :label => "Rejected date (oldest first)"}

    ]
    assert_equal expected_sort_fields, sort_fields
  end

  def test_get_profile_filter_wrapper_for_groups
    title = "rini"
    is_reports_view = true
    result = get_profile_filter_wrapper_for_groups(title, is_reports_view)
    assert_equal_hash({render_panel: false, hide_header_title: true, header_content: content_tag(:b, title), class: "social-feed-box"}, result)

    result = get_profile_filter_wrapper_for_groups(title, false)
    assert_equal_hash({}, result)
  end

  def test_get_input_group_options
    is_reports_view = true
    result = get_input_group_options(is_reports_view)
    assert_equal_hash({class: "hide"}, result)

    result = get_input_group_options(false)
    assert_equal_hash({}, result)
  end

  def test_collapsible_group_search_filter
    inner_block_proc = Proc.new do
      assert_select "div.filter_box" do
        assert_select "input#search_filters_profile_name", name: "search_filters[profile_name]", value: "Sun"
        assert_select "button.btn", onclick: "return GroupSearch.applyFilters();", text: "Go"
        assert_select "a.clear_filter.hide", href: "#", onclick: "jQuery('#search_filters_profile_name').val('');GroupSearch.applyFilters();; return false;", text: "Clear"
      end
    end

    SecureRandom.stubs(:hex).returns("random")
    set_response_text collapsible_group_search_filter("Good Boy", {profile_name: "Sun"})
    assert_select "div.filter_item" do
      assert_select "div#collapsible_random_content.collapse.in" do
        inner_block_proc.call
      end
    end

    set_response_text collapsible_group_search_filter("Test Box", nil)
    assert_select "div.filter_item" do
      assert_no_select "div#collapsible_random_content.collapse.in"
      assert_select "div#collapsible_random_content.collapse" do
        inner_block_proc.call
      end
    end

    set_response_text collapsible_group_search_filter("Test Box", nil, true)
    assert_select "div.social-feed-box" do
      assert_no_select "div#collapsible_random_content.collapse.in"
      assert_select "div#collapsible_random_content.ibox-content" do
        assert_select "div.filter_box" do
          assert_select "input#search_filters_profile_name", name: "search_filters[profile_name]", value: "Sun"
          assert_select "button.btn.hide", onclick: "return GroupSearch.applyFilters();", text: "Go"
          assert_select "a.clear_filter.hide", href: "#", onclick: "jQuery('#search_filters_profile_name').val('');GroupSearch.applyFilters();; return false;", text: "Clear"
        end
      end
    end
  end

  def test_slots_availability_filter_allowed_tab
    [Group::Status::PENDING, Group::Status::ACTIVE, Group::Status::CLOSED, Group::Status::REJECTED, Group::Status::WITHDRAWN].each do |tab|
      assert slots_availability_filter_allowed_tab?(tab)
    end
    [Group::Status::INACTIVE, Group::Status::DRAFTED, Group::Status::PROPOSED].each do |tab|
      assert_false slots_availability_filter_allowed_tab?(tab)
    end
  end

  def test_get_mentor_request_popup_footer
    stubs(:wob_member).returns(members(:f_mentor))
    stubs(:_mentoring).returns("mentoring")
    assert_equal get_mentor_request_popup_footer(0, 4, Program::ConnectionLimit::BOTH), "<div class=\"text-center text-muted\" style=\"font-weight:bold\">You are currently mentoring 4 users and cannot accept requests from more. <a href=\"/members/3/edit?focus_settings_tab=true&amp;scroll_to=user_max_connections_limit\">Change</a></div>"
    assert_equal get_mentor_request_popup_footer(0, 4, Program::ConnectionLimit::NONE), "<div class=\"text-center text-muted\" style=\"font-weight:bold\">You are currently mentoring 4 users and cannot accept requests from more. </div>"
    assert_equal get_mentor_request_popup_footer(3, 4, Program::ConnectionLimit::BOTH), "<div class=\"text-center text-muted\" style=\"font-weight:bold\">You are currently mentoring 4 users and can accept requests from 3 more. <a href=\"/members/3/edit?focus_settings_tab=true&amp;scroll_to=user_max_connections_limit\">Change</a></div>"
    assert_equal get_mentor_request_popup_footer(3, 4, Program::ConnectionLimit::NONE), "<div class=\"text-center text-muted\" style=\"font-weight:bold\">You are currently mentoring 4 users and can accept requests from 3 more. </div>"
  end

  def test_collapsible_group_role_slots_filter_inner_builder
    set_response_text collapsible_group_role_slots_filter_inner_builder(programs(:albers), "title", :key, [RoleConstants::MENTOR_NAME])
    assert_select "label.sr-only", for: "search_filters_key", text: "title"
    assert_select "label.sr-only", for: "search_filters_key_tmp", text: "title"
    assert_select "select#search_filters_key.form-control.input-sm.no-padding.no-border", multiple: "multiple", name: "search_filters[key][]" do
      assert_select "option", value: "mentor", selected: "selected", text: "Mentor"
      assert_select "option", value: "student", text: "Student"
    end
    assert_select "a#reset_filter_key.clear_filter.btn.btn-xs.hide", href: "#", onclick: "jQuery(\"#search_filters_key\").select2(\"val\", \"\"); GroupSearch.applyFilters();; return false;", text: "Clear"
    assert_select "script", text: "\n//<![CDATA[\njQuery('#search_filters_key').select2(); jQuery('label[for=search_filters_key_tmp]').attr('for', 'search_filters_key');\n//]]>\n"
  end

  def test_collapsible_group_role_slots_filter
    program = programs(:albers)
    str = collapsible_group_role_slots_filter(program, {})
    assert_match /Mentoring Connection Slots Availability/, str
    assert_match /Slots Available For Any Of/, str
    assert_match /<option value="mentor">Mentor<\/option>/, str
    assert_match /<option value="student">Student<\/option>/, str
    assert_match /Slots Unavailable For Any Of/, str
    assert_match /<option selected="selected" value="mentor">Mentor<\/option>/, collapsible_group_role_slots_filter(program, {slots_available: [RoleConstants::MENTOR_NAME]})
  end

  def test_show_role_availability_slot_filters
    program = programs(:pbe)
    assert show_role_availability_slot_filters?(program, true, Group::Status::ACTIVE)
    program.roles.for_mentoring.each { |role| role.update_attributes!(slot_config: nil) }
    assert_false show_role_availability_slot_filters?(program, true, Group::Status::ACTIVE)
  end

  def test_collapsible_group_member_filters
    SecureRandom.stubs(:hex).returns("random")
    set_response_text collapsible_group_member_filters(programs(:albers), {:modern_filter => true})
    mentor_role = programs(:albers).get_role(RoleConstants::MENTOR_NAME)

    assert_select "div.filter_item", :count => 2

    assert_select "div#collapsible_random_header", :onclick => "ChronusEffect.ExpandSection('mentor_#{mentor_role.id}', [])", :text => /Mentor/
    assert_select "div#collapsible_random_content" do
      assert_select "div.filter_box" do
        assert_select "input#member_filters_#{mentor_role.id}", :name => "member_filters[#{mentor_role.id}]"
        assert_select "button.btn", :onclick => "return GroupSearch.applyFilters();", :text => "Go"
        assert_select "a.clear_filter.hide", :href => "#", :onclick => "jQuery('#member_filters_#{mentor_role.id}').val('');GroupSearch.applyFilters();; return false;", :text => "Clear", :id => "reset_filter_member_filter_#{mentor_role.id}"
      end
    end

    set_response_text collapsible_group_member_filters(programs(:albers), {:modern_filter => true, is_reports_view: true})
    assert_select "div.social-feed-box" do
      assert_no_select "div#collapsible_random_content.collapse.in"
      assert_select "div#collapsible_random_content.ibox-content" do
        assert_select "div.filter_box" do
          assert_select "input#member_filters_#{mentor_role.id}", :name => "member_filters[#{mentor_role.id}]"
          assert_select "button.btn.hide", onclick: "return GroupSearch.applyFilters();", text: "Go"
          assert_select "a.clear_filter.hide", :href => "#", :onclick => "jQuery('#member_filters_#{mentor_role.id}').val('');GroupSearch.applyFilters();; return false;", :text => "Clear", :id => "reset_filter_member_filter_#{mentor_role.id}"
        end
      end
    end
  end

  def test_can_write_to_group
    # Expired groups
    g =  groups(:group_4)
    assert !g.active?
    assert !can_write_to_group?(g, g.mentors.first)

    # Admin cannot add goal
    g = groups(:multi_group)
    assert g.active?
    assert !can_write_to_group?(g, g.program.admin_users.first)
    assert can_write_to_group?(g, g.mentors.first)
    assert can_write_to_group?(g, g.students.first)
  end

  def test_get_leave_connection_popup_head_text
    quick_link_text = get_leave_connection_popup_head_text(true, "head")
    popup_text = get_leave_connection_popup_head_text(true, "content")
    assert_equal "Close Mentoring Connection", quick_link_text
    assert_equal "closing the Mentoring Connection", popup_text

    quick_link_text = get_leave_connection_popup_head_text(false, "head")
    popup_text = get_leave_connection_popup_head_text(false, "content")
    assert_equal "Leave Mentoring Connection", quick_link_text
    assert_equal "leaving the Mentoring Connection", popup_text
  end

  def test_get_group_notes_content
    g = groups(:mygroup)
    assert_nil get_group_notes_content(g, false)
    g.notes = "Test notes"
    g.save!

    content = get_group_notes_content(g, false)
    assert_match /Notes/, content
    assert_match /Test notes/, content
    assert_no_match(/popover/, content)

    content = get_group_notes_content(g, true)
    assert_match /View Notes/, content
    assert_match /popover\(\{html: true, placement: \"bottom\", title:.*Notes by administrator.*content:.*Test notes/, content
  end

  def test_get_group_expiry_content
    group = groups(:mygroup)
    v1_content = get_group_expiry_content(group)
    v1_content_only_values = get_group_expiry_content(group, false, only_values: true)
    v2_content = get_group_expiry_content(group, true)
    assert_match /Expires in/, v1_content
    assert_no_match(/Expires in/, v2_content)
    assert_match /#{distance_of_time_in_words(Time.now, group.expiry_time)} \(#{formatted_time_in_words(group.expiry_time, :no_ago => true, :no_time => true)}\)/, v1_content
    assert_no_match(/#{distance_of_time_in_words(Time.now, group.expiry_time)} \(#{formatted_time_in_words(group.expiry_time, :no_ago => true, :no_time => true)}\)/, v2_content)
    assert_match /#{formatted_time_in_words(group.expiry_time, :no_ago => true, :no_time => true)}/, v2_content
    assert_equal "Expires in", v1_content_only_values[0]
    assert_match /#{distance_of_time_in_words(Time.now, group.expiry_time)} \(#{formatted_time_in_words(group.expiry_time, :no_ago => true, :no_time => true)}\)/, v1_content_only_values[1]

    group.expiry_time = 2.days.from_now
    group.save!
    assert_match /expires soon/, get_group_expiry_content(group, true)
    assert_no_match /expires soon/, get_group_expiry_content(group, true, show_expired_text: false)
    assert_match /expires soon/, get_group_expiry_content(group, false)
    assert_no_match /expires soon/, get_group_expiry_content(group, false, show_expired_text: false)

    group.termination_mode = nil
    group.closed_by = nil
    group.termination_reason = 'My termination_reason'
    group.save(:validate => false)

    group.status = Group::Status::CLOSED
    group.closed_at = Time.now
    group.closed_by = users(:f_admin)
    group.termination_mode = Group::TerminationMode::ADMIN
    group.closure_reason_id = group.get_auto_terminate_reason_id
    group.save!
    assert_match /groups_expires_in/, get_group_expiry_content(group, true)
  end

  def test_get_group_cannot_be_reactivated_text
    program = programs(:albers)
    program_roles = program.roles.group_by(&:name)
    str1 = get_group_cannot_be_reactivated_text(program, ({ program_roles[RoleConstants::MENTOR_NAME].first => [users(:f_mentor)] }))
    assert_equal "<p>You cannot reactivate the group as Good unique name is no longer a mentor.<\/p>", str1
    str2 = get_group_cannot_be_reactivated_text(program, ({ program_roles[RoleConstants::STUDENT_NAME].first => [users(:f_student)]}))
    assert_equal "<p>You cannot reactivate the group as student example is no longer a student.<\/p>", str2
    str3 = get_group_cannot_be_reactivated_text(program, ({ program_roles[RoleConstants::MENTOR_NAME].first => [users(:f_mentor)], program_roles[RoleConstants::STUDENT_NAME].first => [users(:f_student)]}))
    assert_equal "<p>You cannot reactivate the group as Good unique name is no longer a mentor and student example is no longer a student.<\/p>", str3
    str4 = get_group_cannot_be_reactivated_text(program, ({ program_roles[RoleConstants::MENTOR_NAME].first => [users(:f_mentor),users(:f_student),users(:f_admin)] }))
    assert_equal "<p>You cannot reactivate the group as Good unique name, student example and Freakin Admin (Administrator) are no longer mentors.<\/p>", str4
  end

  def test_get_group_cannot_be_duplicated_text
    program = programs(:albers)
    program_roles = program.roles.group_by(&:name)
    str1 = get_group_cannot_be_duplicated_text(program, ({ program_roles[RoleConstants::MENTOR_NAME].first => [users(:f_mentor)] }))
    assert_select_helper_function "p", str1, text: "You cannot duplicate the mentoring connection as Good unique name is no longer a mentor"
    str2 = get_group_cannot_be_duplicated_text(program, ({ program_roles[RoleConstants::STUDENT_NAME].first => [users(:f_student)]}))
    assert_select_helper_function "p", str2, text: "You cannot duplicate the mentoring connection as student example is no longer a student"
    str3 = get_group_cannot_be_duplicated_text(program, ({ program_roles[RoleConstants::MENTOR_NAME].first => [users(:f_mentor)], program_roles[RoleConstants::STUDENT_NAME].first => [users(:f_student)]}))
    assert_select_helper_function "p", str3, text: "You cannot duplicate the mentoring connection as Good unique name is no longer a mentor and student example is no longer a student"
    str4 = get_group_cannot_be_duplicated_text(program, ({ program_roles[RoleConstants::MENTOR_NAME].first => [users(:f_mentor),users(:f_student),users(:f_admin)] }))
    assert_select_helper_function "p", str4, text: "You cannot duplicate the mentoring connection as Good unique name, student example and Freakin Admin (Administrator) are no longer mentors"
  end

  def test_get_groups_bulk_actions_box_for_single_type
    stubs(:current_program_or_organization).returns(programs(:albers))

    programs(:albers).update_attribute(:allow_one_to_many_mentoring, false)
    content = get_groups_bulk_actions_box(Group::Status::ACTIVE, Group::View::LIST, programs(:albers))
    assert_nil content.match(/bulk_action_add_remove_#{Group::Status::ACTIVE}/)
    content = get_groups_bulk_actions_box(Group::Status::ACTIVE, Group::View::DETAILED, programs(:albers))
    assert_nil content.match(/bulk_action_add_remove_#{Group::Status::ACTIVE}/)
    content = get_groups_bulk_actions_box(Group::Status::DRAFTED, Group::View::LIST, programs(:albers))
    assert_nil content.match(/bulk_action_add_remove_#{Group::Status::ACTIVE}/)
    content = get_groups_bulk_actions_box(Group::Status::DRAFTED, Group::View::DETAILED, programs(:albers))
    assert_nil content.match(/bulk_action_add_remove_#{Group::Status::ACTIVE}/)

    programs(:albers).update_attribute(:allow_one_to_many_mentoring, true)
    content = get_groups_bulk_actions_box(Group::Status::ACTIVE, Group::View::LIST, programs(:albers))
    assert_no_match /Add\/Remove Owners/, content
    assert_match /bulk_action_private_notes/, content
    assert_match /bulk_action_add_remove_#{Group::Status::ACTIVE}/, content

    content = get_groups_bulk_actions_box(Group::Status::ACTIVE, Group::View::DETAILED, programs(:albers))
    assert_no_match /Add\/Remove Owners/, content
    assert_match /bulk_action_private_notes/, content
    assert_match /bulk_action_add_remove_#{Group::Status::ACTIVE}/, content

    content = get_groups_bulk_actions_box(Group::Status::DRAFTED, Group::View::LIST, programs(:albers))
    assert_no_match /Add\/Remove Owners/, content
    assert_match /bulk_action_private_notes/, content
    assert_match /bulk_action_add_remove_#{Group::Status::DRAFTED}/, content

    content = get_groups_bulk_actions_box(Group::Status::DRAFTED, Group::View::DETAILED, programs(:albers))
    assert_no_match /Add\/Remove Owners/, content
    assert_match /bulk_action_private_notes/, content
    assert_match /bulk_action_add_remove_#{Group::Status::DRAFTED}/, content

    content = get_groups_bulk_actions_box(Group::Status::CLOSED, Group::View::LIST, programs(:albers))
    assert_no_match /Add\/Remove Owners/, content
    assert_match /bulk_action_private_notes/, content
    assert_nil content.match(/bulk_action_add_remove/)

    content = get_groups_bulk_actions_box(Group::Status::CLOSED, Group::View::DETAILED, programs(:albers))
    assert_no_match /Add\/Remove Owners/, content
    assert_match /Duplicate Mentoring Connections/, content
    assert_match /bulk_action_private_notes/, content
    assert_nil content.match(/bulk_action_add_remove/)

    content = get_groups_bulk_actions_box(Group::Status::PROPOSED, Group::View::DETAILED, programs(:pbe))
    assert_match /bulk_action_private_notes/, content
    assert_nil content.match(/bulk_action_add_remove/)
    assert_match /Accept & Make Available/, content
    assert_match /Reject Mentoring Connection/, content
    assert_match /Export Mentoring Connections as CSV/, content
    assert_match /Send Message/, content
    assert_match /Add\/Remove Owners/, content
    assert_no_match /Make Mentoring Connections Available/, content
    assert_no_match /Discard Mentoring Connection/, content
    assert_no_match /Assign Mentoring Connection Plan Template/, content
    assert_no_match /Set Expiration Date/, content
    assert_no_match /Close Mentoring Connection/, content
    assert_no_match /Reactivate Mentoring Connection/, content
    assert_no_match /Publish Mentoring Connection/, content

    content = get_groups_bulk_actions_box(Group::Status::REJECTED, Group::View::DETAILED, programs(:pbe))
    assert_no_match /bulk_action_private_notes/, content
    assert_nil content.match(/bulk_action_add_remove/)
    assert_no_match /Accept & Make Available/, content
    assert_no_match /Reject Mentoring Connection/, content
    assert_match /Export Mentoring Connections as CSV/, content
    assert_match /Send Message/, content
    assert_no_match /Add\/Remove Owners/, content
    assert_no_match /Make Mentoring Connections Available/, content
    assert_no_match /Discard Mentoring Connection/, content
    assert_no_match /Assign Mentoring Connection Plan Template/, content
    assert_no_match /Set Expiration Date/, content
    assert_no_match /Close Mentoring Connection/, content
    assert_no_match /Reactivate Mentoring Connection/, content
    assert_no_match /Publish Mentoring Connection/, content

    content = get_groups_bulk_actions_box(Group::Status::WITHDRAWN, Group::View::DETAILED, programs(:pbe))
    assert_no_match /bulk_action_private_notes/, content
    assert_nil content.match(/bulk_action_add_remove/)
    assert_no_match /Accept & Make Available/, content
    assert_no_match /Reject Mentoring Connection/, content
    assert_match /Export Mentoring Connections as CSV/, content
    assert_match /Send Message/, content
    assert_no_match /Add\/Remove Owners/, content
    assert_no_match /Make Mentoring Connections Available/, content
    assert_no_match /Discard Mentoring Connection/, content
    assert_no_match /Assign Mentoring Connection Plan Template/, content
    assert_no_match /Set Expiration Date/, content
    assert_no_match /Close Mentoring Connection/, content
    assert_no_match /Reactivate Mentoring Connection/, content
    assert_no_match /Publish Mentoring Connection/, content

    content = get_groups_bulk_actions_box(Group::Status::PENDING, Group::View::DETAILED, programs(:pbe))
    assert_match /bulk_action_private_notes/, content
    assert_match /bulk_action_add_remove/, content
    assert_no_match /Accept & Make Available/, content
    assert_no_match /Reject Mentoring Connection/, content
    assert_match /Export Mentoring Connections as CSV/, content
    assert_match /Send Message/, content
    assert_no_match /Make Mentoring Connections Available/, content
    assert_match /Publish Mentoring Connection/, content
    assert_no_match /Discard Mentoring Connection/, content
    assert_match /Assign Mentoring Connection Plan Template/, content
    assert_match /Add\/Remove Owners/, content
    assert_no_match /Set Expiration Date/, content
    assert_no_match /Close Mentoring Connection/, content
    assert_no_match /Reactivate Mentoring Connection/, content

    content = get_groups_bulk_actions_box(Group::Status::CLOSED, Group::View::DETAILED, programs(:pbe))
    assert_no_match /Add\/Remove Owners/, content
    assert_no_match /Duplicate Mentoring Connections/, content

    content = get_groups_bulk_actions_box(Group::Status::DRAFTED, Group::View::DETAILED, programs(:pbe))
    assert_no_match /Add\/Remove Owners/, content
  end

  def test_display_mentoring_model_info
    mentoring_model = programs(:albers).default_mentoring_model
    content = display_mentoring_model_info(mentoring_model)
    assert_match /Mentoring Connection Plan Template/, content
    assert_match link_to(mentoring_model.title + " (Default)", view_mentoring_model_path(mentoring_model)), content
    assert_equal link_to(mentoring_model.title + " (Default)", view_mentoring_model_path(mentoring_model)), display_mentoring_model_info(mentoring_model, true)
    assert_equal mentoring_model.title + " (Default)", display_mentoring_model_info(mentoring_model, true, true)

    mentoring_model = nil
    content = display_mentoring_model_info(mentoring_model)
    assert_match /Mentoring Connection Plan Template/, content
    assert_match /None/, content
    assert_equal "", display_mentoring_model_info(mentoring_model, true)
    assert_equal "", display_mentoring_model_info(mentoring_model, true, true)
  end

  def test_max_number_of_users_in_group_field
    program = programs(:pbe)
    student_role = program.get_role(RoleConstants::STUDENT_NAME)

    content = max_number_of_users_in_group_field(program, :role => student_role, :show_help_text => true)
    assert_match /Maximum number of students who can participate/, content
    assert_match /input/, content
    assert_match /Please note that this limit includes you/, content
    assert_no_match /hide/, content

    student_role.update_attributes!(slot_config: RoleConstants::SlotConfig::REQUIRED)
    content = max_number_of_users_in_group_field(program, :role => student_role, :show_help_text => false)
    assert_match /Maximum number of students who can participate */, content
    assert_match /Maximum number of students who can participate/, content
    assert_match /input/, content
    assert_match /Please note that this limit includes you/, content
    assert_match /hide/, content

    student_role.update_attributes!(slot_config: nil)
    content = max_number_of_users_in_group_field(program, :role => student_role)
    assert_no_match /Maximum number of students who can participate/, content
  end

  def test_group_members_list
    program = programs(:albers)
    student_role = fetch_role(:albers, :student)
    group = create_group(name: "Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    label, content = group_members_list(group, student_role)
    assert_select_helper_function "span[class=\"text-muted\"]", content, text: "No users in the mentoring connection yet."
    assert_equal "Students", label

    group.update_members([], [users(:f_student)])
    group.reload
    label, content = group_members_list(group, student_role)
    assert_select_helper_function "a[class=\"nickname\"][href=\"/members/2\"][title_method=\"name\"]", content, text:"student example"
    assert_equal "Student", label

    group.membership_of(users(:f_student)).update_attributes!(owner: true)
    label, content = group_members_list(group.reload, student_role)
    assert_match "<a title_method=\"name\" class=\"nickname\" href=\"/members/2\">student example</a></span></span> (Owner)", content
    assert_equal "Student", label

    group.update_members([], [], users(:f_admin))
    group.reload
    label, content = group_members_list(group, student_role)
    assert_select_helper_function "span[class=\"text-muted\"]", content, text: "No users in the mentoring connection yet."
    assert_equal "Students", label

    program = programs(:pbe)
    group = groups(:group_pbe_2)
    @current_user = users(:f_admin_pbe)
    ProjectRequest.expects(:get_project_request_path_for_privileged_users).with(@current_user, filters: { project: group.name }, from_quick_link: nil).returns(project_requests_path(from_quick_link: nil, filters: { project: group.name }))
    ProjectRequest.expects(:get_project_request_path_for_privileged_users).with(@current_user, filters: { project: group.name }).returns(project_requests_path(from_quick_link: nil, filters: { project: group.name }))
    label, content = group_members_list(group, program.roles.find{|role| role.name == RoleConstants::STUDENT_NAME }, show_requests_and_slots: true, members_to_show: 1)
    assert_match "student_c example", content
    assert_match "student_h example", content
    assert_match /href=\"\/project_requests\?filters\%5Bproject\%5D=project_c\".*1.*href=\"\/project_requests\?filters\%5Bproject\%5D=project_c\".*request pending/, content
    assert_equal "Students", label

    group = groups(:group_pbe)
    ProjectRequest.expects(:get_project_request_path_for_privileged_users).with(@current_user, filters: { project: group.name }, from_quick_link: nil).returns(project_requests_path(from_quick_link: nil, filters: { project: group.name }))
    ProjectRequest.expects(:get_project_request_path_for_privileged_users).with(@current_user, filters: { project: group.name }).returns(project_requests_path(from_quick_link: nil, filters: { project: group.name }))
    create_project_request(group, users(:f_student_pbe))
    _label, content = group_members_list(group, program.roles.find{|role| role.name == RoleConstants::STUDENT_NAME }, show_requests_and_slots: true, members_to_show: 1)
    assert_select_helper_function "big", content, text: "1"
    assert_select_helper_function "a", content, text: "request pending"
  end

  def test_get_active_groups_navigation_links
    user = users(:f_student)
    groups_to_render = [groups(:mygroup), groups(:group_2)]

    tab_content = get_active_groups_navigation_links(groups_to_render, user, false)
    group_tabs = safe_join(tab_content, "")
    assert_match /name &amp; madankumarrajan/, group_tabs
    assert_match /mentor &amp; example/, group_tabs
  end

  def test_get_groups_content_inside_connection_navigation_header
    user = users(:f_student)
    groups_to_render = [groups(:mygroup), groups(:group_2)]
    all_groups_size = 3

    Group.any_instance.stubs(:badge_count).returns(5)

    tab_content = get_groups_content_inside_connection_navigation_header(groups_to_render, all_groups_size, user)
    group_tabs = safe_join(tab_content, "")

    assert_match /name &amp; madankumarrajan/, group_tabs
    assert_match /mentor &amp; example/, group_tabs
    assert_match /View All/, group_tabs

    # View all should be there in all cases
    tab_content = get_groups_content_inside_connection_navigation_header(groups_to_render, 2, user)
    group_tabs = safe_join(tab_content, "")

    assert_match /name &amp; madankumarrajan/, group_tabs
    assert_match /mentor &amp; example/, group_tabs
    assert_match "View All", group_tabs

    tab_content = get_groups_content_inside_connection_navigation_header([], 0, user)
    group_tabs = safe_join(tab_content, "")
    assert_nil group_tabs.match("View All")

    #Only Closed groups
    student = groups(:mygroup).students.first
    student.groups.update_all(status: Group::Status::CLOSED)
    tab_content = safe_join(get_groups_content_inside_connection_navigation_header(groups_to_render, 0, student), "")
    assert_select_helper_function "a.navigation_tab_link", tab_content, text: "Closed"
  end

  def test_get_meetings_link_for_connection_tab_header
    user = users(:f_student)
    stubs(:wob_member).returns(members(:f_student))

    User.any_instance.stubs(:can_be_shown_meetings_listing?).returns(true)
    Program.any_instance.stubs(:calendar_enabled?).returns(true)

    assert_equal [], get_meetings_link_for_connection_tab_header(user, [])

    Program.any_instance.stubs(:calendar_enabled?).returns(false)
    tab_content = get_meetings_link_for_connection_tab_header(user, [])

    assert_match /Meetings/, tab_content[0]

    User.any_instance.stubs(:can_be_shown_meetings_listing?).returns(false)
    assert_equal [], get_meetings_link_for_connection_tab_header(user, [])

    Program.any_instance.stubs(:calendar_enabled?).returns(true)
    assert_equal [], get_meetings_link_for_connection_tab_header(user, [])
  end

  def test_get_non_pbe_subtabs
    user = users(:mkr_student)
    program = programs(:albers)
    stubs(:wob_member).returns(members(:mkr_student))

    users(:not_requestable_mentor).update_attribute(:max_connections_limit, 10)
    
    group1 = groups(:mygroup)
    group1.update_column(:last_member_activity_at, Time.now-6.hours)

    group2 = create_group(name: "Group 2", students: [user], mentors: [users(:not_requestable_mentor)], program: program, last_member_activity_at: Time.now-10.hours)
    group3 = create_group(name: "Group 3", students: [user], mentors: [users(:requestable_mentor)], program: program, last_member_activity_at: Time.now-1.day)
    group4 = create_group(name: "Group 4", students: [user], mentors: [users(:robert)], program: program, status: Group::Status::PENDING, last_member_activity_at: Time.now-2.days)

    assert_equal_unordered [group1, group2, group3], user.groups.reload.active

    User.any_instance.stubs(:can_be_shown_meetings_listing?).returns(true)
    Program.any_instance.stubs(:calendar_enabled?).returns(true)

    group_tabs = get_non_pbe_subtabs(user)

    assert_match /name &amp; madankumarrajan/, group_tabs
    assert_match /Group 2/, group_tabs
    assert_match /Group 3/, group_tabs
    assert_match "View All", group_tabs
    assert_nil group_tabs.match(/Group 4/)
    assert_nil group_tabs.match(/Meetings/)

    group4.update_column(:status, Group::Status::ACTIVE)

    group_tabs = get_non_pbe_subtabs(user)

    assert_match /name &amp; madankumarrajan/, group_tabs
    assert_match /Group 2/, group_tabs
    assert_match /View All/, group_tabs
    assert_nil group_tabs.match(/Group 4/)
    assert_nil group_tabs.match(/Group 3/)

    group3.update_column(:status, Group::Status::CLOSED)
    group4.update_column(:status, Group::Status::CLOSED)

    Program.any_instance.stubs(:calendar_enabled?).returns(false)

    group_tabs = get_non_pbe_subtabs(user)

    assert_match /name &amp; madankumarrajan/, group_tabs
    assert_match /Group 2/, group_tabs
    assert_match /Meetings/, group_tabs
  end

  def test_get_available_projects
    user = users(:f_mentor_pbe)
    teacher_role = roles("16_teacher")
    teacher_role.update_attributes(for_mentoring: false)
    user.roles << teacher_role

    Group.expects(:available_projects).with(user.roles.pluck(:id) - [teacher_role.id]).returns([Group.last])
    assert_equal_unordered [Group.last], get_available_projects(user)
  end

  def test_get_pbe_subtabs
    program = programs(:albers)
    active_pbe_group = groups(:group_pbe)
    stubs(:wob_member).returns(members(:f_student))
    student_tabs = get_pbe_subtabs(users(:f_student), program)
    fetch_role(:albers, :student).add_permission('send_project_request')
    User.any_instance.stubs(:can_be_shown_meetings_listing?).returns(true)
    User.any_instance.stubs(:can_create_group_without_approval?).returns(false)
    Program.any_instance.stubs(:calendar_enabled?).returns(true)

    pbe_student_tabs = get_pbe_subtabs(users(:f_student_pbe).reload, programs(:pbe))

    tab_content = []
    tab_content << content_tag(:li, link_to(get_icon_content("fa fa-fw fa-group") + "tab_constants.sub_tabs.all_resources".translate, groups_path))
    fetch_role(:pbe, :student).add_permission('propose_groups')
    self.stubs(:get_groups_content_inside_connection_navigation_header).returns(tab_content)

    Program.any_instance.stubs(:calendar_enabled?).returns(false)

    pbe_student_tabs_2 = get_pbe_subtabs(users(:f_student_pbe).reload, programs(:pbe))

    assert_match /Discover/, pbe_student_tabs
    assert_nil student_tabs.match(/Discover/)

    assert_select_helper_function "div", get_pbe_subtabs(users(:pbe_mentor_0), programs(:pbe)), text: "Discover"
    assert_select_helper_function "span.badge", get_pbe_subtabs(users(:pbe_mentor_0), programs(:pbe)), text: "5"
    active_pbe_group.update_column(:pending_at, 2.days.ago)
    assert_select_helper_function "span.badge", get_pbe_subtabs(users(:pbe_mentor_0), programs(:pbe)), text: "6"

    assert_match /All mentoring connections/, student_tabs
    assert_nil pbe_student_tabs.match(/All mentoring connections/)

    assert_match /Meetings/, pbe_student_tabs_2
    assert_match /View All/, pbe_student_tabs_2
    assert_match /Propose a new mentoring connection/, pbe_student_tabs_2
    assert_match /My proposed mentoring connections/, pbe_student_tabs_2
    assert_nil student_tabs.match(/Propose a new mentoring connection/)
    assert_nil student_tabs.match(/Meetings/)
    assert_nil student_tabs.match(/My proposed mentoring connections/)
    assert_nil pbe_student_tabs.match(/Propose a new mentoring connection/)
    assert_nil pbe_student_tabs.match(/My proposed mentoring connections/)

    self.stubs(:get_groups_content_inside_connection_navigation_header).returns([])
    User.any_instance.stubs(:can_be_shown_proposed_groups?).returns(false)
    pbe_student_tabs_3 = get_pbe_subtabs(users(:f_student_pbe).reload, programs(:pbe))
    assert_no_match(/My proposed mentoring connections/, pbe_student_tabs_3)

    User.any_instance.stubs(:can_create_group_without_approval?).returns(true)
    User.any_instance.stubs(:can_be_shown_proposed_groups?).returns(true)
    pbe_student_tabs_3 = get_pbe_subtabs(users(:f_student_pbe).reload, programs(:pbe))
    assert_no_match(/Start a new mentoring connections/, pbe_student_tabs_3)
  end

  def test_find_new_projects_title
    fetch_role(:albers, :student).add_permission('send_project_request')
    assert_equal "Find new mentoring connections", find_new_projects_title(users(:f_student).reload)
    assert_equal "All mentoring connections", find_new_projects_title(users(:f_mentor).reload)
  end

  def test_render_group_name
    GroupsHelperTest.any_instance.stubs(:super_console?).returns(false)
    enable_project_based_engagements!
    program = programs(:albers)
    published_group = groups(:mygroup)
    published_group.global = true
    published_group.save!
    group_text = render_group_name(published_group, users(:f_admin))
    assert_match /groups\/#{published_group.id}/, group_text
    assert_match /#{h published_group.name}/, group_text

    # disable link options test
    group_text = render_group_name(published_group, users(:f_admin), :disable_link => true)
    assert_no_match /groups\/#{published_group.id}/, group_text
    assert_match /#{published_group.name}/, group_text

    group_text = render_group_name(published_group, users(:mentor_1))
    assert_match /groups\/#{published_group.id}\/profile/, group_text
    assert_match /#{h published_group.name}/, group_text

    pending_group = create_group(name: "Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    group_text = render_group_name(pending_group, users(:mentor_1))
    assert_no_match /groups\/#{pending_group.id}\/profile/, group_text
    assert_match /#{h pending_group.name}/, group_text

    pending_group.global = true
    pending_group.save!
    group_text = render_group_name(pending_group, users(:mentor_1))
    assert_match /groups\/#{pending_group.id}\/profile/, group_text
    assert_match /#{h pending_group.name}/, group_text

    drafted_group = groups(:drafted_group_1)
    drafted_group.global = true
    drafted_group.save!
    group_text = render_group_name(drafted_group, users(:f_admin))
    assert_match /#{h drafted_group.name}/, group_text
    assert_match /groups\/#{drafted_group.id}\/profile/, group_text

    program.enable_feature(FeatureName::CONNECTION_PROFILE, false)
    program.reload
    drafted_group = groups(:drafted_group_1)
    group_text = render_group_name(drafted_group, users(:f_admin))
    assert_match /#{h drafted_group.name}/, group_text
    assert_match /groups\/#{drafted_group.id}\/profile/, group_text
    group_text = render_group_name(drafted_group, users(:f_admin), find_new: true)
    assert_match /#{h drafted_group.name}/, group_text
    assert_match /groups\/#{drafted_group.id}\/profile\?from_find_new=true/, group_text
  end

  def test_can_access_groups_show
    group = groups(:mygroup)
    assert can_access_groups_show?(group, users(:f_admin))
    assert can_access_groups_show?(group, group.mentors.first)
    assert can_access_groups_show?(group, group.students.first)
    assert_false can_access_groups_show?(group, users(:student_1))
    assert_false can_access_groups_show?(group, users(:mentor_2))
  end

  def test_group_notes_label
    group_notes = group_notes_label(mentoring_connection: "group", admins: "administrators")
    assert_match /Notes/, group_notes
    assert_match /fa-lock/, group_notes
    assert_match /Type your notes for this group. This will be visible only to the administrators./, group_notes
    group_notes = group_notes_label(mentoring_connections: "groups", admins: "administrators", bulk: true)
    assert_match /Notes/, group_notes
    assert_match /fa-lock/, group_notes
    assert_match /Type your notes for these groups. This is optional and will be visible only to the administrators./, group_notes
  end

  def test_connection_membership_terms
    group = groups(:mygroup)
    role_terms_hash = connection_membership_terms(group)
    mentor_user = group.mentors.first
    student_user = group.students.first
    assert_equal "Mentor", role_terms_hash[mentor_user.id]
    assert_equal "Student", role_terms_hash[student_user.id]
  end

  def test_display_group_in_auto_complete
    group = groups(:mygroup)
    program = programs(:albers)
    organization = programs(:org_primary)
    assert_equal "Students:    mkr_student madankumarrajan<br />Mentors:    Good unique name", display_group_in_auto_complete(group)
    teacher_role = create_role(name: "teacher", program: program, for_mentoring: true)
    user = users(:student_7)
    user.roles += [teacher_role]
    user.save!
    group.update_members(group.mentors, group.students, nil, other_roles_hash: {teacher_role => [user]})
    assert_equal "Students:    mkr_student madankumarrajan<br />Mentors:    Good unique name<br />Teachers:    student_h example", display_group_in_auto_complete(group.reload)
    custom_term = program.roles.find_by(name: RoleConstants::MENTOR_NAME).customized_term
    custom_term.pluralized_term = "Gurus"
    custom_term.save!
    group.students += [users(:student_9)]
    group.save!
    assert_equal "Students:    mkr_student madankumarrajan and student_j ...<br />Gurus:    Good unique name<br />Teachers:    student_h example", display_group_in_auto_complete(group.reload)
  end

  def test_render_memberships
    group = groups(:mygroup)
    program = group.program
    allow_one_to_many_mentoring_for_program(program)
    mentor_role = program.get_role(RoleConstants::MENTOR_NAME)
    student_role = program.get_role(RoleConstants::STUDENT_NAME)
    assert_equal "Good unique name <robert@example.com>", render_memberships(group, mentor_role)

    cloned_group = Group::CloneFactory.new(group, program).clone
    result = render_memberships(cloned_group, mentor_role, true)
    assert_equal "Good unique name <robert@example.com>", result

    group.update_members(group.mentors, group.students + [users(:student_1)])
    assert_equal "Good unique name <robert@example.com>", render_memberships(group.reload, mentor_role)
    assert_equal "mkr_student madankumarrajan <mkr@example.com>,student_b example <student_1@example.com>", render_memberships(group.reload, student_role)
  end

  def test_collapsible_find_new_filters
    content = collapsible_find_new_filters
    assert_match /Status/, content
    assert_match /Include only available mentoring connections/, content
  end

  def test_render_join_button
    group = groups(:group_pbe)
    current_user_is :pbe_student_6

    current_user.stubs(:can_apply_for_join?).returns(false)
    assert_nil render_join_button(group)

    current_user.stubs(:can_apply_for_join?).returns(true)
    result = render_join_button(group)
    assert_equal_hash({ label: "Join Mentoring Connection", url: new_project_request_path(group_id: group.id, format: :js, project_request: { from_page: :profile }), class: "btn btn-primary cjs_create_project_request", js_class: "cjs_create_project_request"}, result)

    result = render_join_button(group, src_path: "src_path")
    assert_equal new_project_request_path(group_id: group.id, format: :js, project_request: { from_page: :profile },src: "src_path"), result[:url]
  end

  def test_instantiate_group_profile_back_link
    self.stubs(:current_user).returns(users(:f_student_pbe))

    self.expects(:find_new_projects_title).returns("Find New")
    instantiate_group_profile_back_link(true, "")
    assert_equal_hash({ label: "Find New", link: find_new_groups_path }, @back_link)

    instantiate_group_profile_back_link(nil, "some url")
    assert_equal_hash({ label: "Mentoring Connections", link: "some url" }, @back_link)

    instantiate_group_profile_back_link(nil, "")
    assert_nil @back_link

    current_user.stubs(:can_manage_connections?).returns(true)
    instantiate_group_profile_back_link(nil, "")
    assert_equal_hash({ label: "Mentoring Connections", link: groups_path }, @back_link)
  end

  def test_instantiate_group_profile_title_badge_and_sub_title
    program = programs(:pbe)
    admin_user = users(:f_admin_pbe)

    rejected_group = program.groups.rejected.first
    pending_group = program.groups.pending.first
    published_group = program.groups.published.first
    proposed_group = program.groups.proposed.first
    withdrawn_group = program.groups.withdrawn.first

    self.expects(:get_group_label_for_end_user).never
    assert_nil instantiate_group_profile_title_badge_and_sub_title(proposed_group, true)
    assert_nil instantiate_group_profile_title_badge_and_sub_title(rejected_group, true)

    self.expects(:get_group_label_for_end_user).returns("title badge")
    instantiate_group_profile_title_badge_and_sub_title(published_group, true)
    assert_equal "title badge", @title_badge

    self.expects(:get_group_label_for_end_user).returns(nil)
    instantiate_group_profile_title_badge_and_sub_title(published_group, true)
    assert_equal "Profile", @sub_title
    assert_nil @title_badge
    @sub_title = nil

    self.stubs(:get_group_label_for_end_user).returns(nil)
    instantiate_group_profile_title_badge_and_sub_title(pending_group, true)
    assert_nil @sub_title
    assert_nil @title_badge

    drafted_group = create_group(program: program, students: [program.student_users.first], mentors: [program.mentor_users.first], status: Group::Status::DRAFTED, creator_id: admin_user.id)
    instantiate_group_profile_title_badge_and_sub_title(drafted_group, false)
    assert_select_helper_function "span.label", @title_badge, text: "Drafted"

    instantiate_group_profile_title_badge_and_sub_title(pending_group, false)
    assert_select_helper_function "span.label", @title_badge, text: "Available"

    User.any_instance.stubs(:is_admin?).returns(false)
    instantiate_group_profile_title_badge_and_sub_title(pending_group, false)
    assert_select_helper_function "span.label", @title_badge, text: "Not Started"

    instantiate_group_profile_title_badge_and_sub_title(withdrawn_group, false)
    assert_select_helper_function "span.label", @title_badge, text: ""
  end

  def test_group_settings_hash_with_pbe_enabled
    # admin_user cannot send project proposals
    admin_user = users(:f_admin_pbe)
    program = programs(:pbe)
    @current_program = program
    tabs_hash = {show_drafted_tab: true, show_pending_tab: true, show_open_tab: true, show_proposed_tab: true, show_rejected_tab: true, show_withdrawn_tab: false}
    assert_equal_hash tabs_hash.merge(show_open_tab: false, show_proposed_tab: false, show_rejected_tab: false), group_settings_hash(true, false, admin_user)
    User.any_instance.stubs(:can_be_shown_proposed_groups?).returns(false)
    assert_equal_hash tabs_hash.merge(show_open_tab: false, show_proposed_tab: false, show_rejected_tab: false), group_settings_hash(true, false, admin_user, counts: {proposed: 1, rejected: 0})
    User.any_instance.stubs(:can_be_shown_proposed_groups?).returns(true)
    assert_equal_hash tabs_hash.merge(show_open_tab: false), group_settings_hash(true, false, admin_user, counts: {proposed: 1, rejected: 0})
    assert_equal_hash tabs_hash.merge(show_open_tab: false), group_settings_hash(true, false, admin_user, counts: {proposed: 0, rejected: 1})
    student_role = program.get_role(RoleConstants::STUDENT_NAME)
    student_role.add_permission(RolePermission::PROPOSE_GROUPS)
    student_role.reload
    assert_equal_hash tabs_hash.merge(show_open_tab: false), group_settings_hash(true, false, admin_user, counts: {proposed: 0, rejected: 0})
    student_role.remove_permission(RolePermission::PROPOSE_GROUPS)
    student_role.reload
    assert_equal_hash tabs_hash.merge(show_drafted_tab: false, show_pending_tab: false, show_proposed_tab: false, show_rejected_tab: false), group_settings_hash(false, true, admin_user)
    assert_equal_hash tabs_hash.merge(show_open_tab: false, show_pending_tab: false, show_drafted_tab: false, show_proposed_tab: false, show_rejected_tab: false), group_settings_hash(false, false, admin_user)

    role = program.get_role(RoleConstants::STUDENT_NAME)
    role.add_permission(RolePermission::PROPOSE_GROUPS)
    student_user = users(:f_student_pbe)
    assert_equal_hash tabs_hash.merge(show_open_tab: false), group_settings_hash(true, false, student_user)
    assert_equal_hash tabs_hash.merge(show_drafted_tab: false, show_pending_tab: false), group_settings_hash(false, true, student_user)
    assert_equal_hash tabs_hash.merge(show_open_tab: false, show_pending_tab: false, show_drafted_tab: false, show_proposed_tab: false, show_rejected_tab: false), group_settings_hash(false, false, student_user)
  end

  def test_group_settings_hash_for_withdrawn_tab
    admin_user = users(:f_admin_pbe)
    program = programs(:pbe)
    @current_program = program
    tabs_hash = {show_drafted_tab: true, show_pending_tab: true, show_open_tab: false, show_proposed_tab: false, show_rejected_tab: false}
    assert_equal_hash tabs_hash.merge(show_withdrawn_tab: true), group_settings_hash(true, false, admin_user, counts: {pending: 1})
    assert_equal_hash tabs_hash.merge(show_withdrawn_tab: true), group_settings_hash(true, false, admin_user, counts: {pending: 1, withdrawn: 1})
    assert_equal_hash tabs_hash.merge(show_withdrawn_tab: true), group_settings_hash(true, false, admin_user, counts: { withdrawn: 1})
    assert_equal_hash tabs_hash.merge(show_drafted_tab: false, show_pending_tab: false, show_open_tab: true, show_withdrawn_tab: true), group_settings_hash(false, true, admin_user, counts: { withdrawn: 1})
    assert_equal_hash tabs_hash.merge(show_drafted_tab: false, show_pending_tab: false, show_open_tab: false, show_withdrawn_tab: false), group_settings_hash(false, false, admin_user, counts: { withdrawn: 1})
  end

  def test_group_settings_hash_regular_program
    # admin_user cannot send project proposals
    admin_user = users(:f_admin)
    program = programs(:albers)
    @current_program = program
    tabs_hash = {show_drafted_tab: true, show_pending_tab: true, show_open_tab: true, show_proposed_tab: true, show_rejected_tab: true, show_withdrawn_tab: false}
    assert_equal_hash tabs_hash.merge(show_open_tab: false, show_proposed_tab: false, show_rejected_tab: false, show_pending_tab: false), group_settings_hash(true, false, admin_user)
    assert_equal_hash tabs_hash.merge(show_open_tab: false, show_drafted_tab: false, show_pending_tab: false, show_proposed_tab: false, show_rejected_tab: false), group_settings_hash(false, true, admin_user)
    assert_equal_hash tabs_hash.merge(show_open_tab: false, show_pending_tab: false, show_drafted_tab: false, show_proposed_tab: false, show_rejected_tab: false), group_settings_hash(false, false, admin_user)

    role = program.get_role(RoleConstants::STUDENT_NAME)
    role.add_permission(RolePermission::PROPOSE_GROUPS)
    student_user = users(:f_student)
    assert_equal_hash tabs_hash.merge(show_open_tab: false, show_proposed_tab: false, show_rejected_tab: false, show_pending_tab: false), group_settings_hash(true, false, student_user)
    assert_equal_hash tabs_hash.merge(show_open_tab: false, show_drafted_tab: false, show_pending_tab: false, show_proposed_tab: false, show_rejected_tab: false), group_settings_hash(false, true, student_user)
    assert_equal_hash tabs_hash.merge(show_open_tab: false, show_pending_tab: false, show_drafted_tab: false, show_proposed_tab: false, show_rejected_tab: false), group_settings_hash(false, false, student_user)
  end

  def test_join_role_select_drop_down_field
    user = users(:f_mentor)
    group = groups(:mygroup)
    content = join_role_select_drop_down_field(group, user, user.roles.for_mentoring)
    assert content.blank?

    new_roles = [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]
    roles_index = programs(:albers).roles.where(name: new_roles).index_by(&:name)
    user.role_names += [RoleConstants::STUDENT_NAME]
    user.save!

    content = join_role_select_drop_down_field(group, user, user.roles.for_mentoring)
    assert content.present?
    assert_select_helper_function_block "div.form-group.form-group-sm", content do
      assert_select "label[class=\"col-sm-3 control-label\"][for=\"group_join_as_role_id\"]", text: "Select your role in this mentoring connection"
      assert_select "div[class=\"controls col-sm-9\"]" do
        assert_select "select[name=\"group[join_as_role_id]\"][id=\"group_join_as_role_id\"][class=\"form-control\"]" do
          assert_select "option[selected=\"selected\"][value=\"#{roles_index[RoleConstants::MENTOR_NAME].id}\"]", text:"Mentor"
          assert_select "option[value=\"#{roles_index[RoleConstants::STUDENT_NAME].id}\"]", text:"Student"
        end
      end
    end
  end

  def test_get_group_label_for_end_user
    @current_program = programs(:pbe)
    group = groups(:group_pbe)
    group.program.roles.find_by(name: RoleConstants::MENTOR_NAME).remove_permission("send_project_request")
    label = get_group_label_for_end_user(users(:f_student_pbe), group)
    assert_match /My Mentoring Connection/, label
    label = get_group_label_for_end_user(users(:f_mentor_pbe), group)
    assert_match /My Mentoring Connection/, label

    assert_nil get_group_label_for_end_user(users(:pbe_student_6), group)

    group.update_column(:status, Group::Status::CLOSED)
    assert_nil get_group_label_for_end_user(users(:pbe_mentor_2), group)

    assert_nil get_group_label_for_end_user(users(:f_student_pbe), group, skip_my_group: true)
    assert_nil get_group_label_for_end_user(users(:f_mentor_pbe), group, skip_my_group: true)
    m_setting = group.membership_settings.find_or_initialize_by(role_id: group.program.get_role(RoleConstants::STUDENT_NAME).id)
    m_setting.update_attributes!(:max_limit => 1)
    assert_nil get_group_label_for_end_user(users(:f_student_pbe), group, skip_my_group: true)
    assert_nil get_group_label_for_end_user(users(:f_mentor_pbe), group, skip_my_group: true)

    group = groups(:group_pbe_4)
    label = get_group_label_for_end_user(users(:pbe_student_4), group)
    assert_match /My Mentoring Connection/, label
    label = get_group_label_for_end_user(users(:pbe_mentor_4), group)
    assert_match /My Mentoring Connection/, label
    assert_nil get_group_label_for_end_user(users(:pbe_student_3), group)
    assert_nil get_group_label_for_end_user(users(:pbe_mentor_3), group)
    label = get_group_label_for_end_user(users(:pbe_student_6), group)
    assert_match /Request pending approval/, label

    label = get_group_label_for_end_user(users(:pbe_student_4), group, skip_my_group: true)
    assert_match /Mentoring Connection not started/, label
    label = get_group_label_for_end_user(users(:pbe_mentor_4), group, skip_my_group: true)
    assert_match /Mentoring Connection not started/, label

    m_setting = group.membership_settings.find_or_initialize_by(role_id: group.program.get_role(RoleConstants::STUDENT_NAME).id)
    m_setting.update_attributes!(:max_limit => 2)
    label = get_group_label_for_end_user(users(:pbe_student_3), group)
    assert_match /Not available to join/, label

    m_setting = group.membership_settings.find_or_initialize_by(role_id: group.program.get_role(RoleConstants::STUDENT_NAME).id)
    m_setting.update_attributes!(:max_limit => 5)
    users(:pbe_student_6).sent_project_requests.each{|r| r.mark_accepted(users(:f_admin_pbe))}

    label = get_group_label_for_end_user(users(:pbe_student_6), group)
    assert_match /My Mentoring Connection/, label
    label = get_group_label_for_end_user(users(:pbe_student_6), group, skip_my_group: true)
    assert_match /Mentoring Connection not started/, label
  end

  def test_group_end_users_actions_dropdown
    user = users(:f_student_pbe)
    student_role = user.roles.first

    User.any_instance.stubs(:can_create_group_without_approval?).returns(false)

    assert_equal [{label: "Find new mentoring connections", url: "/groups/find_new"}], group_end_users_actions_dropdown(user)
    student_role.add_permission("propose_groups")
    user.reload
    assert_equal [{label: "Find new mentoring connections", url: "/groups/find_new"}, {label: "Propose a new mentoring connection", url: "/groups/new?propose_view=true"}], group_end_users_actions_dropdown(user)
    student_role.remove_permission("send_project_request")
    user.reload
    assert_equal [{label: "Propose a new mentoring connection", url: "/groups/new?propose_view=true"}], group_end_users_actions_dropdown(user)

    User.any_instance.stubs(:can_create_group_without_approval?).returns(true)
    assert_equal [{label: "Start a new mentoring connection", url: "/groups/new?propose_view=true"}], group_end_users_actions_dropdown(user)
    student_role.remove_permission("propose_groups")
    user.reload
    assert_equal [], group_end_users_actions_dropdown(user)
    assert_equal "", dropdown_buttons_or_button([])
  end

  def test_display_group_proposed_data
    program = programs(:pbe)
    group = nil
    time_traveller(Time.new(2012).utc) do
      group = create_group(name: "Claire Underwood - Francis Underwood", students: [], mentors: [users(:f_mentor_pbe)], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)
    end

    content = set_response_text(display_group_proposed_data(group, false))
    assert_select "span", text: "Proposed on: " + Time.new(2012).utc.strftime("%B %d, %Y")
    assert_match /Proposed by:/, content
    assert_match /Good unique name/, content

    content = display_group_proposed_data(group, true)
    set_response_text(content)
    assert_select "span", text: "Proposed on: " + Time.new(2012).utc.strftime("%B %d, %Y")
    assert_no_match /Good unique name/, content
    assert_no_match /Proposed By/, content
  end

  def test_overdue_groups_filter_params
    program = programs(:albers)
    filter_params = { tab: Group::Status::ACTIVE, search_filters: { v2_tasks_status: GroupsController::TaskStatusFilter::OVERDUE }, root: program.root }
    assert_equal filter_params, overdue_groups_filter_params(program)
  end

  def test_ontrack_groups_filter_params
    program = programs(:albers)
    filter_params = { tab: Group::Status::ACTIVE, search_filters: { v2_tasks_status: GroupsController::TaskStatusFilter::NOT_OVERDUE }, root: program.root }
    assert_equal filter_params, ontrack_groups_filter_params(program)
  end

  def test_get_user_text
    program = programs(:pbe)
    group = create_group(name: "Claire Underwood - Francis Underwood", students: [], mentors: [users(:f_mentor_pbe)], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)
    assert_match "Good unique name", get_user_text([group])
    assert_equal "proposer", get_user_text([group, groups(:mygroup)])
  end

  def test_side_pane_action_header_text
    assert_equal "Administrator Actions", side_pane_action_header_text(false)
    assert_equal "Actions", side_pane_action_header_text(true)
  end

  def test_get_group_members_data_for_select2
    student_user1 = users(:pbe_student_2)
    student_user2 = users(:pbe_student_7)
    mentor_user = users(:pbe_mentor_2)
    group = groups(:group_pbe_2)
    group_with_no_user = create_group(name: "Claire Underwood - Francis Underwood", students: [], mentors: [], program: programs(:pbe), status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)
    assert_equal [].to_json, get_group_members_data_for_select2(group_with_no_user)
    assert_equal [{id: student_user1.id, text: student_user1.name(name_only: true)}, {id: student_user2.id, text: student_user2.name(name_only: true)}, {id: mentor_user.id, text: mentor_user.name(name_only: true)}].to_json, get_group_members_data_for_select2(group)
  end

  def test_get_status_filter_fields_v2
    not_started = { status_value: true, value: 10, label: "Not Started", checkbox_id: "not_started" }
    active = { status_value: true, value: 0, label: "Started and currently Active", checkbox_id: "active" }
    inactive = { status_value: true, value: 1, label: "Started and currently Inactive", checkbox_id: "inactive" }
    closed = { status_value: true, value: 2, label: "Closed", checkbox_id: "closed" }
    content_hash = get_status_filter_fields_v2({}, true, false)
    assert_equal [not_started, inactive, active], content_hash

    content_hash = get_status_filter_fields_v2({}, false, false)
    not_started[:status_value] = false
    assert_equal [not_started, inactive, active], content_hash

    content_hash = get_status_filter_fields_v2({ "active" => 0 }, true, false)
    not_started[:status_value] = true
    inactive[:status_value] = false
    assert_equal [not_started, inactive, active], content_hash

    content_hash = get_status_filter_fields_v2({}, false, true, add_closed_filter: false)
    not_started[:status_value] = false
    inactive[:status_value] = true
    assert_equal [not_started, inactive, active], content_hash

    content_hash = get_status_filter_fields_v2({}, false, true, add_closed_filter: true)
    assert_equal [not_started, inactive, active, closed], content_hash

    content_hash = get_status_filter_fields_v2({}, false, false, add_closed_filter: true)
    closed[:status_value] = false
    assert_equal [not_started, inactive, active, closed], content_hash
  end

  def test_get_survey_status_filter_with_no_preselected_attribute
    SecureRandom.stubs(:hex).returns("random")
    content = set_response_text(get_survey_status_filter(programs(:albers), {}))
    assert_select "div" do
      assert_select "div.filter_item" do
        assert_no_select "div#collapsible_random_content.collapse.in"
        assert_select "div#collapsible_random_content.collapse" do
          assert_select "div.filter_box" do
            assert_select "label", text: "Survey"
            assert_select "select#filter_survey_name_status", name: "search_filters[survey_status][survey_id]" do
              assert_no_select "option[selected='selected']"
              assert_select "option", text: "Select a survey"
              assert_select "option", text: "Introduce yourself"
              assert_select "option", text: "Mentoring Relationship Closure"
              assert_select "option", text: "Mentoring Relationship Health"
              assert_select "option", text: "Partnership Effectiveness"
            end
            assert_select "a.clear_filter.hide", href: "#", onclick: "jQuery('#search_filters_user_name').val('');GroupSearch.applyFilters();; return false;", text: "Clear"
          end
        end
      end
    end
  end

  def test_get_survey_status_filter_with_survey_preselected
    program = programs(:albers)
    SecureRandom.stubs(:hex).returns("random")
    content = set_response_text(get_survey_status_filter(program, { survey_id: surveys(:two).id } ))
    assert_select "div" do
      assert_select "div.filter_item" do
        assert_select "div#collapsible_random_content.collapse.in" do
          assert_select "div.filter_box" do
            assert_select "label", text: "Survey"
            assert_select "select#filter_survey_name_status", name: "search_filters[survey_status][survey_id]" do
              assert_select "option", text: "Select a survey"
              assert_select "option", text: "Introduce yourself", selected: "selected"
              assert_select "option", text: "Mentoring Relationship Closure"
              assert_select "option", text: "Mentoring Relationship Health"
              assert_select "option", text: "Partnership Effectiveness"
            end
            assert_select "div#filter_survey_task_status_container" do
              assert_select "label", text: "Status"
              assert_select "select#survey_task_status", name: "search_filters[survey_status][survey_task_status]" do
                assert_select "option", text: "Select...", selected: "selected"
                assert_select "option", text: "Completed"
                assert_select "option", text: "Not Completed"
                assert_select "option", text: "Overdue"
              end
            end
            assert_select "button.btn", onclick: "return GroupSearch.applyFilters();", text: "Go"
            assert_select "a.clear_filter.hide", href: "#", onclick: "jQuery('#search_filters_user_name').val('');GroupSearch.applyFilters();; return false;", text: "Clear"
          end
        end
      end
    end
    Survey.stubs(:of_engagement_type).returns(Survey.where(id: 0))
    assert_nil set_response_text(get_survey_status_filter(program, {}))
  end

  def test_get_survey_response_filter_with_no_preselected_attribute
    SecureRandom.stubs(:hex).returns("random")
    content = set_response_text(get_survey_response_filter(programs(:albers), {}))
    assert_select "div" do
      assert_select "div.filter_item" do
        assert_no_select "div#collapsible_random_content.collapse.in"
        assert_select "div#collapsible_random_content.collapse" do
          assert_select "div.filter_box" do
            assert_select "label", text: "Mentoring Connection with users response for:"
            assert_select "select#filter_survey_name", name: "search_filters[survey_response][survey_id]", data: { url: "/groups/fetch_survey_questions.js" } do
              assert_no_select "option[selected='selected']"
              assert_select "option", text: "Select a survey"
              assert_select "option", text: "Introduce yourself"
              assert_select "option", text: "Mentoring Relationship Closure"
              assert_select "option", text: "Mentoring Relationship Health"
              assert_select "option", text: "Partnership Effectiveness"
            end
            assert_select "a.clear_filter.hide", href: "#", onclick: "jQuery('#search_filters_user_name').val('');GroupSearch.applyFilters();; return false;", text: "Clear"
          end
        end
      end
    end

    set_response_text(get_survey_response_filter(programs(:albers), {}, true))

    assert_select "div" do
      assert_select "div.social-feed-box.ibox" do
        assert_select "div#collapsible_random_content.ibox-content" do
          assert_select "div.filter_box" do
            assert_select "label", text: "Mentoring Connection with users response for:"
            assert_select "select#filter_survey_name", name: "search_filters[survey_response][survey_id]", data: { url: "/groups/fetch_survey_questions.js" } do
              assert_no_select "option[selected='selected']"
              assert_select "option", text: "Select a survey"
              assert_select "option", text: "Introduce yourself"
              assert_select "option", text: "Mentoring Relationship Closure"
              assert_select "option", text: "Mentoring Relationship Health"
              assert_select "option", text: "Partnership Effectiveness"
            end
            assert_select "a.clear_filter.hide", href: "#", onclick: "jQuery('#search_filters_user_name').val('');GroupSearch.applyFilters();; return false;", text: "Clear"
          end
        end
      end
    end
  end

  def test_get_survey_response_filter_with_survey_preselected
    SecureRandom.stubs(:hex).returns("random")
    content = set_response_text(get_survey_response_filter(programs(:albers), { survey_id: surveys(:two).id } ))
    assert_select "div" do
      assert_select "div.filter_item" do
        assert_select "div#collapsible_random_content.collapse.in" do
          assert_select "div.filter_box" do
            assert_select "label", text: "Mentoring Connection with users response for:"
            assert_select "select#filter_survey_name", name: "search_filters[survey_response][survey_id]", data: { url: "/groups/fetch_survey_questions.js" } do
              assert_select "option", text: "Select a survey"
              assert_select "option", text: "Introduce yourself", selected: "selected"
              assert_select "option", text: "Mentoring Relationship Closure"
              assert_select "option", text: "Mentoring Relationship Health"
              assert_select "option", text: "Partnership Effectiveness"
            end
            assert_select "div#filter_survey_question_container" do
              assert_select "label", text: "Survey Question :"
              assert_select "select#survey_question_dropdown", name: "search_filters[survey_response][question_id]" do
                assert_select "option", text: "Select your question", selected: "selected"
                assert_select "option", text: "What is your name?"
                assert_select "option", text: "Where do you live?"
                assert_select "option", text: "Where are you from?"
              end
            end
            assert_select "a.clear_filter.hide", href: "#", onclick: "jQuery('#search_filters_user_name').val('');GroupSearch.applyFilters();; return false;", text: "Clear"
          end
        end
      end
    end
  end

  def test_get_survey_response_filter_with_survey_and_question_preselected
    program = programs(:albers)
    survey = surveys(:two)
    SecureRandom.stubs(:hex).returns("random")

    content = set_response_text(get_survey_response_filter(program, { survey_id: survey.id, question_id: survey.survey_questions.first.id } ))
    assert_select "div" do
      assert_select "div.filter_item" do
        assert_select "div#collapsible_random_content.collapse.in" do
          assert_select "div.filter_box" do
            assert_select "label", text: "Mentoring Connection with users response for:"
            assert_select "select#filter_survey_name", name: "search_filters[survey_response][survey_id]", data: { url: "/groups/fetch_survey_questions.js" } do
              assert_select "option", text: "Select a survey"
              assert_select "option", text: "Introduce yourself", selected: "selected"
              assert_select "option", text: "Mentoring Relationship Closure"
              assert_select "option", text: "Mentoring Relationship Health"
              assert_select "option", text: "Partnership Effectiveness"
            end
            assert_select "div#filter_survey_question_container" do
              assert_select "label", text: "Survey Question :"
              assert_select "select#survey_question_dropdown", name: "search_filters[survey_response][question_id]" do
                assert_select "option", text: "Select your question"
                assert_select "option", text: "What is your name?", selected: "selected"
                assert_select "option", text: "Where do you live?"
                assert_select "option", text: "Where are you from?"
              end
            end
            assert_select "div#filter_survey_answer_container" do
              assert_select "label", text: "Survey Answer :"
              assert_select "input", name: "search_filters[survey_response][answer_text]"
            end
            assert_select "button.btn", onclick: "return GroupSearch.applyFilters();", text: "Go"
            assert_select "a.clear_filter.hide", href: "#", onclick: "jQuery('#search_filters_user_name').val('');GroupSearch.applyFilters();; return false;", text: "Clear"
          end
        end
      end
    end

    Survey.stubs(:of_engagement_type).returns(Survey.where(id: 0))
    assert_nil set_response_text(get_survey_response_filter(program, {}))
  end

  def test_get_survey_answer_choice_based
    content = set_response_text(get_survey_answer(SurveyQuestion.first, { answer_text: "Okay" } ))
    assert_select "div#filter_survey_answer_container" do
      assert_select "label", text: "Survey Answer :"
      assert_select "input#survey_answer_choice", name: "search_filters[survey_response][answer_text]", data: { placeholder: "Select Choices" }, type: "hidden"
    end
  end

  def test_show_provide_rating_link
    program = programs(:albers)
    group = groups(:mygroup)
    mentor = group.mentors.first
    mentee = group.students.first

    # without enabling the feature
    assert_false show_provide_rating_link?(group, mentee, mentor)

    # enabling coach rating
    program.enable_feature(FeatureName::COACH_RATING, true)
    group.program.reload

    assert show_provide_rating_link?(group, mentor, mentee)
    assert_false show_provide_rating_link?(group, mentee, mentor)

    #testing for old group
    closed_group = groups(:group_4)
    assert show_provide_rating_link?(closed_group, users(:requestable_mentor), users(:student_4))

    # testing for drafted group
    drafted_group = groups(:drafted_group_1)
    assert_false show_provide_rating_link?(drafted_group, mentor, mentee)
  end

  def test_display_notes_group_mentoring
    current_user_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE)
    group = groups(:group_2)
    user_edit_view = false
    assert display_notes(user_edit_view)
  end

  def test_display_notes_group_mentoring_not_admin
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE)
    group = groups(:mygroup)
    @current_user = users(:f_mentor)
    user_edit_view = false
    assert_false display_notes(user_edit_view)
  end

  def test_can_show_pending_group_header_alert
    mentor_user = users(:f_mentor_pbe)
    admin_user = users(:f_admin_pbe)
    group = groups(:group_pbe)

    assert can_show_pending_group_header_alert?(group, mentor_user, true)
    assert_false can_show_pending_group_header_alert?(group, mentor_user, false)

    Group.any_instance.stubs(:pending?).returns(false)
    assert_false can_show_pending_group_header_alert?(group, admin_user, false)
    assert can_show_pending_group_header_alert?(group, admin_user, true)

    Group.any_instance.stubs(:pending?).returns(true)
    assert can_show_pending_group_header_alert?(group, admin_user, false)
  end

  def test_render_alert_for_pending_groups
    group = groups(:group_pbe)
    user = users(:f_mentor_pbe)

    assert_nil group.start_date
    assert group.program.allow_circle_start_date?

    self.stubs(:get_pending_group_alert_for_groups_without_start_date).with(user, group).returns("without start date")
    self.stubs(:get_pending_group_alert_for_groups_with_start_date).with(user, group).returns("with start date")

    assert_select_helper_function "div.font-600", render_alert_for_pending_groups(user, group), text: "without start date"

    group.update_attributes!(start_date: Time.now)
    assert_select_helper_function "div.font-600", render_alert_for_pending_groups(user, group), text: "with start date"

    group.program.update_attributes!(allow_circle_start_date: false)
    assert_select_helper_function "div.font-600", render_alert_for_pending_groups(user, group), text: "without start date"
  end

  def test_render_alert_for_proposed_groups
    group = groups(:group_pbe)
    user = users(:f_mentor_pbe)
    admin = users(:f_admin_pbe)

    assert_select_helper_function "div.font-600", render_alert_for_proposed_groups(admin, group), text: "Please accept and make the mentoring connection available for users."

    assert_select_helper_function "div.font-600", render_alert_for_proposed_groups(user, group), text: "Your proposed mentoring connection is awaiting acceptance from administrator. You will be notified once the administrator accepts your mentoring connection."

    Group.any_instance.stubs(:has_member?).returns(false)
    assert_select_helper_function "div.font-600", render_alert_for_proposed_groups(user, group), text: ""
  end

  def test_render_find_new_group_link_text
    group = groups(:group_pbe)
    user = users(:f_mentor_pbe)

    user.expects(:is_owner_of?).with(group).returns(true)
    assert_equal "", render_find_new_group_link_text(user, group)

    user.stubs(:is_owner_of?).returns(false)
    user.expects(:is_admin?).returns(true)
    assert_equal "", render_find_new_group_link_text(user, group)

    user.stubs(:is_admin?).returns(false)
    user.expects(:can_view_find_new_projects?).returns(false)
    assert_equal "", render_find_new_group_link_text(user, group)

    user.stubs(:can_view_find_new_projects?).returns(true)
    self.expects(:get_available_projects).returns(Group.where(id: 0))
    assert_equal "", render_find_new_group_link_text(user, group)

    self.expects(:get_available_projects).returns(Group.where(id: group.id))
    assert_equal "", render_find_new_group_link_text(user, group)

    self.expects(:get_available_projects).returns(Group.where(id: groups(:mygroup).id))
    assert_select_helper_function "div.m-t-sm", render_find_new_group_link_text(user, group), text: "Click here to explore other mentoring connections if you would like to join them."
  end

  def test_get_pending_group_alert_for_groups_with_start_date
    group = groups(:mygroup)
    user = users(:mkr_student)

    self.stubs(:get_alert_message_for_past_start_date_circles).with(user, group).returns("with past date")
    self.stubs(:get_alert_message_for_future_start_date_circles).with(user, group).returns("with future date")

    Group.any_instance.stubs(:has_past_start_date?).returns(true)
    assert_equal "with past date", get_pending_group_alert_for_groups_with_start_date(user, group)

    Group.any_instance.stubs(:has_past_start_date?).returns(false)
    assert_equal "with future date", get_pending_group_alert_for_groups_with_start_date(user, group)
  end

  def test_get_alert_message_for_past_start_date_circles
    Time.zone = "Asia/Kolkata"
    group = groups(:group_pbe)
    user = users(:f_student_pbe)
    current_time = Time.now.beginning_of_day + 12.hours

    group.update_attribute(:start_date, current_time)
    start_date = DateTime.localize(current_time, format: :short)

    User.any_instance.stubs(:is_owner_of?).with(group).returns(true)
    assert_equal "The mentoring connection didn't start on #{start_date} as users are yet to join the mentoring connection. Please #{link_to('feature.connection.content.set_a_new_start_date'.translate, 'javascript:void(0)', class: 'cjs_set_or_edit_connection_start_date', data: {url: get_edit_start_date_popup_group_path(id: group.id, from_profile_flash: true)})} or publish the circle manually.", get_alert_message_for_past_start_date_circles(user, group)

    User.any_instance.stubs(:is_owner_of?).with(group).returns(false)
    assert_equal "The mentoring connection didn't start on #{start_date} as users are yet to join the mentoring connection. Please #{link_to('feature.connection.content.set_a_new_start_date'.translate, 'javascript:void(0)', class: 'cjs_set_or_edit_connection_start_date', data: {url: get_edit_start_date_popup_group_path(id: group.id, from_profile_flash: true)})} or publish the circle manually.", get_alert_message_for_past_start_date_circles(users(:f_admin_pbe), group)

    assert_equal "This mentoring connection has not started yet. You will be notified once it starts.", get_alert_message_for_past_start_date_circles(user, group)

    Group.any_instance.stubs(:has_member?).with(user).returns(false)
    assert_equal "This mentoring connection has not started yet. If you join, you will be notified once it starts.", get_alert_message_for_past_start_date_circles(user, group)
  end

  def test_get_alert_message_for_future_start_date_circles
    Time.zone = "Asia/Kolkata"
    group = groups(:group_pbe)
    user = users(:f_student_pbe)
    current_time = Time.now.beginning_of_day + 12.hours

    group.update_attribute(:start_date, current_time)
    start_date = DateTime.localize(current_time, format: :short)

    assert group.has_member?(user)
    assert_equal "The mentoring connection will start on #{start_date}. You will be notified once it starts.", get_alert_message_for_future_start_date_circles(user, group)

    assert_equal "The mentoring connection will start on #{start_date}.", get_alert_message_for_future_start_date_circles(users(:f_admin_pbe), group)

    Group.any_instance.stubs(:has_member?).with(user).returns(false)
    assert_equal "The mentoring connection will start on #{start_date}. If you join, you will be notified once it starts.", get_alert_message_for_future_start_date_circles(user, group)
  end

  def test_get_pending_group_alert_for_groups_without_start_date
    group = groups(:mygroup)
    user = users(:mkr_student)
    admin = users(:f_admin)

    assert_equal get_pending_group_alert_for_groups_without_start_date(user, group), "This mentoring connection has not started yet. You will be notified once it starts."

    assert_equal get_pending_group_alert_for_groups_without_start_date(users(:requestable_mentor), group), "This mentoring connection has not started yet. If you join, you will be notified once it starts."

    group.membership_of(user).update_attributes!(owner: true)

    assert_equal "This mentoring connection has not started yet. Publish the mentoring connection for access to collaboration tools and resources. If you want, others may continue to find and join the mentoring connection after it's published.", get_pending_group_alert_for_groups_without_start_date(user, group)

    assert_equal "This mentoring connection has not started yet. Publish the mentoring connection for access to collaboration tools and resources. If you want, others may continue to find and join the mentoring connection after it's published.", get_pending_group_alert_for_groups_without_start_date(admin, group)
  end

  def test_order_members_for_group_user_listing
    program = programs(:pbe)
    group = groups(:group_pbe_2)
    teacher_role = create_role(name: "teacher", for_mentoring: true)
    user = program.all_users.where("id NOT IN (?)", group.members.collect(&:id)).first
    user.roles += [teacher_role]
    user.save!
    user.reload
    group.update_members(group.mentors, group.students, nil, other_roles_hash: {teacher_role => [user]})
    group.reload
    mentor_list = group.mentors
    mentee_list = group.students
    custom_user_list = group.custom_users
    assert_equal custom_user_list, [user]
    assert_equal order_members_for_group_user_listing(group), mentee_list + mentor_list + custom_user_list
  end

  def test_display_group_data
    set_response_text(display_group_data("Content", "Label:"))
    assert_select "span" do
      assert_select "span.font-bold", text: "Label:"
      assert_select "span", text: "Label:Content"
      assert_no_select "i"
    end

    set_response_text(display_group_data("Content"))
    assert_select "span" do
      assert_select "span", text: "Content"
      assert_no_select "span.font-bold"
      assert_no_select "i"
    end

    set_response_text(display_group_data("Content", nil, "fa fa-clock-o"))
    assert_select "span" do
      assert_select "span", count: 1
      assert_no_select "span.font-bold"
      assert_select "i.fa.fa-clock-o"
    end

    set_response_text(display_group_data("Content", "Label", "fa fa-clock-o", "label_class"))
    assert_select "span" do
      assert_select "span", count: 2
      assert_select "span.font-bold.label_class", :text => "Label"
      assert_select "i.fa.fa-clock-o"
    end
  end

  def test_get_active_or_pending_group_display_info
    group = groups(:group_pbe)
    user = users(:f_mentor_pbe)
    non_group_user = users(:pbe_student_6)
    admin_user = users(:f_admin_pbe)

    current_time = Time.now
    Time.stubs(:now).returns(current_time)

    group.update_attributes!(published_at: current_time)
    self.stubs(:get_group_expiry_content).with(group, true, show_expired_text: true).returns("expired content")

    Group.any_instance.stubs(:pending?).returns(true)
    self.stubs(:get_circle_start_and_available_info).with(group, user.member).returns(["label", current_time])

    assert_equal ["label", formatted_time_in_words(current_time, no_ago: true, no_time: true)], get_active_or_pending_group_display_info(group, user)

    Group.any_instance.stubs(:pending?).returns(false)
    Group.any_instance.stubs(:active?).returns(true)

    label, date = get_active_or_pending_group_display_info(group, user)
    assert_nil label
    assert_equal formatted_time_in_words(group.published_at, no_ago: true, no_time: true) + " - " + content_tag(:span, "expired content", id: "cjs_expiry_#{group.id}"), date

    label, date = get_active_or_pending_group_display_info(group, admin_user)
    assert_nil label
    assert_equal formatted_time_in_words(group.published_at, no_ago: true, no_time: true) + " - " + content_tag(:span, "expired content", id: "cjs_expiry_#{group.id}"), date

    label, date = get_active_or_pending_group_display_info(group, non_group_user)
    assert_equal "feature.connection.header.started_label".translate, label
    assert_equal formatted_time_in_words(group.published_at, no_ago: true, no_time: true), date
  end

  def test_get_circle_start_and_available_info
    group = groups(:group_pbe)
    member = members(:f_mentor)

    assert group.program.allow_circle_start_date?

    current_time = Time.now
    group.update_attributes!(published_at: current_time, pending_at: current_time - 3.day)

    Group.any_instance.stubs(:active?).returns(true)
    label, date = get_circle_start_and_available_info(group, member)
    assert_equal "feature.connection.header.started_label".translate, label
    assert_equal current_time.to_i, date.to_i

    Group.any_instance.stubs(:active?).returns(false)
    label, date = get_circle_start_and_available_info(group, member)
    assert_equal "feature.connection.header.pending_label".translate, label
    assert_equal (current_time-3.day).to_i, date.to_i

    group.update_attribute(:start_date, current_time + 1.day)
    Group.any_instance.stubs(:has_past_start_date?).returns(true)
    Group.any_instance.stubs(:active?).returns(false)
    label, date = get_circle_start_and_available_info(group, member)
    assert_equal "feature.connection.header.pending_label".translate, label
    assert_equal (current_time-3.day).to_i, date.to_i

    Group.any_instance.stubs(:has_past_start_date?).returns(false)
    Group.any_instance.stubs(:active?).returns(false)
    label, date = get_circle_start_and_available_info(group, member)
    assert_equal "feature.connection.header.start_label".translate, label
    assert_equal (current_time + 1.day).to_i, date.to_i

    Group.any_instance.stubs(:has_past_start_date?).returns(true)
    programs(:pbe).update_attribute(:allow_circle_start_date, false)
    label, date = get_circle_start_and_available_info(group.reload, member)
    assert_equal "feature.connection.header.pending_label".translate, label
    assert_equal (current_time-3.day).to_i, date.to_i
  end

  def test_get_circle_start_and_available_info_text_class
    group = groups(:group_pbe)
    member = members(:f_mentor)
    current_time = Time.now

    assert group.program.allow_circle_start_date?

    Group.any_instance.stubs(:pending?).returns(true)
    assert_nil get_circle_start_and_available_info_text_class(group, member)

    group.update_attribute(:start_date, current_time+1.day)
    assert_equal "text-success", get_circle_start_and_available_info_text_class(group, member)

    programs(:pbe).update_attribute(:allow_circle_start_date, false)
    assert_nil get_circle_start_and_available_info_text_class(group.reload, member)

    programs(:pbe).update_attribute(:allow_circle_start_date, true)

    Group.any_instance.stubs(:pending?).returns(false)
    assert_nil get_circle_start_and_available_info_text_class(group, member)

    Group.any_instance.stubs(:pending?).returns(true)
    group.update_attribute(:start_date, current_time-1.day)
    assert_nil get_circle_start_and_available_info_text_class(group, member)
  end

  def test_groups_filter_input_group_submit_options
    content = groups_filter_input_group_submit_options
    assert_equal "btn", content[:type]
    assert_equal "Go", content[:content]
    assert_equal "return GroupSearch.applyFilters();", content[:btn_options][:onclick]
    assert_match /btn/, content[:btn_options][:class]
  end

  def test_display_survey_response_link
    answer = common_answers(:q3_name_answer_1)
    set_response_text(display_survey_response_link(answer, {url: survey_response_group_path(answer.group, { user_id: answer.user_id, response_id: answer.response_id, survey_id: answer.survey.id, format: :js })}))
    assert_select "li" do
      assert_select "div.media" do
        assert_select "div.media-middle" do
          assert_select "a" do
            assert_select "div.image_with_initial", text: /NM/
          end
        end
      end
      assert_select "a.cjs_show_response.font-bold[href=?][data-url]", "javascript:void(0)", text: answer.survey.name
      assert_select "span", text: "on " + "#{DateTime.localize(answer.updated_at, format: :short)}"
    end

    set_response_text(display_survey_response_link(answer, {url: survey_response_group_path(answer.group, { user_id: answer.user_id, response_id: answer.response_id, survey_id: answer.survey.id, format: :js })}, true))
    assert_select "li" do
      assert_select "a.cjs_show_response[href=?][data-url]", "javascript:void(0)", text: answer.survey.name
      assert_no_select "span", text: "on " + "#{DateTime.localize(answer.updated_at, format: :short)}"
    end
  end

  def test_display_closed_group_data
    group = groups(:group_4)
    response = ActionController::Base.helpers.strip_tags(display_closed_group_data(group))
    assert_match /Closed By: Freakin Admin \(Administrator\)/, response

    group.stubs(:closed_by).returns(nil)
    response = ActionController::Base.helpers.strip_tags(display_closed_group_data(group))
    assert_match /Closed By: Admin/, response

    group.termination_mode = Group::TerminationMode::EXPIRY
    group.save!
    response = ActionController::Base.helpers.strip_tags(display_closed_group_data(group))
    assert_match /Auto closed/, response
    assert_no_match(/Admin/, response)
  end

  def test_get_task_status_filter_options
    assert_equal [["Completed", 0], ["Not Completed", 1], ["Overdue", 2]], get_task_status_filter_options
  end

  def test_get_task_status_custom_filter_text_when_filters_are_applied
    operators = []
    assert_equal "0 tasks in different statuses", get_task_status_custom_filter_text_when_filters_are_applied(operators)

    operators = ["#{MentoringModel::Task::StatusFilter::COMPLETED}"]
    assert_equal "1 task in completed status", get_task_status_custom_filter_text_when_filters_are_applied(operators)

    operators = ["#{MentoringModel::Task::StatusFilter::COMPLETED}", "#{MentoringModel::Task::StatusFilter::COMPLETED}"]
    assert_equal "2 tasks in completed status", get_task_status_custom_filter_text_when_filters_are_applied(operators)

    operators = ["#{MentoringModel::Task::StatusFilter::COMPLETED}", "#{MentoringModel::Task::StatusFilter::NOT_COMPLETED}"]
    assert_equal "2 tasks in different statuses", get_task_status_custom_filter_text_when_filters_are_applied(operators)

    operators = ["#{MentoringModel::Task::StatusFilter::OVERDUE}"]
    assert_equal "1 task in overdue status", get_task_status_custom_filter_text_when_filters_are_applied(operators)

    operators = ["#{MentoringModel::Task::StatusFilter::NOT_COMPLETED}", "#{MentoringModel::Task::StatusFilter::NOT_COMPLETED}"]
    assert_equal "2 tasks in not completed status", get_task_status_custom_filter_text_when_filters_are_applied(operators)
  end

  def test_get_task_status_custom_filter_text
    assert_equal "Custom (<small>Selected tasks with status</small>)", get_task_status_custom_filter_text(nil)
    assert_equal "Custom (<small>Selected tasks with status</small>)", get_task_status_custom_filter_text({})
    assert_equal "Custom (<small>Selected tasks with status</small>)", get_task_status_custom_filter_text({custom_v2_tasks_status: {}})
    assert_equal "0 tasks in different statuses", get_task_status_custom_filter_text({custom_v2_tasks_status: {rows: {}}})
    assert_equal "1 task in not completed status", get_task_status_custom_filter_text({custom_v2_tasks_status: {rows: {"0" => {operator: "#{MentoringModel::Task::StatusFilter::NOT_COMPLETED}"}}}})
    assert_equal "2 tasks in different statuses", get_task_status_custom_filter_text({custom_v2_tasks_status: {rows: {"0" => {operator: "#{MentoringModel::Task::StatusFilter::NOT_COMPLETED}"}, "1" => {operator: "#{MentoringModel::Task::StatusFilter::COMPLETED}"}}}})
  end

  def test_get_custom_task_status_filter_hidden_fields
    assert_equal "", get_custom_task_status_filter_hidden_fields(nil)
    assert_equal "", get_custom_task_status_filter_hidden_fields({})
    assert_equal "", get_custom_task_status_filter_hidden_fields({custom_v2_tasks_status: {}})
    assert_select_helper_function "input[class=\"cjs_hidden_custom_task_filter\"][id=\"cjs_hidden_custom_task_filter_template\"][name=\"search_filters[custom_v2_tasks_status][template]\"][type=\"hidden\"][value=\"5\"]", get_custom_task_status_filter_hidden_fields({custom_v2_tasks_status: {template: "5"}})

    assert_select_helper_function_block "div[class=\"hide cjs_hidden_custom_task_filter cjs_hidden_custom_task_rows\"]", get_custom_task_status_filter_hidden_fields({custom_v2_tasks_status: {rows: {"0" => {operator: 'op', task_id: 'tid'}}}}) do
      assert_select "input[class=\"cjs_hidden_custom_task_filter_task\"][id=\"search_filters_custom_v2_tasks_status_rows_0_task_id\"][name=\"search_filters[custom_v2_tasks_status][rows][0][task_id]\"][type=\"hidden\"][value=\"tid\"]"
      assert_select "input[class=\"cjs_hidden_custom_task_filter_operator\"][id=\"search_filters_custom_v2_tasks_status_rows_0_operator\"][name=\"search_filters[custom_v2_tasks_status][rows][0][operator]\"][type=\"hidden\"][value=\"op\"]"
    end
    set_response_text get_custom_task_status_filter_hidden_fields({custom_v2_tasks_status: {rows: {"0" => {operator: 'op0', task_id: 'tid0'}, "1" => {operator: 'op1', task_id: 'tid1'}}}})
    assert_select "div[class=\"hide cjs_hidden_custom_task_filter cjs_hidden_custom_task_rows\"]" do
      assert_select "input[class=\"cjs_hidden_custom_task_filter_task\"][id=\"search_filters_custom_v2_tasks_status_rows_0_task_id\"][name=\"search_filters[custom_v2_tasks_status][rows][0][task_id]\"][type=\"hidden\"][value=\"tid0\"]"
      assert_select "input[class=\"cjs_hidden_custom_task_filter_operator\"][id=\"search_filters_custom_v2_tasks_status_rows_0_operator\"][name=\"search_filters[custom_v2_tasks_status][rows][0][operator]\"][type=\"hidden\"][value=\"op0\"]"
    end
    assert_select "div[class=\"hide cjs_hidden_custom_task_filter cjs_hidden_custom_task_rows\"]" do
      assert_select "input[class=\"cjs_hidden_custom_task_filter_task\"][id=\"search_filters_custom_v2_tasks_status_rows_1_task_id\"][name=\"search_filters[custom_v2_tasks_status][rows][1][task_id]\"][type=\"hidden\"][value=\"tid1\"]"
      assert_select "input[class=\"cjs_hidden_custom_task_filter_operator\"][id=\"search_filters_custom_v2_tasks_status_rows_1_operator\"][name=\"search_filters[custom_v2_tasks_status][rows][1][operator]\"][type=\"hidden\"][value=\"op1\"]"
    end
  end

  def test_mentoring_connections_v2_behind_schedule
    self.stubs(:get_task_status_custom_filter_text).returns("custom_filter_text")
    self.stubs(:get_custom_task_status_filter_hidden_fields).returns("filter_hidden_fields")
    html_content = to_html(mentoring_connections_v2_behind_schedule(nil))
    assert_select html_content, "div.collapse.in", count: 0
    assert_select html_content, "div.collapse" do
      assert_select "input[type=radio]", count: 4
      assert_select "input[type=radio][value=''][checked=checked]"
      assert_select "a#cjs_custom_task_status_filter_popup", text: "custom_filter_text", count: 1
    end

    html_content = to_html(mentoring_connections_v2_behind_schedule({v2_tasks_status: GroupsController::TaskStatusFilter::OVERDUE}))
    assert_select html_content, "div.collapse.in" do
      assert_select "input[type=radio]", count: 4
      assert_select "input[type=radio][value='#{GroupsController::TaskStatusFilter::OVERDUE}'][checked=checked]"
      assert_select "a#cjs_custom_task_status_filter_popup", text: "custom_filter_text", count: 1
    end

    html_content = to_html(mentoring_connections_v2_behind_schedule({v2_tasks_status: GroupsController::TaskStatusFilter::CUSTOM}))
    assert_select html_content, "div.collapse.in" do
      assert_select "input[type=radio]", count: 4
      assert_select "input[type=radio][value='#{GroupsController::TaskStatusFilter::CUSTOM}'][checked=checked]"
      assert_select "a#cjs_custom_task_status_filter_popup", text: "custom_filter_text", count: 1
    end
  end

  def test_options_for_bulk_send_message_to_groups
    program = programs(:albers)
    group_ids = Group.pluck(:id)
    assert_false program.project_based?

    options = options_for_bulk_send_message_to_groups(group_ids, program)
    assert_equal 3, options.size

    program = programs(:pbe)
    Program.any_instance.stubs(:project_based?).returns(false)
    self.stubs(:get_users_count_string_for_bulk_send_message_to_groups_of_type).times(4).returns("2 users")
    options = options_for_bulk_send_message_to_groups(group_ids, program)
    assert_equal 4, options.size
    assert_equal ["All teachers in the selected mentoring connections (2 users)", RoleConstants::TEACHER_NAME], options.last

    Program.any_instance.stubs(:project_based?).returns(true)
    self.stubs(:get_users_count_string_for_bulk_send_message_to_groups_of_type).times(5).returns("3 users")
    options = options_for_bulk_send_message_to_groups(group_ids, program)
    assert_equal 5, options.size
    assert_equal ["All owners of the selected mentoring connections (3 users)", Connection::Membership::SendMessage::OWNER], options.last

    self.stubs(:get_option_for_bulk_send_message_to_groups).returns([])
    options = options_for_bulk_send_message_to_groups(group_ids, program)
    assert_equal [], options
  end

  def test_get_option_for_bulk_send_message_to_groups
    program = programs(:albers)
    program_roles = RoleConstants.program_roles_mapping(program, pluralize: true, no_capitalize: true)
    group_ids = Group.pluck(:id)
    self.stubs(:get_users_count_string_for_bulk_send_message_to_groups_of_type).returns("2 users")
    option = get_option_for_bulk_send_message_to_groups(group_ids, program, Connection::Membership::SendMessage::ALL, program_roles)
    assert_equal ["All users in the selected mentoring connections (2 users)", Connection::Membership::SendMessage::ALL], option

    option = get_option_for_bulk_send_message_to_groups(group_ids, program, RoleConstants::MENTOR_NAME, program_roles)
    assert_equal ["All mentors in the selected mentoring connections (2 users)", RoleConstants::MENTOR_NAME], option

    option = get_option_for_bulk_send_message_to_groups(group_ids, program, Connection::Membership::SendMessage::OWNER, program_roles)
    assert_equal ["All owners of the selected mentoring connections (2 users)", Connection::Membership::SendMessage::OWNER], option

    self.stubs(:get_users_count_string_for_bulk_send_message_to_groups_of_type).returns(nil)
    assert_equal [], get_option_for_bulk_send_message_to_groups(group_ids, program, Connection::Membership::SendMessage::ALL, program_roles)
  end

  def test_get_users_count_string_for_bulk_send_message_to_groups_of_type
    program = programs(:albers)
    group_ids = Group.pluck(:id)
    type = Connection::Membership::SendMessage::ALL
    Connection::Membership.stubs(:user_ids_in_groups).with(group_ids, program, type).returns([1,2,3])
    string = get_users_count_string_for_bulk_send_message_to_groups_of_type(group_ids, program, type)
    assert_equal "3 users", string

    Connection::Membership.stubs(:user_ids_in_groups).with(group_ids, program, type).returns([4])
    string = get_users_count_string_for_bulk_send_message_to_groups_of_type(group_ids, program, type)
    assert_equal "1 user", string

    Connection::Membership.stubs(:user_ids_in_groups).with(group_ids, program, type).returns([])
    assert_nil get_users_count_string_for_bulk_send_message_to_groups_of_type(group_ids, program, type)
  end

  def test_multiple_templates_filters
    program = programs(:albers)
    mentoring_model_1 = program.default_mentoring_model
    mentoring_model_2 = create_mentoring_model(title: "Carrie Mathison", program_id: program.id)

    content = multiple_templates_filters(program, mentoring_models: ["#{mentoring_model_1.id}", "#{mentoring_model_2.id}"])
    assert_select_helper_function_block "div.filter_item", content do
      assert_select "div.collapse.in" do
        assert_select "input[type='checkbox']", count: 2
        assert_select "input[type='checkbox'][name='search_filters[mentoring_models][]'][onclick='GroupSearch.applyFilters();'][value='#{mentoring_model_1.id}'][checked='checked']"
        assert_select "input[type='checkbox'][name='search_filters[mentoring_models][]'][onclick='GroupSearch.applyFilters();'][value='#{mentoring_model_2.id}'][checked='checked']"
        assert_select "a#reset_filter_mentoring_model_filters"
      end
    end

    content = multiple_templates_filters(program, nil)
    assert_select_helper_function_block "div.filter_item", content do
      assert_no_select "div.collapse.in"
      assert_select "div.collapse" do
        assert_select "input[type='checkbox']", count: 2
        assert_no_select "input[type='checkbox'][checked='checked']"
        assert_select "input[type='checkbox'][name='search_filters[mentoring_models][]'][onclick='GroupSearch.applyFilters();'][value='#{mentoring_model_1.id}']"
        assert_select "input[type='checkbox'][name='search_filters[mentoring_models][]'][onclick='GroupSearch.applyFilters();'][value='#{mentoring_model_2.id}']"
        assert_select "a#reset_filter_mentoring_model_filters"
      end
    end
  end

  def test_closure_reason_filters
    program = programs(:albers)
    closure_reasons = program.group_closure_reasons
    closure_reason_1 = closure_reasons[0]
    closure_reason_2 = closure_reasons[5]
    assert_equal 6, closure_reasons.size

    content = closure_reason_filters(program, closure_reasons: ["#{closure_reason_1.id}", "#{closure_reason_2.id}"])
    assert_select_helper_function_block "div.filter_item", content do
      assert_select "div.collapse.in" do
        assert_select "input[type='checkbox']", count: 6
        assert_select "input[type='checkbox'][checked='checked']", count: 2
        assert_select "input[type='checkbox'][name='search_filters[closure_reasons][]'][onclick='GroupSearch.applyFilters();'][value='#{closure_reason_1.id}'][checked='checked']"
        assert_select "input[type='checkbox'][name='search_filters[closure_reasons][]'][onclick='GroupSearch.applyFilters();'][value='#{closure_reason_2.id}'][checked='checked']"
        (closure_reasons - [closure_reason_1, closure_reason_2]).each do |closure_reason|
          assert_select "input[type='checkbox'][name='search_filters[closure_reasons][]'][onclick='GroupSearch.applyFilters();'][value='#{closure_reason.id}']"
        end
        assert_select "a#reset_filter_closure_reason_filters"
      end
    end

    content = closure_reason_filters(program, nil)
    assert_select_helper_function_block "div.filter_item", content do
      assert_no_select "div.collapse.in"
      assert_select "div.collapse" do
        assert_select "input[type='checkbox']", count: 6
        assert_no_select "input[type='checkbox'][checked='checked']"
        closure_reasons.each do |closure_reason|
          assert_select "input[type='checkbox'][name='search_filters[closure_reasons][]'][onclick='GroupSearch.applyFilters();'][value='#{closure_reason.id}']"
        end
        assert_select "a#reset_filter_closure_reason_filters"
      end
    end
  end

  def test_generate_data_for_groups_date_filters
    Time.zone = "Pacific/Apia"
    time = Time.new(2016, 7, 10, 0, 0, 1, "+13:00")
    Timecop.freeze(time) do
      start_time = time.beginning_of_day
      end_time = time.end_of_day
      expected_start_date = start_time.to_date
      expected_end_date = end_time.to_date
      daterange_presets = [DateRangePresets::NEXT_7_DAYS, DateRangePresets::NEXT_30_DAYS, DateRangePresets::CUSTOM]
      min_date = time.to_date
      max_date = ""

      expected =  []
      expected << "Closes on"
      expected << "expiry_date"
      expected << { start: expected_start_date, end: expected_end_date }
      expected << { presets: daterange_presets, min_date: min_date, max_date: max_date, is_reports_view: false }
      assert_equal expected, generate_data_for_groups_date_filters("expiry_date", start_time, end_time)

      daterange_presets = [DateRangePresets::LAST_7_DAYS, DateRangePresets::LAST_30_DAYS, DateRangePresets::CUSTOM]
      min_date = ""
      max_date = time.to_date

      expected =  []
      expected << "Closed on"
      expected << "closed_date"
      expected << {}
      expected << { presets: daterange_presets, min_date: min_date, max_date: max_date, is_reports_view: false }
      assert_equal expected, generate_data_for_groups_date_filters("closed_date")
    end
  end

  def test_get_formatted_choices_for_connection_question
    choices_hash = { "1" => "a", "2" => "b", "3" => "c" }
    content = get_formatted_choices_for_connection_question(choices_hash, "23", ["1"])
    assert_select_helper_function "input[name='connection_questions[23][]'][type='checkbox']", content, count: 3, onchange: "GroupSearch.applyFilters();"
    assert_select_helper_function "input[type='checkbox'][checked='checked']", content, count: 1
    assert_select_helper_function "input[type='checkbox'][value='1'][checked='checked']", content
    assert_select_helper_function "input[type='checkbox'][value='2']", content
    assert_select_helper_function "input[type='checkbox'][value='3']", content
    assert_select_helper_function "div", content, text: "a"
    assert_select_helper_function "div", content, text: "b"
    assert_select_helper_function "div", content, text: "c"
  end

  def test_groups_listing_filter_params
    assert_equal_hash( {
      search_filters: { "a" => { "a1" => 1, "a2" => 2 } },
      member_filters: "y",
      connection_questions: "b",
      sub_filter: "v",
      member_profile_filters: "s"
    }, groups_listing_filter_params)
  end

  def test_reset_groups_listing_filter_params
    assert_equal_hash( {
      search_filters: {},
      member_filters: {},
      connection_questions: {},
      sub_filter: {},
      member_profile_filters: {}
    }, reset_groups_listing_filter_params)
  end

  def test_state_to_string_map
    assert_equal_hash( {
      Group::Status::ACTIVE => "Active",
      Group::Status::INACTIVE => "Inactive",
      Group::Status::CLOSED => "Closed",
      Group::Status::DRAFTED => "Drafted",
      Group::Status::PENDING => "Pending",
      Group::Status::PROPOSED => "Proposed",
      Group::Status::REJECTED => "Rejected",
      Group::Status::WITHDRAWN => "Withdrawn"
    }, GroupsHelper.state_to_string_map)
  end

  def test_state_to_string_downcase_map
    assert_equal_hash( {
      Group::Status::ACTIVE => "active",
      Group::Status::INACTIVE => "inactive",
      Group::Status::CLOSED => "closed",
      Group::Status::DRAFTED => "drafted",
      Group::Status::PENDING => "pending",
      Group::Status::PROPOSED => "proposed",
      Group::Status::REJECTED => "rejected",
      Group::Status::WITHDRAWN => "withdrawn"
    }, GroupsHelper.state_to_string_downcase_map)
  end

  def test_generate_connection_summary_expires
    group = groups(:mygroup)
    stub_current_program(programs(:albers))
    current_user_is users(:f_mentor)

    # Active
    result = generate_connection_summary_expires(group)
    set_response_text result

    assert_select "div.group_expires_on", text: "Expires on"
    assert_select "div.group_expires_in" do
      assert_select "span.cjs_expiry_in_group", text: formatted_time_in_words(group.expiry_time, :no_ago => true, :no_time => true)
    end

    # Closed
    closure_reason = group.program.permitted_closure_reasons.first
    group.terminate!(users(:f_admin), 'My termination_reason', closure_reason.id)
    result = generate_connection_summary_expires(group)
    set_response_text result

    assert_select "div.group_expires_on", text: "Closed on"
    assert_select "div.group_expires_in", text: formatted_time_in_words(group.closed_at, :no_ago => true, :no_time => true) do
      assert_select "span.cjs_expiry_in_group", count: 0
    end
  end

  def test_select_box_in_checkin_form_for
    form = mock()
    # For hours
    hours_options = (0..100).map { |n| [n, n] }
    form.expects(:select).with(:hours, options_for_select(hours_options, 0), {}, class: "fixed-spinner form-control", id: "checkin_hours_1_1", style: "width:75px;").once
    text = select_box_in_checkin_form_for(:hours, form, 1, 1)

    # For minutes
    minutes_options = [[0, 0], [15, 15], [30, 30], [45, 45]]
    form.expects(:select).with(:minutes, options_for_select(minutes_options, 30), {}, class: "fixed-spinner form-control", id: "checkin_minutes_1_1", style: "width:75px;").once
    text = select_box_in_checkin_form_for(:minutes, form, 1, 1)
  end

  def test_group_meetings_status
    member = members(:f_mentor)
    stubs(:wob_member).returns(member)
    group = groups(:mygroup)
    stub_current_program(group.program)
    group.stubs(:can_manage_mm_meetings?).returns(true)

    result = group_meeetings_status(group)
    set_response_text(result)

    meetings = Meeting.get_meetings_for_view(group, true, member, group.program)
    upcoming_meetings, completed_meetings = Meeting.recurrent_meetings(meetings)

    assert_select "h4", text: "Status"
    assert_select "div", text: "Meetings - #{completed_meetings.count} Completed, #{upcoming_meetings.count} Upcoming" do
      assert_select "i.fa-calendar"
    end

    # No meetings
    group.meetings.update_all(active: false)
    set_response_text(group_meeetings_status(group))
    assert_select "h4", text: "Status"
    assert_select "div", text: "No meetings scheduled yet"
  end

  def test_render_allow_to_join
    group = groups(:mygroup)
    program = group.program
    stub_current_program(program)
    assert_nil render_allow_to_join(group)

    group = groups(:group_pbe_0)
    program = group.program
    stub_current_program(program)
    Program.any_instance.stubs(:slot_config_enabled?).returns(false)
    result = render_allow_to_join(group)
    set_response_text(result)
    assert_select "input[type='hidden'][name='group[membership_settings][allow_join]'][value='false']"
    assert_select "label.checkbox", text: "Allow new users to send requests to join this mentoring connection." do
      assert_select "input[name='group[membership_settings][allow_join]'][value='true']"
    end

    Program.any_instance.stubs(:slot_config_enabled?).returns(true)
    result = render_allow_to_join(group, true)
    set_response_text(result)
    assert_select "input[type='hidden'][name='bulk_actions[membership_settings][allow_join]'][value='false']"
    assert_select "label.checkbox", text: "Allow new users to send requests to join this mentoring connection for the available slots." do
      assert_select "input[name='bulk_actions[membership_settings][allow_join]'][value='true']"
    end

    Program.any_instance.stubs(:allows_users_to_apply_to_join_in_project?).returns(false)
    assert_nil render_allow_to_join(group)
  end

  def test_group_start_date_with_set_start_date_content
    start_date = Time.now
    group = groups(:mygroup)

    self.stubs(:start_date_with_update_date_content).with(group, start_date).returns("with start date")
    self.stubs(:set_new_start_date_content).with(group).returns("without start date")

    assert_equal "with start date", group_start_date_with_set_start_date_content(group, start_date)
    assert_equal "without start date", group_start_date_with_set_start_date_content(group, nil)
  end

  def test_start_date_with_update_date_content
    group = groups(:mygroup)
    start_date = Time.now + 2.days
    old_start_date = 2.days.ago

    set_response_text(start_date_with_update_date_content(group, start_date))
    assert_select "span.m-r-xxs", :text => DateTime.localize(start_date, format: :short)
    assert_select "a.cjs_set_or_edit_connection_start_date", :text => "Change date"
    assert_select "a[data-url=\"#{get_edit_start_date_popup_group_path(id: group.id)}\"]"
    assert_select "a[href=\"javascript:void(0)\"]"

    Group.any_instance.stubs(:has_past_start_date?).returns(true)
    set_response_text(start_date_with_update_date_content(group, old_start_date))
    assert_select "span.m-r-xxs.text-danger", :text => DateTime.localize(old_start_date, format: :short)
    assert_select "a.cjs_set_or_edit_connection_start_date", :text => "Change date"
    assert_select "a[data-url=\"#{get_edit_start_date_popup_group_path(id: group.id)}\"]"
    assert_select "a[href=\"javascript:void(0)\"]"
  end

  def test_set_new_start_date_content
    group = groups(:mygroup)

    set_response_text(set_new_start_date_content(group))
    assert_select "span.m-r-xxs", :text => "feature.connection.content.Not_set".translate
    assert_select "a.cjs_set_or_edit_connection_start_date", :text => "Set date"
    assert_select "a[data-url=\"#{get_edit_start_date_popup_group_path(id: group.id)}\"]"
    assert_select "a[href=\"javascript:void(0)\"]"
  end

  def test_get_start_date_content
    group = groups(:mygroup)
    user = users(:mkr_student)
    start_date = Time.now

    User.any_instance.stubs(:can_set_start_date_for_group?).with(group).returns(false)
    self.stubs(:group_start_date_with_set_start_date_content).with(group, start_date).returns("date content")
    assert_equal DateTime.localize(start_date, format: :short), get_start_date_content(group, user, start_date)

    User.any_instance.stubs(:can_set_start_date_for_group?).with(group).returns(true)
    assert_equal "date content", get_start_date_content(group, user, start_date)
  end

  def test_get_page_title_for_new_group_creation
    user = users(:f_mentor_pbe)
    
    User.any_instance.stubs(:can_create_group_without_approval?).returns(false)
    assert_equal "Propose a New Mentoring Connection", get_page_title_for_new_group_creation(true, user)

    User.any_instance.stubs(:can_create_group_without_approval?).returns(true)
    assert_equal "Start a New Mentoring Connection", get_page_title_for_new_group_creation(true, user)

    assert_equal "New Mentoring Connection", get_page_title_for_new_group_creation(false, user)
  end

  def test_render_start_date_content
    Time.zone = "Asia/Kolkata"

    group = groups(:mygroup)
    user = users(:mkr_student)
    start_date = Time.now.beginning_of_day + 12.hours
    
    Program.any_instance.stubs(:project_based?).returns(false)
    User.any_instance.stubs(:can_be_shown_group_start_date?).with(group).returns(true)
    assert_nil render_start_date_content(group, user)

    Program.any_instance.stubs(:project_based?).returns(true)
    User.any_instance.stubs(:can_be_shown_group_start_date?).with(group).returns(false)
    assert_nil render_start_date_content(group, user)

    Program.any_instance.stubs(:project_based?).returns(true)
    User.any_instance.stubs(:can_be_shown_group_start_date?).with(group).returns(true)
    
    User.any_instance.stubs(:can_set_start_date_for_group?).with(group).returns(false)
    assert_nil render_start_date_content(group, user)

    User.any_instance.stubs(:can_set_start_date_for_group?).with(group).returns(false)
    group.update_attribute(:start_date, start_date)
    Group.any_instance.stubs(:has_past_start_date?).returns(true)
    assert_nil render_start_date_content(group, user)
    
    Group.any_instance.stubs(:has_past_start_date?).returns(false)
    
    set_response_text(render_start_date_content(group, user))
    assert_select "div.m-b-sm.cjs_circle_start_date_#{group.id}" do
      assert_select "h4.m-t-sm.m-b-xs", :text => "feature.connection.content.start_date_label".translate
      assert_select "div", :text => DateTime.localize(start_date, format: :short)
    end

    User.any_instance.stubs(:can_set_start_date_for_group?).with(group).returns(true)
    self.stubs(:group_start_date_with_set_start_date_content).returns("date content")
    
    set_response_text(render_start_date_content(group, user))
    assert_select "div.m-b-sm.cjs_circle_start_date_#{group.id}" do
      assert_select "h4.m-t-sm.m-b-xs", :text => "feature.connection.content.start_date_label".translate
      assert_select "div", :text => "date content"
    end
  end

  def test_render_roles_for_join_settings
    group = groups(:group_pbe_0)
    program = group.program
    available_roles = program.roles.for_mentoring.with_permission_name(RolePermission::SEND_PROJECT_REQUEST)

    set_response_text render_roles_for_join_settings(group)
    available_roles.each do |role|
      assert_select "input[name='group[role_permission][#{role.id}]'][type='hidden'][value='false']"
      assert_select "label.checkbox", text: RoleConstants.human_role_string([role.name]) do
        assert_select "input[name='group[role_permission][#{role.id}]'][checked='checked']"
      end
    end
    teacher_role = program.find_role(RoleConstants::TEACHER_NAME)
    assert_select "input[name='group[role_permission][#{teacher_role.id}]'][checked='checked']", count: 0

    role = available_roles.first
    membership_setting = group.membership_settings.find_or_create_by(role_id: role.id)
    membership_setting.update_column(:allow_join, false)

    set_response_text render_roles_for_join_settings(group)

    assert_select "label.checkbox", text: RoleConstants.human_role_string([role.name]) do
      assert_select "input[name='group[role_permission][#{role.id}]'][checked='checked']", count: 0
    end
  end

def test_render_add_tasks_for_project_requests
    form = mock()
    form.stubs(:radio_button).returns("")
    group = groups(:group_pbe_0)
    program = group.program
    stub_current_program(program)
    project_request_ids = group.project_requests.pluck(:id)

    assert_nil render_add_tasks_for_project_requests(form, project_request_ids)
    group.update_column(:status, Group::Status::ACTIVE)

    # multiple users requesting for single group
    set_response_text render_add_tasks_for_project_requests(form, project_request_ids)
    assert_select "div.m-t-md.clearfix.m-b-md" do
      assert_select "div", text: "There are 2 users who have requested to join a mentoring connection which has already started. Please choose an option below"
    end

    # multiple users requesting for multiple groups
    new_group = groups(:group_pbe_1)
    new_group.update_column(:status, Group::Status::ACTIVE)
    project_request_ids << create_project_request(new_group, users(:f_student_pbe)).id
    set_response_text render_add_tasks_for_project_requests(form, project_request_ids)
    assert_select "div.m-t-md.clearfix.m-b-md" do
      assert_select "div", text: "There are 3 users who have requested to join 2 mentoring connections which have already started. Please choose an option below"
    end

    # single user requesting for single group
    set_response_text render_add_tasks_for_project_requests(form, group.project_requests.first.id)
    assert_select "div.m-t-md.clearfix.m-b-md" do
      assert_select "div", text: "There is 1 user who has requested to join a mentoring connection which has already started. Please choose an option below"
    end
  end

  def test_render_publish_circle_widget_slot_tooltip
    program = programs(:albers)
    group = groups(:mygroup)
    role_name = RoleConstants::MENTOR_NAME
    role = program.get_role(role_name)

    assert_nil group.setting_for_role_id(role.id)

    content = render_publish_circle_widget_slot_tooltip(group, role_name)
    set_response_text content
    assert_select "script", text: "\n//<![CDATA[\njQuery(\"#slot_tooltip_#{group.id}_#{role.id}_web\").tooltip({html: true, title: '<div>No slot limit</div>', placement: \"top\", container: \"#slot_tooltip_#{group.id}_#{role.id}_web\", delay: { \"show\" : 500, \"hide\" : 100 } } );jQuery(\"#slot_tooltip_#{group.id}_#{role.id}_web\").on(\"remove\", function () {jQuery(\"#slot_tooltip_#{group.id}_#{role.id}_web .tooltip\").hide().remove();})\n//]]>\n"
    assert_select "span#slot_tooltip_#{group.id}_#{role.id}_web" do
      assert_select "i.fa.fa-info-circle.m-l-xs"
    end

    group_setting = group.membership_settings.create(role_id: role.id, max_limit: 5)

    content = render_publish_circle_widget_slot_tooltip(group, role_name, true)
    set_response_text content
    assert_select "script", text: "\n//<![CDATA[\njQuery(\"#slot_tooltip_#{group.id}_#{role.id}_mobile\").tooltip({html: true, title: '<div>4 slots left</div>', placement: \"top\", container: \"#slot_tooltip_#{group.id}_#{role.id}_mobile\", delay: { \"show\" : 500, \"hide\" : 100 } } );jQuery(\"#slot_tooltip_#{group.id}_#{role.id}_mobile\").on(\"remove\", function () {jQuery(\"#slot_tooltip_#{group.id}_#{role.id}_mobile .tooltip\").hide().remove();})\n//]]>\n"
    assert_select "span#slot_tooltip_#{group.id}_#{role.id}_mobile" do
      assert_select "i.fa.fa-info-circle.m-l-xs"
    end
  end

  def test_get_circle_remaining_slot_info_for_role
    program = programs(:albers)
    group = groups(:mygroup)
    role_name = RoleConstants::MENTOR_NAME
    role = program.get_role(role_name)

    assert_nil group.setting_for_role_id(role.id)
    assert_equal "No slot limit", get_circle_remaining_slot_info_for_role(group, role_name)

    group_setting = group.membership_settings.create(role_id: role.id, max_limit: 5)
    assert_equal "4 slots left", get_circle_remaining_slot_info_for_role(group, role_name)
  end

  def test_get_publish_action
    group = groups(:group_pbe_0)

    result = get_publish_action(group, {src: "test source"})
    assert_match "Publish Mentoring Connection", result[:label]
    assert_match fetch_publish_group_path(group, src: "test source"), result[:js]
  end

  def test_get_safe_member_profile_filters
    member_profile_filters = {"83" => [{"field" => "column220","operator" => "eq","value" => "value"}], "84" => [{"field" => "column220","operator" => "eq","value" => "value"}, {"field" => "column222","operator" => "eq","value" => "value"}]}
    assert_equal ({"83" => [{"field" => "column220","operator" => "eq","value" => "value"}], "84" => [{"field" => "column220","operator" => "eq","value" => "value"}, {"field" => "column222","operator" => "eq","value" => "value"}]}), get_safe_member_profile_filters(member_profile_filters)

    member_profile_filters = {"83" => [{"field" => "<script>alert()</script>","operator" => "eq","value" => "value"}]}
    assert_equal ({"83"=>[{"field"=>"<script>alert()<\\/script>", "operator"=>"eq", "value"=>"value"}]}), get_safe_member_profile_filters(member_profile_filters)
  end

  def test_get_engagement_surveys
    program = programs(:albers)
    program.surveys.of_engagement_type.destroy_all
    survey = create_engagement_survey(:name => "Test Survey", :program => program)
    create_survey_question({survey: survey, program: program})
    survey1 = create_engagement_survey(:name => "Test Survey1", :program => program)
    create_survey_question({survey: survey1, program: program})
    assert_equal 2, get_engagement_surveys(program).size
  end

  def test_fetch_date_change_action
    group = groups(:mygroup)
    program = group.program
    stub_current_program(program)
    set_response_text fetch_date_change_action(group)
    assert_select "a#set_expiry_date_1", text: "(change)"
    set_response_text fetch_date_change_action(group, home_page: true)
    assert_select "a#set_expiry_date_1", text: "(Extend)"
  end

  def test_initialize_memberships_for_select2
    group = groups(:mygroup)
    program = group.program
    mentor_role = program.find_role(RoleConstants::MENTOR_NAME)

    expected_hash = [ { nameEmail: "Good unique name <robert@example.com>", userId: users(:f_mentor).id, nameEmailForDisplay: "Good unique name &lt;robert@example.com&gt;" } ].to_json
    assert_equal expected_hash, initialize_memberships_for_select2(group, mentor_role)

    cloned_group = Group::CloneFactory.new(group, program).clone
    assert_equal expected_hash, initialize_memberships_for_select2(cloned_group, mentor_role, true)
  end

  def test_display_project_based_group_in_auto_complete
    group = Group.first
    group_roles = group.program.roles.for_mentoring
    mentor_role = group_roles.find{ |r| r.name == 'mentor' }
    mentee_role = group_roles.find{ |r| r.name == 'student' }
    group.membership_settings.create(role_id: mentor_role.id, max_limit: nil)
    group.membership_settings.create(role_id: mentee_role.id, max_limit: 5)

    response = display_project_based_group_in_auto_complete(group, group_roles)
    slots_left = 5 - group.memberships.select{|membership| membership.role_id == mentee_role.id}.size
    assert_select_helper_function "b", response, text: group.name
    assert_select_helper_function "span", response, text: "Mentors : No slot limit"
    assert_select_helper_function "span", response, text: "Students : #{slots_left} out of 5 slots left"
    assert_select_helper_function "div.label-success", response
  end

  def test_get_grouped_select_options_for_closure_reasons
    program = programs(:albers)
    result = get_grouped_select_options_for_closure_reasons(program)
    assert_select_helper_function_block "optgroup[label='Completed Mentoring Connections']",  result do
      assert_select "option[selected=\"selected\"]", text: "Accomplished goals of connection"
    end
    assert_select_helper_function_block "optgroup[label='Incomplete Mentoring Connections']",  result do
      assert_select "option", text: "Lack of communication or availability between participants"
      assert_select "option", text: "Needs changed and no longer seeking this particular connection"
      assert_select "option", text: "Other"
    end

    program.permitted_closure_reasons.non_default.completed.destroy_all
    result = get_grouped_select_options_for_closure_reasons(program)
    assert_select_helper_function "optgroup[label='Completed Mentoring Connections']",  result, count: 0
    assert_select_helper_function_block "optgroup[label='Incomplete Mentoring Connections']",  result do
      assert_select "option", text: "Lack of communication or availability between participants"
      assert_select "option", text: "Needs changed and no longer seeking this particular connection"
      assert_select "option", text: "Other"
    end
  end

  def test_get_dashboard_filters_in_groups_listing_flash
    count = 6
    current_tab_count = 3
    time = "#{DateTime.localize("15/06/2018".to_time, format: :abbr_short)} - #{DateTime.localize("17/06/2018".to_time, format: :abbr_short)}"

    self.stubs(:get_dashboard_filters_in_groups_listing_flash_ongoing_link).with(count, current_tab_count, {type: GroupsController::DashboardFilter::NEUTRAL_BAD, start_date: "15/06/2018", end_date: "17/06/2018"}, "tab").returns("ongoing_link")
    self.stubs(:get_dashboard_filters_in_groups_listing_flash_closed_link).with(count, current_tab_count, {type: GroupsController::DashboardFilter::NEUTRAL_BAD, start_date: "15/06/2018", end_date: "17/06/2018"}, "tab").returns("closed_link")
    assert_equal "feature.group.content.dashboard_filter.negative_html".translate(count: count, ongoing_count_link: "ongoing_link", closed_count_link: "closed_link", connection: _mentoring_connection, connections: _mentoring_connections, time: time), get_dashboard_filters_in_groups_listing_flash(count, current_tab_count, {type: GroupsController::DashboardFilter::NEUTRAL_BAD, start_date: "15/06/2018", end_date: "17/06/2018"}, "tab")

    self.stubs(:get_dashboard_filters_in_groups_listing_flash_ongoing_link).with(count, current_tab_count, {type: GroupsController::DashboardFilter::GOOD, start_date: "15/06/2018", end_date: "17/06/2018"}, "tab").returns("ongoing_link")
    self.stubs(:get_dashboard_filters_in_groups_listing_flash_closed_link).with(count, current_tab_count, {type: GroupsController::DashboardFilter::GOOD, start_date: "15/06/2018", end_date: "17/06/2018"}, "tab").returns("closed_link")
    assert_equal "feature.group.content.dashboard_filter.positive_html".translate(count: count, ongoing_count_link: "ongoing_link", closed_count_link: "closed_link", connection: _mentoring_connection, connections: _mentoring_connections, time: time), get_dashboard_filters_in_groups_listing_flash(count, current_tab_count, {type: GroupsController::DashboardFilter::GOOD, start_date: "15/06/2018", end_date: "17/06/2018"}, "tab")

    self.stubs(:get_dashboard_filters_in_groups_listing_flash_ongoing_link).with(count, current_tab_count, {type: GroupsController::DashboardFilter::NO_RESPONSE, start_date: "15/06/2018", end_date: "17/06/2018"}, "tab").returns("ongoing_link")
    self.stubs(:get_dashboard_filters_in_groups_listing_flash_closed_link).with(count, current_tab_count, {type: GroupsController::DashboardFilter::NO_RESPONSE, start_date: "15/06/2018", end_date: "17/06/2018"}, "tab").returns("closed_link")
    assert_equal "feature.group.content.dashboard_filter.no_responses_html".translate(count: count, ongoing_count_link: "ongoing_link", closed_count_link: "closed_link", connection: _mentoring_connection, connections: _mentoring_connections, time: time), get_dashboard_filters_in_groups_listing_flash(count, current_tab_count, {type: GroupsController::DashboardFilter::NO_RESPONSE, start_date: "15/06/2018", end_date: "17/06/2018"}, "tab")
  end

  def test_get_dashboard_filters_in_groups_listing_flash_ongoing_link
    assert_equal link_to(1, groups_path(tab: Group::Status::ACTIVE, dashboard: "filters")), get_dashboard_filters_in_groups_listing_flash_ongoing_link(10, 1, "filters", Group::Status::ACTIVE)
    assert_equal link_to(9, groups_path(tab: Group::Status::ACTIVE, dashboard: "filters")), get_dashboard_filters_in_groups_listing_flash_ongoing_link(10, 1, "filters", Group::Status::CLOSED)
  end

  def test_get_dashboard_filters_in_groups_listing_flash_closed_link
    assert_equal link_to(9, groups_path(tab: Group::Status::CLOSED, dashboard: "filters")), get_dashboard_filters_in_groups_listing_flash_closed_link(10, 1, "filters", Group::Status::ACTIVE)
    assert_equal link_to(1, groups_path(tab: Group::Status::CLOSED, dashboard: "filters")), get_dashboard_filters_in_groups_listing_flash_closed_link(10, 1, "filters", Group::Status::CLOSED)
  end

  def test_get_discussions_tab_label
    tab_label_content = get_discussions_tab_label("messages", 5, "fa-envelope", {show_in_dropdown: true, badge_class: "cjs_unread_scraps_count", text_class: "text_class"})
    assert_select_helper_function "i.fa-envelope", tab_label_content, count: 1
    assert_select_helper_function "span.text_class", tab_label_content, text: "messages", count: 1
    assert_select_helper_function "span.rounded.label.label-danger.m-l-xs.m-t-3", tab_label_content, text: "5", count: 1
    assert_select_helper_function "div.m-r-xxs.visible-xs.small.m-t-xs.font-bold", tab_label_content, text: "messages", count: 0

    tab_label_content = get_discussions_tab_label("messages", 5, "fa-envelope", {show_in_dropdown: false, badge_class: "cjs_unread_scraps_count", text_class: "text_class"})
    assert_select_helper_function "i.fa-envelope", tab_label_content, count: 1
    assert_select_helper_function "span.text_class.hidden-xs", tab_label_content, text: "messages", count: 1
    assert_select_helper_function "span.rounded.label.label-danger.cui_count_label", tab_label_content, text: "5", count: 1
    assert_select_helper_function "div.m-r-xxs.visible-xs.small.m-t-xs.font-bold", tab_label_content, text: "messages", count: 0

    tab_label_content = get_discussions_tab_label("messages", 5, "fa-envelope", {show_in_dropdown: true, badge_class: "cjs_unread_scraps_count", text_class: "text_class", home_page: true})
    assert_select_helper_function "i.fa-envelope", tab_label_content, count: 1
    assert_select_helper_function "span.text_class", tab_label_content, text: "messages", count: 1
    assert_select_helper_function "span.rounded.label.label-danger.m-l-xs.m-t-3", tab_label_content, text: "5", count: 1
    assert_select_helper_function "div.m-r-xxs.visible-xs.small.m-t-xs.font-bold", tab_label_content, text: "messages", count: 0

    tab_label_content = get_discussions_tab_label("messages", 5, "fa-envelope", {show_in_dropdown: false, badge_class: "cjs_unread_scraps_count", text_class: "text_class", home_page: true})
    assert_select_helper_function "i.fa-envelope", tab_label_content, count: 1
    assert_select_helper_function "span.text_class.hidden-xs", tab_label_content, text: "messages", count: 1
    assert_select_helper_function "span.rounded.label.label-danger.cui_count_label", tab_label_content, text: "5", count: 1
    assert_select_helper_function "div.m-r-xxs.visible-xs.small.m-t-xs.font-bold", tab_label_content, text: "messages", count: 1
  end

  def test_get_badge_count_label
    assert_nil get_badge_count_label(0)
    label_content = get_badge_count_label(5)
    assert_select_helper_function "span.rounded.label.label-danger.cui_count_label", label_content, text: "5", count: 1
    label_content = get_badge_count_label(5, {show_in_dropdown: true})
    assert_select_helper_function "span.cui_count_label", label_content, text: "5", count: 0
    assert_select_helper_function "span.rounded.label.label-danger.m-l-xs.m-t-3", label_content, text: "5", count: 1
    label_content = get_badge_count_label(5, {badge_class: "badge_class"})
    assert_select_helper_function "span.rounded.label.label-danger.badge_class.cui_count_label", label_content, text: "5", count: 1
  end

  def test_get_add_member_link
    teacher_role = Role.find_by(name: RoleConstants::TEACHER_NAME)
    @current_program = teacher_role.program
    @current_program.stubs(:allow_one_to_many_mentoring?).returns(true)
    mentor_role = @current_program.roles.find_by(name: RoleConstants::MENTOR_NAME)

    assert_select_helper_function "a.btn.btn-primary.btn-xs.pull-right.cjs_add_member.cjs_add_member_#{RoleConstants::MENTOR_NAME}", get_add_member_link(mentor_role, {RoleConstants::MENTOR_NAME => "mentor"}, true)
    @current_program.stubs(:allow_one_to_many_mentoring?).returns(false)
    assert_empty get_add_member_link(mentor_role, {RoleConstants::MENTOR_NAME => "mentor"}, true)
    assert_select_helper_function "a.btn.btn-primary.btn-xs.pull-right.cjs_add_member.cjs_add_member_#{RoleConstants::TEACHER_NAME}", get_add_member_link(teacher_role, {RoleConstants::TEACHER_NAME => "teacher"}, true)
    assert_select_helper_function "a.btn.btn-primary.btn-xs.pull-right.cjs_add_member.cjs_add_member_#{RoleConstants::TEACHER_NAME}.hide", get_add_member_link(teacher_role, {RoleConstants::TEACHER_NAME => "teacher"}, false)
  end

  private

  def wob_member
    members(:f_admin)
  end

  def _Mentoring_Connection
    "Mentoring Connection"
  end

  def _Mentoring_Connections
    "Mentoring Connections"
  end

  def _mentoring_connection
    "mentoring connection"
  end

  def _mentoring_connections
    "mentoring connections"
  end

  def _mentor
    "mentor"
  end

  def _Mentors
    "Mentors"
  end

  def _Mentor
    "Mentor"
  end

  def _Mentees
    "Mentees"
  end

  def _Mentee
    "Mentee"
  end

  def _mentors
    "mentors"
  end

  def _mentee
    "student"
  end

  def _mentees
    "students"
  end

  def _Admin
    "Administrator"
  end

  def _admin
    "administrator"
  end

  def group_params
    return ActionController::Parameters.new(
      search_filters: { "a" => { "a1" => 1, "a2" => 2 } },
      connection_questions: "b",
      search_filter: "c",
      connection_question: "d",
      sub_filters: "u",
      sub_filter: "v",
      member_filter: "x",
      member_filters: "y",
      member_profile_filters: "s",
      member_profile_filter: "m",
      tab: "0"
    )
  end

  def _Meetings
    "Meetings"
  end

  def _meetings
    "meetings"
  end

  def _a_mentoring_connection
    "a mentoring connection"
  end

  def _resources
    "resources"
  end
end