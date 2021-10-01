require_relative './../../test_helper.rb'

class MentoringModel::ImporterTest < ActiveSupport::TestCase
  def setup
    super
    @program = programs(:albers)
    @mentoring_model = @program.default_mentoring_model
  end

  def test_initialize
    csv_content = generate_csv_content
    importer = MentoringModel::Importer.new(@mentoring_model, csv_content)
    assert_equal csv_content, importer.instance_variable_get("@csv_content")
    assert_equal CSV.parse(csv_content), importer.instance_variable_get("@data")
    assert_equal @program, importer.instance_variable_get("@program")
    assert_equal @mentoring_model, importer.instance_variable_get("@mentoring_model")
    assert_false importer.instance_variable_get("@successful")
    assert_equal_hash importer.instance_variable_get("@milestones_referenced_by_title"), {}
    assert_equal_hash importer.instance_variable_get("@goals_referenced_by_title"), {}
    assert_equal_hash importer.instance_variable_get("@tasks_referenced_by_title"), {"Start"=>nil}
    assert_equal @program.roles.for_mentoring_models, importer.instance_variable_get("@all_roles")
    assert_equal @program.roles.for_mentoring, importer.instance_variable_get("@user_roles")
    assert_equal @program.get_roles([RoleConstants::ADMIN_NAME]), importer.instance_variable_get("@admin_roles")
  end

  def test_successfull
    importer = MentoringModel::Importer.new(@mentoring_model, generate_csv_content)
    assert_false importer.successful?
    importer.import
    assert importer.successful?
  end

  def test_topical_consultation_import_with_meeting
    csv_content = generate_csv_content({include_milestones: false, include_goals: false, include_facilitation_messages: false})
    t1 = create_mentoring_model_task_template
    assert_equal [t1], @mentoring_model.reload.mentoring_model_task_templates
    importer = MentoringModel::Importer.new(@mentoring_model, csv_content)
    assert importer.import.successful?
    assert_equal ["Task 1", "Task 2", "Task 3", "Task 4", "Task 5","Task 8"], @mentoring_model.reload.mentoring_model_task_templates.collect(&:title)
    assert_equal [], @mentoring_model.reload.mentoring_model_goal_templates
    assert_equal [], @mentoring_model.reload.mentoring_model_milestone_templates

    all_roles, user_roles, admin_roles = get_roles_from_importer(importer)

    assert_false @mentoring_model.can_manage_mm_milestones?(all_roles)
    assert_false @mentoring_model.can_manage_mm_goals?(all_roles)
    assert @mentoring_model.can_manage_mm_tasks?(all_roles)

    assert @mentoring_model.can_manage_mm_meetings?(user_roles)
    assert @mentoring_model.can_manage_mm_messages?(admin_roles)
    assert @mentoring_model.can_manage_mm_engagement_surveys?(admin_roles)
  end

  def test_tasks_start_of_connection_as_due_date
    csv_content = "#Tasks,,,,,,,,\nTitle,Description,Required,Due by,After,Action Item,Assignee,Goal,Milestone\nTask 1,Task 1 description,Yes,3,Start,,Mentor,,\nTask 2,Task 2 description,Yes,5,Start,,Mentee,,\nTask 3,,No,,,,Mentee,,\nTask 3a,,No,,,,Mentee,,\nTask 4,,Yes,7,Start,,Mentor,,\nTask 5,,Yes,4,Task 2,,Mentor,,\nTask 6,,No,,,,Mentor,,\nTask 7,,No,,,,Mentor,,\n"
    importer = MentoringModel::Importer.new(@mentoring_model, csv_content)
    assert importer.import.successful?
    assert_equal ["Task 1", "Task 2", "Task 3", "Task 3a", "Task 4", "Task 5", "Task 6", "Task 7"], @mentoring_model.reload.mentoring_model_task_templates.map(&:title)
    task_templates = @mentoring_model.mentoring_model_task_templates
    assert_equal [nil, nil, task_templates[1].id, task_templates[1].id, nil, task_templates[1].id, task_templates[5].id, task_templates[5].id], task_templates.map(&:associated_id)
    assert_equal [3, 5, 0, 0, 7, 4, 0, 0], task_templates.map(&:duration)
  end

  def test_process_ckeditor_content
    task_description_1 = "Line 1\nLine 2\n\nLine 3"
    task_description_2 = nil
    csv_content = "#Tasks,,,,,,,,\nTitle,Description,Required,Due by,After,Action Item,Assignee,Goal,Milestone\nTask 1,Task 1 description,Yes,3,Start,,Mentor,,\nTask 2,Task 2 description,Yes,5,Start,,Mentee,,\nTask 3,,No,,,,Mentee,,Milestone 1\nTask 3a,,No,,,,Mentee,,Milestone 1\nTask 4,,Yes,7,Start,,Mentor,,\nTask 5,,Yes,4,Task 2,,Mentor,,\nTask 6,,No,,,,Mentor,,\nTask 7,,No,,,,Mentor,,\n"
    importer = MentoringModel::Importer.new(@mentoring_model, csv_content)
    assert_equal "Line 1<br/>Line 2<br/><br/>Line 3", importer.process_ckeditor_content(task_description_1)
    assert_nil importer.process_ckeditor_content(task_description_2)
  end

  def test_topical_consultation_import_without_meeting
    csv_content = generate_csv_content({include_milestones: false, include_goals: false, include_facilitation_messages: false, include_meetings: false})
    t1 = create_mentoring_model_task_template
    assert_equal [t1], @mentoring_model.reload.mentoring_model_task_templates
    importer = MentoringModel::Importer.new(@mentoring_model, csv_content)
    assert importer.import.successful?
    assert_equal ["Task 1", "Task 3", "Task 4", "Task 5","Task 8"], @mentoring_model.reload.mentoring_model_task_templates.collect(&:title)
    assert_equal [], @mentoring_model.reload.mentoring_model_goal_templates
    assert_equal [], @mentoring_model.reload.mentoring_model_milestone_templates

    all_roles, user_roles, admin_roles = get_roles_from_importer(importer)

    assert_false @mentoring_model.can_manage_mm_milestones?(all_roles)
    assert_false @mentoring_model.can_manage_mm_goals?(all_roles)
    assert @mentoring_model.can_manage_mm_tasks?(all_roles)

    assert @mentoring_model.can_manage_mm_meetings?(user_roles)
    assert @mentoring_model.can_manage_mm_messages?(admin_roles)
    assert @mentoring_model.can_manage_mm_engagement_surveys?(admin_roles)
  end

  def test_growth_on_goals
    csv_content = generate_csv_content({include_milestones: false, include_facilitation_messages: false})
    t1 = create_mentoring_model_task_template
    assert_equal [t1], @mentoring_model.reload.mentoring_model_task_templates
    importer = MentoringModel::Importer.new(@mentoring_model, csv_content)
    assert importer.import.successful?
    assert_equal ["Task 1", "Task 2", "Task 3", "Task 4", "Task 5", "Task 6", "Task 8"], @mentoring_model.reload.mentoring_model_task_templates.collect(&:title)
    assert_equal ["Goal 1", "Goal 2"], @mentoring_model.reload.mentoring_model_goal_templates.collect(&:title)
    assert_equal [], @mentoring_model.mentoring_model_goal_templates[0].task_templates
    assert_equal [@mentoring_model.mentoring_model_task_templates[4]], @mentoring_model.mentoring_model_goal_templates[1].task_templates
    assert_equal [], @mentoring_model.reload.mentoring_model_milestone_templates

    all_roles, user_roles, admin_roles = get_roles_from_importer(importer)

    assert_false @mentoring_model.can_manage_mm_milestones?(all_roles)
    assert @mentoring_model.can_manage_mm_goals?(all_roles)
    assert @mentoring_model.can_manage_mm_tasks?(all_roles)
    assert @mentoring_model.can_manage_mm_meetings?(user_roles)
    assert @mentoring_model.can_manage_mm_messages?(admin_roles)
    assert @mentoring_model.can_manage_mm_engagement_surveys?(admin_roles)
  end

  def test_goals_enabled_with_setup_goal
    csv_content = generate_csv_content({include_milestones: false, include_goals: false, include_facilitation_messages: false})
    t1 = create_mentoring_model_task_template(action_item_type: MentoringModel::TaskTemplate::ActionItem::GOAL)
    assert_equal [t1], @mentoring_model.reload.mentoring_model_task_templates
    importer = MentoringModel::Importer.new(@mentoring_model, csv_content)
    assert importer.import.successful?

    all_roles, user_roles, admin_roles = get_roles_from_importer(importer)

    assert_false @mentoring_model.can_manage_mm_goals?(all_roles)
    assert_false @mentoring_model.can_manage_mm_goals?(admin_roles)
    assert_false @mentoring_model.can_manage_mm_goals?(user_roles)

    @mentoring_model.object_role_permissions.destroy_all
    t1 = create_mentoring_model_task_template(action_item_type: MentoringModel::TaskTemplate::ActionItem::GOAL)
    csv_content = generate_csv_content({include_milestones: false, include_goals: false, include_facilitation_messages: false, include_setup_goal_tasks: true})
    importer = MentoringModel::Importer.new(@mentoring_model, csv_content)
    assert importer.import.successful?

    all_roles, user_roles, admin_roles = get_roles_from_importer(importer)
    assert @mentoring_model.can_manage_mm_goals?(all_roles)
    assert @mentoring_model.can_manage_mm_goals?(admin_roles)
    assert @mentoring_model.can_manage_mm_goals?(user_roles)
  end

  def test_facilitated_training
    csv_content = generate_csv_content
    t1 = create_mentoring_model_task_template
    assert_equal [t1], @mentoring_model.reload.mentoring_model_task_templates
    importer = MentoringModel::Importer.new(@mentoring_model, csv_content)
    assert importer.import.successful?
    assert_equal ["Goal 1", "Goal 2"], @mentoring_model.reload.mentoring_model_goal_templates.collect(&:title)
    assert_equal ["Milestone 1", "Milestone 2"], @mentoring_model.reload.mentoring_model_milestone_templates.collect(&:title)
    assert_equal ["Task 1", "Task 2", "Task 3"], @mentoring_model.mentoring_model_milestone_templates[0].mentoring_model_task_templates.collect(&:title)
    assert_equal ["Task 4", "Task 5", "Task 6", "Task 8"], @mentoring_model.mentoring_model_milestone_templates[1].mentoring_model_task_templates.collect(&:title)
    assert_equal ["FM 1", "FM 2", "FM 3"], @mentoring_model.reload.mentoring_model_facilitation_templates.collect(&:subject)
    assert_equal ["FM 1", "FM 2"], @mentoring_model.mentoring_model_milestone_templates[0].mentoring_model_facilitation_templates.collect(&:subject)
    assert_equal ["FM 3"], @mentoring_model.mentoring_model_milestone_templates[1].mentoring_model_facilitation_templates.collect(&:subject)
    fm1, fm2, fm3 = @mentoring_model.reload.mentoring_model_facilitation_templates
    assert_equal "FM 1 Content", fm1.message
    assert_equal 2, fm1.send_on

    all_roles, user_roles, admin_roles = get_roles_from_importer(importer)

    assert @mentoring_model.can_manage_mm_milestones?(all_roles)
    assert @mentoring_model.can_manage_mm_goals?(all_roles)
    assert @mentoring_model.can_manage_mm_tasks?(all_roles)

    assert @mentoring_model.can_manage_mm_meetings?(user_roles)
    assert @mentoring_model.can_manage_mm_messages?(admin_roles)
    assert @mentoring_model.can_manage_mm_engagement_surveys?(admin_roles)
  end

  def test_import_with_teacher_role
    @program.roles.create!(name: 'teacher', for_mentoring: true)

    csv_content = generate_csv_content(:for_teacher => true)
    importer = MentoringModel::Importer.new(@mentoring_model, csv_content)
    assert importer.import.successful?

    assert_equal ["Goal 1", "Goal 2"], @mentoring_model.reload.mentoring_model_goal_templates.collect(&:title)
    assert_equal ["Milestone 1", "Milestone 2"], @mentoring_model.reload.mentoring_model_milestone_templates.collect(&:title)
    assert_equal ["Task 1", "Task 2", "Task 3"], @mentoring_model.mentoring_model_milestone_templates[0].mentoring_model_task_templates.collect(&:title)
    assert_equal ["Task 4", "Task 5", "Task 6", "Task 7","Task 8"], @mentoring_model.mentoring_model_milestone_templates[1].mentoring_model_task_templates.collect(&:title)
    assert_equal ["FM 4", "FM 1", "FM 2", "FM 3"], @mentoring_model.reload.mentoring_model_facilitation_templates.collect(&:subject)
    assert_equal ["FM 1", "FM 2"], @mentoring_model.mentoring_model_milestone_templates[0].mentoring_model_facilitation_templates.collect(&:subject)
    assert_equal ["FM 3", "FM 4"], @mentoring_model.mentoring_model_milestone_templates[1].mentoring_model_facilitation_templates.collect(&:subject)

    fm1, fm2, fm3, fm4 = @mentoring_model.reload.mentoring_model_facilitation_templates
    assert_equal "FM 1 Content", fm2.message
    assert_equal 2, fm2.send_on
    assert_equal "FM 4 Content For Teacher", fm1.message
    assert_equal "11/02/2014", (fm1.specific_date.utc).to_date.strftime('%m/%d/%Y').to_s


    all_roles, user_roles, admin_roles = get_roles_from_importer(importer)

    assert @mentoring_model.can_manage_mm_milestones?(all_roles)
    assert @mentoring_model.can_manage_mm_goals?(all_roles)
    assert @mentoring_model.can_manage_mm_tasks?(all_roles)

    assert @mentoring_model.can_manage_mm_meetings?(user_roles)
    assert @mentoring_model.can_manage_mm_messages?(admin_roles)
    assert @mentoring_model.can_manage_mm_engagement_surveys?(admin_roles)
    assert_equal @mentoring_model.goal_progress_type, MentoringModel::GoalProgressType::AUTO
  end

  def test_failure_for_invalid_engagement_surveys_in_facilitation_templates
    importer = MentoringModel::Importer.new(@mentoring_model, generate_csv_content(invalid_engagement_survey_facilitation_template: true))
    assert_false importer.successful?
    importer.import
    assert_false importer.successful?
  end

  def test_failure_for_invalid_engagement_surveys_in_task_templates
    importer = MentoringModel::Importer.new(@mentoring_model, generate_csv_content(include_survey_invalid: true))
    assert_false importer.successful?
    importer.import
    assert_false importer.successful?
  end

  def test_success_for_invalid_engagement_surveys_in_facilitation_templates_skipping_survey_validations
    importer = MentoringModel::Importer.new(@mentoring_model, generate_csv_content(invalid_engagement_survey_facilitation_template: true))
    assert_false importer.successful?
    importer.import(true)
    assert importer.successful?
  end

  def test_success_for_invalid_engagement_surveys_in_task_templates_skipping_survey_validations
    importer = MentoringModel::Importer.new(@mentoring_model, generate_csv_content(include_survey_invalid: true))
    assert_false importer.successful?
    importer.import(true)
    assert importer.successful?
  end

  def test_manual_goal_progress_type
    assert @mentoring_model.allow_messaging?
    assert_false @mentoring_model.allow_forum?
    assert_false @mentoring_model.allow_due_date_edit?
    assert_equal "Welcome to the discussion board! Ask questions, debate ideas, and share articles. You can follow conversations you like, expand a conversation to view the posts, or get a new conversation started!", @mentoring_model.forum_help_text

    # No change when model row not present
    csv_content = generate_csv_content(include_model: false)
    importer = MentoringModel::Importer.new(@mentoring_model, csv_content)
    assert importer.import.successful?
    assert @mentoring_model.allow_messaging?
    assert_false @mentoring_model.allow_forum?
    assert_false @mentoring_model.allow_due_date_edit?
    assert_equal "Welcome to the discussion board! Ask questions, debate ideas, and share articles. You can follow conversations you like, expand a conversation to view the posts, or get a new conversation started!", @mentoring_model.forum_help_text
    assert_equal @mentoring_model.goal_progress_type, MentoringModel::GoalProgressType::AUTO

    @mentoring_model.object_role_permissions.destroy_all
    csv_content = generate_csv_content(include_model: true, include_goals: false)
    importer = MentoringModel::Importer.new(@mentoring_model, csv_content)
    assert importer.import.successful?
    assert_false @mentoring_model.allow_messaging?
    assert @mentoring_model.allow_forum?
    assert @mentoring_model.allow_due_date_edit?
    assert_equal "Custom Help Text", @mentoring_model.forum_help_text
    assert_equal @mentoring_model.goal_progress_type, MentoringModel::GoalProgressType::AUTO

    @mentoring_model.object_role_permissions.destroy_all
    csv_content = generate_csv_content(include_model: true)
    importer = MentoringModel::Importer.new(@mentoring_model, csv_content)
    assert importer.import.successful?
    assert_equal @mentoring_model.goal_progress_type, MentoringModel::GoalProgressType::MANUAL
  end

  def test_manual_goal_progress_type
    csv_content = generate_csv_content(include_model: true, include_goals: false)
    importer = MentoringModel::Importer.new(@mentoring_model, csv_content)
    assert importer.import.successful?
    assert_equal @mentoring_model.goal_progress_type, MentoringModel::GoalProgressType::AUTO

    @mentoring_model.object_role_permissions.destroy_all
    csv_content = generate_csv_content(include_model: true)
    importer = MentoringModel::Importer.new(@mentoring_model, csv_content)
    assert importer.import.successful?
    assert_equal @mentoring_model.goal_progress_type, MentoringModel::GoalProgressType::MANUAL
  end

  def test_manual_goal_progress_type_without_program_goal_feature
    program = @mentoring_model.program

    csv_content = generate_csv_content(include_model: true)
    importer = MentoringModel::Importer.new(@mentoring_model, csv_content)
    assert importer.import.successful?
  end

  def test_milestone_validation
    program = @mentoring_model.program
    csv_content = generate_csv_content
    csv_content.sub!('Milestone 1', 'Milestone 7')
    importer = MentoringModel::Importer.new(@mentoring_model, csv_content)
    assert_false importer.import.successful?
    assert_equal importer.error_message_key, "feature.mentoring_model.description.error_in_milestones_content"
  end

  def test_goal_validation
    program = @mentoring_model.program
    csv_content = generate_csv_content
    csv_content.sub!('Goal 1', 'Goal 7')
    importer = MentoringModel::Importer.new(@mentoring_model, csv_content)
    assert_false importer.import.successful?
    assert_equal importer.error_message_key, "feature.mentoring_model.description.error_in_goals_content"
  end

  def test_role_validation
    program = @mentoring_model.program
    csv_content = generate_csv_content(include_tasks: false)
    csv_content.sub!('Mentor', 'Mentengen')
    importer = MentoringModel::Importer.new(@mentoring_model, csv_content)
    assert_false importer.import.successful?
    assert_equal importer.error_message_key, "feature.mentoring_model.description.error_in_roles"
    csv_content.sub!('Mentengen', 'Mentor')
    importer = MentoringModel::Importer.new(@mentoring_model, csv_content)
    assert importer.import.successful?

    csv_content = generate_csv_content(include_facilitation_messages: false)
    csv_content.sub!('Mentor', 'Mentengen')
    importer = MentoringModel::Importer.new(@mentoring_model, csv_content)
    assert_false importer.import.successful?
    assert_equal importer.error_message_key, "feature.mentoring_model.description.error_in_roles"
    csv_content.sub!('Mentengen', 'Mentor')
    importer = MentoringModel::Importer.new(@mentoring_model, csv_content)
    assert importer.import.successful?
  end

  private

  def generate_csv_content(options = {})
    options.reverse_merge!({include_model: false,
      include_milestones: true, include_goals: true, include_tasks: true, include_surveys: true,
      include_facilitation_messages: true, include_meetings: true, include_setup_goal_tasks: false
    })
    csv_content = ""
    csv_content = "#MentoringTemplate\nGoal Progress Type,Alter Admin Created Tasks,Enable Messaging,Enable Discussion Board,Help-text describing the purpose of the discussion board.\nManual,Enabled,Disabled,Enabled,Custom Help Text\n" if options[:include_model]
    csv_content += "#Milestones,,,,,,,,\nTitle,Description,,,,,,,\nMilestone 1,Milestone 1 description,,,,,,,\nMilestone 2,,,,,,,,\n,,,,,,,,\n" if options[:include_milestones]
    csv_content += "#Goals,,,,,,,,\nTitle,Description,,,,,,,\nGoal 1,Goal 1 description,,,,,,,\nGoal 2,,,,,,,,\n,,,,,,,,\n" if options[:include_goals]
    milestone_1 = options[:include_milestones] ? 'Milestone 1' : ""
    milestone_2 = options[:include_milestones] ? 'Milestone 2' : ""
    goal_1 = options[:include_goals] ? 'Goal 1' : ""
    goal_2 = options[:include_goals] ? 'Goal 2' : ""
    csv_content += "#Tasks,,,,,,,,\nTitle,Description,Required,Due by,After,Action Item,Action Item ID,Assignee,Goal,Milestone\nTask 1,Task 1 description,Yes,3,Start,,,Mentor,,#{milestone_1}\n#{"Task 2,Task 2 description,No,,,Create Meeting,,Mentee,#{goal_1},#{milestone_1}\n" if options[:include_meetings]}Task 3,,Yes,5,Task 1,,,Mentee,,#{milestone_1}\nTask 4,,No,,,,,Mentor,,#{milestone_2}\nTask 5,,Yes,4,Task 3,,,Mentor,#{goal_2},#{milestone_2}\n#{"Task 6,,No,,,Setup Goal,,Mentee,,#{milestone_2}\n" if options[:include_goals] || options[:include_setup_goal_tasks]}#{"Task 7,Task 7 description,Yes,3,Start,,,Teacher,,#{milestone_2}\n" if options[:for_teacher]}#{"Task 8,,No,,,Take Engagement Survey,"+surveys(:two).id.to_s+",Mentee,,#{milestone_2}\n" if options[:include_surveys]}#{"Task 9,,No,,,Take Engagement Survey,"+34.to_s+",Mentee,,#{milestone_2}\n" if options[:include_survey_invalid]},,,,,,,,\n" if options[:include_tasks]
    csv_content += "#Facilitation Messages,,,,,,,,\nSubject,Content,For,Send after (in days),Milestone,Specific Date,,,\nFM 1,FM 1 Content,\"Mentor, Mentee\",2,#{milestone_1},,,,\nFM 2,FM 2 Content,Mentor,5,#{milestone_1},,,,\nFM 3,FM 3 Content,Mentee,8,#{milestone_2},,,,\n#{"FM 4,FM 4 Content For Teacher,Teacher,"",#{milestone_2},\"11/02/2014\",,,\n" if options[:for_teacher]}#{"FM 5,{{engagement_survey_link_156}}FM 4 Content For Survey Validity,Mentor,"",#{milestone_2},\"11/02/2014\",,,\n" if options[:invalid_engagement_survey_facilitation_template]}" if options[:include_facilitation_messages]
    csv_content
  end

  def get_roles_from_importer(importer)
    [importer.instance_variable_get("@all_roles"), importer.instance_variable_get("@user_roles"), importer.instance_variable_get("@admin_roles")]
  end
end