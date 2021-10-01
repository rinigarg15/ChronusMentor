require_relative './../../test_helper.rb'

class Group::MentoringModelClonerTest < ActiveSupport::TestCase
  def setup
    super
    @group = groups(:mygroup)
    @program = programs(:albers)
    @mentoring_model = @program.default_mentoring_model
  end

  def test_copy_permissions
    @admin_role = @program.roles.find_by!(name: RoleConstants::ADMIN_NAME)
    @mentoring_model_cloner = Group::MentoringModelCloner.new(@group, @program, @mentoring_model)
    assert @group.object_role_permissions.empty?
    assert_false @group.can_manage_mm_goals?(@admin_role)
    assert_false @group.can_manage_mm_tasks?(@admin_role)
    assert_false @group.can_manage_mm_milestones?(@admin_role)

    assert_difference "ObjectRolePermission.count", 10 do
      @mentoring_model_cloner.copy_permissions
    end

    assert_equal_unordered ["manage_mm_goals", "manage_mm_goals", "manage_mm_goals", "manage_mm_tasks", "manage_mm_tasks", "manage_mm_tasks", "manage_mm_messages", "manage_mm_meetings", "manage_mm_meetings", "manage_mm_engagement_surveys"], @group.object_permissions.pluck(:name)

    assert @group.reload.can_manage_mm_tasks?(@admin_role)
    assert @group.can_manage_mm_goals?(@admin_role)
    assert_false @group.can_manage_mm_milestones?(@admin_role)

    assert_difference "ObjectRolePermission.count", -2 do
      @mentoring_model.deny_manage_mm_goals!(@admin_role)
      @mentoring_model.deny_manage_mm_messages!(@admin_role)
    end

    @group.object_role_permissions.destroy_all

    @mentoring_model.reload
    @group.reload

    assert_difference "ObjectRolePermission.count", 8 do
      @mentoring_model_cloner.copy_permissions
    end

    assert_false @group.can_manage_mm_goals?(@admin_role)
    assert_false @group.can_manage_mm_messages?(@admin_role)
    assert @group.can_manage_mm_tasks?(@admin_role)
  end

  def test_set_mentoring_model
    @mentoring_model_cloner = Group::MentoringModelCloner.new(@group, @program, @mentoring_model)
    @mentoring_model_cloner.set_mentoring_model!

    assert_equal @group.mentoring_model_id, @mentoring_model.id

    @mentoring_model1 = create_mentoring_model(mentoring_period: 1.day)
    time_traveller(4.days.from_now.beginning_of_day + 1.hour) do
      @mentoring_model_cloner = Group::MentoringModelCloner.new(@group, @program, @mentoring_model1)
      @mentoring_model_cloner.set_mentoring_model!
    end

    assert_equal @group.mentoring_model_id, @mentoring_model1.id
    assert_equal @group.expiry_time.to_s, (5.days.from_now.beginning_of_day).end_of_day.to_s
  end

  def test_cannot_copy_task_templates_when_deny_permission
    @admin_role = @program.roles.find_by!(name: RoleConstants::ADMIN_NAME)
    @mentoring_model_cloner = Group::MentoringModelCloner.new(@group, @program, @mentoring_model)

    @mentoring_model.deny_manage_mm_tasks!(@admin_role)

    t1 = create_mentoring_model_task_template(title: "Awesome Title 1")
    t2 = create_mentoring_model_task_template(title: "Awesome Title 2")

    assert_no_difference "MentoringModel::Task.count" do
      @mentoring_model_cloner.copy_task_templates
    end

    @mentoring_model.allow_manage_mm_tasks!(@admin_role)

    assert_difference "MentoringModel::Task.count", 2 do
      @mentoring_model_cloner.copy_task_templates
    end
  end

  def test_copy_task_attributes_and_positions_due_dates
    @mentoring_model_cloner = Group::MentoringModelCloner.new(@group, @program, @mentoring_model)
    mentor_role = @program.get_roles(RoleConstants::MENTOR_NAME).first
    mentee_role = @program.get_roles(RoleConstants::STUDENT_NAME).first

    Timecop.freeze(Time.new(2000)) do
      # create some task templates
      t1 = create_mentoring_model_task_template(duration: 2, required: true, role_id: mentee_role.id, title: "Sample1")
      t2 = create_mentoring_model_task_template(duration: 4, required: true, role_id: mentor_role.id, title: "Sample 2")
      t3 = create_mentoring_model_task_template(duration: 1, required: true, associated_id: t1.id, role_id: mentee_role.id, title: "Sample 3")
      t4 = create_mentoring_model_task_template(duration: 1, required: true, associated_id: t1.id, title: "Non Role")
      MentoringModel::TaskTemplate.compute_due_dates([t1, t2, t3, t4])
      @mentoring_model.reload

      assert_difference "MentoringModel::Task.count", 4 do
        @mentoring_model_cloner.copy_task_templates
      end

      mentoring_model_tasks = @group.reload.mentoring_model_tasks
      attributes_to_check = ["required", "title", "description", "position", "action_item_type", "action_item_id"]
      assert_equal [t1, t3, t4, t2].map{|t| t.attributes.pick(*attributes_to_check)}, mentoring_model_tasks.map{|t| t.attributes.pick(*attributes_to_check)}
      assert_equal @group.published_at + 2.days, mentoring_model_tasks[0].due_date
      assert_equal @group.published_at + 3.days, mentoring_model_tasks[1].due_date
      assert_equal @group.published_at + 3.days, mentoring_model_tasks[2].due_date
      assert_equal @group.published_at + 4.days, mentoring_model_tasks[3].due_date
      assert_equal t1.id, mentoring_model_tasks[0].mentoring_model_task_template_id
      assert_equal t3.id, mentoring_model_tasks[1].mentoring_model_task_template_id
      assert_equal t4.id, mentoring_model_tasks[2].mentoring_model_task_template_id
      assert_equal t2.id, mentoring_model_tasks[3].mentoring_model_task_template_id
    end
  end

  def test_copy_mentoring_model_objects
    @mentoring_model_cloner = Group::MentoringModelCloner.new(@group, @program, @mentoring_model)

    t1 = create_mentoring_model_task_template(title: "Awesome Title 1")
    t2 = create_mentoring_model_task_template(title: "Awesome Title 2")
    Globalize.with_locale(:en) do
      t2.update_attributes(title: "english title", description: "english description")
    end
    Globalize.with_locale(:"hi") do
      t2.update_attributes(title: "hindi title", description: "hindi description")
    end

    run_in_another_locale(:"fr-CA") do
      assert_difference "ObjectRolePermission.count", 10  do
        assert_difference "MentoringModel::Task.count", 2 do
          @mentoring_model_cloner.copy_mentoring_model_objects
        end
      end
    end

    assert_equal @group.mentoring_model_id, @mentoring_model.id
    assert_equal_unordered ["manage_mm_goals", "manage_mm_goals", "manage_mm_goals", "manage_mm_tasks", "manage_mm_tasks", "manage_mm_tasks", "manage_mm_messages", "manage_mm_meetings", "manage_mm_meetings", "manage_mm_engagement_surveys"], @group.object_permissions.pluck(:name)

    new_task = MentoringModel::Task.last
    Globalize.with_locale(:en) do
      assert_equal "english title", new_task.title
      assert_equal "english description", new_task.description
    end
    Globalize.with_locale(:hi) do
      assert_equal "hindi title", new_task.title
      assert_equal "hindi description", new_task.description
    end
  end

  def test_copy_mentoring_model_objects_in_other_locale
    t1 = create_mentoring_model_task_template(title: "Awesome Title t1")
    g1 = create_mentoring_model_goal_template(title: "Awesome Title g1")
    m1 = create_mentoring_model_milestone_template(title: "Awesome Title m1")
    assert_equal 1, t1.translations.count
    assert_equal 1, g1.translations.count
    assert_equal 1, m1.translations.count

    @mentoring_model.send("allow_#{ObjectPermission::MentoringModel::MILESTONE}!", [@program.roles.find_by(name: RoleConstants::ADMIN_NAME)])
    @mentoring_model_cloner = Group::MentoringModelCloner.new(@group, @program, @mentoring_model.reload)

    run_in_another_locale(:"fr-CA") do
      assert_difference "MentoringModel::Task.count" do
        assert_difference "MentoringModel::Goal.count" do
          assert_difference "MentoringModel::Milestone.count" do
            @mentoring_model_cloner.copy_mentoring_model_objects
          end
        end
      end
    end
    assert_equal @group.mentoring_model_id, @mentoring_model.id
    assert_equal_unordered ["en"], MentoringModel::Task.last.translations.pluck(:locale)
    assert_equal_unordered ["en"], MentoringModel::Goal.last.translations.pluck(:locale)
    assert_equal_unordered ["en"], MentoringModel::Milestone.last.translations.pluck(:locale)
    assert_equal_unordered @mentoring_model.mentoring_model_milestone_templates.pluck(:position), @group.mentoring_model_milestones.pluck(:position)
  end

  def test_copy_mentoring_model_objects_with_custom_roles
    @mentoring_model_cloner = Group::MentoringModelCloner.new(@group, @program, @mentoring_model)
    teacher_role = create_role(name: "teacher", program: @program, for_mentoring: true)
    custom_task_template = create_mentoring_model_task_template(title: "Awesome Title 1", role_id: teacher_role.id)

    t1 = create_mentoring_model_task_template(title: "Awesome Title 1")
    t2 = create_mentoring_model_task_template(title: "Awesome Title 2")

    run_in_another_locale(:"fr-CA") do
      assert_difference "ObjectRolePermission.count", 10  do
        assert_difference "MentoringModel::Task.count", 2 do
          @mentoring_model_cloner.copy_mentoring_model_objects
        end
      end
    end
    assert_equal @group.mentoring_model_id, @mentoring_model.id
    assert_equal_unordered ["manage_mm_goals", "manage_mm_goals", "manage_mm_goals", "manage_mm_tasks", "manage_mm_tasks", "manage_mm_tasks", "manage_mm_messages", "manage_mm_meetings", "manage_mm_meetings", "manage_mm_engagement_surveys"], @group.object_permissions.pluck(:name)
  end

  def test_copy_goal_templates
    @mentoring_model_cloner = Group::MentoringModelCloner.new(@group, @program, @mentoring_model)

    gt1 = create_mentoring_model_goal_template
    tt1 = create_mentoring_model_task_template(title: "Awesome Title 1", goal_template_id: gt1.id)
    Globalize.with_locale(:en) do
      gt1.update_attributes(title: "english title", description: "english description")
    end
    Globalize.with_locale(:"hi") do
      gt1.update_attributes(title: "hindi title", description: "hindi description")
    end

    run_in_another_locale(:"fr-CA") do
      assert_difference "MentoringModel::Goal.count" do
        assert_difference "MentoringModel::Task.count" do
          @mentoring_model_cloner.copy_mentoring_model_objects
        end
      end
    end

    g1 = MentoringModel::Goal.last
    assert_equal gt1.id, g1.mentoring_model_goal_template_id
    Globalize.with_locale(:en) do
      assert_equal "english title", gt1.title
      assert_equal "english description", gt1.description
    end
    Globalize.with_locale(:hi) do
      assert_equal "hindi title", gt1.title
      assert_equal "hindi description", gt1.description
    end

    t1 = MentoringModel::Task.last
    assert_equal t1.mentoring_model_goal, g1
  end

  def test_copy_milestone_templates
    @mentoring_model_cloner = Group::MentoringModelCloner.new(@group, @program, @mentoring_model)
    @mentoring_model.allow_manage_mm_milestones!(@program.roles.for_mentoring_models)

    milestone_template1 = create_mentoring_model_milestone_template
    Globalize.with_locale(:en) do
      milestone_template1.update_attributes(title: "english title", description: "english description")
    end
    Globalize.with_locale(:hi) do
      milestone_template1.update_attributes(title: "hindi title", description: "hindi description")
    end

    task_template1 = create_mentoring_model_task_template(title: "Claire Danes 1", milestone_template_id: milestone_template1.id)
    task_template2 = create_mentoring_model_task_template(title: "Claire Danes 2", milestone_template_id: milestone_template1.id, required: true, duration: 3)
    milestone_template2 = create_mentoring_model_milestone_template
    task_template3 = create_mentoring_model_task_template(title: "Carrie Mathison 1", milestone_template_id: milestone_template2.id, required: true, duration: 5, associated_id: task_template2.id)
    task_template4 = create_mentoring_model_task_template(title: "Carrie Mathison 2", milestone_template_id: milestone_template2.id, required: true, duration: 3, associated_id: task_template2.id)
    all_task_templates = MentoringModel::TaskTemplate.compute_due_dates([task_template1, task_template2, task_template3, task_template4], skip_positions: true)
    MentoringModel::TaskTemplate.update_due_positions(all_task_templates.select{|task_template| task_template.milestone_template_id == milestone_template1.id })
    MentoringModel::TaskTemplate.update_due_positions(all_task_templates.select{|task_template| task_template.milestone_template_id == milestone_template2.id })

    run_in_another_locale(:"fr-CA") do
      assert_difference "MentoringModel::Milestone.count", 2 do
        assert_difference "MentoringModel::Task.count", 4 do
          @mentoring_model_cloner.copy_mentoring_model_objects
        end
      end
    end

    all_milestones = @group.mentoring_model_milestones
    all_tasks = @group.mentoring_model_tasks

    assert_equal ["Claire Danes 2", "Claire Danes 1"], all_milestones[0].mentoring_model_tasks.map(&:title)
    assert_equal ["Carrie Mathison 2", "Carrie Mathison 1"], all_milestones[1].mentoring_model_tasks.map(&:title)

    assert_equal [all_milestones[0], all_milestones[0], all_milestones[1], all_milestones[1]],  all_tasks.map(&:milestone)

    assert_equal [true] * 2, all_milestones.map(&:from_template)
    assert_equal 3, all_milestones[0].template_version
    assert_equal 1, all_milestones[1].template_version
    assert_equal [milestone_template1.id, milestone_template2.id], all_milestones.collect(&:mentoring_model_milestone_template_id)
    assert_equal [true] * 4, all_tasks.map(&:from_template)
    all_tasks.each { |task| assert task.template_version.present? }

    assert_equal_unordered [0, 1, 0, 1], all_tasks.map(&:position)
    Globalize.with_locale(:en) do
      assert_equal "english title", all_milestones[0].title
      assert_equal "english description", all_milestones[0].description
    end
    Globalize.with_locale(:hi) do
      assert_equal "hindi title", all_milestones[0].title
      assert_equal "hindi description", all_milestones[0].description
    end
  end

  def test_goal_id_not_copied_in_manual_goals
    new_mentoring_model = create_mentoring_model(mentoring_period: 2.months)
    new_mentoring_model.update_attribute(:should_sync, false)
    new_mentoring_model.update_attribute(:goal_progress_type, MentoringModel::GoalProgressType::MANUAL)
    @group.mentoring_model = new_mentoring_model
    @group.save!
    roles_hash = @program.roles.for_mentoring_models.group_by(&:name)
    @mentoring_model_cloner = Group::MentoringModelCloner.new(@group, @program, new_mentoring_model)
    gt1 = create_mentoring_model_goal_template(:mentoring_model_id => new_mentoring_model.id)
    new_mentoring_model.allow_manage_mm_milestones!([roles_hash[RoleConstants::ADMIN_NAME].first])
    new_mentoring_model.allow_manage_mm_tasks!([roles_hash[RoleConstants::ADMIN_NAME].first, roles_hash[RoleConstants::STUDENT_NAME].first])
    new_mentoring_model.allow_manage_mm_goals!([roles_hash[RoleConstants::ADMIN_NAME].first, roles_hash[RoleConstants::STUDENT_NAME].first])
    milestone_template = create_mentoring_model_milestone_template

    old_t1 = create_mentoring_model_task_template(title: "Awesome Title 1")
    old_t2 = create_mentoring_model_task_template(title: "Awesome Title 2")

    new_t1 = create_mentoring_model_task_template(title: "House Of Cards", mentoring_model_id: new_mentoring_model.id, goal_template_id: gt1, milestone_template_id: milestone_template.id)
    new_t2 = create_mentoring_model_task_template(title: "Claire Underwood", mentoring_model_id: new_mentoring_model.id, goal_template_id: gt1, milestone_template_id: milestone_template.id)
    new_t3 = create_mentoring_model_task_template(title: "Frank Underwood", mentoring_model_id: new_mentoring_model.id, goal_template_id: gt1, milestone_template_id: milestone_template.id)

    assert_difference "ObjectRolePermission.count", 5  do
      assert_difference "MentoringModel::Task.count", 3 do
        @mentoring_model_cloner.copy_mentoring_model_objects
      end
    end

    assert_equal @group.mentoring_model_id, new_mentoring_model.id
    assert_equal_unordered ["manage_mm_milestones", "manage_mm_tasks", "manage_mm_tasks", "manage_mm_goals", "manage_mm_goals"], @group.object_permissions.pluck(:name)
    assert_equal ["House Of Cards", "Claire Underwood", "Frank Underwood"], @group.mentoring_model_tasks.collect(&:title)
    assert_equal [nil, nil, nil], @group.mentoring_model_tasks.collect(&:goal_id)
  end

  def test_mentoring_model_cloner_with_group_mentoring_template
    new_mentoring_model = create_mentoring_model(mentoring_period: 2.months)
    new_mentoring_model.update_attribute(:should_sync, false)
    @group.mentoring_model = new_mentoring_model
    @group.save!
    roles_hash = @program.roles.for_mentoring_models.group_by(&:name)
    @mentoring_model_cloner = Group::MentoringModelCloner.new(@group, @program, new_mentoring_model)
    new_mentoring_model.allow_manage_mm_milestones!([roles_hash[RoleConstants::ADMIN_NAME].first])
    new_mentoring_model.allow_manage_mm_tasks!([roles_hash[RoleConstants::ADMIN_NAME].first, roles_hash[RoleConstants::STUDENT_NAME].first])
    milestone_template = create_mentoring_model_milestone_template
    old_t1 = create_mentoring_model_task_template(title: "Awesome Title 1")
    old_t2 = create_mentoring_model_task_template(title: "Awesome Title 2")

    new_t1 = create_mentoring_model_task_template(title: "House Of Cards", mentoring_model_id: new_mentoring_model.id, milestone_template_id: milestone_template.id)
    new_t2 = create_mentoring_model_task_template(title: "Claire Underwood", mentoring_model_id: new_mentoring_model.id, milestone_template_id: milestone_template.id)
    new_t3 = create_mentoring_model_task_template(title: "Frank Underwood", mentoring_model_id: new_mentoring_model.id, milestone_template_id: milestone_template.id)

    assert_difference "ObjectRolePermission.count", 3  do
      assert_difference "MentoringModel::Task.count", 3 do
        @mentoring_model_cloner.copy_mentoring_model_objects
      end
    end

    assert_equal @group.mentoring_model_id, new_mentoring_model.id
    assert_equal_unordered ["manage_mm_milestones", "manage_mm_tasks", "manage_mm_tasks"], @group.object_permissions.pluck(:name)
    assert_equal ["House Of Cards", "Claire Underwood", "Frank Underwood"], @group.mentoring_model_tasks.collect(&:title)
  end

  def test_mentoring_model_cloner_with_group_mentoring_template_in_a_milestone_with_specific_date_tasks
    new_mentoring_model = create_mentoring_model(mentoring_period: 2.months)
    roles_hash = @program.roles.for_mentoring_models.group_by(&:name)
    @mentoring_model_cloner = Group::MentoringModelCloner.new(@group, @program, new_mentoring_model)
    new_mentoring_model.allow_manage_mm_milestones!([roles_hash[RoleConstants::ADMIN_NAME].first])
    new_mentoring_model.allow_manage_mm_tasks!([roles_hash[RoleConstants::ADMIN_NAME].first, roles_hash[RoleConstants::STUDENT_NAME].first])

    new_m1 = create_mentoring_model_milestone_template(mentoring_model_id: new_mentoring_model.id)
    new_m2 = create_mentoring_model_milestone_template(mentoring_model_id: new_mentoring_model.id)

    new_t1 = create_mentoring_model_task_template(title: "House Of Cards", milestone_template_id: new_m1.id, mentoring_model_id: new_mentoring_model.id, position: 0)
    new_t2 = create_mentoring_model_task_template(title: "Rank Boy", milestone_template_id: new_m1.id, mentoring_model_id: new_mentoring_model.id, required: true, specific_date: "2012-02-03")
    new_t3 = create_mentoring_model_task_template(title: "Frankenstein", milestone_template_id: new_m1.id, mentoring_model_id: new_mentoring_model.id, required: true, duration: "7")
    new_t4 = create_mentoring_model_task_template(title: "Frank Underwood", milestone_template_id: new_m1.id, mentoring_model_id: new_mentoring_model.id, position: 2)
    new_t5 = create_mentoring_model_task_template(title: "Claire Underwood", milestone_template_id: new_m1.id, mentoring_model_id: new_mentoring_model.id, position: 4)

    new_t8= create_mentoring_model_task_template(title: "Frankenstein", milestone_template_id: new_m2.id, mentoring_model_id: new_mentoring_model.id, required: true, duration: "7")
    new_t7 = create_mentoring_model_task_template(title: "Rank Boy", milestone_template_id: new_m2.id, mentoring_model_id: new_mentoring_model.id, required: true, specific_date: "2012-02-03")
    new_t6 = create_mentoring_model_task_template(title: "House Of Cards", milestone_template_id: new_m2.id, mentoring_model_id: new_mentoring_model.id, position: 0)
    new_t9 = create_mentoring_model_task_template(title: "Frank Underwood", milestone_template_id: new_m2.id, mentoring_model_id: new_mentoring_model.id, position: 1)

    @group.mentoring_model = new_mentoring_model
    @group.save!

    assert_difference "ObjectRolePermission.count", 3  do
      assert_difference "MentoringModel::Task.count", 9 do
        @mentoring_model_cloner.copy_mentoring_model_objects
      end
    end

    assert_equal @group.mentoring_model_id, new_mentoring_model.id
    assert_equal_unordered ["manage_mm_milestones", "manage_mm_tasks", "manage_mm_tasks"], @group.object_permissions.pluck(:name)
    assert_equal ["Rank Boy", "Frankenstein", "House Of Cards", "Frank Underwood", "Claire Underwood"], @group.mentoring_model_milestones.first.mentoring_model_tasks.collect(&:title)
    assert_equal ["Rank Boy", "Frankenstein", "House Of Cards", "Frank Underwood"], @group.mentoring_model_milestones.second.mentoring_model_tasks.collect(&:title)
  end

  def test_mentoring_model_cloner_with_group_mentoring_template_and_specific_date_tasks
    new_mentoring_model = create_mentoring_model(mentoring_period: 2.months)
    @group.mentoring_model = new_mentoring_model
    @group.save!
    roles_hash = @program.roles.for_mentoring_models.group_by(&:name)
    @mentoring_model_cloner = Group::MentoringModelCloner.new(@group, @program, new_mentoring_model)
    new_mentoring_model.allow_manage_mm_milestones!([roles_hash[RoleConstants::ADMIN_NAME].first])
    new_mentoring_model.allow_manage_mm_tasks!([roles_hash[RoleConstants::ADMIN_NAME].first, roles_hash[RoleConstants::STUDENT_NAME].first])
    milestone_template = create_mentoring_model_milestone_template

    new_t1 = create_mentoring_model_task_template(title: "House Of Cards", mentoring_model_id: new_mentoring_model.id, position: 0, milestone_template_id: milestone_template.id)
    new_t2 = create_mentoring_model_task_template(title: "Rank Boy", mentoring_model_id: new_mentoring_model.id, required: true, specific_date: "2012-02-03", milestone_template_id: milestone_template.id)
    new_t3 = create_mentoring_model_task_template(title: "Frankenstein", mentoring_model_id: new_mentoring_model.id, required: true, duration: "7", milestone_template_id: milestone_template.id)
    new_t4 = create_mentoring_model_task_template(title: "Frank Underwood", mentoring_model_id: new_mentoring_model.id, position: 2, milestone_template_id: milestone_template.id)
    new_t5 = create_mentoring_model_task_template(title: "Claire Underwood", mentoring_model_id: new_mentoring_model.id, position: 4, milestone_template_id: milestone_template.id)

    @group.mentoring_model_tasks.destroy_all
    assert_difference "ObjectRolePermission.count", 3  do
      assert_difference "MentoringModel::Task.count", 5 do
        @mentoring_model_cloner.copy_mentoring_model_objects
      end
    end

    assert_equal @group.mentoring_model_id, new_mentoring_model.id
    assert_equal_unordered ["manage_mm_milestones", "manage_mm_tasks", "manage_mm_tasks"], @group.object_permissions.pluck(:name)
    assert_equal ["Rank Boy", "House Of Cards", "Frankenstein",  "Frank Underwood", "Claire Underwood"], @group.mentoring_model_tasks.collect(&:title)
    assert_equal [false] *  5, @group.mentoring_model_tasks.collect(&:unassigned_from_template?)
  end

  def test_set_unassigned_from_template
    unassigned_task_template = create_mentoring_model_task_template(title: "Walter White - Skyler", role_id: nil, mentoring_model_id: @mentoring_model.id)
    assigned_task_template = create_mentoring_model_task_template(title: "Frank and Claire Underwood", mentoring_model_id: @mentoring_model.id)
    assert_equal 2, @mentoring_model.mentoring_model_task_templates.size

    @mentoring_model_cloner = Group::MentoringModelCloner.new(@group, @program, @mentoring_model)

    assert_difference "MentoringModel::Task.count", 2 do
      @mentoring_model_cloner.copy_mentoring_model_objects
    end

    tasks = @group.mentoring_model_tasks
    unassigned_tasks = tasks.select{|task| task.connection_membership.nil? }
    assigned_tasks = tasks.select{|task| task.connection_membership.present? }

    assert_equal 1, unassigned_tasks.size
    assert_equal 1, assigned_tasks.size

    assert_equal unassigned_task_template.id, unassigned_tasks.first.mentoring_model_task_template_id
    assert_equal assigned_task_template.id, assigned_tasks.first.mentoring_model_task_template_id

    assert unassigned_tasks.first.unassigned_from_template?
    assert_false assigned_tasks.first.unassigned_from_template?
  end

  def test_copy_template_tasks_for_memberships
    mentor_role = @program.find_role RoleConstants::MENTOR_NAME
    student_role = @program.find_role RoleConstants::STUDENT_NAME
    mentor_tt = create_mentoring_model_task_template(title: "Mentor Task", role_id: mentor_role.id, mentoring_model_id: @mentoring_model.id, required: true)
    student_tt = create_mentoring_model_task_template(title: "Student Task", role_id: student_role.id, mentoring_model_id: @mentoring_model.id, required: true, associated_id: mentor_tt.id)
    unassigned_tt = create_mentoring_model_task_template(title: "Unassigned Task", role_id: nil, mentoring_model_id: @mentoring_model.id)
    assert_equal 3, @mentoring_model.mentoring_model_task_templates.size
    assert_equal 0, @group.mentoring_model_tasks.size

    mentoring_model_cloner = Group::MentoringModelCloner.new(@group, @program, @mentoring_model, @group.mentor_memberships)
    assert_difference "MentoringModel::Task::count", 2 do
      mentoring_model_cloner.copy_template_tasks_for_memberships
    end
    tasks = @group.mentoring_model_tasks
    assert_equal 2, tasks.size
    assert_equal 1, tasks.select{|task| task.connection_membership.nil? }.size
    assert_equal 1, tasks.select{|task| task.connection_membership.present? }.size

    mentoring_model_cloner = Group::MentoringModelCloner.new(@group, @program, @mentoring_model)
    assert_difference "MentoringModel::Task::count", 1 do
      mentoring_model_cloner.copy_template_tasks_for_memberships
    end
    tasks = @group.mentoring_model_tasks
    mentor_task = tasks.find_by(mentoring_model_task_template_id: mentor_tt.id)
    student_task = tasks.find_by(mentoring_model_task_template_id: student_tt.id)
    assert_equal 3, tasks.size
    assert_equal 1, tasks.select{|task| task.connection_membership.nil? }.size
    assert_equal 2, tasks.select{|task| task.connection_membership.present? }.size
    assert mentor_task.position < student_task.position

    @group.students = @group.students + [users(:student_0)]
    @group.save!
    new_membership = @group.student_memberships.of(users(:student_0)).first
    mentoring_model_cloner = Group::MentoringModelCloner.new(@group, @program, @mentoring_model, [new_membership])
    assert_difference "MentoringModel::Task::count", 1 do
      mentoring_model_cloner.copy_template_tasks_for_memberships
    end
    tasks = @group.mentoring_model_tasks
    mentor_task = tasks.find_by(mentoring_model_task_template_id: mentor_tt.id)
    student_tasks = tasks.find_by(mentoring_model_task_template_id: student_tt.id)
    assert_equal 4, tasks.size
    assert_equal 1, tasks.select{|task| task.connection_membership.nil? }.size
    assert_equal 3, tasks.select{|task| task.connection_membership.present? }.size
  end
end