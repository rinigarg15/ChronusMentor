require_relative './../../../test_helper.rb'

class MentoringModelsHelperTest < ActionView::TestCase

  def test_object_description_content
    task = create_mentoring_model_task_template(description: '<strong>bold</strong> no <em>italic</em> no <u>undrline</u> no <ol> <li> item 1</li> <li> itme 2</li> </ol> <ul> <li> bull 1</li> <li> bull2</li> </ul> <a href="www.chronus.com">chronus</a>') # ckeditor handles script tags
    assert_equal "<strong>bold</strong> no <em>italic</em> no <u>undrline</u> no <ol> <li> item 1</li> <li> itme 2</li> </ol> <ul> <li> bull 1</li> <li> bull2</li> </ul> <a href=\"www.chronus.com\">chronus</a>", object_description_content(task)
  end

  def test_mentoring_model_permission_checkbox
    form = mock()
    assert_nil mentoring_model_permission_checkbox(nil, form, "manage_mm_goals", "admin", {}, true)
    set_response_text(mentoring_model_permission_checkbox(true, form, "manage_mm_goals", "admin", {}, true))
    assert_select "input.cjs_features_list", count: 1
  end

  def test_generate_feature_list
    mentoring_model = programs(:albers).default_mentoring_model
    roles = programs(:albers).roles.for_mentoring_models.group_by(&:name)
    object_permissions = ObjectPermission.all.group_by(&:name)

    content = generate_feature_list(mentoring_model, roles, object_permissions)
    set_response_text(content)
    assert_select "i.fa", count: 6
    assert_select "b", count: 6
    assert_select "div", text: /Goal Plans/ do
      assert_select "span", text: /Administrators, Users/
    end
    assert_select "div", text: /Tasks/ do
      assert_select "span", text: /Administrators, Users/
    end
    assert_select "div", text: /Meetings/ do
      assert_select "span", text: /Users/
    end
    assert_select "div", text: /Facilitation Messages/ do
      assert_select "span", text: /Administrators/
    end
    assert_select "div", text: /Surveys/ do
      assert_select "span", text: /Administrators/
    end
    assert_select "div", text: /Messaging/ do
      assert_select "span", text: /Users/
    end

    mentoring_model.deny_manage_mm_goals!([roles[RoleConstants::MENTOR_NAME][0], roles[RoleConstants::STUDENT_NAME][0]])
    content = generate_feature_list(mentoring_model, roles, object_permissions)
    set_response_text(content)
    assert_select "i.fa", count: 6
    assert_select "b", count: 6
    assert_select "div", text: /Goal Plans/ do
      assert_select "span", text: /Administrators/
    end
    assert_select "div", text: /Tasks/ do
      assert_select "span", text: /Administrators, Users/
    end
    assert_select "div", text: /Meetings/ do
      assert_select "span", text: /Users/
    end
    assert_select "div", text: /Facilitation Messages/ do
      assert_select "span", text: /Administrators/
    end
    assert_select "div", text: /Surveys/ do
      assert_select "span", text: /Administrators/
    end
    assert_select "div", text: /Messaging/ do
      assert_select "span", text: /Users/
    end

    mentoring_model.stubs(:allow_messaging).returns(false)
    mentoring_model.stubs(:allow_forum).returns(true)
    mentoring_model.allow_manage_mm_milestones!([roles[RoleConstants::MENTOR_NAME][0], roles[RoleConstants::STUDENT_NAME][0]])
    content = generate_feature_list(mentoring_model, roles, object_permissions)
    set_response_text(content)
    assert_select "i.fa", count: 7
    assert_select "b", count: 7
    assert_select "div", text: /Milestones/ do
      assert_select "span", text: /Users/
    end
    assert_select "div", text: /Goal Plans/ do
      assert_select "span", text: /Administrators/
    end
    assert_select "div", text: /Tasks/ do
      assert_select "span", text: /Administrators, Users/
    end
    assert_select "div", text: /Meetings/ do
      assert_select "span", text: /Users/
    end
    assert_select "div", text: /Facilitation Messages/ do
      assert_select "span", text: /Administrators/
    end
    assert_select "div", text: /Surveys/ do
      assert_select "span", text: /Administrators/
    end
    assert_select "div", text: /Discussion Board/ do
      assert_select "span", text: /Users/
    end

    content = generate_feature_list(mentoring_model, roles, object_permissions, fixed_date_tasks_available: true)
    set_response_text(content)
    assert_select "i.fa", count: 8
    assert_select "b", count: 7
    assert_select "div", text: /Milestones/ do
      assert_select "span", text: /Users/
    end
    assert_select "div", text: /Goal Plans/ do
      assert_select "span", text: /Administrators/
    end
    assert_select "div", text: /Tasks/ do
      assert_select "span", text: /Administrators, Users/
    end
    assert_select "div", text: /Note that this template has tasks with fixed dates./
    assert_select "div", text: /Meetings/ do
      assert_select "span", text: /Users/
    end
    assert_select "div", text: /Facilitation Messages/ do
      assert_select "span", text: /Administrators/
    end
    assert_select "div", text: /Surveys/ do
      assert_select "span", text: /Administrators/
    end
    assert_select "div", text: /Discussion Board/ do
      assert_select "span", text: /Users/
    end
  end

  def test_render_milestone_position_choices
    mentoring_model = programs(:albers).default_mentoring_model

    content = render_milestone_position_choices(mentoring_model)

    assert_nil content

    mt1 = create_mentoring_model_milestone_template({title: "Template1"})
    mt2 = create_mentoring_model_milestone_template({title: "Template2"})
    mt3 = create_mentoring_model_milestone_template({title: "Template3"})
    mt4 = create_mentoring_model_milestone_template({title: "Template4"})

    content = render_milestone_position_choices(mentoring_model.reload)
    set_response_text(content)

    assert_select "input[id=\"milestone_position_1\"][name=\"milestone_position\"][type=\"radio\"][value=\"1\"]"
    assert_select "input[id=\"milestone_position_2\"][name=\"milestone_position\"][type=\"radio\"][value=\"2\"][checked=checked]"

    assert_select "option[value=\"#{mt1.position}\"][selected=selected]", :text => "Template1"
    assert_select "option[value=\"#{mt2.position}\"]", :text => "Template2"
    assert_select "option[value=\"#{mt3.position}\"]", :text => "Template3"
    assert_select "option[value=\"#{mt4.position}\"]", :text => "Template4"

    assert_match "As first Milestone", content
    assert_match "Insert it after", content
  end

  def test_get_mentoring_period_unit
    mentoring_model = programs(:albers).default_mentoring_model
    mentoring_model.mentoring_period = 21.days.to_i
    assert_equal "Weeks", get_mentoring_period_unit(mentoring_model)
    mentoring_model.mentoring_period = 30.days.to_i
    assert_equal "Days", get_mentoring_period_unit(mentoring_model)
  end

  def test_progressive_form_related_helper
    assert_equal ["n_weeks_after_task", 5], display_days_or_weeks_format(35)
    assert_equal ["n_days_after_task", 8], display_days_or_weeks_format(8)
    assert_equal ["n_weeks_after_task", 13], display_days_or_weeks_format(91)
    assert_equal ["n_days_after_task", 13], display_days_or_weeks_format(13)
    assert_equal ["n_days_after_task", 0], display_days_or_weeks_format(0)
    assert_equal [[["days", 1], ["weeks", 7]], "{durationName: 'days', durationId: '1'},{durationName: 'weeks', durationId: '7'}"], generate_duration_unit_list_and_map
  end

  def test_render_tasks_filter
    connection_users = groups(:mygroup).members
    @target_user_type =  GroupsController::TargetUserType::ALL_MEMBERS
    set_response_text(render_tasks_filter(connection_users, groups(:mygroup)))
    assert_select "div.radio", count: 3
    assert_select "span.cjs_task_and_meetings_filter_text", count: 3
    assert_select "span.member_name", count: 2
    assert_select "span.cjs_task_and_meetings_filter_text", text: "Unassigned"
  end

  def test_render_view_mode_filter
    expects(:view_by_milestones?).at_least_once.returns(true)
    set_response_text(render_view_mode_filter)
    assert_select "div.radio", count: 2
    assert_select "label.cjs-view-mode-filter-by-milestone", text: "By Milestones"
    assert_select "label.cjs-view-mode-filter-by-due-date", text: "By Due Date"
  end

  def test_render_completed_view_mode_filter
    assert_equal 1, render_completed_view_mode_filter.scan("Show Completed Tasks").size
  end

  def test_get_mentoring_model_settings_for_display
    program = programs(:albers)
    mentoring_model = program.default_mentoring_model

    assert mentoring_model.allow_messaging?
    assert_false mentoring_model.allow_forum?
    assert_false mentoring_model.allow_due_date_edit?
    assert mentoring_model.can_disable_messaging?
    assert mentoring_model.can_disable_forum?
    settings_1 = get_mentoring_model_settings_for_display(mentoring_model)
    assert_equal 3, settings_1.size
    assert_equal_hash( {
      name: :allow_due_date_edit,
      icon_class: "fa fa-check-square-o",
      heading: "Alter Admin Created Tasks",
      description: "End-Users in a connection can alter due-dates of an admin created task.",
      label: "Users can configure"
    }, settings_1[0])
    assert_equal_hash( {
      name: :allow_messaging,
      icon_class: "fa fa-envelope",
      heading: "Messages",
      description: "End-Users can send messages to everyone in the connection.",
      label: "Enable Messaging",
      disable_tooltip: nil
    }, settings_1[1])
    assert_equal_hash( {
      name: :allow_forum,
      icon_class: "fa fa-comment",
      heading: "Discussion Board",
      description: "End-Users can post, follow and discuss topics inside the connection.",
      label: "Enable Discussion Board",
      assoc_text_area_field: :forum_help_text,
      disable_tooltip: nil
    }, settings_1[2])

    mentoring_model.stubs(:can_disable_messaging?).returns(false)
    settings_2 = get_mentoring_model_settings_for_display(mentoring_model)
    assert_equal 3, settings_2.size
    assert_equal_hash(settings_1[0], settings_2[0])
    assert_equal_hash(settings_1[1].merge(disable_tooltip: "There are ongoing/closed connections using this connection template. Clone this template to create a new template or remove all the ongoing/closed connections to disable messages."), settings_2[1])
    assert_equal_hash(settings_1[2], settings_2[2])

    mentoring_model.stubs(:allow_messaging?).returns(false)
    mentoring_model.stubs(:allow_forum?).returns(true)
    mentoring_model.stubs(:can_disable_forum?).returns(false)
    settings_3 = get_mentoring_model_settings_for_display(mentoring_model)
    assert_equal 3, settings_3.size
    assert_equal_hash(settings_1[0], settings_3[0])
    assert_equal_hash(settings_1[1], settings_3[1])
    assert_equal_hash(settings_1[2].merge(disable_tooltip: "There are ongoing/closed connections using this connection template. Clone this template to create a new template or remove all the ongoing/closed connections to disable discussion boards."), settings_3[2])
  end

  def test_get_mentoring_models_collection
    program = programs(:albers)
    mentoring_model = program.default_mentoring_model
    self.stubs(:current_program).returns(program)
    assert_equal [["#{mentoring_model.title} (Default)", mentoring_model.id]], get_mentoring_models_collection

    mentoring_model.update_column(:default, false)
    mentoring_model_2 = create_mentoring_model(default: true)
    assert_equal [
      ["#{mentoring_model.title}", mentoring_model.id],
      ["#{mentoring_model_2.title} (Default)", mentoring_model_2.id]
    ], get_mentoring_models_collection
  end

  private

  def _Admins
    "Administrators"
  end

  def _Meetings
    "Meetings"
  end

  def _mentoring_connection
    "connection"
  end

  def _mentoring_connections
    "connections"
  end

  def _a_mentoring_connection
    "a connection"
  end
end