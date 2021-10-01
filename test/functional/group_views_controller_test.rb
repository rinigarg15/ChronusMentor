require_relative './../test_helper.rb'

class GroupViewsControllerTest < ActionController::TestCase

  def test_only_admin_can_perform_the_update
    current_user_is :f_mentor

    assert_permission_denied do
      post :update, params: { :id => programs(:albers).group_view}
    end
  end

  def test_update_group_view
    current_user_is :f_admin
    group_view = programs(:albers).group_view
    mentor_role_id = programs(:albers).roles.find_by(name: RoleConstants::MENTOR_NAME).id
    student_role_id = programs(:albers).roles.find_by(name: RoleConstants::STUDENT_NAME).id
    assert_equal 18, group_view.group_view_columns.size
    assert_equal 18, group_view.group_view_columns.default.size

    assert_blank group_view.group_view_columns.group_questions
    assert_blank group_view.group_view_columns.user_questions
    assert_blank group_view.group_view_columns.role_questions(mentor_role_id)
    assert_blank group_view.group_view_columns.role_questions(student_role_id)

    connection_question = programs(:albers).connection_questions.first

    assert_difference "GroupViewColumn.count", -(14 - (group_view.group_view_columns.collect(&:key) & GroupViewColumn::Columns::Defaults::COLUMNS_TO_IGNORE_MAP[Group::Status::ACTIVE]).count) do
      post :update, params: { :id => group_view.id, :group_view => {:group_view_columns => ["default:name", "connection:#{connection_question.id}", "#{mentor_role_id}:3", "#{student_role_id}:4"], :view => "1", :tab => ""}}
    end

    assert_equal 11, group_view.reload.group_view_columns.size
    assert_equal_unordered group_view.group_view_columns.collect(&:key) - ["name", connection_question.id.to_s, "3", "4"], (group_view.group_view_columns.collect(&:key) & GroupViewColumn::Columns::Defaults::COLUMNS_TO_IGNORE_MAP[Group::Status::ACTIVE])
    assert_equal 8, group_view.group_view_columns.default.size
    assert_equal 1, group_view.group_view_columns.group_questions.size
    assert_equal 2, group_view.group_view_columns.user_questions.size
    assert_equal 1, group_view.group_view_columns.role_questions(mentor_role_id).size
    assert_equal 1, group_view.group_view_columns.role_questions(student_role_id).size

    assert_equal ["name", "Closed_by", "Closed_on", "Reason", "Created_by", "Drafted_since", "Available_since", "Pending_requests"], group_view.group_view_columns.default.collect(&:key)
    assert_equal [connection_question.id.to_s], group_view.group_view_columns.group_questions.collect(&:key)
    assert_equal ["3", "4"], group_view.group_view_columns.user_questions.collect(&:key)
    assert_equal ["3"], group_view.group_view_columns.role_questions(mentor_role_id).collect(&:key)
    assert_equal ["4"], group_view.group_view_columns.role_questions(student_role_id).collect(&:key)

    assert_difference "GroupViewColumn.count", -3 do
      post :update, params: { :id => group_view.id, :group_view => {:group_view_columns => ["default:Active_since", "connection:#{connection_question.id}", "#{mentor_role_id}:3", "#{student_role_id}:4"], :view => "1", :tab => "#{Group::Status::CLOSED}"}}
    end
    assert_false group_view.reload.group_view_columns.collect(&:key).include?("Closed_on")
    assert_false group_view.reload.group_view_columns.collect(&:key).include?("Closed_by")
    assert_false group_view.group_view_columns.collect(&:key).include?("Reason")
    assert_false group_view.group_view_columns.collect(&:key).include?("name")
    assert group_view.group_view_columns.collect(&:key).include?("Active_since")
  end

  def test_update_group_view_create_role_based_columns
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    group_view = program.group_view
    mentor_role_id = program.roles.find_by(name: RoleConstants::MENTOR_NAME).id
    student_role_id = program.roles.find_by(name: RoleConstants::STUDENT_NAME).id
    teacher_role_id = program.roles.find_by(name: RoleConstants::TEACHER_NAME).id
    group_view.group_view_columns.where(role_id: program.role_ids).destroy_all

    post :update, params: { :id => group_view.id, :group_view => {:group_view_columns => ["default:name", "default:total_slots:#{mentor_role_id}", "default:slots_taken:#{student_role_id}", "default:slots_remaining:#{teacher_role_id}", "default:members:#{mentor_role_id}", "default:meetings_activity:#{mentor_role_id}", "default:messages_activity:#{student_role_id}", "default:login_activity:#{teacher_role_id}"], :view => "1", :tab => "0"}}
    assert_equal ["total_slots", "slots_taken", "slots_remaining", "members", "meetings_activity", "messages_activity", "login_activity"], group_view.group_view_columns.where(role_id: program.role_ids).order(:position).pluck(:column_key)
    assert_equal [mentor_role_id, student_role_id, teacher_role_id, mentor_role_id, mentor_role_id, student_role_id, teacher_role_id], group_view.group_view_columns.where(role_id: program.role_ids).order(:position).pluck(:role_id)
  end

  def test_update_group_view_update_positions_role_based_columns
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    group_view = program.group_view
    mentor_role_id = program.roles.find_by(name: RoleConstants::MENTOR_NAME).id
    student_role_id = program.roles.find_by(name: RoleConstants::STUDENT_NAME).id
    teacher_role_id = program.roles.find_by(name: RoleConstants::TEACHER_NAME).id

    post :update, params: { :id => group_view.id, :group_view => {:group_view_columns => ["default:name", "default:slots_remaining:#{teacher_role_id}", "default:total_slots:#{mentor_role_id}", "default:slots_taken:#{student_role_id}", "default:members:#{teacher_role_id}", "default:meetings_activity:#{mentor_role_id}", "default:messages_activity:#{student_role_id}", "default:login_activity:#{teacher_role_id}"], :view => "1", :tab => "0"}}

    assert_equal ["slots_remaining", "total_slots", "slots_taken", "members", "meetings_activity", "messages_activity", "login_activity"], group_view.group_view_columns.where(role_id: program.role_ids).order(:position).pluck(:column_key)
    assert_equal [teacher_role_id, mentor_role_id, student_role_id, teacher_role_id, mentor_role_id, student_role_id, teacher_role_id], group_view.group_view_columns.where(role_id: program.role_ids).order(:position).pluck(:role_id)
  end

  def test_update_group_view_destroy_role_based_columns
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    group_view = program.group_view
    teacher_role_id = program.roles.find_by(name: RoleConstants::TEACHER_NAME).id
    mentor_role_id = program.roles.find_by(name: RoleConstants::MENTOR_NAME).id

    post :update, params: { :id => group_view.id, :group_view => {:group_view_columns => ["default:name", "default:slots_remaining:#{teacher_role_id}", "default:login_activity:#{mentor_role_id}"], :view => "1", :tab => "0"}}

    assert_equal 1, group_view.group_view_columns.where(role_id: teacher_role_id).size
    assert_equal 1, group_view.group_view_columns.where(role_id: mentor_role_id).size
    assert_equal "slots_remaining", group_view.group_view_columns.where(role_id: teacher_role_id).first.column_key
    assert_equal "login_activity", group_view.group_view_columns.where(role_id: mentor_role_id).first.column_key
  end

  def test_create_group_view_column_third_role_profile_question
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    group_view = program.group_view
    teacher_role_id = program.roles.find_by(name: RoleConstants::TEACHER_NAME).id
    profile_question = create_profile_question
    create_role_question(program: program, role_names: [RoleConstants::TEACHER_NAME], profile_question: profile_question)
    post :update, params: { :id => group_view.id, :group_view => {:group_view_columns => ["#{teacher_role_id}:#{profile_question.id}"], :view => "1", :tab => "0"}}

    assert_equal 1, group_view.group_view_columns.where(role_id: teacher_role_id).size
    assert_equal profile_question.id.to_s, group_view.group_view_columns.where(role_id: teacher_role_id).first.key
  end

end