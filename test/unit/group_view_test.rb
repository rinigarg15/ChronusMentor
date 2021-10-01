require_relative './../test_helper.rb'

class GroupViewTest < ActiveSupport::TestCase

  def test_validations
    GroupView.destroy_all
    group_view = GroupView.new
    assert_false group_view.valid?
    assert_equal(["can't be blank"], group_view.errors[:program_id])

    group_view = GroupView.create!(program: programs(:albers))

    group_view_1 = GroupView.new(program: programs(:albers))
    assert_false group_view_1.valid?
    assert_equal(["has already been taken"], group_view_1.errors[:program_id])

    assert group_view.valid?
  end

  def test_has_many_group_view_columns
    group_view = programs(:albers).group_view

    assert_equal 18, group_view.group_view_columns.size
    assert_difference 'GroupView.count', -1 do
      assert_difference 'GroupViewColumn.count', -18 do
        group_view.destroy
      end
    end
  end

  def test_belongs_to_program
    GroupView.destroy_all
    assert_difference 'GroupView.count' do
      GroupView.create!(program: programs(:albers))
    end
    group_view = GroupView.last
    assert_equal programs(:albers), group_view.program
  end

  def test_create_default_columns
    GroupViewColumn.destroy_all
    group_view = programs(:albers).group_view
    assert_difference 'GroupViewColumn.count', 18 do
      group_view.create_default_columns
    end
    assert_equal_unordered ["name", "notes", "Closed_by", "Closed_on", "Reason", "Available_since", "Pending_requests", "Active_since", "Last_activity", "Expires_on", "members", "messages_activity", "login_activity", "members", "messages_activity", "login_activity", "Created_by", "Drafted_since"], group_view.group_view_columns.collect(&:key)

    group_view = programs(:pbe).group_view
    group_view.create_default_columns
    assert_equal_unordered [GroupViewColumn::Columns::Key::MEMBERS, GroupViewColumn::Columns::Key::TOTAL_SLOTS, GroupViewColumn::Columns::Key::SLOTS_TAKEN, GroupViewColumn::Columns::Key::SLOTS_REMAINING, GroupViewColumn::Columns::Key::MEETINGS_ACTIVITY, GroupViewColumn::Columns::Key::POSTS_ACTIVITY, GroupViewColumn::Columns::Key::LOGIN_ACTIVITY]*3, group_view.group_view_columns.where.not(role_id: nil).pluck(:column_key)
  end

  def test_get_group_view_columns
    program = programs(:albers)
    mentor_role_id = program.roles.find_by(name: RoleConstants::MENTOR_NAME).id
    program.group_view.destroy
    enable_feature(program, FeatureName::CONNECTION_PROFILE)
    Program.create_default_group_view(program.id)

    group_view = program.reload.group_view
    name_question = profile_questions(:profile_questions_1)
    email_question = profile_questions(:profile_questions_2)

    connection_question = common_questions(:string_connection_q)
    group_view.group_view_columns.create!(profile_question_id: name_question.id, ref_obj_type: GroupViewColumn::ColumnType::USER, role_id: mentor_role_id)
    group_view.group_view_columns.create!(profile_question_id: email_question.id, ref_obj_type: GroupViewColumn::ColumnType::USER, role_id: mentor_role_id)
    group_view.group_view_columns.create!(connection_question_id: connection_question.id, ref_obj_type: GroupViewColumn::ColumnType::GROUP)

    tab_numbers = Group::Status.all.to_a - [Group::Status::INACTIVE]
    tab_numbers.each do |tab_number|
      columns = group_view.get_group_view_columns(tab_number)
      actual_keys = columns.collect(&:key)
      assert_empty GroupViewColumn::Columns::Defaults::COLUMNS_TO_IGNORE_MAP[tab_number] & actual_keys
      assert actual_keys.exclude?(name_question.id.to_s)
      assert actual_keys.include?(email_question.id.to_s)
      assert actual_keys.include?(connection_question.id.to_s)
    end

    email_question.role_questions.where(role_id: mentor_role_id).destroy_all
    tab_numbers.each do |tab_number|
      group_view.expects(:get_applicable_group_view_column_keys).once.returns([])
      columns = group_view.get_group_view_columns(tab_number)
      actual_keys = columns.collect(&:key)
      assert actual_keys.exclude?(email_question.id.to_s)
    end
  end

  def test_get_applicable_group_view_column_keys
    program = programs(:albers)
    enable_feature(program, FeatureName::MENTORING_CONNECTIONS_V2)
    enable_feature(program, FeatureName::MENTORING_CONNECTION_MEETING)
    meeting_column_keys = get_role_based_column_keys(program, GroupViewColumn::Columns::Defaults::GROUP_MEETINGS_DEFAULTS)

    applicable_column_keys = program.group_view.get_applicable_group_view_column_keys
    assert (GroupViewColumn::Columns::Defaults::DRAFTED_DEFAULTS + GroupViewColumn::Columns::Defaults::MENTORING_MODEL_V2_DEFAULTS + GroupViewColumn::Columns::Defaults::MULTIPLE_TEMPLATES_DEFAULTS).all? { |key| applicable_column_keys.include?(key) }
    assert meeting_column_keys.all? { |key| applicable_column_keys.include?(key) }

    disable_feature(program, FeatureName::MENTORING_CONNECTIONS_V2)
    applicable_column_keys = program.group_view.get_applicable_group_view_column_keys
    assert (GroupViewColumn::Columns::Defaults::MENTORING_MODEL_V2_DEFAULTS + GroupViewColumn::Columns::Defaults::MULTIPLE_TEMPLATES_DEFAULTS).all? { |key| applicable_column_keys.exclude?(key) }
    assert meeting_column_keys.all? { |key| applicable_column_keys.include?(key) }

    disable_feature(program, FeatureName::MENTORING_CONNECTION_MEETING)
    applicable_column_keys = program.group_view.get_applicable_group_view_column_keys
    assert (GroupViewColumn::Columns::Defaults::MENTORING_MODEL_V2_DEFAULTS + GroupViewColumn::Columns::Defaults::MULTIPLE_TEMPLATES_DEFAULTS + GroupViewColumn::Columns::Defaults::PROJECT_BASED_COLUMNS).all? { |key| applicable_column_keys.exclude?(key) }
    assert meeting_column_keys.all? { |key| applicable_column_keys.exclude?(key) }
  end

  def test_get_applicable_group_view_column_keys_with_project_proposal_permission
    program = programs(:pbe)
    student_role = program.roles.for_mentoring.find_by(name: RoleConstants::STUDENT_NAME)
    program.groups.with_status([Group::Status::PROPOSED, Group::Status::REJECTED]).destroy_all

    student_role.add_permission(RolePermission::PROPOSE_GROUPS)
    applicable_column_keys = program.group_view.get_applicable_group_view_column_keys
    assert GroupViewColumn::Columns::Defaults::PROPOSED_REJECTED_DEFAULTS.all? { |key| applicable_column_keys.include?(key) }

    student_role.remove_permission(RolePermission::PROPOSE_GROUPS)
    applicable_column_keys = program.group_view.get_applicable_group_view_column_keys
    assert GroupViewColumn::Columns::Defaults::PROPOSED_REJECTED_DEFAULTS.all? { |key| applicable_column_keys.exclude?(key) }

    group = create_group(:name => "Proposed Project", :status => Group::Status::PROPOSED, :mentor => [], :student => [], :program => program, :created_by => users(:f_student_pbe))
    applicable_column_keys = program.group_view.get_applicable_group_view_column_keys
    assert GroupViewColumn::Columns::Defaults::PROPOSED_REJECTED_DEFAULTS.all? { |key| applicable_column_keys.include?(key) }
  end

  def test_get_applicable_group_view_column_keys_with_slot_config
    program = programs(:pbe)
    slot_columns_for_role = ->(role_id) { GroupViewColumn::Columns::Defaults::PROJECT_SLOT_COLUMNS.collect {|col_key| [col_key, role_id].join(GroupViewColumn::COLUMN_SPLITTER)} }
    teacher_role = program.roles.for_mentoring.find_by(name: RoleConstants::TEACHER_NAME)

    assert program.roles.for_mentoring.all { |role| role.slot_config_optional? }
    applicable_column_keys = program.group_view.get_applicable_group_view_column_keys
    slot_column_keys_for_all_roles = program.mentoring_role_ids.collect { |role_id| slot_columns_for_role.call(role_id) }.flatten!
    assert slot_column_keys_for_all_roles.all? { |key| applicable_column_keys.include?(key) }

    teacher_role.update_attributes(slot_config: nil)
    applicable_column_keys = program.group_view.get_applicable_group_view_column_keys
    assert slot_columns_for_role.call(teacher_role.id).all? { |key| applicable_column_keys.exclude?(key) }

    teacher_role.update_attributes(slot_config: RoleConstants::SlotConfig::REQUIRED)
    applicable_column_keys = program.group_view.get_applicable_group_view_column_keys
    assert slot_columns_for_role.call(teacher_role.id).all? { |key| applicable_column_keys.include?(key) }
  end

  def test_get_applicable_group_view_column_keys_for_start_date
    program = programs(:pbe)

    assert program.allow_circle_start_date?
    applicable_column_keys = program.group_view.get_applicable_group_view_column_keys
    assert (GroupViewColumn::Columns::Defaults::PROJECT_BASED_COLUMNS).all? { |key| applicable_column_keys.include?(key) }

    Program.any_instance.stubs(:project_based?).returns(false)
    applicable_column_keys = program.group_view.get_applicable_group_view_column_keys
    assert (GroupViewColumn::Columns::Defaults::PROJECT_BASED_COLUMNS).all? { |key| applicable_column_keys.exclude?(key) }

    Program.any_instance.stubs(:project_based?).returns(true)
    program.update_attribute(:allow_circle_start_date, false)
    applicable_column_keys = program.group_view.get_applicable_group_view_column_keys
    assert (GroupViewColumn::Columns::Defaults::PROJECT_BASED_COLUMNS).all? { |key| applicable_column_keys.exclude?(key) }
  end

  def test_get_applicable_group_view_column_keys_with_withdraw_column
    program = programs(:pbe)
    applicable_column_keys = program.group_view.get_applicable_group_view_column_keys
    assert GroupViewColumn::Columns::Defaults::WITHDRAWN_DEFAULTS.all? { |key| applicable_column_keys.include?(key) }
    program.groups.where(status: Group::Status::WITHDRAWN).destroy_all
    applicable_column_keys = program.group_view.get_applicable_group_view_column_keys
    assert GroupViewColumn::Columns::Defaults::WITHDRAWN_DEFAULTS.all? { |key| applicable_column_keys.exclude?(key) }
  end

  def test_get_applicable_group_view_column_keys_with_messaging_and_forum
    program = programs(:albers)
    group_view = program.group_view
    message_column_keys = get_role_based_column_keys(program, GroupViewColumn::Columns::Defaults::GROUP_MESSAGING_DEFAULTS)
    forum_column_keys = get_role_based_column_keys(program, GroupViewColumn::Columns::Defaults::GROUP_FORUM_DEFAULTS)

    assert program.group_messaging_enabled?
    assert_false program.group_forum_enabled?
    applicable_column_keys = group_view.get_applicable_group_view_column_keys
    assert message_column_keys.all? { |message_column_key| message_column_key.in?(applicable_column_keys) }
    assert_false forum_column_keys.any? { |forum_column_key| forum_column_key.in?(applicable_column_keys) }

    program.stubs(:group_messaging_enabled?).returns(false)
    applicable_column_keys = group_view.get_applicable_group_view_column_keys
    assert_false message_column_keys.any? { |message_column_key| message_column_key.in?(applicable_column_keys) }
    assert_false forum_column_keys.any? { |forum_column_key| forum_column_key.in?(applicable_column_keys) }

    program.stubs(:group_forum_enabled?).returns(true)
    applicable_column_keys = group_view.get_applicable_group_view_column_keys
    assert_false message_column_keys.any? { |message_column_key| message_column_key.in?(applicable_column_keys) }
    assert forum_column_keys.all? { |forum_column_key| forum_column_key.in?(applicable_column_keys) }
  end

  def test_profile_questions_for_role
    program = programs(:pbe)
    group_view = program.group_view
    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentor_questions_to_display = group_view.profile_questions_for_role(mentor_role)
    mentor_questions = program.role_questions.where(role_id: mentor_role.id)
    mentor_question_ids_except_skype_and_name_questions = mentor_questions.reject do |role_question|
      role_question.profile_question.name_type? || role_question.profile_question.skype_id_type?
    end.collect(&:profile_question_id)
    assert mentor_questions_to_display.none?(&:skype_id_type?)
    assert mentor_questions_to_display.none?(&:name_type?)
    assert mentor_questions_to_display.any?(&:email_type?)
    assert_equal_unordered mentor_question_ids_except_skype_and_name_questions, mentor_questions_to_display.collect(&:id)
  end

  private

  def get_role_based_column_keys(program, column_keys = GroupViewColumn::Columns::Defaults::ROLE_BASED_COLUMNS)
    program.mentoring_role_ids.collect do |role_id|
      column_keys.collect { |column_key| [column_key, role_id].join(GroupViewColumn::COLUMN_SPLITTER) }
    end.flatten
  end
end