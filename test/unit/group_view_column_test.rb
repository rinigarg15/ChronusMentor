require_relative './../test_helper.rb'

class GroupViewColumnTest < ActiveSupport::TestCase

  def test_validations
    group_view = programs(:albers).group_view
    group_view_column = GroupViewColumn.new
    assert_false group_view_column.valid?
    assert_equal(["can't be blank"], group_view_column.errors[:group_view])
    assert_equal(["can't be blank", "is not included in the list"], group_view_column.errors[:column_key])
    assert_equal(["can't be blank"], group_view_column.errors[:profile_question_id])
    assert_equal(["can't be blank"], group_view_column.errors[:connection_question_id])

    group_view_column = group_view.group_view_columns.new(column_key: "name123")
    assert_false group_view_column.valid?
    assert_equal(["is not included in the list"], group_view_column.errors[:column_key])

    group_view_column = group_view.group_view_columns.new(column_key: "name")
    assert_false group_view_column.valid?
    assert_equal(["has already been taken"], group_view_column.errors[:column_key])

    group_view_column = group_view.group_view_columns.create!(profile_question_id: 1, position: 9)
    assert group_view_column.valid?

    group_view_column = group_view.group_view_columns.new(profile_question_id: 1)
    assert_false group_view_column.valid?
    assert_equal(["has already been taken"], group_view_column.errors[:profile_question_id])

    group_view_column = group_view.group_view_columns.create!(connection_question_id: 1, position: 10)
    assert group_view_column.valid?

    group_view_column = group_view.group_view_columns.new(connection_question_id: 1)
    assert_false group_view_column.valid?
    assert_equal(["has already been taken"], group_view_column.errors[:connection_question_id])

    program = programs(:pbe)
    group_view = program.group_view
    group_view_column = group_view.group_view_columns.new(ref_obj_type: GroupViewColumn::ColumnType::USER, column_key: GroupViewColumn::Columns::Key::SLOTS_TAKEN)
    assert_false group_view_column.valid?
    assert_equal(["can't be blank"], group_view_column.errors[:role_id])
  end

  def test_get_title
    group_view_column = GroupViewColumn.first
    program = group_view_column.group_view.program
    roles_hsh = program.roles.includes(:translations, :customized_term).index_by(&:id)
    mentor_role_id = program.roles.find_by(name: RoleConstants::MENTOR_NAME).id
    student_role_id = program.roles.find_by(name: RoleConstants::STUDENT_NAME).id
    assert_equal "Mentoring Connection Name", group_view_column.get_title(roles_hsh)

    group_view_column.update_attributes!(column_key: nil, profile_question_id: 2, ref_obj_type: GroupViewColumn::ColumnType::USER, role_id: mentor_role_id)
    assert_equal "Mentor - Email", group_view_column.get_title(roles_hsh)
    group_view_column.update_attributes!(column_key: nil, connection_question_id: Connection::Question.first.id, ref_obj_type: GroupViewColumn::ColumnType::GROUP)
    assert_equal "Funding Value", group_view_column.get_title(roles_hsh)

    program = programs(:pbe)
    group_view = program.group_view
    student_role_id = program.roles.find_by(name: RoleConstants::STUDENT_NAME).id
    group_view_column = group_view.group_view_columns.find_by(column_key: GroupViewColumn::Columns::Key::SLOTS_TAKEN, role_id: student_role_id)
    customized_role_term = program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME)
    customized_role_term.update_attributes!(term: "Mentee")
    roles_hsh = program.roles.includes(:translations, :customized_term).index_by(&:id)
    assert_equal "Number of slots taken (Mentee)", group_view_column.get_title(roles_hsh)
  end

  def test_key
    group_view = programs(:albers).group_view

    column = group_view.group_view_columns.first
    assert_equal "name", column.key

    profile_question = programs(:albers).profile_questions_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], {skype: false, default: false}).first
    column.update_attributes!(:column_key => nil, :profile_question => profile_question, :ref_obj_type => GroupViewColumn::ColumnType::USER)
    assert_equal profile_question.id.to_s, column.key

    connection_question = programs(:albers).connection_questions.first
    group_column = GroupViewColumn.create!(:group_view => group_view, :connection_question => connection_question, :position => 2, :ref_obj_type => GroupViewColumn::ColumnType::GROUP) 
    assert_equal connection_question.id.to_s, group_column.key
  end

  def test_sorting_key
    group_view = programs(:pbe).group_view
    column = group_view.group_view_columns.first
    roles_hsh = programs(:pbe).roles.index_by(&:id)
    assert_equal column.column_key, column.sorting_key
    keys = {
      GroupViewColumn::Columns::Key::TOTAL_SLOTS => "membership_setting_total_slots.",
      GroupViewColumn::Columns::Key::SLOTS_TAKEN => "membership_setting_slots_taken.",
      GroupViewColumn::Columns::Key::SLOTS_REMAINING => "membership_setting_slots_remaining.",
    }
    keys.each do |input, output|
      column.column_key = input
      roles_hsh.each do |id, role|
        column.role_id = id
        assert_equal output + role.name, column.sorting_key(roles_hsh)
        assert_equal output + role.name, column.sorting_key
      end
    end
    column.column_key = "members"
    roles_hsh.each do |id, role|
      column.role_id = id
      expected = if role.mentor?
        "mentors.name_only.sort"
      elsif role.mentee?
        "students.name_only.sort"
      else
        "role_users_full_name." + role.name + "_name"
      end
      assert_equal expected, column.sorting_key(roles_hsh)
      assert_equal expected, column.sorting_key
    end
  end

  def test_check_dependent_destoy_on_profile_question
    group_view_column = GroupViewColumn.first

    pq = ProfileQuestion.first
    group_view_column.update_attributes!(:column_key => nil, :profile_question_id => pq.id, :ref_obj_type => GroupViewColumn::ColumnType::USER)

    assert_difference "GroupViewColumn.count", -1 do
      pq.destroy
    end
  end

  def test_column_default_has
    assert_false GroupViewColumn::Columns::Defaults.has?("sample")
    assert_false GroupViewColumn::Columns::Defaults.has?("sample123")

    assert GroupViewColumn::Columns::Defaults.has?("name")
    assert GroupViewColumn::Columns::Defaults.has?("members")
  end

  def test_belongs_to
    group_view = programs(:albers).group_view
    connection_question = programs(:albers).connection_questions.first
    group_view_column = GroupViewColumn.create!(:group_view => group_view, :connection_question => connection_question, :position => 10)

    assert_equal group_view, group_view_column.group_view
    assert_equal connection_question, group_view_column.connection_question

    profile_question = profile_questions(:profile_questions_3)
    group_view_column = GroupViewColumn.create!(:group_view => group_view, :profile_question => profile_question, :position => 10)
    assert_equal profile_question, group_view_column.profile_question
  end

  def test_scopes
    GroupViewColumn.destroy_all
    group_view = programs(:albers).group_view
    mentor_role_id = programs(:albers).roles.find_by(name: RoleConstants::MENTOR_NAME).id
    student_role_id = programs(:albers).roles.find_by(name: RoleConstants::STUDENT_NAME).id
    default_column = group_view.group_view_columns.create!(column_key: "name", position: 1, ref_obj_type: GroupViewColumn::ColumnType::NONE)
    connection_question = programs(:albers).connection_questions.first
    group_column = group_view.group_view_columns.create!(connection_question: connection_question, position: 2, ref_obj_type: GroupViewColumn::ColumnType::GROUP)
    profile_question = profile_questions(:profile_questions_3)
    user_column_1 = group_view.group_view_columns.create!(profile_question: profile_question, position: 3, role_id: mentor_role_id, :ref_obj_type => GroupViewColumn::ColumnType::USER)
    user_column_2 = group_view.group_view_columns.create!(profile_question: profile_question, position: 4, role_id: student_role_id, ref_obj_type: GroupViewColumn::ColumnType::USER)

    assert_equal [default_column], group_view.group_view_columns.default
    assert_equal [group_column], group_view.group_view_columns.group_questions
    assert_equal [user_column_1, user_column_2], group_view.group_view_columns.user_questions
    assert_equal [user_column_2], group_view.group_view_columns.role_questions(student_role_id)
    assert_equal [user_column_1], group_view.group_view_columns.role_questions(mentor_role_id)
  end

  def test_is_default_or_user_or_group_question
    GroupViewColumn.destroy_all
    program = programs(:albers)
    group_view = program.group_view
    default_column = group_view.group_view_columns.create!(column_key: "name", position: 1, ref_obj_type: GroupViewColumn::ColumnType::NONE)
    connection_question = program.connection_questions.first
    group_column = group_view.group_view_columns.create!(connection_question: connection_question, position: 2, ref_obj_type: GroupViewColumn::ColumnType::GROUP)
    profile_question = profile_questions(:profile_questions_3)
    user_column = group_view.group_view_columns.create!(profile_question: profile_question, position: 3, ref_obj_type: GroupViewColumn::ColumnType::USER, role_id: program.roles.find_by(name: RoleConstants::MENTOR_NAME).id)

    assert default_column.is_default_question?
    assert_false user_column.is_default_question?
    assert_false group_column.is_default_question?
    assert_false default_column.is_group_question?
    assert_false user_column.is_group_question?
    assert group_column.is_group_question?
    assert_false default_column.is_user_question?
    assert user_column.is_user_question?
    assert_false group_column.is_user_question?
  end

  def test_title
    program = programs(:albers)
    assert_equal ["Started on", "Closes on", "Closes in"], (["Active_since", "Expires_on", "Expires_in"]).collect {|key| GroupViewColumn::Columns::Defaults.title(key, program)}
  end

  def test_get_default_title
    organization = programs(:org_primary)
    program = programs(:albers)
    mentor_role_id = program.roles.find_by(name: RoleConstants::MENTOR_NAME).id
    student_role_id = program.roles.find_by(name: RoleConstants::STUDENT_NAME).id

    assert_equal "Mentoring Connection Name", GroupViewColumn.get_default_title("name", program)
    assert_equal "Reason", GroupViewColumn.get_default_title("Reason", program)
    assert_false program.allow_one_to_many_mentoring?
    assert_equal "Mentor", GroupViewColumn.get_default_title("members:#{mentor_role_id}", program)
    assert_equal "Mentor Meetings", GroupViewColumn.get_default_title("meetings_activity:#{mentor_role_id}", program)
    assert_equal "Mentor Messages", GroupViewColumn.get_default_title("messages_activity:#{mentor_role_id}", program)
    assert_equal "Mentor Login Instances", GroupViewColumn.get_default_title("login_activity:#{mentor_role_id}", program)
    assert_equal "Student", GroupViewColumn.get_default_title("members:#{student_role_id}", program)
    assert_equal "Student Meetings", GroupViewColumn.get_default_title("meetings_activity:#{student_role_id}", program)
    assert_equal "Student Messages", GroupViewColumn.get_default_title("messages_activity:#{student_role_id}", program)
    assert_equal "Student Login Instances", GroupViewColumn.get_default_title("login_activity:#{student_role_id}", program)

    program.update_attributes!(allow_one_to_many_mentoring: true)
    assert program.allow_one_to_many_mentoring?
    assert_equal "Mentors", GroupViewColumn.get_default_title("members:#{mentor_role_id}", program)
    assert_equal "Mentor Meetings", GroupViewColumn.get_default_title("meetings_activity:#{mentor_role_id}", program)
    assert_equal "Students", GroupViewColumn.get_default_title("members:#{student_role_id}", program)
    assert_equal "Student Meetings", GroupViewColumn.get_default_title("meetings_activity:#{student_role_id}", program)
  end

  def test_is_sortable
    group_view = programs(:albers).group_view
    default_column = group_view.group_view_columns.where(column_key: "name")
    default_column_1 = group_view.group_view_columns.where(column_key: "Reason")
    connection_question = programs(:albers).connection_questions.first
    group_column = GroupViewColumn.create!(:group_view => group_view, :connection_question => connection_question, :position => 2, :ref_obj_type => GroupViewColumn::ColumnType::GROUP) 

    assert default_column.first.is_sortable?
    assert_false group_column.is_sortable?
    assert_false default_column_1.first.is_sortable?
  end

  def test_find_object
    group_view = programs(:albers).group_view
    mentor_role_id = programs(:albers).roles.find_by(name: RoleConstants::MENTOR_NAME).id
    student_role_id = programs(:albers).roles.find_by(name: RoleConstants::STUDENT_NAME).id
    column_object_array = group_view.group_view_columns

    column_key = "sample"
    ref_obj_type = GroupViewColumn::ColumnType::NONE
    assert_nil GroupViewColumn.find_object(column_object_array, column_key, ref_obj_type, role_id: nil)

    column_key = "name"
    assert_equal "name", GroupViewColumn.find_object(column_object_array, column_key, ref_obj_type, role_id: nil).key

    connection_question = programs(:albers).connection_questions.first
    group_column = group_view.group_view_columns.create!(connection_question: connection_question, position: 2, ref_obj_type: GroupViewColumn::ColumnType::GROUP)
    profile_question = profile_questions(:profile_questions_3)
    user_column = group_view.group_view_columns.create!(profile_question: profile_question, position: 3, role_id: mentor_role_id, ref_obj_type: GroupViewColumn::ColumnType::USER)
    column_object_array = group_view.reload.group_view_columns

    ref_obj_type = GroupViewColumn::ColumnType::GROUP
    column_key = connection_question.id
    assert_equal group_column, GroupViewColumn.find_object(column_object_array, column_key, ref_obj_type, role_id: mentor_role_id)

    ref_obj_type = GroupViewColumn::ColumnType::USER
    column_key = profile_question.id
    assert_equal user_column, GroupViewColumn.find_object(column_object_array, column_key, ref_obj_type, role_id: mentor_role_id)

    program = programs(:pbe)
    group_view = program.group_view
    mentor_role_id = program.roles.find_by(name: RoleConstants::MENTOR_NAME).id
    student_role_id = program.roles.find_by(name: RoleConstants::STUDENT_NAME).id
    assert_equal mentor_role_id, GroupViewColumn.find_object(group_view.group_view_columns, GroupViewColumn::Columns::Key::TOTAL_SLOTS, GroupViewColumn::ColumnType::NONE, role_id: mentor_role_id).role_id
    assert_equal student_role_id, GroupViewColumn.find_object(group_view.group_view_columns, GroupViewColumn::Columns::Key::TOTAL_SLOTS, GroupViewColumn::ColumnType::NONE, role_id: student_role_id).role_id
  end

  def test_get_invalid_column_keys
    assert_equal GroupViewColumn::Columns::Defaults::COLUMNS_TO_IGNORE_MAP[Group::Status::DRAFTED], GroupViewColumn.get_invalid_column_keys(Group::Status::DRAFTED)
    assert GroupViewColumn.get_invalid_column_keys(Group::Status::DRAFTED).include?(GroupViewColumn::Columns::Key::AVAILABLE_SINCE)
    assert_false GroupViewColumn.get_invalid_column_keys(Group::Status::DRAFTED).include?(GroupViewColumn::Columns::Key::DRAFTED_SINCE)

    assert_equal GroupViewColumn::Columns::Defaults::COLUMNS_TO_IGNORE_MAP[Group::Status::PENDING], GroupViewColumn.get_invalid_column_keys(Group::Status::PENDING)
    assert GroupViewColumn.get_invalid_column_keys(Group::Status::PENDING).include?(GroupViewColumn::Columns::Key::EXPIRES_ON)
    assert_false GroupViewColumn.get_invalid_column_keys(Group::Status::PENDING).include?(GroupViewColumn::Columns::Key::PENDING_REQUESTS_COUNT)

    assert_equal GroupViewColumn::Columns::Defaults::COLUMNS_TO_IGNORE_MAP[Group::Status::CLOSED], GroupViewColumn.get_invalid_column_keys(Group::Status::CLOSED)
    assert GroupViewColumn.get_invalid_column_keys(Group::Status::CLOSED).include?(GroupViewColumn::Columns::Key::REJECTED_BY)
    assert_false GroupViewColumn.get_invalid_column_keys(Group::Status::CLOSED).include?(GroupViewColumn::Columns::Key::CLOSED_BY)
    assert_false GroupViewColumn.get_invalid_column_keys(Group::Status::CLOSED).include?(GroupViewColumn::Columns::Key::CLOSED_ON)

    assert_equal GroupViewColumn::Columns::Defaults::COLUMNS_TO_IGNORE_MAP[Group::Status::PROPOSED], GroupViewColumn.get_invalid_column_keys(Group::Status::PROPOSED)
    assert GroupViewColumn.get_invalid_column_keys(Group::Status::PROPOSED).include?(GroupViewColumn::Columns::Key::MILESTONES_OVERDUE_STATUS_V2)
    assert_false GroupViewColumn.get_invalid_column_keys(Group::Status::PROPOSED).include?(GroupViewColumn::Columns::Key::PROPOSED_BY)

    assert_equal GroupViewColumn::Columns::Defaults::COLUMNS_TO_IGNORE_MAP[Group::Status::REJECTED], GroupViewColumn.get_invalid_column_keys(Group::Status::REJECTED)
    assert_false GroupViewColumn.get_invalid_column_keys(Group::Status::REJECTED).include?(GroupViewColumn::Columns::Key::REJECTED_BY)
    assert_equal GroupViewColumn::Columns::Defaults::COLUMNS_TO_IGNORE_MAP[Group::Status::WITHDRAWN], GroupViewColumn.get_invalid_column_keys(Group::Status::WITHDRAWN)
    assert GroupViewColumn::Columns::Defaults.all.include?(GroupViewColumn::Columns::Key::WITHDRAWN_BY)
    assert GroupViewColumn::Columns::Defaults.all.include?(GroupViewColumn::Columns::Key::WITHDRAWN_AT)
    assert_false GroupViewColumn.get_invalid_column_keys(Group::Status::WITHDRAWN).include?(GroupViewColumn::Columns::Key::WITHDRAWN_BY)
    assert_false GroupViewColumn.get_invalid_column_keys(Group::Status::WITHDRAWN).include?(GroupViewColumn::Columns::Key::WITHDRAWN_AT)
    assert_equal GroupViewColumn::Columns::Defaults::COLUMNS_TO_IGNORE_MAP[Group::Status::ACTIVE], GroupViewColumn.get_invalid_column_keys(Group::Status::ACTIVE)
    assert GroupViewColumn.get_invalid_column_keys(Group::Status::ACTIVE).include?(GroupViewColumn::Columns::Key::REASON)
    assert_false GroupViewColumn.get_invalid_column_keys(Group::Status::ACTIVE).include?(GroupViewColumn::Columns::Key::GOALS_STATUS_V2)
  end

  def test_is_messaging_column_and_forum_column
    column = GroupViewColumn.new
    column.column_key = GroupViewColumn::Columns::Key::MESSAGES_ACTIVITY
    assert column.is_messaging_column?
    assert_false column.is_forum_column?

    column.column_key = GroupViewColumn::Columns::Key::POSTS_ACTIVITY
    assert_false column.is_messaging_column?
    assert column.is_forum_column?

    column.column_key = GroupViewColumn::Columns::Key::MEETINGS_ACTIVITY
    assert_false column.is_messaging_column?
    assert_false column.is_forum_column?
  end
end