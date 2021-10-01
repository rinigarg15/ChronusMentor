require_relative './../../test_helper.rb'

class GroupsAlertHelperTest < ActionView::TestCase
  include GroupsAlertHelper
  include TranslationsService

  def setup
    super
    helper_setup
    @current_program = programs(:albers)
    TranslationsService.program = @current_program
    set_terminology_helpers
  end

  def test_existing_groups_alert_nil_cases
    @current_program.stubs(:show_existing_groups_alert?).returns(false)
    assert_nil existing_groups_alert([groups(:mygroup).id])

    @current_program.stubs(:show_existing_groups_alert?).returns(true)
    assert_nil existing_groups_alert
  end

  def test_existing_groups_alert
    Program.any_instance.stubs(:allow_multiple_groups_between_student_mentor_pair?).returns(true)
    @current_program.stubs(:show_existing_groups_alert?).returns(true)
    @current_program.stubs(:admin_access_to_mentoring_area_disabled?).returns(false)
    allow_one_to_many_mentoring_for_program(@current_program)

    admin = users(:f_admin)
    student_1 = users(:student_2)
    student_2 = users(:student_4)
    student_3 = users(:student_6)
    mentor_1 = users(:mentor_3)
    mentor_2 = users(:mentor_5)
    mentor_3 = users(:mentor_7)
    mentor_1.update_column(:max_connections_limit, 100)
    mentor_2.update_column(:max_connections_limit, 100)
    mentor_3.update_column(:max_connections_limit, 100)

    active_group_1 = create_group(students: [student_1], mentors: [mentor_1], name: "Active Group 1")
    active_group_2 = create_group(students: [student_1, student_2, student_3], mentors: [mentor_1, mentor_2, mentor_3], name: "Active Group 2")
    active_group_3 = create_group(students: [student_1, student_3], mentors: [mentor_1, mentor_3], name: "Active Group 3")
    inactive_group_1 = create_group(students: [student_2], mentors: [mentor_2], status: Group::Status::INACTIVE, name: "Inactive Group 1")
    drafted_group_1 = create_group(students: [student_3], mentors: [mentor_3], status: Group::Status::DRAFTED, creator_id: admin.id, name: "Drafted Group 1")
    drafted_group_2 = create_group(students: [student_1, student_2, student_3], mentors: [mentor_1, mentor_3], status: Group::Status::DRAFTED, creator_id: admin.id, name: "Drafted Group 2")
    closed_group_1 = create_group(students: [student_1], mentors: [mentor_1], name: "Closed Group 1")
    closed_group_2 = create_group(students: [student_1, student_2], mentors: [mentor_1, mentor_3], name: "Closed Group 2")
    closed_group_1.terminate!(admin, "Reason", @current_program.group_closure_reasons.first.id)
    closed_group_2.terminate!(admin, "Reason", @current_program.group_closure_reasons.first.id)

    # Create new group from groups listing
    content = existing_groups_alert([], [[[student_1.id, student_2.id, student_3.id], [mentor_1.id, mentor_2.id, mentor_3.id]]], Group::Status::DRAFTED, :user)
    assert_select_helper_function_block "div.alert-warning", content, count: 1, text: /The selected users are already connected with each other in the following mentoring connections./ do
      assert_select "div.media-left" do
        assert_select "i.fa-exclamation-triangle"
      end
      assert_select "div.media-body" do
        assert_select "ul", count: 1 do
          assert_select "li", count: 6
          assert_select "li", text: "#{mentor_1.name} is a mentor to #{student_1.name} in #{active_group_1.name}." do
            assert_select "a", href: group_path(active_group_1), text: active_group_1.name
          end
          assert_select "li", text: "#{mentor_1.name}, #{mentor_2.name} and #{mentor_3.name} are mentors to #{student_1.name}, #{student_2.name} and #{student_3.name} in #{active_group_2.name}." do
            assert_select "a", href: group_path(active_group_2), text: active_group_2.name
          end
          assert_select "li", text: "#{mentor_1.name} and #{mentor_3.name} are mentors to #{student_1.name} and #{student_3.name} in #{active_group_3.name}." do
            assert_select "a", href: group_path(active_group_3), text: active_group_3.name
          end
          assert_select "li", text: "#{mentor_2.name} is a mentor to #{student_2.name} in #{inactive_group_1.name}." do
            assert_select "a", href: group_path(inactive_group_1), text: inactive_group_1.name
          end
          assert_select "li", text: "#{mentor_3.name} is drafted as a mentor to #{student_3.name} in #{drafted_group_1.name}." do
            assert_select "a", href: groups_path(tab: Group::Status::DRAFTED, search_filters: { profile_name: drafted_group_1.name } ), text: drafted_group_1.name
          end
          assert_select "li", text: "#{mentor_1.name} and #{mentor_3.name} are drafted as mentors to #{student_1.name}, #{student_2.name} and #{student_3.name} in #{drafted_group_2.name}." do
            assert_select "a", href: groups_path(tab: Group::Status::DRAFTED, search_filters: { profile_name: drafted_group_2.name } ), text: drafted_group_2.name
          end
        end
      end
    end

    # Bulk match: draft/publish; Find a mentor: draft/publish
    content = existing_groups_alert([], [[[student_1.id], [mentor_1.id]]], Group::Status::DRAFTED)
    assert_select_helper_function_block "div.alert-warning", content, count: 1 do
      assert_select "ul", count: 1 do
        assert_select "li", count: 2
        assert_select "li", text: "#{mentor_1.name} is a mentor to #{student_1.name} in #{active_group_1.name}, #{active_group_2.name} and #{active_group_3.name}." do
          assert_select "a", href: group_path(active_group_1), text: active_group_1.name
          assert_select "a", href: group_path(active_group_2), text: active_group_2.name
          assert_select "a", href: group_path(active_group_3), text: active_group_3.name
        end
        assert_select "li", text: "#{mentor_1.name} is drafted as a mentor to #{student_1.name} in #{drafted_group_2.name}." do
          assert_select "a", href: groups_path(tab: Group::Status::DRAFTED, search_filters: { profile_name: drafted_group_2.name } ), text: drafted_group_2.name
        end
      end
    end

    # Bulk match: publish drafted group
    content = existing_groups_alert([], [[[student_1.id], [mentor_1.id]]])
    assert_select_helper_function_block "div.alert-warning", content, count: 1 do
      assert_no_select "ul"
      assert_select "div.media-body", text: "#{mentor_1.name} is a mentor to #{student_1.name} in #{active_group_1.name}, #{active_group_2.name} and #{active_group_3.name}." do
        assert_select "a", href: group_path(active_group_1), text: active_group_1.name
        assert_select "a", href: group_path(active_group_2), text: active_group_2.name
        assert_select "a", href: group_path(active_group_3), text: active_group_3.name
      end
    end

    # Bulk match: bulk draft
    content = existing_groups_alert([], [[[student_1.id], [mentor_1.id]], [[student_2.id], [mentor_2.id]]], Group::Status::DRAFTED, :user, false, alert_class: "alert-class", icon_class: "fa fa-star")
    assert_select_helper_function_block "div.alert-class", content, count: 1, text: /The selected users are already connected with each other in the following mentoring connections./ do
      assert_select "i.fa-star", count: 1
      assert_no_select "i.fa-exclamation-triangle"
      assert_select "ul", count: 1 do
        assert_select "li", count: 3
        assert_select "li", text: "#{mentor_1.name} is a mentor to #{student_1.name} in #{active_group_1.name}, #{active_group_2.name} and #{active_group_3.name}." do
          assert_select "a", href: group_path(active_group_1), text: active_group_1.name
          assert_select "a", href: group_path(active_group_2), text: active_group_2.name
          assert_select "a", href: group_path(active_group_3), text: active_group_3.name
        end
        assert_select "li", text: "#{mentor_2.name} is a mentor to #{student_2.name} in #{active_group_2.name} and #{inactive_group_1.name}." do
          assert_select "a", href: group_path(active_group_2), text: active_group_2.name
          assert_select "a", href: group_path(inactive_group_1), text: inactive_group_1.name
        end
        assert_select "li", text: "#{mentor_1.name} is drafted as a mentor to #{student_1.name} in #{drafted_group_2.name}." do
          assert_select "a", href: groups_path(tab: Group::Status::DRAFTED, search_filters: { profile_name: drafted_group_2.name } ), text: drafted_group_2.name
        end
      end
    end

    # Bulk match: bulk publish drafted groups
    group_ids = [drafted_group_1.id, drafted_group_2.id]
    content = existing_groups_alert(group_ids, [], Group::Status::DRAFTED, :group, true)
    assert_select_helper_function "div.alert-warning", content, text: /The following sets of users in the selected mentoring connections are already actively connected./
    assert_select_helper_function "div.alert-warning", content, text: /The following set of users in the selected mentoring connections is part of multiple drafted mentoring connections./
    assert_select_helper_function_block "div.alert-warning", content, count: 2 do
      assert_select "div.media-left", count: 2
      assert_select "div.media-body", count: 2 do
        assert_select "ul", count: 2
        assert_select "li", count: 5
        assert_select "ul" do
          assert_select "li", text: "#{mentor_3.name} is a mentor to #{student_3.name} in #{active_group_2.name} and #{active_group_3.name}." do
            assert_select "a", href: group_path(active_group_2), text: active_group_2.name
            assert_select "a", href: group_path(active_group_3), text: active_group_3.name
          end
          assert_select "li", text: "#{mentor_1.name} is a mentor to #{student_1.name} in #{active_group_1.name}." do
            assert_select "a", href: group_path(active_group_1), text: active_group_1.name
          end
          assert_select "li", text: "#{mentor_1.name} and #{mentor_3.name} are mentors to #{student_1.name}, #{student_2.name} and #{student_3.name} in #{active_group_2.name}." do
            assert_select "a", href: group_path(active_group_2), text: active_group_2.name
          end
          assert_select "li", text: "#{mentor_1.name} and #{mentor_3.name} are mentors to #{student_1.name} and #{student_3.name} in #{active_group_3.name}." do
            assert_select "a", href: group_path(active_group_3), text: active_group_3.name
          end
        end
        assert_select "ul" do
          assert_select "li", text: "#{mentor_3.name} is drafted as a mentor to #{student_3.name} in #{drafted_group_1.name} and #{drafted_group_2.name}." do
            assert_select "a", href: groups_path(tab: Group::Status::DRAFTED, search_filters: { profile_name: drafted_group_1.name } ), text: drafted_group_1.name
            assert_select "a", href: groups_path(tab: Group::Status::DRAFTED, search_filters: { profile_name: drafted_group_2.name } ), text: drafted_group_2.name
          end
        end
      end
    end

    # Groups listing: publish drafted group
    group_ids = [drafted_group_1.id]
    content = existing_groups_alert(group_ids, [], nil, :group)
    assert_select_helper_function_block "div.alert-warning", content, count: 1, text: /The following set of users in the selected mentoring connection is already actively connected./ do
      assert_select "ul", count: 1 do
        assert_select "li", count: 1
        assert_select "li", text: "#{mentor_3.name} is a mentor to #{student_3.name} in #{active_group_2.name} and #{active_group_3.name}." do
          assert_select "a", href: group_path(active_group_2), text: active_group_2.name
          assert_select "a", href: group_path(active_group_3), text: active_group_3.name
        end
      end
    end

    # Groups listing: reactivate closed group
    group_ids = [closed_group_1.id]
    content = existing_groups_alert(group_ids, [], nil, :group)
    assert_select_helper_function_block "div.alert-warning", content, count: 1, text: /The following set of users in the selected mentoring connection is already actively connected./ do
      assert_select "ul", count: 1 do
        assert_select "li", count: 1
        assert_select "li", text: "#{mentor_1.name} is a mentor to #{student_1.name} in #{active_group_1.name}, #{active_group_2.name} and #{active_group_3.name}." do
          assert_select "a", href: group_path(active_group_1), text: active_group_1.name
          assert_select "a", href: group_path(active_group_2), text: active_group_2.name
          assert_select "a", href: group_path(active_group_3), text: active_group_3.name
        end
      end
    end

    # Groups listing: bulk reactivate
    group_ids = [closed_group_1.id, closed_group_2.id]
    content = existing_groups_alert(group_ids, [], Group::Status::CLOSED, :group, true)
    assert_select_helper_function "div.alert-warning", content, text: /The following sets of users in the selected mentoring connections are already actively connected./
    assert_select_helper_function "div.alert-warning", content, text: /The following set of users in the selected mentoring connections is part of multiple closed mentoring connections./
    assert_select_helper_function_block "div.alert-warning", content, count: 2 do
      assert_select "div.media-left", count: 2
      assert_select "div.media-body", count: 2 do
        assert_select "ul", count: 2
        assert_select "li", count: 4
        assert_select "ul" do
          assert_select "li", text: "#{mentor_1.name} is a mentor to #{student_1.name} in #{active_group_1.name}, #{active_group_2.name} and #{active_group_3.name}." do
            assert_select "a", href: group_path(active_group_1), text: active_group_1.name
            assert_select "a", href: group_path(active_group_2), text: active_group_2.name
            assert_select "a", href: group_path(active_group_3), text: active_group_3.name
          end
          assert_select "li", text: "#{mentor_1.name} and #{mentor_3.name} are mentors to #{student_1.name} and #{student_2.name} in #{active_group_2.name}." do
            assert_select "a", href: group_path(active_group_2), text: active_group_2.name
          end
          assert_select "li", text: "#{mentor_1.name} and #{mentor_3.name} are mentors to #{student_1.name} in #{active_group_3.name}." do
            assert_select "a", href: group_path(active_group_3), text: active_group_3.name
          end
        end
        assert_select "ul" do
          assert_select "li", text: "#{mentor_1.name} was a mentor to #{student_1.name} in #{closed_group_1.name} and #{closed_group_2.name}." do
            assert_select "a", href: group_path(closed_group_1), text: closed_group_1.name
            assert_select "a", href: group_path(closed_group_2), text: closed_group_2.name
          end
        end
      end
    end

    # Manage members
    group_ids = [active_group_1.id]
    content = existing_groups_alert(group_ids, [[[student_1.id, student_2.id, student_3.id], [mentor_1.id, mentor_2.id, mentor_3.id]]], Group::Status::DRAFTED, :user)
    assert_select_helper_function_block "div.alert-warning", content, count: 1, text: /The selected users are already connected with each other in the following mentoring connections./ do
      assert_select "ul", count: 1 do
        assert_select "li", count: 5
        assert_select "li", text: "#{mentor_1.name}, #{mentor_2.name} and #{mentor_3.name} are mentors to #{student_1.name}, #{student_2.name} and #{student_3.name} in #{active_group_2.name}." do
          assert_select "a", href: group_path(active_group_2), text: active_group_2.name
        end
        assert_select "li", text: "#{mentor_1.name} and #{mentor_3.name} are mentors to #{student_1.name} and #{student_3.name} in #{active_group_3.name}." do
          assert_select "a", href: group_path(active_group_3), text: active_group_3.name
        end
        assert_select "li", text: "#{mentor_2.name} is a mentor to #{student_2.name} in #{inactive_group_1.name}." do
          assert_select "a", href: group_path(inactive_group_1), text: inactive_group_1.name
        end
        assert_select "li", text: "#{mentor_3.name} is drafted as a mentor to #{student_3.name} in #{drafted_group_1.name}." do
          assert_select "a", href: groups_path(tab: Group::Status::DRAFTED, search_filters: { profile_name: drafted_group_1.name } ), text: drafted_group_1.name
        end
        assert_select "li", text: "#{mentor_1.name} and #{mentor_3.name} are drafted as mentors to #{student_1.name}, #{student_2.name} and #{student_3.name} in #{drafted_group_2.name}." do
          assert_select "a", href: groups_path(tab: Group::Status::DRAFTED, search_filters: { profile_name: drafted_group_2.name } ), text: drafted_group_2.name
        end
      end
    end
  end

  def test_existing_groups_alert_when_group_access_is_disabled
    Program.any_instance.stubs(:allow_multiple_groups_between_student_mentor_pair?).returns(true)
    @current_program.stubs(:admin_access_to_mentoring_area_disabled?).returns(true)
    group = groups(:mygroup)
    student = group.students.first
    mentor = group.mentors.first
    admin = group.program.admin_users.first
    drafted_group = create_group(students: [student], mentors: [mentor], status: Group::Status::DRAFTED, creator_id: admin.id, name: "Drafted Group")

    content = existing_groups_alert([], [[[student.id], [mentor.id]]], Group::Status::DRAFTED)
    assert_select_helper_function_block "div.alert-warning", content, count: 1 do
      assert_select "ul", count: 1 do
        assert_select "li", count: 2
        assert_select "li", text: "#{mentor.name} is a mentor to #{student.name} in #{group.name}." do
          assert_select "span", text: group.name, class: "font-bold"
        end
        assert_select "li", text: "#{mentor.name} is drafted as a mentor to #{student.name} in #{drafted_group.name}." do
          assert_select "a", href: groups_path(tab: Group::Status::DRAFTED, search_filters: { profile_name: drafted_group.name } ), text: drafted_group.name
        end
      end
    end
  end

  def test_bulk_match_additional_users_alert
    drafted_group_1 = groups(:drafted_group_1)
    drafted_group_1_student = drafted_group_1.students.first
    drafted_group_1_mentor = drafted_group_1.mentors.first
    drafted_group_2 = groups(:drafted_group_2)
    drafted_group_2_student = drafted_group_2.students.first
    drafted_group_2_mentor = drafted_group_2.mentors.first
    drafted_group_ids = [drafted_group_1.id, drafted_group_2.id]
    additional_students = [users(:student_8)]
    additional_mentors = [users(:mentor_8)]
    bulk_match_id = drafted_group_1.program.bulk_matches.first.id

    assert_nil bulk_match_additional_users_alert([])
    assert_nil bulk_match_additional_users_alert([drafted_group_1.id])
    assert_nil bulk_match_additional_users_alert([drafted_group_2.id])
    assert_nil bulk_match_additional_users_alert(drafted_group_ids)

    drafted_group_1.update_members(drafted_group_1.mentors + additional_mentors, drafted_group_1.students)
    assert_nil bulk_match_additional_users_alert(drafted_group_ids)

    drafted_group_1.update_column(:bulk_match_id, bulk_match_id)
    drafted_group_2.update_column(:bulk_match_id, bulk_match_id)
    content = bulk_match_additional_users_alert([drafted_group_1.id])
    assert_select_helper_function_block "div.alert-info", content, count: 1 do
      assert_select "div.media-left" do
        assert_select "i.fa-info-circle"
      end
      assert_select "div.media-body", text: "#{additional_mentors[0].name} was added to the mentoring connection between #{drafted_group_1_student.name} and #{drafted_group_1_mentor.name}." do
        assert_no_select "ul"
        assert_select "a", count: 1
        assert_select "a", href: member_path(additional_mentors[0].member)
      end
    end

    content = bulk_match_additional_users_alert(drafted_group_ids, true)
    assert_select_helper_function_block "div.alert-info", content, count: 1, text: /The following user was added to the drafted mentoring connection outside \'Bulk Match\' tool./ do
      assert_select "div.media-left" do
        assert_select "i.fa-info-circle"
      end
      assert_select "div.media-body" do
        assert_select "ul", count: 1 do
          assert_select "li", count: 1
          assert_select "li", text: "#{additional_mentors[0].name} was added to the mentoring connection between #{drafted_group_1_student.name} and #{drafted_group_1_mentor.name}." do
            assert_select "a", count: 1
            assert_select "a", href: member_path(additional_mentors[0].member), text: additional_mentors[0].name
          end
        end
      end
    end

    drafted_group_2.update_members(drafted_group_2.mentors + additional_mentors, drafted_group_2.students)
    content = bulk_match_additional_users_alert(drafted_group_ids, true)
    assert_select_helper_function_block "div.alert-info", content, count: 1, text: /The following user was added to the drafted mentoring connections outside \'Bulk Match\' tool./ do
      assert_select "ul", count: 1 do
        assert_select "li", count: 2
        assert_select "li", text: "#{additional_mentors[0].name} was added to the mentoring connection between #{drafted_group_1_student.name} and #{drafted_group_1_mentor.name}." do
          assert_select "a", count: 1
          assert_select "a", href: member_path(additional_mentors[0].member), text: additional_mentors[0].name
        end
        assert_select "li", text: "#{additional_mentors[0].name} was added to the mentoring connection between #{drafted_group_2_student.name} and #{drafted_group_2_mentor.name}." do
          assert_select "a", count: 1
          assert_select "a", href: member_path(additional_mentors[0].member), text: additional_mentors[0].name
        end
      end
    end

    drafted_group_1.update_members(drafted_group_1.mentors + additional_mentors, drafted_group_1.students + additional_students)
    content = bulk_match_additional_users_alert(drafted_group_ids, true)
    assert_select_helper_function_block "div.alert-info", content, count: 1, text: /The following users were added to the drafted mentoring connections outside \'Bulk Match\' tool./ do
      assert_select "ul", count: 1 do
        assert_select "li", count: 2
        assert_select "li", text: "#{additional_students[0].name} and #{additional_mentors[0].name} were added to the mentoring connection between #{drafted_group_1_student.name} and #{drafted_group_1_mentor.name}." do
          assert_select "a", count: 2
          assert_select "a", href: member_path(additional_mentors[0].member), text: additional_mentors[0].name
          assert_select "a", href: member_path(additional_students[0].member), text: additional_students[0].name
        end
        assert_select "li", text: "#{additional_mentors[0].name} was added to the mentoring connection between #{drafted_group_2_student.name} and #{drafted_group_2_mentor.name}." do
          assert_select "a", count: 1
          assert_select "a", href: member_path(additional_mentors[0].member), text: additional_mentors[0].name
        end
      end
    end
  end

  def test_multiple_existing_groups_note
    Program.any_instance.stubs(:allow_multiple_groups_between_student_mentor_pair?).returns(true)
    Program.any_instance.stubs(:show_existing_groups_alert?).returns(true)
    allow_one_to_many_mentoring_for_program(@current_program)

    admin = users(:f_admin)
    mentor = users(:f_mentor)
    student = users(:mkr_student)
    mentor.update_attribute(:max_connections_limit, 10)
    new_student = users(:f_student)
    group_1 = groups(:mygroup)
    group_2 = create_group(mentors: group_1.mentors, students: group_1.students + [users(:f_student)])
    group_3 = create_group(mentors: group_1.mentors, students: group_2.students, status: Group::Status::DRAFTED, creator_id: admin.id)
    group_4 = create_group(mentors: group_1.mentors, students: [users(:f_student)])

    content = multiple_existing_groups_note
    assert_select_helper_function "span", content, text: "To enable this setting, please ensure that only one active mentoring connection exists between all student - mentor pairs."
    assert_select_helper_function_block "span", content, text: "Please click here to view the student - mentor pairs with multiple mentoring connections." do
      assert_select "a", href: "javascript:void(0)", text: "click here"
    end
    assert_select_helper_function "script", content, count: 1
    assert_match(/mkr_student madankumarrajan and Good unique name are actively connected in.*name &amp; madankumarrajan.*and.*name, madankumarrajan, &amp; example/, content)
    assert_match(/student example and Good unique name are actively connected in.*name, madankumarrajan, &amp; example.*and.*name &amp; example/, content)

    Program.any_instance.stubs(:show_existing_groups_alert?).returns(false)
    assert_nil multiple_existing_groups_note
  end

  def test_assign_template_alert
    program = programs(:pbe)
    groups = program.groups
    pending_groups = groups.pending
    pending_group = pending_groups.first
    non_pending_groups = groups - pending_groups
    non_pending_group = non_pending_groups.first
    forum_enabled_template = program.mentoring_models.first
    messaging_enabled_template = create_mentoring_model(program_id: program.id)
    messaging_enabled_template.update_columns(allow_forum: false, allow_messaging: true)
    both_disabled_template = create_mentoring_model(program_id: program.id, title: "Both disabled")
    both_disabled_template.update_columns(allow_forum: false, allow_messaging: false)
    both_enabled_template = create_mentoring_model(program_id: program.id, title: "Both enabled")
    both_enabled_template.update_columns(allow_forum: true, allow_messaging: true)

    assert groups.all? &:forum_enabled?
    assert_nil assign_template_alert([], forum_enabled_template)
    assert_nil assign_template_alert(groups, forum_enabled_template)
    assert_nil assign_template_alert(non_pending_groups, messaging_enabled_template)
    assert_nil assign_template_alert([pending_group], messaging_enabled_template)

    create_topic(forum: non_pending_group.forum, user: non_pending_group.mentors.first)
    assert_nil assign_template_alert([non_pending_group], messaging_enabled_template)

    create_topic(forum: pending_group.forum, user: pending_group.mentors.first)
    content = assign_template_alert([pending_group], messaging_enabled_template)
    assert_select_helper_function_block "div.alert-warning", content, count: 1 do
      assert_select "div.media-left > i.fa-exclamation-triangle", count: 1
      assert_select "div.media-body", text: "The updated template does not have Discussion Boards enabled. If you go ahead with this change, the users of the mentoring connection will no longer be able to see the discussions."
    end

    pending_group.update_columns(mentoring_model_id: messaging_enabled_template.id)
    assert_nil assign_template_alert([pending_group], forum_enabled_template)

    create_scrap(:group => pending_group)
    content = assign_template_alert([pending_group], forum_enabled_template)
    assert_select_helper_function "div", content, text: "The updated template does not have Messages enabled. If you go ahead with this change, the users of the mentoring connection will no longer be able to see the messages."

    content = assign_template_alert([pending_group], both_disabled_template)
    assert_select_helper_function "div", content, text: "The updated template does not have Messages enabled. If you go ahead with this change, the users of the mentoring connection will no longer be able to see the messages."

    assert_false pending_group.forum_enabled?
    pending_group.stubs(:scraps_enabled?).returns(false)
    assert_nil assign_template_alert([pending_group], messaging_enabled_template)
    pending_group.unstub(:scraps_enabled?)

    pending_group.update_columns(mentoring_model_id: both_enabled_template.id)
    content = assign_template_alert([pending_group], both_disabled_template)
    assert_select_helper_function "div", content, text: "The updated template does not have Discussion Boards\/Messages enabled. If you go ahead with this change, the users of the mentoring connection will no longer be able to see the discussions\/messages."
    pending_group.update_columns(mentoring_model_id: messaging_enabled_template.id)

    forum_groups = pending_groups.reload.select(&:forum_enabled?)
    forum_groups.each { |forum_group| create_topic(forum: forum_group.forum, user: forum_group.mentors.first) }

    assert pending_group.scraps_enabled?
    content = assign_template_alert(pending_groups, messaging_enabled_template)
    assert_select_helper_function_block "div.alert-warning", content, count: 1 do
      assert_select "div.media-left > i.fa-exclamation-triangle", count: 1
      assert_select "div.media-body", text: /Some of the selected mentoring connections have been configured to have Discussion Boards based on their existing template\. Changing the template to 'Homeland' will disable Discussion Boards and will result in loss of discussions for users in the following mentoring connections.*/ do
        assert_select "ul", count: 1 do
          forum_groups.each do |forum_group|
            assert_select "li", text: forum_group.name, count: 1
          end
          assert_select "li", text: pending_group.name, count: 0
        end
      end
    end

    content = assign_template_alert(pending_groups, both_disabled_template)
    assert_select_helper_function "div.media-body", content, text: /Some of the selected mentoring connections have been configured to have Discussion Boards\/Messages based on their existing template\. Changing the template to 'Both disabled' will disable Discussion Boards\/Messages and will result in loss of discussions\/messages for users in the following mentoring connections.*/ do
      assert_select "ul", count: 1 do
        pending_groups.each do |forum_group|
          assert_select "li", text: forum_group.name, count: 1
        end
      end
    end

    content = assign_template_alert(pending_groups, forum_enabled_template)
    assert_select_helper_function_block "div.media-body", content, count: 1, text: /Some of the selected mentoring connections have been configured to have Messages based on their existing template\. Changing the template to 'Project Based Engagement Template' will disable Messages and will result in loss of messages for users in the following mentoring connections.*/ do
      assert_select "ul", count: 1 do
        forum_groups.each do |forum_group|
            assert_select "li", text: forum_group.name, count: 0
          end
        assert_select "li", text: pending_group.name, count: 1
      end
    end
  end
end