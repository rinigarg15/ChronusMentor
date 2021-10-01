require_relative './../test_helper.rb'

class EngagementSurveyTest < ActiveSupport::TestCase

  def test_has_associated_tasks_in_active_groups_or_templates
    survey = surveys(:two)
    assert_false survey.has_associated_tasks_in_active_groups_or_templates?

    task_template = create_mentoring_model_task_template(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id)
    assert survey.has_associated_tasks_in_active_groups_or_templates?
    task_template.destroy
    assert_false survey.has_associated_tasks_in_active_groups_or_templates?

    task = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id)
    assert task.group.active?
    assert survey.has_associated_tasks_in_active_groups_or_templates?
    Program.any_instance.stubs(:active_group_ids).returns([])
    assert_false survey.has_associated_tasks_in_active_groups_or_templates?
  end

  def test_assigned_overdue_tasks
    survey = surveys(:two)
    assert_equal [], survey.assigned_overdue_tasks
    assert_difference "MentoringModel::Task.count", 1 do
      @task = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, required: true, due_date: Date.today - 10.days)
    end
    assert_equal [@task.id], survey.reload.assigned_overdue_tasks.pluck(:id)

    assert_difference "MentoringModel::Task.count", 1 do
      @task2 = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, required: true, due_date: Date.today + 10.days)
    end
    assert_equal 1, survey.reload.assigned_overdue_tasks.count

    assert_difference "MentoringModel::Task.count", 1 do
      @task3 = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, required: true, due_date: Date.today - 10.days)
    end
    @task3.update_attribute(:connection_membership_id, nil)
    assert_equal 1, survey.reload.assigned_overdue_tasks.count

    group = @task.group
    group.update_attribute(:status, Group::Status::DRAFTED)
    assert_equal 0, survey.reload.assigned_overdue_tasks.count

    group.termination_mode = Group::TerminationMode::ADMIN
    group.update_attribute(:status, Group::Status::CLOSED)
    assert_equal 0, survey.reload.assigned_overdue_tasks.count

    not_complete_reason = group_closure_reasons(:group_closure_reasons_2)
    group.update_attribute(:closure_reason_id, not_complete_reason.id)
    assert_equal 0, survey.reload.assigned_overdue_tasks.count

    complete_reason = group_closure_reasons(:group_closure_reasons_1)
    group.update_attribute(:closure_reason_id, complete_reason.id)
    assert_equal 1, survey.reload.assigned_overdue_tasks.count
  end

  def test_get_user_for_campaign
    s = surveys(:two)
    task = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: s.id, required: true, due_date: Date.today - 10.days)
    assert_equal task.user, s.get_user_for_campaign(task)
  end

  def test_date_filter_default
    program =  programs(:no_mentor_request_program)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)

    survey = surveys(:progress_report)
    group = groups(:no_mreq_group)
    mentoring_model = program.default_mentoring_model
    mentoring_model.update_attribute(:should_sync, true)
    group.update_attribute(:mentoring_model_id, mentoring_model.id)
    tem_task1 = create_mentoring_model_engagement_survey_task_template(role_id: program.roles.find{|r| r.name == RoleConstants::MENTOR_NAME }.id, :action_item_id => survey.id, :mentoring_model_id => mentoring_model.id)

    options = {:due_date => program.created_at + 1.days, :created_at => "July 04, 2016", :action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, :required => true, :mentoring_model_task_template_id => tem_task1.id, :action_item_id => survey.id, :group_id => group.id }
   
    task1 = create_mentoring_model_task(options)
    options.merge!(:user => users(:no_mreq_mentor))
    options.merge!(:group => groups(:no_mreq_group))
    task2 = create_mentoring_model_task(options)
    
    task_ids_after_date_filter = survey.date_filter_applied(program.created_at, Time.now.utc.to_date.at_beginning_of_day)
    assert_equal task_ids_after_date_filter, [task1.id, task2.id]
  end

  def test_date_filter_applied
    program =  programs(:no_mentor_request_program)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    survey = surveys(:progress_report)
    group = groups(:no_mreq_group)
    mentoring_model = program.default_mentoring_model
    mentoring_model.update_attribute(:should_sync, true)
    group.update_attribute(:mentoring_model_id, mentoring_model.id)
    tem_task1 = create_mentoring_model_engagement_survey_task_template(role_id: program.roles.find{|r| r.name == RoleConstants::MENTOR_NAME }.id, :action_item_id => survey.id, :mentoring_model_id => mentoring_model.id)

    options = {:due_date => 3.weeks.ago, :created_at => "July 04, 2016", :action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, :required => true, :mentoring_model_task_template_id => tem_task1.id, :action_item_id => survey.id, :group_id => group.id }
   
    task1 = create_mentoring_model_task(options)
    options.merge!(:user => users(:no_mreq_mentor))
    options.merge!(:group => groups(:no_mreq_group))
    task2 = create_mentoring_model_task(options)

    filter_params = {"0"=>{"field"=>"date", "operator"=>"eq", "value"=>"July 06, 2016"}, "1"=>{"field"=>"date", "operator"=>"eq", "value"=>2.weeks.ago}}
    filter_params = SurveyResponsesDataService::FilterResponses.dynamic_filter_params({:filter => {:filters => filter_params}})
    
    task_ids_after_date_filter = survey.date_filter_applied(filter_params[:date][0].to_time, filter_params[:date][1].to_time)
    assert_equal task_ids_after_date_filter, [task1.id, task2.id]
  end

  def test_profile_field_filter_applied
    program =  programs(:no_mentor_request_program)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    survey = surveys(:progress_report)
    group = groups(:no_mreq_group)
    mentoring_model = program.default_mentoring_model
    mentoring_model.update_attribute(:should_sync, true)
    group.update_attribute(:mentoring_model_id, mentoring_model.id)

    options = {:created_at => "July 04, 2016", :action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, :required => true, :action_item_id => survey.id, :group_id => group.id,:user => users(:no_mreq_mentor), :group => groups(:no_mreq_group)}

    task1 = create_mentoring_model_task(options)

    options.merge!(:user => users(:no_mreq_mentor))
    options.merge!(:group => groups(:no_mreq_group))
    task2 = create_mentoring_model_task(options)

    common_answer_1 = common_answers(:q3_name_answer_1)
    common_answer_2 = common_answers(:q3_from_answer_1)
    common_answer_1.update_attribute(:task_id, task1.id)
    common_answer_2.update_attribute(:task_id, task1.id)

    filter_params = {"0"=>{"field"=>"column3", "operator"=>"answered", "value"=>""}}

    srds = SurveyResponsesDataService.new(survey, {:filter => {:filters => filter_params}})
    
    task_ids_after_profile_field_filter = survey.profile_field_filter_applied(srds.user_ids)

    assert_equal task_ids_after_profile_field_filter, [task1.id, task2.id]
  end

  def test_get_object_count
    program = programs(:albers)
    survey = surveys(:progress_report)
    count = survey.get_object_count(survey.survey_answers)
    assert_equal count, 1
  end

  def test_get_answered_ids
    program =  programs(:no_mentor_request_program)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    survey = surveys(:progress_report)
    group = groups(:no_mreq_group)
    mentoring_model = program.default_mentoring_model
    mentoring_model.update_attribute(:should_sync, true)
    group.update_attribute(:mentoring_model_id, mentoring_model.id)

    options = {:created_at => "July 04, 2016", :action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, :required => true, :action_item_id => survey.id, :group_id => group.id,:user => users(:no_mreq_mentor), :group => groups(:no_mreq_group)}

    task1 = create_mentoring_model_task(options)

    options.merge!(:user => users(:no_mreq_mentor))
    options.merge!(:group => groups(:no_mreq_group))
    task2 = create_mentoring_model_task(options)

    ids = survey.get_answered_ids
    assert_equal ids, []

    common_answer_1 = common_answers(:q3_name_answer_1)
    common_answer_2 = common_answers(:q3_from_answer_1)
    common_answer_1.update_attribute(:task_id, task1.id)
    common_answer_2.update_attribute(:task_id, task1.id)

    ids = survey.get_answered_ids
    assert_equal ids, [task1.id]
  end

  def test_create_scrap_for_progress_report
    survey = surveys(:progress_report)
    group = groups(:mygroup)
    sender = group.members.first.member
    assert_difference "Scrap.count" do
      assert_difference "Scraps::Receiver.count" do
        survey.create_scrap_for_progress_report(sender, group, {subject: "Test subject", content: "Test content", attachment: fixture_file_upload(File.join("files", "some_file.txt")) })
      end
    end
    scrap = group.reload.scraps.last
    assert_equal "Progress_Report.pdf", scrap.attachment_file_name
    assert_equal "Test subject", scrap.subject
    assert_equal "Test content", scrap.content
  end

  def test_progress_report_file_name
    survey = surveys(:progress_report)
    SecureRandom.stubs(:hex).returns(1)
    Timecop.freeze(Time.now) do
      assert_equal "progress-report-#{Time.now.to_i}-1", survey.progress_report_file_name
    end
  end

  def test_progress_report_s3_location
    survey = surveys(:progress_report)
    assert_equal "progress_reports_files/#{survey.id}", survey.progress_report_s3_location
  end

  def test_generate_and_email_progress_report_pdf
    survey = surveys(:two)
    group = groups(:mygroup)
    user = group.members.first
    program = group.program
    file = fixture_file_upload(File.join("files", "some_file.txt"))
    EngagementSurvey.expects(:generate_progress_report_pdf).returns(file).twice
    # newly created survey
    assert_difference "Scrap.count" do
      assert_difference "Scraps::Receiver.count" do
        EngagementSurvey.generate_and_email_progress_report_pdf(survey.id, true, user_id: user.id, program_id: program.id, group_id: group.id)
      end
    end
    scrap = group.reload.scraps.last
    assert_equal "New Introduce yourself", scrap.subject
    assert_equal "Hello everyone,\n\nI would like to share my new Introduce yourself with you all. Please find the new Introduce yourself attached to this message as PDF.", scrap.content
    assert_equal "Introduce_yourself.pdf", scrap.attachment_file_name

    # already published survey
    assert_difference "Scrap.count" do
      assert_difference "Scraps::Receiver.count" do
        EngagementSurvey.generate_and_email_progress_report_pdf(survey.id, false, user_id: user.id, program_id: program.id, group_id: group.id)
      end
    end
    scrap = group.reload.scraps.last
    assert_equal "Updated Introduce yourself", scrap.subject
    assert_equal "Hello everyone,\n\nI would like to share my updated Introduce yourself with you all. Please find the updated Introduce yourself attached to this message as PDF.", scrap.content
    assert_equal "Introduce_yourself.pdf", scrap.attachment_file_name
  end
end