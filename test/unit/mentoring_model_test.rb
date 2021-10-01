require_relative './../test_helper.rb'

class MentoringModelTest < ActiveSupport::TestCase

  def setup
    super
    @default_mentoring_model = programs(:albers).mentoring_models.default.first
  end

  def test_validations
    mentoring_model = MentoringModel.new(goal_progress_type: nil, allow_messaging: nil, allow_forum: nil)
    assert_false mentoring_model.valid?
    assert_equal ["can't be blank"], mentoring_model.errors[:program_id]
    assert_equal ["can't be blank"], mentoring_model.errors[:title]
    assert_equal ["can't be blank"], mentoring_model.errors[:goal_progress_type]
    assert_equal ["can't be blank", "is not a number"], mentoring_model.errors[:mentoring_period]
    assert_equal ["is not included in the list"], mentoring_model.errors[:allow_messaging]
    assert_equal ["is not included in the list"], mentoring_model.errors[:allow_forum]

    mentoring_model.program_id = programs(:albers).id
    mentoring_model.goal_progress_type = MentoringModel::GoalProgressType::AUTO
    mentoring_model.allow_messaging = false
    mentoring_model.allow_forum = true
    assert_false mentoring_model.valid?
    mentoring_model.title = "Carrie Mathison"
    assert_false mentoring_model.valid?
    mentoring_model.mentoring_period = 0.months
    assert_false mentoring_model.valid?
    mentoring_model.mentoring_period = 12.months
    assert mentoring_model.valid?
  end

  def test_scope_with_manual_goals
    mm = MentoringModel.first
    assert_false MentoringModel.with_manual_goals.include?(mm)

    mm.update_attribute(:goal_progress_type, MentoringModel::GoalProgressType::MANUAL)
    assert MentoringModel.with_manual_goals.include?(mm)
  end

  def test_manual_progress_goals
    mm = MentoringModel.first
    assert_false mm.manual_progress_goals?

    mm.update_attribute(:goal_progress_type, MentoringModel::GoalProgressType::MANUAL)
    assert mm.reload.manual_progress_goals?
  end

  def test_uniqueness_validation
    program = programs(:albers)
    organization = program.organization

    assert_nothing_raised do
      create_mentoring_model(title: "Carrie Mathison", program_id: organization.id)
    end

    assert_nothing_raised do
      create_mentoring_model(title: "Carrie Mathison", program_id: program.id)
    end

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :title do
      create_mentoring_model(title: "Carrie Mathison", program_id: program.id)
    end

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :title do
      create_mentoring_model(title: "Carrie Mathison", program_id: organization.id)
    end

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :title do
      create_mentoring_model(title: "carrie mathison", program_id: organization.id)
    end

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :title do
      create_mentoring_model(title: "CARRIE MATHISON", program_id: organization.id)
    end
  end

  def test_default_scope
    program = programs(:albers)
    default_mentoring_models = program.mentoring_models.default
    assert_equal 1, default_mentoring_models.size
    mentoring_model = program.mentoring_models.first
    assert_equal mentoring_model, default_mentoring_models.first
    assert default_mentoring_models.first.default?
  end

  def test_can_update_duration
    program = programs(:albers)
    default_mentoring_model = program.default_mentoring_model
    assert_equal 0, default_mentoring_model.groups.active.size
    assert default_mentoring_model.can_update_duration?
    default_mentoring_model.program.groups[0].update_attribute(:mentoring_model_id, default_mentoring_model.id)
    assert_equal 1, default_mentoring_model.reload.groups.active.size
    assert_false default_mentoring_model.can_update_duration?
    default_mentoring_model.update_attribute(:mentoring_model_type, MentoringModel::Type::HYBRID)
    assert default_mentoring_model.hybrid?
    assert_false default_mentoring_model.can_update_duration?
  end

  def test_can_update_features
    program = programs(:albers)
    default_mentoring_model = program.default_mentoring_model
    assert_equal 0, default_mentoring_model.groups.active.size
    assert default_mentoring_model.can_update_features?
    hybrid = create_mentoring_model(mentoring_model_type: MentoringModel::Type::HYBRID)
    default_mentoring_model.parents = [hybrid]
    assert_false default_mentoring_model.can_update_features?
    default_mentoring_model.parents = []
    assert default_mentoring_model.can_update_features?
    default_mentoring_model.program.groups[0].update_attribute(:mentoring_model_id, default_mentoring_model.id)
    assert_equal 1, default_mentoring_model.reload.groups.active.size
    assert_false default_mentoring_model.can_update_features?
  end

  def test_permissions_dont_get_created_if_present
    program = programs(:albers)
    roles_hash = program.roles.select([:id, :name]).for_mentoring_models.group_by(&:name)
    admin = {"manage_mm_milestones"=>"1", "manage_mm_goals"=>"1", "manage_mm_tasks"=>"1", "manage_mm_messages"=>"1", "manage_mm_meetings"=>"1", "manage_mm_engagement_surveys"=>"1"}
    users = {"manage_mm_milestones"=>"0", "manage_mm_goals"=>"1", "manage_mm_tasks"=>"0", "manage_mm_messages"=>"1", "manage_mm_meetings"=>"0", "manage_mm_engagement_surveys"=>"0"}
    permissions = {"permissions" => {"admin" => admin, "users" => users}}
    mentoring_model = program.default_mentoring_model
    mentoring_model.allow_manage_mm_milestones!(program.roles.with_name(RoleConstants::ADMIN_NAME))
    assert_no_difference("mentoring_model.reload.object_role_permissions.count") do
      mentoring_model.allow_manage_mm_milestones!(program.roles.with_name(RoleConstants::ADMIN_NAME))
    end
  end

  def test_object_role_permissions
    program = programs(:albers)
    roles = program.roles
    permission = ObjectPermission.where(name: "manage_mm_goals").first

    assert_equal "manage_mm_goals", permission.name
    @default_mentoring_model.deny_manage_mm_goals!(roles)
    assert_false @default_mentoring_model.can_manage_mm_goals?(roles)
    assert_false @default_mentoring_model.can_manage_mm_goals?(roles[0])
    assert_false @default_mentoring_model.can_manage_mm_goals?(roles[1])
    @default_mentoring_model.allow_manage_mm_goals!(roles[0])
    assert @default_mentoring_model.can_manage_mm_goals?(roles)
    assert @default_mentoring_model.can_manage_mm_goals?(roles[0])
    assert_false @default_mentoring_model.can_manage_mm_goals?(roles[1])
    @default_mentoring_model.allow_manage_mm_goals!(roles)
    assert @default_mentoring_model.can_manage_mm_goals?(roles)
    assert @default_mentoring_model.can_manage_mm_goals?(roles[0])
    assert @default_mentoring_model.can_manage_mm_goals?(roles[1])
    @default_mentoring_model.deny_manage_mm_goals!(roles[0])
    @default_mentoring_model.reload
    assert @default_mentoring_model.can_manage_mm_goals?(roles)
    assert_false @default_mentoring_model.can_manage_mm_goals?(roles[0])
    assert @default_mentoring_model.can_manage_mm_goals?(roles[1])
    @default_mentoring_model.deny_manage_mm_goals!(roles)
    @default_mentoring_model.reload
    assert_false @default_mentoring_model.can_manage_mm_goals?(roles)
    assert_false @default_mentoring_model.can_manage_mm_goals?(roles[0])
    assert_false @default_mentoring_model.can_manage_mm_goals?(roles[1])
    @default_mentoring_model.allow_manage_mm_goals!(roles)
  end

  def test_object_role_extensions_associations
    program = programs(:albers)
    assert_no_difference "ObjectRolePermission.count" do
      @default_mentoring_model.allow_manage_mm_meetings!(program.roles.with_name([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]))
    end

    assert_equal_unordered ["manage_mm_goals", "manage_mm_goals", "manage_mm_goals", "manage_mm_tasks", "manage_mm_tasks", "manage_mm_tasks", "manage_mm_messages", "manage_mm_meetings", "manage_mm_meetings", "manage_mm_engagement_surveys"], @default_mentoring_model.object_permissions.pluck(:name)
    assert_difference "ObjectRolePermission.count", -10 do
      @default_mentoring_model.destroy
    end
  end

  def test_has_many_goal_templates
    assert_equal 0, @default_mentoring_model.mentoring_model_goal_templates.count
    goal_template = @default_mentoring_model.mentoring_model_goal_templates.create!(title: "Hello4", description: "Hello4Desc")
    goal_template = @default_mentoring_model.mentoring_model_goal_templates.create!(title: "Hello2", description: "Hello2Desc")
    goal_template = @default_mentoring_model.mentoring_model_goal_templates.create!(title: "Hello3", description: "Hello3Desc")

    assert_equal 3, @default_mentoring_model.mentoring_model_goal_templates.count

    assert_difference "MentoringModel::GoalTemplate.count", -3 do
      @default_mentoring_model.destroy
    end
  end

  def test_has_many_milestone_templates
    create_mentoring_model_milestone_template
    create_mentoring_model_milestone_template

    assert_equal 2, @default_mentoring_model.mentoring_model_milestone_templates.size

    assert_difference "MentoringModel::MilestoneTemplate.count", -2 do
      @default_mentoring_model.destroy
    end
  end

  def test_has_many_groups
    assert @default_mentoring_model.groups.count.zero?
    mentoring_model = programs(:albers).default_mentoring_model

    Group::MentoringModelCloner.new(groups(:mygroup), programs(:albers), mentoring_model).copy_mentoring_model_objects
    Group::MentoringModelCloner.new(groups(:group_2), programs(:albers), mentoring_model).copy_mentoring_model_objects

    assert_equal [groups(:mygroup), groups(:group_2)], @default_mentoring_model.groups

    @default_mentoring_model.destroy
    assert_nil groups(:mygroup).reload.mentoring_model_id
    assert_nil groups(:group_2).reload.mentoring_model_id
  end

  def test_active_groups
    assert @default_mentoring_model.groups.count.zero?
    mentoring_model = programs(:albers).default_mentoring_model

    Group::MentoringModelCloner.new(groups(:mygroup), programs(:albers), mentoring_model).copy_mentoring_model_objects
    Group::MentoringModelCloner.new(groups(:group_2), programs(:albers), mentoring_model).copy_mentoring_model_objects

    assert_equal [groups(:mygroup), groups(:group_2)], @default_mentoring_model.groups.active
    assert_equal [groups(:mygroup), groups(:group_2)], @default_mentoring_model.active_groups

    groups(:group_2).terminate!(nil, "Watch Homeland", groups(:group_2).program.permitted_closure_reasons.first.id, Group::TerminationMode::EXPIRY)

    assert_equal [groups(:mygroup)], @default_mentoring_model.reload.active_groups
  end

  def test_only_one_default_mentoring_model
    program = programs(:albers)
    assert_equal @default_mentoring_model, program.default_mentoring_model
    assert_equal 1, program.mentoring_models.size

    assert_nothing_raised do
      create_mentoring_model
    end

    assert_nothing_raised do
      create_mentoring_model(title: "Carrie Mathison")
    end

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :default do
      create_mentoring_model(title: "Carrie Mathison1", default: true)
    end
  end

  def test_before_destroy
    drafted_groups = programs(:albers).groups.drafted
    default_mentoring_model = programs(:albers).default_mentoring_model
    mentoring_model1 = create_mentoring_model
    drafted_groups.each do |drafted_group|
      drafted_group.update_attributes!(mentoring_model_id: mentoring_model1.id)
    end

    other_groups = [groups(:mygroup), groups(:group_4)]
    other_groups.each do |group|
      group.update_attributes!(mentoring_model_id: mentoring_model1.id)
    end

    mentoring_model1.reload
    drafted_groups.collect(&:reload)

    assert_difference "MentoringModel.count", -1 do
      assert_no_difference "Group.count" do
        mentoring_model1.destroy
      end
    end

    drafted_groups.each do |group|
      assert_equal default_mentoring_model, group.reload.mentoring_model
    end

    other_groups.each do |group|
      assert_nil group.reload.mentoring_model
    end
  end

  def test_before_destroy_for_default_mentoring_models
    drafted_groups = programs(:albers).groups.drafted
    default_mentoring_model = programs(:albers).default_mentoring_model
    other_groups = [groups(:mygroup), groups(:group_4)]
    all_groups = drafted_groups + other_groups
    all_groups.each do |drafted_group|
      drafted_group.update_attributes!(mentoring_model_id: default_mentoring_model.id)
    end

    default_mentoring_model.reload
    all_groups.collect(&:reload)

    assert_difference "MentoringModel.count", -1 do
      assert_no_difference "Group.count" do
        default_mentoring_model.destroy
      end
    end

    all_groups.collect(&:reload)
    all_groups.each do |group|
      assert_nil group.mentoring_model
    end
  end

  def test_increment_version
    version = @default_mentoring_model.version
    @default_mentoring_model.increment_version
    assert_equal version + 1, @default_mentoring_model.version
  end

  def test_increment_version_and_trigger_sync
    @hybrid = create_mentoring_model(mentoring_model_type: MentoringModel::Type::HYBRID)
    @default_mentoring_model.parents = [@hybrid]
    template_version_increases_by_one_and_triggers_sync_once "@hybrid" do
      template_version_increases_by_one_and_triggers_sync_once "@default_mentoring_model" do
        @default_mentoring_model.increment_version_and_trigger_sync
      end
    end
  end

  def test_trigger_sync_if_should_not_sync
    @default_mentoring_model.program.groups.each{|g| g.update_attribute(:mentoring_model_id, @default_mentoring_model.id)}
    @default_mentoring_model.update_attributes!({should_sync: false, version: 10})
    Group.expects(:sync_with_template).times(0)
    MentoringModel.trigger_sync(@default_mentoring_model.id, I18n.locale)
  end

  def test_trigger_sync_if_should_sync
    @default_mentoring_model.program.groups.each{|g| g.update_attribute(:mentoring_model_id, @default_mentoring_model.id)}
    @default_mentoring_model.update_attributes!({should_sync: true, version: 10})
    @default_mentoring_model.reload.groups.reload
    @default_mentoring_model.groups.active.each do |group|
      Group.expects(:sync_with_template).with(group.id, I18n.locale).once
    end
    MentoringModel.trigger_sync(@default_mentoring_model.id, I18n.locale)
  end

  def test_has_ongoing_related_connections
    hybrid_mentoring_model = create_mentoring_model(mentoring_model_type: MentoringModel::Type::HYBRID, title: "a")
    base_mentoring_model = create_mentoring_model(mentoring_model_type: MentoringModel::Type::BASE, title: "b")
    temp_base_mentoring_model = create_mentoring_model(mentoring_model_type: MentoringModel::Type::BASE, title: "c")
    parent_hybrid_mentoring_model = create_mentoring_model(mentoring_model_type: MentoringModel::Type::HYBRID, title: "d")
    program = hybrid_mentoring_model.program
    temp_base_mentoring_model_group = create_group(mentor: program.mentor_users[2], student: program.student_users[2], mentoring_model_id: temp_base_mentoring_model.id)

    assert_false hybrid_mentoring_model.has_ongoing_related_connections?
    parent_hybrid_mentoring_model.children = [hybrid_mentoring_model]
    assert_false hybrid_mentoring_model.has_ongoing_related_connections?
    hybrid_mentoring_model.children = [base_mentoring_model]
    assert_false hybrid_mentoring_model.has_ongoing_related_connections?

    parent_hybrid_mentoring_model_group = create_group(mentor: program.mentor_users[3], student: program.student_users[3], mentoring_model_id: parent_hybrid_mentoring_model.id)
    assert hybrid_mentoring_model.reload.has_ongoing_related_connections?
    parent_hybrid_mentoring_model_group.destroy
    assert_false hybrid_mentoring_model.reload.has_ongoing_related_connections?

    hybrid_mentoring_model_group = create_group(mentor: program.mentor_users[0], student: program.student_users[0], mentoring_model_id: hybrid_mentoring_model.id)
    assert hybrid_mentoring_model.reload.has_ongoing_related_connections?
    hybrid_mentoring_model_group.destroy
    assert_false hybrid_mentoring_model.reload.has_ongoing_related_connections?

    base_mentoring_model_group = create_group(mentor: program.mentor_users[2], student: program.student_users[1], mentoring_model_id: base_mentoring_model.id)
    assert hybrid_mentoring_model.reload.has_ongoing_related_connections?
    base_mentoring_model_group.destroy
    assert_false hybrid_mentoring_model.reload.has_ongoing_related_connections?
  end

  def test_all_associated_group_ids
    hybrid_mentoring_model = create_mentoring_model(mentoring_model_type: MentoringModel::Type::HYBRID, title: "a")
    base_mentoring_model = create_mentoring_model(mentoring_model_type: MentoringModel::Type::BASE, title: "b")
    temp_base_mentoring_model = create_mentoring_model(mentoring_model_type: MentoringModel::Type::BASE, title: "c")
    parent_hybrid_mentoring_model = create_mentoring_model(mentoring_model_type: MentoringModel::Type::HYBRID, title: "d")
    parent_hybrid_mentoring_model.children = [hybrid_mentoring_model]
    hybrid_mentoring_model.children = [base_mentoring_model]
    program = hybrid_mentoring_model.program
    hybrid_mentoring_model_group = create_group(mentor: program.mentor_users[0], student: program.student_users[0], mentoring_model_id: hybrid_mentoring_model.id)
    base_mentoring_model_group = create_group(mentor: program.mentor_users[2], student: program.student_users[1], mentoring_model_id: base_mentoring_model.id)
    temp_base_mentoring_model_group = create_group(mentor: program.mentor_users[2], student: program.student_users[2], mentoring_model_id: temp_base_mentoring_model.id)
    parent_hybrid_mentoring_model_group = create_group(mentor: program.mentor_users[3], student: program.student_users[3], mentoring_model_id: parent_hybrid_mentoring_model.id)
    assert_equal_unordered [hybrid_mentoring_model_group.id, base_mentoring_model_group.id, parent_hybrid_mentoring_model_group.id], hybrid_mentoring_model.all_associated_group_ids
  end

  def test_hybrid_or_base
    template = create_mentoring_model
    template.update_attribute(:mentoring_model_type, MentoringModel::Type::BASE)
    assert template.reload.base?
    template.update_attribute(:mentoring_model_type, MentoringModel::Type::HYBRID)
    assert template.reload.hybrid?
  end

  def test_base_templates
    hybrid_mentoring_model = create_mentoring_model(mentoring_model_type: MentoringModel::Type::HYBRID, title: "a")
    base_mentoring_model_1 = create_mentoring_model(mentoring_model_type: MentoringModel::Type::BASE, title: "b")
    base_mentoring_model_2 = create_mentoring_model(mentoring_model_type: MentoringModel::Type::BASE, title: "c")
    hybrid_mentoring_model_extra = create_mentoring_model(mentoring_model_type: MentoringModel::Type::HYBRID, title: "d")
    hybrid_mentoring_model.child_ids = [base_mentoring_model_1.id, hybrid_mentoring_model_extra.id]
    hybrid_mentoring_model_extra.child_ids = [base_mentoring_model_2.id]
    assert_equal_unordered [base_mentoring_model_1, base_mentoring_model_2], hybrid_mentoring_model.base_templates
  end

  def test_descendants
    hybrid_mentoring_model = create_mentoring_model(mentoring_model_type: MentoringModel::Type::HYBRID, title: "a")
    base_mentoring_model_1 = create_mentoring_model(mentoring_model_type: MentoringModel::Type::BASE, title: "b")
    base_mentoring_model_2 = create_mentoring_model(mentoring_model_type: MentoringModel::Type::BASE, title: "c")
    hybrid_mentoring_model_extra = create_mentoring_model(mentoring_model_type: MentoringModel::Type::HYBRID, title: "d")
    hybrid_mentoring_model.child_ids = [base_mentoring_model_1.id, hybrid_mentoring_model_extra.id]
    hybrid_mentoring_model_extra.child_ids = [base_mentoring_model_2.id]
    assert_equal_unordered [base_mentoring_model_1, base_mentoring_model_2, hybrid_mentoring_model_extra], hybrid_mentoring_model.descendants
  end

  def test_other_templates_to_associate
    hybrid_mentoring_model = create_mentoring_model(mentoring_model_type: MentoringModel::Type::HYBRID, title: "a")
    base_mentoring_model_1 = create_mentoring_model(mentoring_model_type: MentoringModel::Type::BASE, title: "b")
    base_mentoring_model_2 = create_mentoring_model(mentoring_model_type: MentoringModel::Type::BASE, title: "c")
    assert_equal_unordered [base_mentoring_model_1, base_mentoring_model_2, @default_mentoring_model], @default_mentoring_model.other_templates_to_associate
  end

  def test_features_signature
    program = programs(:albers)
    roles = program.roles
    permission = ObjectPermission.where(name: "manage_mm_goals").first
    assert_equal "manage_mm_goals", permission.name
    @default_mentoring_model.deny_manage_mm_goals!(roles)
    assert_equal "0001110011", @default_mentoring_model.features_signature
    @default_mentoring_model.allow_manage_mm_goals!(roles)
    assert_equal "0011110111", @default_mentoring_model.features_signature
  end

  def test_update_permissions
    hybrid_mentoring_model = create_mentoring_model(mentoring_model_type: MentoringModel::Type::HYBRID, title: "a")
    base_mentoring_model_1 = create_mentoring_model(mentoring_model_type: MentoringModel::Type::BASE, title: "b")
    hybrid_mentoring_model.child_ids = [base_mentoring_model_1.id]
    program = programs(:albers)
    roles = program.roles
    permission = ObjectPermission.where(name: "manage_mm_goals").first
    assert_equal "manage_mm_goals", permission.name

    base_mentoring_model_1.allow_manage_mm_goals!(roles)
    hybrid_mentoring_model.update_permissions!
    hybrid_mentoring_model.reload
    assert_equal "0010000100", hybrid_mentoring_model.features_signature

    base_mentoring_model_1.deny_manage_mm_goals!(roles)
    hybrid_mentoring_model.update_permissions!
    hybrid_mentoring_model.reload
    assert_equal "0000000000", hybrid_mentoring_model.features_signature

    base_mentoring_model_1.update_attribute(:goal_progress_type, MentoringModel::GoalProgressType::MANUAL)
    base_mentoring_model_1.reload
    assert_equal "1000000000", base_mentoring_model_1.features_signature
  end

  def test_hybrid_mentoring_model_destroy_should_not_destroy_the_related_template_objects
    hybrid_mentoring_model = create_mentoring_model(mentoring_model_type: MentoringModel::Type::HYBRID, title: "h")
    base_mentoring_model = create_mentoring_model(mentoring_model_type: MentoringModel::Type::BASE, title: "b")

    assert_equal [], hybrid_mentoring_model.mentoring_model_task_templates
    assert_equal [], hybrid_mentoring_model.mentoring_model_goal_templates
    assert_equal [], hybrid_mentoring_model.mentoring_model_milestone_templates
    assert_equal [], hybrid_mentoring_model.mentoring_model_facilitation_templates
    assert_equal [], base_mentoring_model.mentoring_model_task_templates
    assert_equal [], base_mentoring_model.mentoring_model_goal_templates
    assert_equal [], base_mentoring_model.mentoring_model_milestone_templates
    assert_equal [], base_mentoring_model.mentoring_model_facilitation_templates

    goal_template = base_mentoring_model.mentoring_model_goal_templates.create!(title: "Hello4", description: "Hello4Desc")
    milestone_template = base_mentoring_model.mentoring_model_milestone_templates.create!(title: "Hello2", description: "Hello2Desc")
    task_template = create_mentoring_model_task_template(mentoring_model_id: base_mentoring_model.id)
    facilitation_template = create_mentoring_model_facilitation_template(mentoring_model_id: base_mentoring_model.id)
    facilitation_template_with_specific_date = create_mentoring_model_facilitation_template(mentoring_model_id: base_mentoring_model.id, specific_date: '2014-08-08', send_on: nil)
    assert_equal [], hybrid_mentoring_model.reload.mentoring_model_task_templates
    assert_equal [], hybrid_mentoring_model.reload.mentoring_model_goal_templates
    assert_equal [], hybrid_mentoring_model.reload.mentoring_model_milestone_templates
    assert_equal [], hybrid_mentoring_model.reload.mentoring_model_facilitation_templates
    assert_equal [task_template], base_mentoring_model.reload.mentoring_model_task_templates
    assert_equal [goal_template], base_mentoring_model.reload.mentoring_model_goal_templates
    assert_equal [milestone_template], base_mentoring_model.reload.mentoring_model_milestone_templates
    assert_equal [facilitation_template_with_specific_date, facilitation_template], base_mentoring_model.reload.mentoring_model_facilitation_templates
    hybrid_mentoring_model.children = [base_mentoring_model]
    assert_equal [task_template], hybrid_mentoring_model.reload.mentoring_model_task_templates
    assert_equal [goal_template], hybrid_mentoring_model.reload.mentoring_model_goal_templates
    assert_equal [milestone_template], hybrid_mentoring_model.reload.mentoring_model_milestone_templates
    assert_equal [facilitation_template_with_specific_date, facilitation_template], hybrid_mentoring_model.reload.mentoring_model_facilitation_templates

    assert_no_difference "MentoringModel::TaskTemplate.count" do
      assert_no_difference "MentoringModel::GoalTemplate.count" do
        assert_no_difference "MentoringModel::MilestoneTemplate.count" do
          assert_no_difference "MentoringModel::FacilitationTemplate.count" do
            hybrid_mentoring_model.destroy
          end
        end
      end
    end

    assert_difference "MentoringModel::TaskTemplate.count", -1 do
      assert_difference "MentoringModel::GoalTemplate.count", -1 do
        assert_difference "MentoringModel::MilestoneTemplate.count", -1 do
          assert_difference "MentoringModel::FacilitationTemplate.count", -2 do
            base_mentoring_model.destroy
          end
        end
      end
    end
  end

  def test_without_handle_hybrid_templates
    hybrid_mentoring_model = create_mentoring_model(mentoring_model_type: MentoringModel::Type::HYBRID, title: "h")
    base_mentoring_model = create_mentoring_model(mentoring_model_type: MentoringModel::Type::BASE, title: "b")
    goal_template = base_mentoring_model.mentoring_model_goal_templates.create!(title: "Hello4", description: "Hello4Desc")
    milestone_template = base_mentoring_model.mentoring_model_milestone_templates.create!(title: "Hello2", description: "Hello2Desc")
    task_template = create_mentoring_model_task_template(mentoring_model_id: base_mentoring_model.id)
    facilitation_template = create_mentoring_model_facilitation_template(mentoring_model_id: base_mentoring_model.id)
    facilitation_template_with_specific_date = create_mentoring_model_facilitation_template(mentoring_model_id: base_mentoring_model.id, specific_date: '2014-08-08', send_on: nil)
    assert_equal [], hybrid_mentoring_model.reload.mentoring_model_task_templates
    assert_equal [], hybrid_mentoring_model.reload.mentoring_model_goal_templates
    assert_equal [], hybrid_mentoring_model.reload.mentoring_model_milestone_templates
    assert_equal [], hybrid_mentoring_model.reload.mentoring_model_facilitation_templates
    assert_equal [task_template], base_mentoring_model.reload.mentoring_model_task_templates
    assert_equal [goal_template], base_mentoring_model.reload.mentoring_model_goal_templates
    assert_equal [milestone_template], base_mentoring_model.reload.mentoring_model_milestone_templates
    assert_equal [facilitation_template_with_specific_date, facilitation_template], base_mentoring_model.reload.mentoring_model_facilitation_templates
    hybrid_mentoring_model.children = [base_mentoring_model]
    assert_equal [task_template], hybrid_mentoring_model.reload.mentoring_model_task_templates
    assert_equal [goal_template], hybrid_mentoring_model.reload.mentoring_model_goal_templates
    assert_equal [milestone_template], hybrid_mentoring_model.reload.mentoring_model_milestone_templates
    assert_equal [facilitation_template_with_specific_date, facilitation_template], hybrid_mentoring_model.reload.mentoring_model_facilitation_templates
    assert_equal [], hybrid_mentoring_model.reload.mentoring_model_task_templates_without_handle_hybrid_templates
    assert_equal [], hybrid_mentoring_model.reload.mentoring_model_goal_templates_without_handle_hybrid_templates
    assert_equal [], hybrid_mentoring_model.reload.mentoring_model_milestone_templates_without_handle_hybrid_templates
    assert_equal [], hybrid_mentoring_model.reload.mentoring_model_facilitation_templates_without_handle_hybrid_templates
    assert_equal [task_template], base_mentoring_model.reload.mentoring_model_task_templates_without_handle_hybrid_templates
    assert_equal [goal_template], base_mentoring_model.reload.mentoring_model_goal_templates_without_handle_hybrid_templates
    assert_equal [milestone_template], base_mentoring_model.reload.mentoring_model_milestone_templates_without_handle_hybrid_templates
    assert_equal [facilitation_template_with_specific_date, facilitation_template], base_mentoring_model.reload.mentoring_model_facilitation_templates_without_handle_hybrid_templates
  end

  def test_translated_fields
    mm = create_mentoring_model(:title => "Carrie Mathison", program_id: programs(:albers).id)
    Globalize.with_locale(:en) do
      mm.title = "english title"
      mm.description = "english description"
      mm.save!
    end
    Globalize.with_locale(:"fr-CA") do
      mm.title = "french title"
      mm.description = "french description"
      mm.save!
    end
    Globalize.with_locale(:en) do
      assert_equal "english title", mm.title
      assert_equal "english description", mm.description
    end
    Globalize.with_locale(:"fr-CA") do
      assert_equal "french title", mm.title
      assert_equal "french description", mm.description
    end
  end

  def test_get_task_options_array
    mm = create_mentoring_model
    assert_equal [], mm.get_task_options_array
    tt1 = create_mentoring_model_task_template({mentoring_model_id: mm.id})
    assert_equal [{id: tt1.id, text: tt1.title, role: "Mentor"}], mm.reload.get_task_options_array
    tt2 = create_mentoring_model_task_template({mentoring_model_id: mm.id, role_id: programs(:albers).find_role(RoleConstants::STUDENT_NAME).id})
    assert_equal [{id: tt1.id, text: tt1.title, role: "Mentor"}, {id: tt2.id, text: tt2.title, role: "Student"}], mm.reload.get_task_options_array
    tt3 = create_mentoring_model_task_template({mentoring_model_id: mm.id, role_id: nil})
    assert_equal [{id: tt1.id, text: tt1.title, role: "Mentor"}, {id: tt2.id, text: tt2.title, role: "Student"}, {id: tt3.id, text: tt3.title, role: "Unassigned"}], mm.reload.get_task_options_array

    mmt1 = create_mentoring_model_milestone_template({mentoring_model_id: mm.id, title: "one"})
    mmt2 = create_mentoring_model_milestone_template({mentoring_model_id: mm.id, title: "two"})
    tt1.update_attributes(milestone_template_id: mmt1.id)
    tt2.update_attributes(milestone_template_id: mmt1.id)
    assert_equal_unordered [{text: "one", children: [{id: tt1.id, text: tt1.title, role: "Mentor"}, {id: tt2.id, text: tt2.title, role: "Student"}]}, {text: "Others", children: [{id: tt3.id, text: tt3.title, role: "Unassigned"}]}], mm.reload.get_task_options_array
    tt3.update_attributes(milestone_template_id: mmt2.id)
    assert_equal_unordered [{text: "one", children: [{id: tt1.id, text: tt1.title, role: "Mentor"}, {id: tt2.id, text: tt2.title, role: "Student"}]}, {text: "two", children: [{id: tt3.id, text: tt3.title, role: "Unassigned"}]}], mm.reload.get_task_options_array
  end

  def test_increment_positions_for_milestone_templates_with_or_after_position
    mentoring_model = programs(:albers).default_mentoring_model

    mt1 = create_mentoring_model_milestone_template({title: "Template1"})
    mt2 = create_mentoring_model_milestone_template({title: "Template2"})
    mt3 = create_mentoring_model_milestone_template({title: "Template3"})
    mt4 = create_mentoring_model_milestone_template({title: "Template4"})

    assert_equal [0, 1, 2, 3], mentoring_model.reload.mentoring_model_milestone_templates.pluck(:position)

    mentoring_model.increment_positions_for_milestone_templates_with_or_after_position(0)
    assert_equal [1, 2, 3, 4], mentoring_model.reload.mentoring_model_milestone_templates.pluck(:position)

    mentoring_model.increment_positions_for_milestone_templates_with_or_after_position(3)
    assert_equal [1, 2, 4, 5], mentoring_model.reload.mentoring_model_milestone_templates.pluck(:position)
  end

  def test_get_previous_and_next_position_milestone_template_ids
    mentoring_model = programs(:albers).default_mentoring_model

    mt1 = create_mentoring_model_milestone_template({title: "Template1"})
    mt2 = create_mentoring_model_milestone_template({title: "Template2"})
    mt3 = create_mentoring_model_milestone_template({title: "Template3"})
    mt4 = create_mentoring_model_milestone_template({title: "Template4"})

    prev_template_id, next_template_id =  mentoring_model.get_previous_and_next_position_milestone_template_ids(mt1.id)

    assert_nil prev_template_id
    assert_equal mt2.id, next_template_id

    prev_template_id, next_template_id =  mentoring_model.get_previous_and_next_position_milestone_template_ids(mt4.id)

    assert_equal mt3.id, prev_template_id
    assert_nil next_template_id

    prev_template_id, next_template_id =  mentoring_model.get_previous_and_next_position_milestone_template_ids(mt2.id)

    assert_equal mt1.id, prev_template_id
    assert_equal mt3.id, next_template_id
  end

  def test_mentoring_model_milestone_templates_association_ordering
    mentoring_model = programs(:albers).default_mentoring_model

    mt1 = create_mentoring_model_milestone_template({title: "Template1"})
    mt2 = create_mentoring_model_milestone_template({title: "Template2"})
    mt3 = create_mentoring_model_milestone_template({title: "Template3"})
    mt4 = create_mentoring_model_milestone_template({title: "Template4"})

    assert_equal ["Template1", "Template2", "Template3", "Template4"], mentoring_model.mentoring_model_milestone_templates.map(&:title)

    mt1.update_attribute(:position, 2)
    mt2.update_attribute(:position, 3)
    mt3.update_attribute(:position, 0)
    mt4.update_attribute(:position, 1)

    assert_equal ["Template3", "Template4", "Template1", "Template2"], mentoring_model.reload.mentoring_model_milestone_templates.map(&:title)
  end

  def test_impacts_group_forum
    program = programs(:pbe)
    group = groups(:group_pbe)
    mentoring_model = program.default_mentoring_model

    group.expects(:forum_enabled?).returns(false)
    assert_false mentoring_model.impacts_group_forum?(group)

    group.expects(:forum_enabled?).returns(true)
    mentoring_model.allow_forum = true
    assert_false mentoring_model.impacts_group_forum?(group)

    group.expects(:forum_enabled?).returns(true)
    mentoring_model.allow_forum = false
    assert_empty group.topics
    assert_false mentoring_model.impacts_group_forum?(group)

    group.stubs(:forum_enabled?).returns(true)
    mentoring_model.allow_forum = false
    create_topic(forum: group.forum, user: group.mentors.first)
    assert mentoring_model.impacts_group_forum?(group)
  end

  def test_impacts_group_messaging
    program = programs(:pbe)
    group = groups(:group_pbe)
    mentoring_model = program.default_mentoring_model

    group.expects(:scraps_enabled?).returns(false)
    assert_false mentoring_model.impacts_group_messaging?(group)

    group.expects(:scraps_enabled?).returns(true)
    mentoring_model.allow_messaging = true
    assert_false mentoring_model.impacts_group_messaging?(group)

    group.expects(:scraps_enabled?).returns(true)
    mentoring_model.allow_messaging = false
    assert_empty group.scraps
    assert_false mentoring_model.impacts_group_messaging?(group)

    group.stubs(:scraps_enabled?).returns(true)
    mentoring_model.allow_messaging = false
    create_scrap(group: group, sender: group.mentors.first.member)
    assert mentoring_model.impacts_group_messaging?(group)
  end

  def test_populate_default_forum_help_text
    program = programs(:albers)
    assert_equal 3, program.organization.enabled_organization_languages_including_english.size

    mentoring_model = program.mentoring_models.new(title: "MM", mentoring_period: Program::DEFAULT_MENTORING_PERIOD)
    assert_difference "MentoringModel::Translation.count", 3 do
      mentoring_model.populate_default_forum_help_text
      mentoring_model.save!
    end
    assert_equal "Welcome to the discussion board! Ask questions, debate ideas, and share articles. You can follow conversations you like, expand a conversation to view the posts, or get a new conversation started!", mentoring_model.forum_help_text
    assert mentoring_model.translations.all? { |translation| translation.forum_help_text.present? }
  end

  def test_can_disable_messaging_and_forum
    group = groups(:mygroup)
    program = group.program
    admin_user = program.admin_users.first
    mentoring_model = program.default_mentoring_model
    assert mentoring_model.can_disable_messaging?
    assert mentoring_model.can_disable_forum?

    group.update_attribute(:mentoring_model_id, mentoring_model.id)
    assert_false mentoring_model.can_disable_messaging?
    assert_false mentoring_model.can_disable_forum?

    group.status = Group::Status::PENDING
    assert_false mentoring_model.can_disable_messaging?
    assert_false mentoring_model.can_disable_forum?

    group.terminate!(admin_user, "Reason", program.permitted_closure_reasons.first.id)
    assert_false mentoring_model.can_disable_messaging?
    assert_false mentoring_model.can_disable_forum?

    group.status = Group::Status::DRAFTED
    group.created_by = admin_user
    group.save!
    assert mentoring_model.can_disable_messaging?
    assert mentoring_model.can_disable_forum?
  end

  def test_check_disabling_of_messaging
    mentoring_model = programs(:albers).default_mentoring_model
    assert mentoring_model.allow_messaging?

    mentoring_model.stubs(:can_disable_messaging?).returns(false)
    e = assert_raise ActiveRecord::RecordInvalid do
      mentoring_model.allow_messaging = false
      mentoring_model.save!
    end
    assert_equal "Validation failed: There are ongoing/closed mentoring connections using this mentoring connection template. Clone this template to create a new template or remove all the ongoing/closed mentoring connections to disable messages.", e.message
  end

  def test_es_reindex
    mentoring_model = MentoringModel.first
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, mentoring_model.group_ids)
    MentoringModel.es_reindex(mentoring_model)
  end

  def test_reindex_group
    mentoring_model = MentoringModel.first
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, mentoring_model.group_ids)
    MentoringModel.send(:reindex_group, mentoring_model.group_ids)
  end

  def test_check_disabling_of_forum
    mentoring_model = programs(:albers).default_mentoring_model
    mentoring_model.allow_messaging = false
    mentoring_model.allow_forum = true
    mentoring_model.save!

    mentoring_model.stubs(:can_disable_forum?).returns(false)
    e = assert_raise ActiveRecord::RecordInvalid do
      mentoring_model.allow_forum = false
      mentoring_model.save!
    end
    assert_equal "Validation failed: There are ongoing/closed mentoring connections using this mentoring connection template. Clone this template to create a new template or remove all the ongoing/closed mentoring connections to disable discussion boards.", e.message
  end

  def test_get_role_mapping
    roles = [1,2,3]
    role_mapping = { 1 => 2, 2 => 3, 3 => 4 }
    roles_mapping = { 1 => 1, 2 => 2, 3 => 3 }
    obj = MentoringModel.first
    obj.stubs(:roles).returns(roles)
    assert_equal role_mapping, obj.send(:get_role_mapping, obj, { roles: roles, role_mapping: role_mapping })
    assert_equal role_mapping, obj.send(:get_role_mapping, obj, role_mapping: role_mapping)
    assert_equal roles_mapping, obj.send(:get_role_mapping, obj, roles: roles)
    assert_equal roles_mapping, obj.send(:get_role_mapping, obj, {})
  end
end