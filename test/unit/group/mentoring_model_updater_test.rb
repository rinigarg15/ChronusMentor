require_relative './../../test_helper.rb'

class Group::MentoringModelUpdaterTest < ActiveSupport::TestCase
  def setup
    super
    @group = groups(:mygroup)
    @program = programs(:albers)
    @mentoring_model = @program.default_mentoring_model
  end

  def test_add_new_tasks
    assert MentoringModel::Importer.new(@mentoring_model, generate_csv_content).import.successful?
    @mentoring_model.reload
    @group.update_attribute(:mentoring_model_id, @mentoring_model.id)
    assert @group.mentoring_model_milestones.empty?
    assert @group.mentoring_model_goals.empty?
    assert @group.mentoring_model_tasks.empty?
    assert_equal 2, @mentoring_model.mentoring_model_milestone_templates.size
    assert_equal 2, @mentoring_model.mentoring_model_goal_templates.size
    assert_equal 7, @mentoring_model.mentoring_model_task_templates.size

    run_in_another_locale(:"de") do
      mentoring_model_updater = Group::MentoringModelUpdater.new(@group, I18n.locale)
      mentoring_model_updater.sync
      @group.reload
      assert_equal @mentoring_model.version, @group.version
      assert_equal 2, @group.mentoring_model_milestones.size
      assert_equal 2, @group.mentoring_model_goals.size
      assert_equal 7, @group.mentoring_model_tasks.size
    end
  end

  def test_sync
    assert MentoringModel::Importer.new(@mentoring_model, generate_csv_content).import.successful?
    @mentoring_model.reload
    @group.update_attribute(:mentoring_model_id, @mentoring_model.id)
    assert @group.mentoring_model_milestones.empty?
    assert @group.mentoring_model_goals.empty?
    assert @group.mentoring_model_tasks.empty?
    assert_equal 2, @mentoring_model.mentoring_model_milestone_templates.size
    assert_equal 2, @mentoring_model.mentoring_model_goal_templates.size
    assert_equal 7, @mentoring_model.mentoring_model_task_templates.size

    mentoring_model_updater = Group::MentoringModelUpdater.new(@group, I18n.locale)
    mentoring_model_updater.sync
    @group.reload
    assert_equal @mentoring_model.version, @group.version

    create_mentoring_model_milestone
    create_mentoring_model_goal
    create_mentoring_model_task
    @group.reload
    assert_equal 2, @group.mentoring_model_milestones.from_template.size
    assert_equal 2, @group.mentoring_model_goals.from_template.size
    assert_equal 7, @group.mentoring_model_tasks.from_template.size
    assert_equal [1], @group.mentoring_model_milestones.from_template.map(&:template_version).uniq
    assert_equal [1], @group.mentoring_model_goals.from_template.map(&:template_version).uniq
    assert_equal [2], @group.mentoring_model_tasks.from_template.map(&:template_version).uniq
    assert_equal 3, @group.mentoring_model_milestones.size
    assert_equal 3, @group.mentoring_model_goals.size
    assert_equal 8, @group.mentoring_model_tasks.size
    assert_equal [nil], @group.mentoring_model_milestones.where(from_template: false).map(&:template_version).uniq
    assert_equal [nil], @group.mentoring_model_goals.where(from_template: false).map(&:template_version).uniq
    assert_equal [nil], @group.mentoring_model_tasks.where(from_template: false).map(&:template_version).uniq

    assert_false @group.mentoring_model_milestones.map(&:title).include?("Added Milestone")
    added_milestone = create_mentoring_model_milestone_template(title: "Added Milestone")
    assert @group.reload.mentoring_model_milestones.map(&:title).include?("Added Milestone")

    update_object_attributes_for_locale(added_milestone, :en, {title: "english title", description: "english description"})
    update_object_attributes_for_locale(added_milestone, :"de", {title: "french title", description: "french description"})
    Globalize.with_locale(:en) { assert @group.reload.mentoring_model_milestones.map(&:title).include?("english title") }
    Globalize.with_locale(:"de") { assert @group.reload.mentoring_model_milestones.map(&:title).include?("french title") }

    assert_equal 4, @group.mentoring_model_milestones.size
    added_milestone.title = "Added Milestone change title"
    added_milestone.description = "Changed description"
    added_milestone.save!
    assert @group.reload.mentoring_model_milestones.map(&:title).include?("Added Milestone change title")
    assert @group.reload.mentoring_model_milestones.map(&:description).include?("Changed description")
    assert_equal 4, @group.mentoring_model_milestones.size
    added_milestone.destroy
    assert_false @group.reload.mentoring_model_milestones.map(&:title).include?("Added Milestone change title")
    Globalize.with_locale(:"de") { assert_false @group.reload.mentoring_model_milestones.map(&:title).include?("french title") }
    assert_equal 3, @group.mentoring_model_milestones.size

    assert_false @group.mentoring_model_goals.map(&:title).include?("Added goal")
    added_goal = create_mentoring_model_goal_template(title: "Added goal")
    assert @group.reload.mentoring_model_goals.map(&:title).include?("Added goal")
    assert_equal 4, @group.mentoring_model_goals.size
    update_object_attributes_for_locale(added_goal, :en, {title: "english title", description: "english description"})
    update_object_attributes_for_locale(added_goal, :"de", {title: "french title", description: "french description"})
    Globalize.with_locale(:en) { assert @group.reload.mentoring_model_goals.map(&:title).include?("english title") }
    Globalize.with_locale(:"de") { assert @group.reload.mentoring_model_goals.map(&:title).include?("french title") }

    added_goal.title = "Added goal change title"
    added_goal.description = "Changed description"
    added_goal.save!
    assert @group.reload.mentoring_model_goals.map(&:title).include?("Added goal change title")
    assert @group.reload.mentoring_model_goals.map(&:description).include?("Changed description")
    Globalize.with_locale(:"de") { assert @group.reload.mentoring_model_goals.map(&:title).include?("french title") }
    assert_equal 4, @group.mentoring_model_goals.size
    added_goal.destroy
    assert_false @group.reload.mentoring_model_goals.map(&:title).include?("Added goal change title")
    Globalize.with_locale(:"de") { assert_false @group.reload.mentoring_model_goals.map(&:title).include?("french title") }
    assert_equal 3, @group.mentoring_model_goals.size

    roles = @program.roles.select([:id, :name]).for_mentoring_models
    roles_hash = roles.index_by(&:name)

    assert_false @group.reload.mentoring_model_tasks.map(&:title).include?("Added task")
    added_task_template = create_mentoring_model_task_template(title: "Added task", role_id: roles_hash[RoleConstants::MENTOR_NAME].id, action_item_type: MentoringModel::TaskTemplate::ActionItem::MEETING, milestone_template_id: @mentoring_model.mentoring_model_milestone_templates.first.id)
    assert @group.reload.mentoring_model_tasks.map(&:title).include?("Added task")
    update_object_attributes_for_locale(added_task_template, :en, {title: "english title", description: "english description"})
    update_object_attributes_for_locale(added_task_template, :"de", {title: "french title", description: "french description"})
    Globalize.with_locale(:en) { assert @group.reload.mentoring_model_tasks.map(&:title).include?("english title") }
    Globalize.with_locale(:"de") { assert @group.reload.mentoring_model_tasks.map(&:title).include?("french title") }

    assert_equal 9, @group.mentoring_model_tasks.size
    assert_equal [false] * 9, @group.mentoring_model_tasks.collect(&:unassigned_from_template)

    added_task = @group.reload.mentoring_model_tasks.find{|t| t.title == "english title"}
    added_task_template.milestone_template_id = @mentoring_model.mentoring_model_milestone_templates.find{|mt| mt.title == "Milestone 1"}.id
    added_task_template.goal_template_id = @mentoring_model.mentoring_model_goal_templates.find{|mt| mt.title == "Goal 1"}.id
    added_task_template.title = "new title"
    added_task_template.description = "new description"
    added_task_template.action_item_type = MentoringModel::TaskTemplate::ActionItem::DEFAULT
    added_task_template.save!
    assert_equal added_task_template.milestone_template.title, added_task.reload.milestone.title
    assert_equal added_task_template.goal_template.title, added_task.mentoring_model_goal.title
    assert_equal "new title", added_task.title
    assert_equal "new description", added_task.description
    Globalize.with_locale(:"de") {assert_equal "french title", added_task.reload.title}
    Globalize.with_locale(:"de") {assert_equal "french description", added_task.reload.description}
    assert_equal MentoringModel::TaskTemplate::ActionItem::DEFAULT, added_task.action_item_type

    assert added_task.optional?
    added_task_title = added_task.title

    first_required_task_template = @mentoring_model.mentoring_model_task_templates.required.first
    added_task_template.associated_id = first_required_task_template.id
    added_task_template.duration = 1
    added_task_template.required = true
    added_task_template.save!
    assert_false added_task.reload.optional?
    initial_date = added_task.due_date
    added_task_template.duration = 3
    added_task_template.save!
    assert_equal initial_date + 2.days, added_task.reload.due_date

    added_task_template.role_id = roles_hash[RoleConstants::STUDENT_NAME].id
    added_task_template.save!
    assert MentoringModel::Task.where(id: added_task.id).empty?
    added_task = MentoringModel::Task.all.find { |a| a.title == added_task_title }
    assert_equal [roles_hash[RoleConstants::STUDENT_NAME]], added_task.connection_membership.user.roles

    added_task_template.destroy
    assert MentoringModel::Task.where(id: added_task.id).empty?

    survey_task_template = MentoringModel::TaskTemplate.find_by(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY)
    assert_equal "Task 7",survey_task_template.title
    survey_task = @group.reload.mentoring_model_tasks.find{|t| t.title == "Task 7"}
    new_action_item_id = 123
    survey_task_template.update_attribute(:action_item_id, new_action_item_id)
    assert_equal new_action_item_id, survey_task.reload.action_item_id

    survey_task.update_attributes!({:status => MentoringModel::Task::Status::DONE, :completed_date => Date.today})
    new_action_item_id2 = 321
    survey_task_template.update_attribute(:action_item_id, new_action_item_id2)
    assert_equal new_action_item_id2, survey_task.reload.action_item_id
    assert_equal MentoringModel::Task::Status::TODO, survey_task.status

    # sync of milestone position
    mt2 = create_mentoring_model_milestone_template({title: "Template2"})
    mt3 = create_mentoring_model_milestone_template({title: "Template3"})
    mt4 = create_mentoring_model_milestone_template({title: "Template4"})

    assert_equal ["Milestone 1", "Milestone 2", "Template2", "Template3", "Template4", "Carrie Mathison"], @group.reload.mentoring_model_milestones.map(&:title)

    mt3.update_attribute(:position, 11)
    mt4.update_attribute(:position, 10)

    assert_equal ["Milestone 1", "Milestone 2", "Template2", "Template4", "Template3", "Carrie Mathison"], @group.reload.mentoring_model_milestones.map(&:title)
  end

  def test_sync_with_unassigned_tasks
    assert MentoringModel::Importer.new(@mentoring_model, generate_csv_content).import.successful?
    @mentoring_model.reload
    @group.update_attribute(:mentoring_model_id, @mentoring_model.id)

    assert @group.mentoring_model_milestones.empty?
    assert @group.mentoring_model_goals.empty?
    assert @group.mentoring_model_tasks.empty?
    assert_equal 2, @mentoring_model.mentoring_model_milestone_templates.size
    assert_equal 2, @mentoring_model.mentoring_model_goal_templates.size
    assert_equal 7, @mentoring_model.mentoring_model_task_templates.size

    mentoring_model_updater = Group::MentoringModelUpdater.new(@group, I18n.locale)
    mentoring_model_updater.sync
    assert_equal @mentoring_model.version, @group.reload.version
    task_template = create_mentoring_model_task_template(title: "Frank and Claire Underwood", role_id: nil, mentoring_model_id: @mentoring_model.id, milestone_template_id: @mentoring_model.mentoring_model_milestone_templates.first.id)

    @mentoring_model.reload.increment_version_and_trigger_sync
    mentoring_model_task = MentoringModel::Task.last
    assert_equal "Frank and Claire Underwood", mentoring_model_task.title
    assert mentoring_model_task.unassigned_from_template?

    update_object_attributes_for_locale(task_template.reload, :en, { title: "english title", description: "english description" } )
    update_object_attributes_for_locale(task_template, :"de", { title: "french title", description: "french description" } )
    Globalize.with_locale(:"de") { assert_equal "french title", mentoring_model_task.reload.title }
    Globalize.with_locale(:"de") { assert_equal "french description", mentoring_model_task.description }
    Globalize.with_locale(:en) { assert_equal "english title", mentoring_model_task.reload.title }
    Globalize.with_locale(:en) { assert_equal "english description", mentoring_model_task.description }
  end

  def test_sync_with_role_update_and_due_date_altered
    mentor_role = @program.find_role(RoleConstants::MENTOR_NAME)
    student_role = @program.find_role(RoleConstants::STUDENT_NAME)
    mentor_memberships = @group.mentor_memberships
    student_memberships = @group.student_memberships

    mentor_task_template = create_mentoring_model_task_template(required: true, role_id: mentor_role.id)
    student_task_template = create_mentoring_model_task_template(required: true, role_id: student_role.id)
    assert_equal 2, @mentoring_model.mentoring_model_task_templates.size
    assert_empty @group.mentoring_model_tasks

    @group.update_attribute(:mentoring_model_id, @mentoring_model.id)
    Group::MentoringModelUpdater.new(@group, I18n.locale).sync
    assert_equal 2, @group.mentoring_model_tasks.size
    mentor_task = @group.mentoring_model_tasks.from_template.find_by(mentoring_model_task_template_id: mentor_task_template.id)
    student_task = @group.mentoring_model_tasks.from_template.find_by(mentoring_model_task_template_id: student_task_template.id)
    assert_equal 3, mentor_task.template_version
    assert_equal 2, student_task.template_version

    mentor_task.update_attributes(status: MentoringModel::Task::Status::DONE, completed_date: Date.today)
    mentor_task_template.update_attributes(role_id: student_role.id)
    student_task_template.update_attributes(role_id: mentor_role.id)

    assert_equal 3, @group.mentoring_model_tasks.size
    assert_nothing_raised do
      mentor_task.reload
    end
    assert mentor_task.done?
    assert_equal 2, mentor_task_template.mentoring_model_tasks.size
    assert_equal (@group.published_at + 1.day), mentor_task.due_date
    assert_equal (mentor_memberships + student_memberships), mentor_task_template.mentoring_model_tasks.map(&:connection_membership)
    assert_equal [4], mentor_task_template.mentoring_model_tasks.map(&:template_version).uniq
    assert_equal mentor_memberships, student_task_template.mentoring_model_tasks.map(&:connection_membership)
    assert_equal [3], student_task_template.mentoring_model_tasks.map(&:template_version).uniq
    assert_raises(ActiveRecord::RecordNotFound) do
      student_task.reload
    end

    mentor_task.due_date = (@group.published_at + 3.days)
    mentor_task.due_date_altered = true
    mentor_task.save!
    mentor_task_template.reload
    mentor_task_template.duration =  5
    mentor_task_template.save!
    assert_equal (@group.published_at + 3.days), mentor_task.reload.due_date
    assert_equal (@group.published_at + 5.days), mentor_task_template.mentoring_model_tasks.reload.find { |task| task.id != mentor_task.id }.due_date
  end

  private

  def generate_csv_content(options = {})
    options.reverse_merge!({
      include_milestones: true, include_goals: true, include_tasks: true, include_surveys: true,
      include_facilitation_messages: true, include_meetings: true, include_setup_goal_tasks: false
    })
    csv_content = ""
    csv_content += "#Milestones,,,,,,,,\nTitle,Description,Position,,,,,,\nMilestone 1,Milestone 1 description,0,,,,,,\nMilestone 2,,1,,,,,,\n,,,,,,,,\n" if options[:include_milestones]
    csv_content += "#Goals,,,,,,,,\nTitle,Description,,,,,,,\nGoal 1,Goal 1 description,,,,,,,\nGoal 2,,,,,,,,\n,,,,,,,,\n" if options[:include_goals]
    csv_content += "#Tasks,,,,,,,,\nTitle,Description,Required,Due by,After,Action Item,Action Item ID,Assignee,Goal,Milestone\nTask 1,Task 1 description,Yes,3,Start,,,Mentor,,Milestone 1\n#{"Task 2,Task 2 description,No,,,Create Meeting,,Mentee,Goal 1,Milestone 1\n" if options[:include_meetings]}Task 3,,Yes,5,Task 1,,,Mentee,,Milestone 1\nTask 4,,No,,,,,Mentor,,Milestone 2\nTask 5,,Yes,4,Task 3,,,Mentor,Goal 2,Milestone 2\n#{"Task 6,,No,,,Setup Goal,,Mentee,,Milestone 2\n" if options[:include_goals] || options[:include_setup_goal_tasks]}#{"Task 7,,No,,,Take Engagement Survey,"+surveys(:two).id.to_s+",Mentee,,Milestone 2\n" if options[:include_surveys]},,,,,,,,\n" if options[:include_tasks]
    csv_content += "#Facilitation Messages,,,,,,,,\nSubject,Content,For,Send after (in days),Milestone,,,,\nFM 1,FM 1 Content,\"Mentor, Mentee\",2,Milestone 1,,,,\nFM 2,FM 2 Content,Mentor,5,Milestone 1,,,,\nFM 3,FM 3 Content,Mentee,8,Milestone 2,,,,\n" if options[:include_facilitation_messages]
    csv_content
  end

  def update_object_attributes_for_locale(object, locale, options)
    run_in_another_locale(locale) do
      object.update_attributes(options)
    end
  end
end