require_relative './../../test_helper.rb'
require 'fileutils'

class MentoringModel::ClonerTest < ActiveSupport::TestCase
  IMPORT_CSV_FILE_NAME = "mentoring_model/mentoring_model_import.csv"
  IMPORT_TEMP_CSV_FILE_NAME = "mentoring_model/mentoring_model_import_temp.csv"

  TASK_GOALS_IMPORT_CSV_FILE_NAME = "mentoring_model/tasks_goals_import.csv"
  TASK_GOALS_IMPORT_TEMP_CSV_FILE_NAME = "mentoring_model/tasks_goals_import_temp.csv"

  IMPORT_CSV_FILE = "test/fixtures/files/#{IMPORT_CSV_FILE_NAME}"
  IMPORT_TEMP_CSV_FILE = "test/fixtures/files/#{IMPORT_TEMP_CSV_FILE_NAME}"
  EXPORT_CSV_FILE = "tmp/mentoring_model_export.csv"

  TASK_GOALS_IMPORT_CSV_FILE = "test/fixtures/files/#{TASK_GOALS_IMPORT_CSV_FILE_NAME}"
  TASK_GOALS_IMPORT_TEMP_CSV_FILE = "test/fixtures/files/#{TASK_GOALS_IMPORT_TEMP_CSV_FILE_NAME}"
  TASK_GOALS_EXPORT_CSV_FILE = "tmp/tasks_goals_export.csv"

  def setup
    super
    @mentoring_model = programs(:albers).default_mentoring_model
  end

  def test_set_mentoring_model
    attributes_to_update = {
      mentoring_period: 3.months.to_i,
      goal_progress_type: MentoringModel::GoalProgressType::MANUAL,
      allow_due_date_edit: true,
      allow_messaging: false,
      allow_forum: true,
      forum_help_text: "Forum Help Text"
    }
    assert @mentoring_model.default?
    @mentoring_model.update_attributes(attributes_to_update)

    new_mentoring_model = nil
    assert_difference "MentoringModel.count" do
      assert_no_difference "ObjectRolePermission.count" do
        new_mentoring_model = MentoringModel::Cloner.new(@mentoring_model, "House Of Cards").set_mentoring_model
      end
    end
    assert_equal "House Of Cards", new_mentoring_model.title
    assert_nil new_mentoring_model.description
    assert_false new_mentoring_model.default?
    assert_equal @mentoring_model.program, new_mentoring_model.program
    assert new_mentoring_model.object_role_permissions.empty?
    assert_equal attributes_to_update, new_mentoring_model.attributes.symbolize_keys.slice(*attributes_to_update.keys)
  end

  def test_clone_goal_templates
    rand_num = (rand()*10 + 1).to_i
    goal_template1 = create_mentoring_model_goal_template(mentoring_model_id: @mentoring_model.id, title: "Claire Underwood", description: "Frank Underwood")
    goal_template2 = create_mentoring_model_goal_template(mentoring_model_id: @mentoring_model.id, title: "Robin Wright", description: "Kevin Spacey")
    Globalize.with_locale(:en) do
      goal_template2.update_attributes(title: "english title", description: "english description")
    end
    Globalize.with_locale(:hi) do
      goal_template2.update_attributes(title: "hindi title", description: "hindi description")
    end

    cloner = MentoringModel::Cloner.new(@mentoring_model, "House Of Cards")
    cloner.set_mentoring_model

    assert_difference "MentoringModel::GoalTemplate.count", 2 do
      cloner.clone_goal_templates
    end

    new_mentoring_model = cloner.new_mentoring_model
    new_goal_templates = new_mentoring_model.mentoring_model_goal_templates
    @mentoring_model.reload.mentoring_model_goal_templates.each_with_index do |old_goal_template, index|
      assert new_goal_templates[index].title == old_goal_template.title
      assert new_goal_templates[index].description == old_goal_template.description
      assert new_goal_templates[index].mentoring_model == new_mentoring_model
    end
    assert_equal ({goal_template1.id => new_goal_templates[0], goal_template2.id => new_goal_templates[1]}), cloner.goal_template_mapper

    new_goal_template_with_translations = new_mentoring_model.mentoring_model_goal_templates.last
    Globalize.with_locale(:en) do
      assert_equal "english title", new_goal_template_with_translations.title
      assert_equal "english description", new_goal_template_with_translations.description
    end
    Globalize.with_locale(:hi) do
      assert_equal "hindi title", new_goal_template_with_translations.title
      assert_equal "hindi description", new_goal_template_with_translations.description
    end
  end

  def test_clone_linked_templates
    hybrid_mentoring_model = create_mentoring_model(mentoring_model_type: MentoringModel::Type::HYBRID, title: "h", allow_due_date_edit: true)
    base_mentoring_model = create_mentoring_model(mentoring_model_type: MentoringModel::Type::BASE, title: "b", allow_due_date_edit: false)
    hybrid_mentoring_model.children = [base_mentoring_model]
    cloned_mentoring_model = MentoringModel::Cloner.new(hybrid_mentoring_model, "test 1").clone_objects!
    assert_equal hybrid_mentoring_model.children, cloned_mentoring_model.children
  end

  def test_clone_permissions
    roles = programs(:albers).roles.group_by(&:name)
    user_roles = [roles[RoleConstants::MENTOR_NAME][0], roles[RoleConstants::STUDENT_NAME][0]]
    admin_roles = [roles[RoleConstants::ADMIN_NAME][0]]

    cloner = MentoringModel::Cloner.new(@mentoring_model, "House Of Cards")
    cloner.set_mentoring_model

    assert_difference "ObjectRolePermission.count", 10 do
      cloner.clone_permissions
    end
    new_mentoring_model = cloner.new_mentoring_model
    assert_equal_unordered ["manage_mm_goals", "manage_mm_goals", "manage_mm_goals", "manage_mm_tasks", "manage_mm_tasks", "manage_mm_tasks", "manage_mm_messages", "manage_mm_meetings", "manage_mm_meetings", "manage_mm_engagement_surveys"], new_mentoring_model.object_permissions.pluck(:name)

    @mentoring_model.object_role_permissions.joins(:object_permission).where(object_permissions: {name: "manage_mm_tasks"}).destroy_all
    assert_difference "ObjectRolePermission.count", -3 do
      @mentoring_model.reload
      cloner.clone_permissions
    end
    new_mentoring_model = cloner.new_mentoring_model
    new_mentoring_model.reload
    assert_false new_mentoring_model.can_manage_mm_tasks?(admin_roles)
    assert_false new_mentoring_model.can_manage_mm_tasks?(user_roles)
    assert_equal_unordered ["manage_mm_goals", "manage_mm_goals", "manage_mm_goals", "manage_mm_messages", "manage_mm_meetings", "manage_mm_meetings", "manage_mm_engagement_surveys"], new_mentoring_model.object_permissions.pluck(:name)

    @mentoring_model.object_role_permissions.where(role_id: user_roles.collect(&:id)).joins(:object_permission).where(object_permissions: {name: "manage_mm_goals"}).destroy_all
    assert_difference "ObjectRolePermission.count", -2 do
      @mentoring_model.reload
      cloner.clone_permissions
    end
    new_mentoring_model = cloner.new_mentoring_model
    new_mentoring_model.reload
    assert_equal_unordered ["manage_mm_goals", "manage_mm_messages", "manage_mm_meetings", "manage_mm_meetings","manage_mm_engagement_surveys"], new_mentoring_model.object_permissions.pluck(:name)
    assert new_mentoring_model.can_manage_mm_goals?(admin_roles)
    assert_false new_mentoring_model.can_manage_mm_goals?(user_roles)
  end

  def test_clone_milestone_templates
    milestone_template1 = create_mentoring_model_milestone_template(title: "Frank Underwood", description: "Claire Underwood", mentoring_model_id: @mentoring_model.id)
    milestone_template2 = create_mentoring_model_milestone_template(title: "House Of Cards", description: "Homeland", mentoring_model_id: @mentoring_model.id)

    Globalize.with_locale(:en) do
      milestone_template2.update_attributes(title: "english title", description: "english description")
    end
    Globalize.with_locale(:hi) do
      milestone_template2.update_attributes(title: "hindi title", description: "hindi description")
    end

    cloner = MentoringModel::Cloner.new(@mentoring_model, "Robin Wright")
    cloner.set_mentoring_model

    assert_difference "MentoringModel::MilestoneTemplate.count", 2 do
      cloner.clone_milestone_templates
    end

    new_mentoring_model = cloner.new_mentoring_model
    new_milestone_templates = new_mentoring_model.mentoring_model_milestone_templates
    @mentoring_model.mentoring_model_milestone_templates.each_with_index do |old_milestone_template, index|
      assert new_milestone_templates[index].title == old_milestone_template.title
      assert new_milestone_templates[index].description == old_milestone_template.description
      assert new_milestone_templates[index].mentoring_model == new_mentoring_model
    end
    assert_equal ({milestone_template1.id => new_milestone_templates[0], milestone_template2.id => new_milestone_templates[1]}), cloner.milestone_template_mapper

    new_milestone_template_with_translations = new_mentoring_model.mentoring_model_milestone_templates.last
    Globalize.with_locale(:en) do
      assert_equal "english title", new_milestone_template_with_translations.title
      assert_equal "english description", new_milestone_template_with_translations.description
    end
    Globalize.with_locale(:hi) do
      assert_equal "hindi title", new_milestone_template_with_translations.title
      assert_equal "hindi description", new_milestone_template_with_translations.description
    end
  end

  def test_clone_task_templates
    roles = programs(:albers).roles.group_by(&:name)
    current_time = Time.now.utc
    milestone_template1 = create_mentoring_model_milestone_template(title: "Frank Underwood", description: "Claire Underwood", mentoring_model_id: @mentoring_model.id)
    milestone_template2 = create_mentoring_model_milestone_template(title: "House Of Cards", description: "Homeland", mentoring_model_id: @mentoring_model.id)

    goal_template1 = create_mentoring_model_goal_template(mentoring_model_id: @mentoring_model.id, title: "Claire Underwood", description: "Frank Underwood")
    goal_template2 = create_mentoring_model_goal_template(mentoring_model_id: @mentoring_model.id, title: "Robin Wright", description: "Kevin Spacey")

    @mentoring_model.allow_manage_mm_milestones!(@mentoring_model.program.roles.with_name(RoleConstants::ADMIN_NAME))
    task_template1 = create_mentoring_model_task_template(mentoring_model_id: @mentoring_model.id, role_id: roles[RoleConstants::MENTOR_NAME][0].id, title: "Claire Underwood", description: "Frank Underwood", goal_template_id: goal_template2.id, milestone_template_id: milestone_template1.id)
    task_template2 = create_mentoring_model_task_template(mentoring_model_id: @mentoring_model.id, role_id: roles[RoleConstants::STUDENT_NAME][0].id, title: "House Of Cards", required: true, duration: 10, goal_template_id: goal_template1.id, milestone_template_id: milestone_template1.id, action_item_type: MentoringModel::TaskTemplate::ActionItem::MEETING)
    task_template3 = create_mentoring_model_task_template(mentoring_model_id: @mentoring_model.id, role_id: roles[RoleConstants::MENTOR_NAME][0].id, title: "Carrie Mathison", required: true, duration: 12, goal_template_id: goal_template2.id, milestone_template_id: milestone_template1.id, action_item_type: MentoringModel::TaskTemplate::ActionItem::GOAL, associated_id: task_template2.id)
    task_template4 = create_mentoring_model_task_template(mentoring_model_id: @mentoring_model.id, role_id: roles[RoleConstants::MENTOR_NAME][0].id, title: "Homeland", description: "Cerci", required: true, duration: 14, milestone_template_id: milestone_template2.id, action_item_type: MentoringModel::TaskTemplate::ActionItem::DEFAULT, associated_id: task_template3.id)
    task_template5 = create_mentoring_model_task_template(mentoring_model_id: @mentoring_model.id, role_id: roles[RoleConstants::STUDENT_NAME][0].id, title: "Claire Underwood Task", description: "Frank Underwood Description", milestone_template_id: milestone_template2.id, required: true, specific_date: current_time, associated_id: task_template3.id)
    Globalize.with_locale(:en) do
      task_template1.update_attributes(title: "english title", description: "english description")
    end
    Globalize.with_locale(:hi) do
      task_template1.update_attributes(title: "hindi title", description: "hindi description")
    end

    cloner = MentoringModel::Cloner.new(@mentoring_model, "Robin Wright")
    cloner.set_mentoring_model
    cloner.clone_permissions
    cloner.clone_goal_templates
    cloner.clone_milestone_templates

    assert_difference "MentoringModel::TaskTemplate.count", 5 do
      cloner.clone_task_templates
    end
    new_mentoring_model = cloner.new_mentoring_model
    task_templates = @mentoring_model.mentoring_model_task_templates
    new_task_templates = new_mentoring_model.mentoring_model_task_templates
    new_goal_templates = new_mentoring_model.mentoring_model_goal_templates
    new_milestone_templates = new_mentoring_model.mentoring_model_milestone_templates

    task_templates.each_with_index do |task_template, index|
      new_task_template = new_task_templates[index]
      assert new_task_template.title == task_template.title
      assert new_task_template.description == task_template.description
      assert new_task_template.duration == task_template.duration
      assert new_task_template.action_item_type == task_template.action_item_type
      assert new_task_template.action_item_id == task_template.action_item_id
      assert new_task_template.position == task_template.position
      assert new_task_template.role_id == task_template.role_id
      assert(task_template.required? ? new_task_template.required? : !new_task_template.required?)
    end

    assert_equal new_milestone_templates[0].id, new_task_templates[0].milestone_template_id
    assert_equal new_milestone_templates[0].id, new_task_templates[1].milestone_template_id
    assert_equal new_milestone_templates[0].id, new_task_templates[2].milestone_template_id
    assert_equal new_milestone_templates[1].id, new_task_templates[3].milestone_template_id

    assert_equal new_goal_templates[1].id, new_task_templates[0].goal_template_id
    assert_equal new_goal_templates[0].id, new_task_templates[1].goal_template_id
    assert_equal new_goal_templates[1].id, new_task_templates[2].goal_template_id
    assert_nil new_task_templates[3].goal_template_id

    assert_nil new_task_templates[0].associated_id
    assert_nil new_task_templates[1].associated_id
    assert_equal new_task_templates[1].id, new_task_templates[2].associated_id
    assert_equal new_task_templates[2].id, new_task_templates[3].associated_id
    assert_equal current_time.strftime("%B %d, %Y"), new_task_templates[3].specific_date.strftime("%B %d, %Y")

    new_task_template_with_translations = new_mentoring_model.mentoring_model_task_templates.first
    Globalize.with_locale(:en) do
      assert_equal "english title", new_task_template_with_translations.title
      assert_equal "english description", new_task_template_with_translations.description
    end
    Globalize.with_locale(:hi) do
      assert_equal "hindi title", new_task_template_with_translations.title
      assert_equal "hindi description", new_task_template_with_translations.description
    end
  end

  def test_clone_facilitation_templates
    current_time = Time.now.utc
    roles = programs(:albers).roles.group_by(&:name)
    milestone_template1 = create_mentoring_model_milestone_template(title: "Frank Underwood", description: "Claire Underwood", mentoring_model_id: @mentoring_model.id)
    milestone_template2 = create_mentoring_model_milestone_template(title: "House Of Cards", description: "Homeland", mentoring_model_id: @mentoring_model.id)

    facilitation_template1 = create_mentoring_model_facilitation_template(mentoring_model_id: @mentoring_model.id, roles: [roles[RoleConstants::MENTOR_NAME][0], roles[RoleConstants::STUDENT_NAME][0]], send_on: 15, subject: "Claire Underwood", message: "Frank Underwood", milestone_template_id: milestone_template1.id)
    facilitation_template2 = create_mentoring_model_facilitation_template(mentoring_model_id: @mentoring_model.id, roles: [roles[RoleConstants::MENTOR_NAME][0]], send_on: 20, subject: "Robin Wright", message: "Kevin Spacey", milestone_template_id: milestone_template2.id)
    facilitation_template3 = create_mentoring_model_facilitation_template(mentoring_model_id: @mentoring_model.id, roles: [roles[RoleConstants::MENTOR_NAME][0]], specific_date: current_time, send_on: nil, subject: "Robin Wright", message: "Kevin Spacey", milestone_template_id: milestone_template2.id)

    ft_last = @mentoring_model.mentoring_model_facilitation_templates.last
    Globalize.with_locale(:en) do
      ft_last.update_attributes(subject: "english subject", message: "english message")
    end
    Globalize.with_locale(:hi) do
      ft_last.update_attributes(subject: "hindi subject", message: "hindi message")
    end

    cloner = MentoringModel::Cloner.new(@mentoring_model, "House Of Cards")
    cloner.set_mentoring_model
    cloner.clone_permissions
    cloner.clone_goal_templates
    cloner.clone_milestone_templates

    assert_difference "MentoringModel::FacilitationTemplate.count", 3 do
      cloner.clone_facilitation_templates
    end

    new_mentoring_model = cloner.new_mentoring_model
    new_facilitation_templates = new_mentoring_model.mentoring_model_facilitation_templates
    new_milestone_templates = new_mentoring_model.mentoring_model_milestone_templates
    @mentoring_model.mentoring_model_facilitation_templates.each_with_index do |facilitation_template, index|
      assert new_facilitation_templates[index].subject == facilitation_template.subject
      assert new_facilitation_templates[index].message == facilitation_template.message
      assert new_facilitation_templates[index].send_on == facilitation_template.send_on
    end

    assert_equal facilitation_template1.roles, new_facilitation_templates[1].roles
    assert_equal facilitation_template2.roles, new_facilitation_templates[2].roles
    assert_equal facilitation_template3.roles, new_facilitation_templates[0].roles
    assert_equal new_milestone_templates[0], new_facilitation_templates[1].milestone_template
    assert_equal new_milestone_templates[1], new_facilitation_templates[2].milestone_template
    assert_equal new_milestone_templates[1], new_facilitation_templates[0].milestone_template
    assert_equal current_time.strftime("%B %d, %Y"), new_facilitation_templates[0].specific_date.strftime("%B %d, %Y")

    new_facilitation_template_with_translations = new_mentoring_model.mentoring_model_facilitation_templates.last
    Globalize.with_locale(:en) do
      assert_equal "english subject", new_facilitation_template_with_translations.subject
      assert_equal "english message", new_facilitation_template_with_translations.message
    end
    Globalize.with_locale(:hi) do
      assert_equal "hindi subject", new_facilitation_template_with_translations.subject
      assert_equal "hindi message", new_facilitation_template_with_translations.message
    end
  end

  def test_clone_objects
    assert import(@mentoring_model, IMPORT_CSV_FILE_NAME)
    export(@mentoring_model, IMPORT_TEMP_CSV_FILE)

    new_mentoring_model = MentoringModel::Cloner.new(@mentoring_model, "House Of Cards").clone_objects!
    export(new_mentoring_model, EXPORT_CSV_FILE)
    assert FileUtils.compare_file(IMPORT_TEMP_CSV_FILE, EXPORT_CSV_FILE)

    @mentoring_model.object_role_permissions.destroy_all
    assert import(@mentoring_model, TASK_GOALS_IMPORT_CSV_FILE_NAME)
    export(@mentoring_model, TASK_GOALS_IMPORT_TEMP_CSV_FILE)

    new_mentoring_model = MentoringModel::Cloner.new(@mentoring_model, "Homeland").clone_objects!
    export(new_mentoring_model, TASK_GOALS_EXPORT_CSV_FILE)
    assert FileUtils.compare_file(TASK_GOALS_IMPORT_TEMP_CSV_FILE, TASK_GOALS_EXPORT_CSV_FILE)
  end

  def test_cloning_across_programs
    assert import(@mentoring_model, IMPORT_CSV_FILE_NAME)
    export(@mentoring_model, IMPORT_TEMP_CSV_FILE)

    target_program = programs(:nwen)
    source_program = programs(:albers)
    survey_id_mapping = {}
    role_mapping = {}
    source_program.roles.for_mentoring_models.each do |source_role|
      role_mapping[source_role] = target_program.roles.find_by(name: source_role.name)
    end
    @mentoring_model.mentoring_model_task_templates.where(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY).each do |tsk_template|
      survey_id_mapping[tsk_template.action_item_id] = target_program.surveys.find{ |target_prg| target_prg.name == source_program.surveys.find(tsk_template.action_item_id).name }.id
    end

    task_template = @mentoring_model.mentoring_model_task_templates.first
    facilitation_template = mock()
    facilitation_template.stubs(:roles).returns(role_mapping.keys)
    cloner = MentoringModel::Cloner.new(@mentoring_model, "House Of Cards")
    new_mentoring_model = MentoringModel.where.not(id: @mentoring_model.id).first
    cloner.instance_variable_set(:@new_mentoring_model, new_mentoring_model)
    assert_empty cloner.send(:get_options)
    assert_false cloner.send(:cloning_across_programs?)
    assert_equal [task_template.role_id, task_template.action_item_id], cloner.send(:get_role_and_action_item_ids, task_template)
    assert_equal role_mapping.keys, cloner.send(:get_roles, facilitation_template)
    permissions = ObjectPermission::MentoringModel::PERMISSIONS
    permissions[0..2].each do  |permission|
      role_mapping.each do |role, target_role|
        MentoringModel.any_instance.stubs("can_#{permission}?").with(role).returns(false)
        MentoringModel.any_instance.expects("deny_#{permission}!").with(role)
        MentoringModel.any_instance.expects("deny_#{permission}!").with(target_role)
      end
    end
    permissions[3..permissions.length].each do |permission|
      role_mapping.each do |role, target_role|
        MentoringModel.any_instance.stubs("can_#{permission}?").with(role).returns(true)
        MentoringModel.any_instance.expects("allow_#{permission}!").with(role)
        MentoringModel.any_instance.expects("allow_#{permission}!").with(target_role)
      end
    end
    cloner.clone_permissions

    cloner = MentoringModel::Cloner.new(@mentoring_model, "House Of Cards", target_program)
    cloner.instance_variable_set(:@new_mentoring_model, new_mentoring_model)
    assert cloner.send(:cloning_across_programs?)
    options = cloner.send(:get_options)
    assert_nil options[:mentornig_model_children]
    assert_equal survey_id_mapping, options[:survey_id_mapping]
    assert_equal role_mapping, options[:role_mapping]

    task_template = @mentoring_model.mentoring_model_task_templates.where.not(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY).first
    assert_equal [role_mapping[task_template.role].id, task_template.action_item_id], cloner.send(:get_role_and_action_item_ids, task_template)
    task_template = @mentoring_model.mentoring_model_task_templates.where(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY).first
    assert_equal [role_mapping[task_template.role].id, survey_id_mapping[task_template.action_item_id]], cloner.send(:get_role_and_action_item_ids, task_template)
    assert_equal_unordered role_mapping.values, cloner.send(:get_roles, facilitation_template)
    new_mentoring_model = MentoringModel::Cloner.new(@mentoring_model, "House Of Cards", target_program).clone_objects!
    assert_equal target_program, new_mentoring_model.program
    assert_equal_unordered survey_id_mapping.values, new_mentoring_model.mentoring_model_task_templates.where(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY).pluck(:action_item_id).uniq
    assert_empty new_mentoring_model.mentoring_model_task_templates.collect(&:role_id).compact.uniq - role_mapping.values.collect(&:id)

    MentoringModel.any_instance.stubs(:children).returns([target_program.mentoring_models.first])
    MentoringModel.any_instance.stubs(:hybrid?).returns(true)
    cloner = MentoringModel::Cloner.new(@mentoring_model, "House Of Cards", target_program)
    new_mentoring_model = mock()
    assert_equal [target_program.mentoring_models.first], cloner.send(:get_children)
    cloner.instance_variable_set(:@new_mentoring_model, new_mentoring_model)
    new_mentoring_model.expects("children=").with([target_program.mentoring_models.first]).twice
    cloner.clone_linked_templates
    cloner.instance_variable_set(:@options, {})
    cloner.clone_linked_templates
  end

  private

  def import(mentoring_model, filename)
    stream = fixture_file_upload(File.join('files', filename), 'text/csv')
    importer = MentoringModel::Importer.new(mentoring_model, stream)
    importer.import.successful?
  end

  def export(mentoring_model, file)
    exporter = MentoringModel::Exporter.new
    exporter.export(mentoring_model, file)
  end

end