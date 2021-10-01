require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/program_invitations_helper"

class ProgramInvitationsHelperTest < ActionView::TestCase

  def test_program_invitation_columns_and_fields_values
    expected_program_invitation_columns = [
      { title: "checkbox", field: "check_box", width: "2%", encoded: false, sortable: false, filterable: false },
      { field: "sent_to", width: "20%", headerTemplate: program_invitation_header_template("feature.program_invitations.label.recipient".translate), encoded: false},
      { field: "sent_on", width: "15%", headerTemplate: program_invitation_header_template("feature.program_invitations.label.sent".translate) }.merge(column_format(:centered, :datetime)),
      { field: "expires_on", width: "15%", headerTemplate: program_invitation_header_template("feature.program_invitations.label.valid_until".translate)  }.merge(column_format(:centered, :datetime)),
      { field: "roles_name", width: "12%", headerTemplate: program_invitation_header_template("display_string.one_or_many_roles".translate), encoded: false }.merge(column_format(:centered)),
      { field: "sender", width: "12%", headerTemplate: program_invitation_header_template("feature.program_invitations.label.sender".translate), encoded: false }.merge(column_format(:centered)),
      { field: "statuses", width: "12%", headerTemplate: "Status", encoded:false, sortable: false }.merge(column_format(:centered)),
    ];
    assert_equal_unordered expected_program_invitation_columns, program_invitation_listing_columns

    expected_program_invitation_fields = {
      id: { type: :string },
      sent_to: { type: :string },
      sent_on: { type: :date },
      expires_on: { type: :date },
      roles_name: { type: :string },
      sender: { type: :string },
      statuses: { type: :string}
    };
    assert_equal expected_program_invitation_fields, program_invitation_listing_fields
  end

  def test_can_invite_in_other_languages
    program = programs(:albers)
    assert_false program.languages_enabled_and_has_multiple_languages_for_everyone?
    assert_false can_invite_in_other_languages?(users(:f_admin))
    assert_false can_invite_in_other_languages?(users(:f_mentor))
    program.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    assert program.languages_enabled_and_has_multiple_languages_for_everyone?
    assert can_invite_in_other_languages?(users(:f_admin).reload)
    assert_false can_invite_in_other_languages?(users(:f_mentor))
  end

  def test_column_format
    column_format = {
      :headerAttributes=>{:class=>"text-center"},
      :attributes=>{:class=>"text-center"},
      :format=>"{0:MMM dd, yyyy h:mm:ss tt}"
    }
    assert_equal column_format, column_format(:centered, :datetime)
    column_format = {
      :headerAttributes=>{:class=>"text-center"},
      :attributes=>{:class=>"text-center"},
      :format=>"{0:p1}"
    }
    assert_equal column_format, column_format(:centered, :numeric)
  end

  def test_program_invitation_sender
    program_invitation = program_invitations(:mentor)
    assert_equal users(:f_admin).name(:name_only => true), program_invitation_sender(program_invitation)
    program_invitation.user_id = nil
    program_invitation.save
    assert_match(/Deleted User/, program_invitation_sender(program_invitation))
  end

  def test_program_invitation_recipient
    program_invitation = program_invitations(:mentor)
    assert_match "mentor@chronus.com", program_invitation_recipient(program_invitation)

    program = program_invitation.program
    member = program.organization.members.create
    member.email = "mentor@chronus.com"
    member.first_name = "dummy"
    member.last_name = "user"
    member.save
    user = program.users.create
    user.member_id = member.id
    user.roles << program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    user.save
    program_invitation.use_count = 1
    program_invitation.save!
    assert_match(/members/, program_invitation_recipient(program_invitation))
  end

  def test_days_since_sent
    invite1 = mock("invite", :days_since_sent => 0)
    assert_match(/Today/, days_since_sent(invite1))

    invite2 = mock("invite", :days_since_sent => 20)
    assert_match(/20 days/, days_since_sent(invite2))

    invite2 = mock("invite", :days_since_sent => 40)
    assert_match(/40 days/, days_since_sent(invite2))
  end

  def test_message_of_invite_with_message
    msg = "Some message"
    invite1 = stub("invite", :message => "Some message", :membership_request => nil)
    assert_equal(msg, message_of(invite1))
  end

  def test_message_of_invite_without_message
    invite1 = stub("invite", :message => nil, :membership_request => nil)
    assert_equal("<i class=\"empty\">No message</i>", message_of(invite1))
  end

  def test_invitation_role_allow_type
    @current_organization = programs(:org_primary)
    assert_equal "<i>Allow user to choose (Mentor and Student)</i>", invitation_role(stub("invite", :message => "Some message", :roles => [stub('name', :name => "mentor"), stub('name', :name => "student")], :role_type => ProgramInvitation::RoleType::ALLOW_ROLE))
  end

  def test_invitation_role_assign_type
    @current_organization = programs(:org_primary)
    assert_equal "Mentor", invitation_role(stub("invite", :message => "Some message", :roles => [stub('name', :name => "mentor")], :role_type => ProgramInvitation::RoleType::ASSIGN_ROLE))
  end

  def test_invitation_status
    program_invitation = program_invitations(:mentor)
    program_invitation.use_count = 1
    program_invitation.save!
    assert_equal "Accepted", invitation_status(program_invitation)
    program_invitation.use_count = 0
    program_invitation.expires_on = Time.now - 1.days
    program_invitation.save!
    assert_equal content_tag(:span, "Expired", :class => "red"), invitation_status(program_invitation)
  end

  def test_get_highest_event_type_for_program_invitation_emails_sent
    program_invitation = program_invitations(:mentor)

    assert_equal "Opened and Clicked", invitation_status(program_invitation)

    program_invitation.event_logs.where(event_type: CampaignManagement::EmailEventLog::Type::CLICKED).destroy_all
    assert_equal "Opened", invitation_status(program_invitation)

    event = program_invitation.event_logs.first
    event.event_type = CampaignManagement::EmailEventLog::Type::DELIVERED
    event.save!
    assert_equal "Sent and Delivered", invitation_status(program_invitation)

    event.event_type = CampaignManagement::EmailEventLog::Type::FAILED
    event.save!
    assert_equal "Not Delivered", invitation_status(program_invitation)

    event.destroy
    assert_equal "Sent", invitation_status(program_invitation)

    program_invitation.emails.destroy_all
    assert_equal "Pending", invitation_status(program_invitation)
  end

  def test_get_user_role_options
    u1= users(:f_mentor)
    u2= users(:f_student)
    u3= users(:f_admin)
    p = programs(:albers)

    content = get_user_role_options(p, u1)

    role = u1.roles.first
    assert_equal "<div class=\"cjs_nested_show_hide_container cjs_roles_list \"><div class=\"cjs_show_hide_sub_selector has-above\" id=\"cjs_assign_roles\"><label class=\"radio cjs_toggle_radio hide\"><input type=\"radio\" name=\"role\" id=\"role_assign_roles\" value=\"assign_roles\" class=\"cjs_role_name_radio_btn\" checked=\"checked\" />Assign role(s) to users</label> <div class=\"choices_wrapper\" role=\"group\" aria-label=\"Roles\"><label class=\"checkbox font-noraml m-l m-r  cjs_toggle_content\"><input type=\"checkbox\" name=\"assign_roles[]\" id=\"assign_roles_add_#{role.name}_#{u1.id}\" value=\"mentor\" /><span>Mentor</span></label></div></div></div>", content

    content = get_user_role_options(p, u2)
    role = u2.roles.first
    assert_equal "<div class=\"cjs_nested_show_hide_container cjs_roles_list \"><div class=\"cjs_show_hide_sub_selector has-above\" id=\"cjs_assign_roles\"><label class=\"radio cjs_toggle_radio hide\"><input type=\"radio\" name=\"role\" id=\"role_assign_roles\" value=\"assign_roles\" class=\"cjs_role_name_radio_btn\" checked=\"checked\" />Assign role(s) to users</label> <div class=\"choices_wrapper\" role=\"group\" aria-label=\"Roles\"><label class=\"checkbox font-noraml m-l m-r  cjs_toggle_content\"><input type=\"checkbox\" name=\"assign_roles[]\" id=\"assign_roles_add_#{role.name}_#{u2.id}\" value=\"student\" /><span>Student</span></label></div></div></div>", content

    p.find_role("student").add_permission("invite_mentors")
    content = get_user_role_options(p, u2.reload)
    role = u2.roles.first
    assert_equal "<div class=\"cjs_nested_show_hide_container cjs_roles_list \"><div class=\"cjs_show_hide_sub_selector has-above\" id=\"cjs_assign_roles\"><label class=\"radio cjs_toggle_radio \"><input type=\"radio\" name=\"role\" id=\"role_assign_roles\" value=\"assign_roles\" class=\"cjs_role_name_radio_btn\" />Assign role(s) to users</label> <div class=\"choices_wrapper\" role=\"group\" aria-label=\"Roles\"><label class=\"checkbox font-noraml m-l m-r hide iconcol-md-offset-1 cjs_toggle_content\"><input type=\"checkbox\" name=\"assign_roles[]\" id=\"assign_roles_add_mentor_2\" value=\"mentor\" /><span>Mentor</span></label> <label class=\"checkbox font-noraml m-l m-r hide iconcol-md-offset-1 cjs_toggle_content\"><input type=\"checkbox\" name=\"assign_roles[]\" id=\"assign_roles_add_student_2\" value=\"student\" /><span>Student</span></label></div></div><div class=\"cjs_show_hide_sub_selector has-above\" id=\"cjs_allow_roles\"><label class=\"radio cjs_toggle_radio\"><input type=\"radio\" name=\"role\" id=\"role_allow_roles\" value=\"allow_roles\" class=\"cjs_role_name_radio_btn\" />Allow users to select role(s)<span class=\"dim\"> (Non-administrative)</span></label> <div class=\"choices_wrapper\" role=\"group\" aria-label=\"Roles\"><label class=\"checkbox font-noraml m-l m-r hide iconcol-md-offset-1 cjs_toggle_content\"><input type=\"checkbox\" name=\"allow_roles[]\" id=\"allow_roles_invite_mentor_2\" value=\"mentor\" /><span>Mentor</span></label> <label class=\"checkbox font-noraml m-l m-r hide iconcol-md-offset-1 cjs_toggle_content\"><input type=\"checkbox\" name=\"allow_roles[]\" id=\"allow_roles_invite_student_2\" value=\"student\" /><span>Student</span></label></div></div></div>", content

    content = get_user_role_options(p, u3)
    role = u3.roles.first
    assert_equal "<div class=\"cjs_nested_show_hide_container cjs_roles_list \"><div class=\"cjs_show_hide_sub_selector has-above\" id=\"cjs_assign_roles\"><label class=\"radio cjs_toggle_radio \"><input type=\"radio\" name=\"role\" id=\"role_assign_roles\" value=\"assign_roles\" class=\"cjs_role_name_radio_btn\" />Assign role(s) to users</label> <div class=\"choices_wrapper\" role=\"group\" aria-label=\"Roles\"><label class=\"checkbox font-noraml m-l m-r hide iconcol-md-offset-1 cjs_toggle_content\"><input type=\"checkbox\" name=\"assign_roles[]\" id=\"assign_roles_add_mentor_1\" value=\"mentor\" /><span>Mentor</span></label> <label class=\"checkbox font-noraml m-l m-r hide iconcol-md-offset-1 cjs_toggle_content\"><input type=\"checkbox\" name=\"assign_roles[]\" id=\"assign_roles_add_student_1\" value=\"student\" /><span>Student</span></label> <label class=\"checkbox font-noraml m-l m-r hide iconcol-md-offset-1 cjs_toggle_content\"><input type=\"checkbox\" name=\"assign_roles[]\" id=\"assign_roles_add_admin_1\" value=\"admin\" /><span>Administrator</span></label></div></div><div class=\"cjs_show_hide_sub_selector has-above\" id=\"cjs_allow_roles\"><label class=\"radio cjs_toggle_radio\"><input type=\"radio\" name=\"role\" id=\"role_allow_roles\" value=\"allow_roles\" class=\"cjs_role_name_radio_btn\" />Allow users to select role(s)<span class=\"dim\"> (Non-administrative)</span></label> <div class=\"choices_wrapper\" role=\"group\" aria-label=\"Roles\"><label class=\"checkbox font-noraml m-l m-r hide iconcol-md-offset-1 cjs_toggle_content\"><input type=\"checkbox\" name=\"allow_roles[]\" id=\"allow_roles_invite_mentor_1\" value=\"mentor\" /><span>Mentor</span></label> <label class=\"checkbox font-noraml m-l m-r hide iconcol-md-offset-1 cjs_toggle_content\"><input type=\"checkbox\" name=\"allow_roles[]\" id=\"allow_roles_invite_student_1\" value=\"student\" /><span>Student</span></label></div></div></div>", content

    p.find_role("student").remove_permission("invite_mentors")
    p.find_role("student").remove_permission("invite_students")
    content = get_user_role_options(p, u2.reload)
    assert_equal "<div class=\"cjs_nested_show_hide_container cjs_roles_list \"><div class=\"cjs_show_hide_sub_selector has-above\" id=\"cjs_assign_roles\"><label class=\"radio cjs_toggle_radio hide\"><input type=\"radio\" name=\"role\" id=\"role_assign_roles\" value=\"assign_roles\" class=\"cjs_role_name_radio_btn\" checked=\"checked\" />Assign role(s) to users</label> Invitation is turned off for all the roles in the track.</div></div>", content

    p.roles.create!(name: "king")
    p.reload
    content = get_user_role_options(p, u3)
    assert_match /Assign role\(s\) to users/, content
    assert_match /Mentor/, content
    assert_match /Student/, content
    assert_match /Administrator/, content
    assert_match /Allow users to select role\(s\)/, content
    assert_no_match(/King/, content)
    Permission.create_permission!("invite_kings")
    p.find_role("admin").add_permission("invite_kings")
    p.reload
    u3.reload
    content = get_user_role_options(p, u3)
    assert_match /Assign role\(s\) to users/, content
    assert_match /Mentor/, content
    assert_match /Student/, content
    assert_match /Administrator/, content
    assert_match /Allow users to select role\(s\)/, content
    assert_match /King/, content
  end

  def test_construct_options
    self.expects(:kendo_convert_status_array_to_checkbox_hash).returns(["Status"])
    self.expects(:kendo_convert_role_names_array_to_checkbox_hash).returns(["Roles"])
    self.expects(:program_invitation_listing_columns).returns(["Columns"])
    self.expects(:program_invitation_listing_fields).returns(["Fields"])
    self.expects(:program_invitations_path).returns("Path")

    expected_options = {
      columns: ["Columns"],
      fields: ["Fields"],
      dataSource: "Path",
      grid_id: "cjs_program_invitation_listing_kendogrid",
      selectable: false,
      serverPaging: true,
      serverFiltering: true,
      serverSorting: true,
      sortable: true,
      pageable: {
        messages: {
          display: "{0} - {1} of {2} items",
          empty: "There are no invitations to display."
        }
      },
      pageSize: 30,
      filterable: {
        messages: {
          info: "",
          filter: "Filter",
          clear: "Clear"
        }
      },
      fromPlaceholder: "From",
      toPlaceholder: "To",
      checkbox_fields: [:statuses, :roles_name],
      checkbox_values: {
        :statuses => ["Status"],
        :roles_name => ["Roles"]
      },
      simple_search_fields: [:sent_to, :sender],
      date_fields: [:sent_on, :expires_on]
    }

    assert_equal expected_options, construct_options(programs(:albers))
  end

  def test_kendo_convert_role_names_array_to_checkbox_hash_should_return_hash_of_display_and_posted_as_strings
    program = programs(:albers)
    role_names_checkbox_hash_expected = [
      {:displayed_as=>"Administrator", :posted_as=>"admin"},
      {:displayed_as=>"Mentor", :posted_as=>"mentor"},
      {:displayed_as=>"Student", :posted_as=>"student"},
      {:displayed_as=>"User", :posted_as=>"user"},
      {:displayed_as=>"Not Specified", :posted_as => "Not Specified"}
    ]
    assert_equal role_names_checkbox_hash_expected, kendo_convert_role_names_array_to_checkbox_hash(program)
  end

  def test_status_checkboxes
    expected_checkboxes = ["Expired", "Pending", "Sent", "Accepted", "Opened", "Opened and Clicked", "Sent and Delivered", "Not Delivered"]
    assert_equal_unordered expected_checkboxes, status_checkboxes
  end

  def test_customized_role_names
    program = programs(:albers)
    roles = ["Administrator", "Mentor", "Student", "User", "Not Specified"]
    assert_equal_unordered roles, customized_role_names(program)
  end

  def test_kendo_convert_status_array_to_checkbox_hash
    expected_output = [
      {
      :displayed_as => "Value1",
      :posted_as => "Value1"
      },
      {
      :displayed_as => "Value2",
      :posted_as => "Value2"
      }
    ]
    assert_equal_unordered expected_output, kendo_convert_status_array_to_checkbox_hash(["Value1", "Value2"])
  end


  def test_initialize_program_invitation_listing_kendo_script
    options = {:key => "value"}
    self.expects(:construct_options).returns(options)
    count = 5
    expected_output = javascript_tag "CommonSelectAll.initializeSelectAll(#{count}, cjs_program_invitation_listing_kendogrid); CampaignsKendo.initializeKendo(#{options.to_json});"
    assert_equal expected_output, self.initialize_program_invitation_listing_kendo_script(programs(:albers), count)
  end

  def test_initialize_program_invitation_listing_kendo_script_default_pending_filters
    options = {:key => "value"}
    self.expects(:construct_options).returns(options)
    assert_match "Pending", self.initialize_program_invitation_listing_kendo_script(programs(:albers), 5, true)
  end

  def test_program_invitation_checkbox
    result = program_invitation_checkbox("test_id")
    assert_select_helper_function "input#cjs_program_invitation_checkbox_test_id.cjs_select_all_record.cjs_program_invitation_checkbox.cjs_select_all_checkbox_test_id[type='checkbox'][value='test_id']", result
    assert_select_helper_function "label.sr-only[for='cjs_program_invitation_checkbox_test_id']", result, text: "test_id"
  end

  def test_program_invitation_bulk_actions
    result = program_invitation_bulk_actions
    expected_labels = ["<i class=\"fa fa-refresh fa-fw m-r-xs\"></i>Resend", "<i class=\"fa fa-trash fa-fw m-r-xs\"></i>Delete", "<i class=\"fa fa-download fa-fw m-r-xs\"></i>Export to CSV"]
    assert_equal expected_labels, result.collect { |action| action[:label] }
    assert_equal ["cjs_resend_invitations", "cjs_delete_invitations", "cjs_program_invitations_export_csv"], result.collect { |action| action[:id] }
  end

  def test_get_bulk_action_partial_for_program_invitation
    self.expects(:render).with(partial: "program_invitations/bulk_resend").once
    get_bulk_action_partial_for_program_invitation(ProgramInvitationsHelper::BulkActionType::RESEND)
    self.expects(:render).with(partial: "program_invitations/bulk_destroy").once
    get_bulk_action_partial_for_program_invitation(ProgramInvitationsHelper::BulkActionType::DELETE)
  end

  def test_render_invitation_emails
    result = render_invitation_emails(["test1@gmail.com", "test2@gmail.com", "test3@gmail.com", "test4@gmail.com", "test5@gmail.com"])
    assert_select_helper_function "span", result, text: "test1@gmail.com, test2@gmail.com, test3@gmail.com, test4@gmail.com, test5@gmail.com"
    result = render_invitation_emails(["test1@gmail.com", "test2@gmail.com", "test3@gmail.com", "test4@gmail.com", "test5@gmail.com", "test6@gmail.com"])

    assert_select_helper_function_block "span.cjs_show_and_hide_toggle_container", result do
      assert_select "span.cjs_show_and_hide_toggle_sub_selector.cjs_show_and_hide_toggle_show", text: "and 1 more" do
        assert_select "a", text: "1 more"
      end
      assert_select "span.cjs_show_and_hide_toggle_sub_selector.cjs_show_and_hide_toggle_content.hide", text: ", test6@gmail.com"
    end
  end

  private

  def _mentor
    "mentor"
  end

  def _mentee
    "student"
  end

  def _program
    "track"
  end

  def get_primary_checkbox_for_kendo_grid
    "checkbox"
  end

  def get_kendo_bulk_actions_box(bulk_actions)
    bulk_actions
  end
end
