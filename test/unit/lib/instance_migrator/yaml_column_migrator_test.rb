require_relative './../../../test_helper'

class YamlColumnMigratorTest < ActiveSupport::TestCase

  def test_migrate_yaml_columns
    migrator = InstanceMigrator::YamlColumnMigrator.new("source_environment", "source_seed")
    migrator.expects(:migrate_response_id_for_survey_answer).once
    migrator.expects(:migrate_mentoring_model_task_and_template).with(MentoringModel::Task).once
    migrator.expects(:migrate_mentoring_model_task_and_template).with(MentoringModel::TaskTemplate).once
    migrator.expects(:migrate_user_state_change).once
    migrator.expects(:migrate_user_csv_import).once
    migrator.expects(:migrate_admin_view).once
    migrator.expects(:migrate_campaigns).once
    migrator.expects(:migrate_ancestry_models).once
    migrator.expects(:migrate_chronus_versions).once
    migrator.expects(:migrate_admin_view_user_caches).once
    migrator.expects(:migrate_connection_memberships).once
    migrator.expects(:migrate_survey_questions).once
    migrator.send(:migrate_yaml_columns)
  end

  def test_migrate_user_state_change
    migrator = InstanceMigrator::YamlColumnMigrator.new("source_environment", "source_seed")
    program = programs(:albers)
    user_state_change = user_state_changes(:user_state_changes_1)
    to_role = roles("#{program.id}_#{RoleConstants::ADMIN_NAME}")
    from_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    setup_user_state_change(user_state_change, to_role, from_role)
    pre_info_hash = ActiveSupport::HashWithIndifferentAccess.new({state: {from: nil, to: "active"}, role: {from: [200], to: [100]}})
    assert_equal pre_info_hash, user_state_change.info_hash(true)
    pre_membership_hash = ActiveSupport::HashWithIndifferentAccess.new({:role => {:from_role => [200], :to_role => [100] }})
    assert_equal pre_membership_hash, user_state_change.connection_membership_info_hash(true)
    migrator.send("migrate_user_state_change")
    expected_hash = ActiveSupport::HashWithIndifferentAccess.new({state: {from: nil, to: "active"}, role: {from: [from_role.id], to: [to_role.id]}})
    assert_equal expected_hash, user_state_change.reload.info_hash(true)
    expected_hash2 = ActiveSupport::HashWithIndifferentAccess.new({ role: {from_role: [from_role.id], to_role: [to_role.id]}})
    assert_equal expected_hash2, user_state_change.reload.connection_membership_info_hash(true)
  end

  def test_migrate_user_csv_import
    user_csv_import = programs(:albers).user_csv_imports.create!(member: members(:f_admin), attachment: fixture_file_upload("/files/csv_import.csv", "text/csv"))
    profile_question = profile_questions(:profile_questions_1)
    setup_user_csv_import(user_csv_import, profile_question)
    pre_hash ={"roles"=>["mentor"], "csv_dropdown_choices"=>{"0"=>"0", "1"=>"1", "2"=>"2", "3"=>"3"}, "profile_dropdown_choices"=>{"3"=>"profile_question_201"}, "processed_params"=>{"0"=>"first_name", "1"=>"last_name", "2"=>"email", "3"=>"profile_question_201"}}
    assert_equal pre_hash, user_csv_import.info_hash
    migrator = InstanceMigrator::YamlColumnMigrator.new("source_environment", "source_seed")
    migrator.send("migrate_user_csv_import")
    expected_hash = {"roles"=>["mentor"], "csv_dropdown_choices"=>{"0"=>"0", "1"=>"1", "2"=>"2", "3"=>"3"}, "profile_dropdown_choices"=>{"3"=>"profile_question_#{profile_question.id}"}, "processed_params"=>{"0"=>"first_name", "1"=>"last_name", "2"=>"email", "3"=>"profile_question_#{profile_question.id}"}}
    assert_equal expected_hash, user_csv_import.reload.info_hash
  end

  def test_migrate_admin_view
    survey_question = common_questions(:q2_from)
    survey_question_choice = question_choices(:q2_from_1)
    profile_question = profile_questions(:single_choice_q)
    question_choice = question_choices(:single_choice_q_1)
    survey = surveys(:surveys_1)
    language = languages(:hindi)
    admin_view = admin_views(:admin_views_1)
    program_id = admin_view.program.program_ids.first
    role = roles("#{programs(:albers).id}_#{RoleConstants::ADMIN_NAME}")
    pre_hash = setup_admin_view(admin_view, profile_question, question_choice, survey, survey_question, survey_question_choice, role)
    assert_equal pre_hash, admin_view.reload.filter_params_hash
    migrator = InstanceMigrator::YamlColumnMigrator.new("source_environment", "source_seed")
    migrator.send("migrate_admin_view")
    expected_hash = {"profile"=>{"questions"=>{"questions_1"=>{"question"=>"#{profile_question.id}", "value"=>"", "choice" => "#{question_choice.id}"}}}, "language" => ["0", "#{language.id}"], "survey"=>{"user"=>{"users_status"=>"", "survey_id"=>"#{survey.id}"}, "survey_questions"=>{"questions_1"=>{"survey_id"=>"#{survey.id}", "question"=>"answers#{survey_question.id}", "operator"=>"", "value"=>"", "choice"=>"#{survey_question_choice.id}"}}}, "program_role_state" => { AdminView::ProgramRoleStateFilterObjectKey::ALL_MEMBERS => false, AdminView::ProgramRoleStateFilterObjectKey::INCLUSION => AdminView::ProgramRoleStateFilterObjectKey::INCLUDE, "filter_conditions" => { "parent_filter_1" => {"child_filter_1" => {"program" => [program_id.to_s]}}}}}
    assert_equal expected_hash, admin_view.reload.filter_params_hash
    teardown_db
  end

  def test_migrate_chronus_versions
    pre_hash = {"user_id"=>[302, 303]}
    chronus_version = setup_chronus_versions(pre_hash)
    assert_equal pre_hash, chronus_version.reload.modifications
    migrator = InstanceMigrator::YamlColumnMigrator.new("source_environment", "source_seed")
    migrator.send("migrate_chronus_versions")
    expected_hash = {"user_id"=>[users(:ram).id, users(:rahim).id]}
    assert_equal expected_hash, chronus_version.reload.modifications
  end

  def test_migrate_chronus_versions_with_items_not_present
    pre_hash = {"user_id"=>[1000, 1001]}
    chronus_version = setup_chronus_versions(pre_hash)
    assert_equal pre_hash, chronus_version.reload.modifications
    migrator = InstanceMigrator::YamlColumnMigrator.new("source_environment", "source_seed")
    migrator.send("migrate_chronus_versions")
    expected_hash = {"user_id"=>[0, 0]}
    assert_equal expected_hash, chronus_version.reload.modifications
  end

  def test_migrate_chronus_versions_with_one_entry_nil
    pre_hash = {"user_id"=>[302, nil]}
    chronus_version = setup_chronus_versions(pre_hash)
    assert_equal pre_hash, chronus_version.reload.modifications
    migrator = InstanceMigrator::YamlColumnMigrator.new("source_environment", "source_seed")
    migrator.send("migrate_chronus_versions")
    expected_hash = {"user_id"=>[users(:ram).id, nil]}
    assert_equal expected_hash, chronus_version.reload.modifications
  end

  def test_migrate_chronus_versions_for_action_item_id
    pre_hash = { "action_item_id" => [402, 403] }
    chronus_version, engagement_surveys = setup_chronus_versions_for_mentoring_model_task_template(pre_hash)
    assert_equal pre_hash, chronus_version.reload.modifications
    migrator = InstanceMigrator::YamlColumnMigrator.new("source_environment", "source_seed")
    migrator.send("migrate_chronus_versions")
    expected_hash = { "action_item_id" => engagement_surveys.map(&:id) }
    assert_equal expected_hash, chronus_version.reload.modifications
  end

  def test_migrate_mentoring_model_task_and_template
    # action_item_id in mentoring model task template
    task_template = create_mentoring_model_task_template
    MentoringModel::TaskTemplate.where(id: task_template.id).update_all(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: "502", source_audit_key: "source_environment_source_seed_501")
    Survey.where(id: surveys(:two).id).update_all(source_audit_key: "source_environment_source_seed_502")
    assert_equal 502, task_template.reload.action_item_id
    migrator = InstanceMigrator::YamlColumnMigrator.new("source_environment", "source_seed")
    migrator.send("migrate_mentoring_model_task_and_template", MentoringModel::TaskTemplate)
    assert_equal surveys(:two).id, task_template.reload.action_item_id

    # action_item_id in mentoring_model_task
    task = create_mentoring_model_task
    MentoringModel::Task.where(id: task.id).update_all(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: "502", source_audit_key: "source_environment_source_seed_503")
    assert_equal 502, task.reload.action_item_id
    migrator.send("migrate_mentoring_model_task_and_template", MentoringModel::Task)
    assert_equal surveys(:two).id, task.reload.action_item_id
  end

  def test_migrate_response_id_for_survey_answer
    survey_answer1 = common_answers(:q3_name_answer_1)
    survey_answer2 = common_answers(:q3_name_answer_2)
    SurveyAnswer.where(id: survey_answer1.id).update_all(source_audit_key: "source_environment_source_seed_602")
    SurveyAnswer.where(id: survey_answer2.id).update_all(source_audit_key: "source_environment_source_seed_603")
    assert_equal 1, survey_answer1.reload.response_id
    assert_equal 2, survey_answer2.reload.response_id
    max_id = SurveyAnswer.unscoped.maximum(:response_id)
    migrator = InstanceMigrator::YamlColumnMigrator.new("source_environment", "source_seed")
    migrator.send("migrate_response_id_for_survey_answer")
    assert_equal 1000 + max_id + 1, survey_answer1.reload.response_id
    assert_equal 1000 + max_id + 2, survey_answer2.reload.response_id
  end

  def test_migrate_campaigns
    admin_view = admin_views(:admin_views_1)
    campaign = cm_campaigns(:cm_campaigns_1)
    pre_hash = {1 => [702]}
    CampaignManagement::AbstractCampaign.where(id: campaign.id).update_all(source_audit_key: "source_environment_source_seed_701", trigger_params: pre_hash)
    AdminView.where(id: admin_view.id).update_all(source_audit_key: "source_environment_source_seed_702")
    assert_equal pre_hash, campaign.reload.trigger_params

    migrator = InstanceMigrator::YamlColumnMigrator.new("source_environment", "source_seed")
    migrator.send("migrate_campaigns")
    expected_hash = {1 => [admin_view.id]}
    assert_equal expected_hash, campaign.reload.trigger_params
  end

  def test_migrate_ancestry
    topic = create_topic
    user = users(:f_admin)
    post1 = create_post(:topic => topic)
    #Create a child post
    post2 = create_post(:topic => topic, :parent_id => post1.id)
    Post.where(id: post1.id).update_all(source_audit_key: "source_environment_source_seed_802")
    Post.where(id: post2.id).update_all(source_audit_key: "source_environment_source_seed_803", ancestry: "802")
    assert_nil post1.reload.ancestry
    assert_equal "802", post2.reload.ancestry
    migrator = InstanceMigrator::YamlColumnMigrator.new("source_environment", "source_seed")
    migrator.send("migrate_ancestry_models")
    assert_nil post1.reload.ancestry
    assert_equal post1.id.to_s, post2.reload.ancestry
  end

  def test_migrate_admin_view_user_caches
    admin_view_user_cache = admin_views(:admin_views_11).admin_view_user_cache
    AdminViewUserCache.find_by(id: admin_view_user_cache).update_columns(source_audit_key: "source_environment_source_seed_899")
    User.find_by(id: users(:f_admin).id).update_columns(source_audit_key: "source_environment_source_seed_900")
    User.find_by(id: users(:f_mentor).id).update_columns(source_audit_key: "source_environment_source_seed_901")
    admin_view_user_cache.update_columns(user_ids: "900,901")
    migrator = InstanceMigrator::YamlColumnMigrator.new("source_environment", "source_seed")
    migrator.send("migrate_admin_view_user_caches")

    assert_equal "#{users(:f_admin).id},#{users(:f_mentor).id}", admin_view_user_cache.reload.user_ids
  end

  def test_migrate_connection_memberships
    connection_membership = connection_memberships(:connection_memberships_1)
    Connection::Membership.find_by(id: connection_membership.id).update_columns(source_audit_key: "source_environment_source_seed_899")
    User.find_by(id: users(:f_admin).id).update_columns(source_audit_key: "source_environment_source_seed_900")
    connection_membership.update_columns(last_applied_task_filter: {user_info: "900"})
    migrator = InstanceMigrator::YamlColumnMigrator.new("source_environment", "source_seed")
    migrator.send("migrate_connection_memberships")

    assert_equal "#{users(:f_admin).id}", connection_membership.reload.user_info
  end

  def test_migrate_survey_questions
    survey_question = common_questions(:q2_from)
    survey_question_choice = question_choices(:q2_from_1)
    survey_question_choice2 = question_choices(:q2_from_2)
    QuestionChoice.find_by(id: survey_question_choice.id, ref_obj_type: "CommonQuestion").update_columns(source_audit_key: "source_environment_source_seed_209")
    QuestionChoice.find_by(id: survey_question_choice2.id, ref_obj_type: "CommonQuestion").update_columns(source_audit_key: "source_environment_source_seed_210")
    SurveyQuestion.find_by(id: survey_question.id).update_columns(source_audit_key: "source_environment_source_seed_204")
    survey_question.update_columns(positive_outcome_options: "209,210", positive_outcome_options_management_report: "210")
    migrator = InstanceMigrator::YamlColumnMigrator.new("source_environment", "source_seed")
    migrator.send("migrate_survey_questions")

    assert_equal "#{survey_question_choice.id},#{survey_question_choice2.id}", survey_question.reload.positive_outcome_options
    assert_equal "#{survey_question_choice2.id}", survey_question.reload.positive_outcome_options_management_report
  end

  def test_check_user_state_change_have_yaml_changes
    file_content = File.read("#{Rails.root}/app/models/user_state_change.rb")
    # If any key is added/modified in the info or connection_membership_info hash please ensure it is handled in InstanceMigrator::YAMLColumnMigrator#migrate_user_state_change
    assert_equal "1fb329db6c7db5bbe2b0a9599337381ca14803da", Digest::SHA1.hexdigest(file_content)
  end

  def test_check_user_csv_import_have_yaml_changes
    # If any key is added/modified in the info hash please ensure it is handled in InstanceMigrator::YAMLColumnMigrator#migrate_user_csv_import
    file_content1 = File.read("#{Rails.root}/app/models/user_csv_import.rb")
    assert_equal "f94693658e7c430a5522789704a011219d0b4562", Digest::SHA1.hexdigest(file_content1)
  end

  private

  def setup_user_state_change(user_state_change, to_role, from_role)
    info = YAML.load(user_state_change.info)
    info[:role] = {:from => [200], :to => [100] }
    user_state_change.set_info(info)
    connection_membership_info = YAML.load(user_state_change.connection_membership_info)
    connection_membership_info[:role] = {:from_role => [200], :to_role => [100] }
    user_state_change.set_connection_membership_info(connection_membership_info)
    user_state_change.save!
    UserStateChange.where(id: user_state_change.id).update_all(source_audit_key: "source_environment_source_seed_1")
    Role.where(id: to_role.id).update_all(source_audit_key: "source_environment_source_seed_100")
    Role.where(id: from_role.id).update_all(source_audit_key: "source_environment_source_seed_200")
  end

  def setup_user_csv_import(user_csv_import, profile_question)
    ProfileQuestion.where(id: profile_question.id).update_all(source_audit_key: "source_environment_source_seed_201")
    UserCsvImport.where(id: user_csv_import.id).update_all(source_audit_key: "source_environment_source_seed_101")
    csv_dropdown_choices = {"0"=>"0", "1"=>"1", "2"=>"2", "3"=>"3"}
    profile_dropdown_choices = {"3"=>"profile_question_201"}
    user_csv_import.update_or_save_role([RoleConstants::MENTOR_NAME])
    user_csv_import.save_mapping_params(csv_dropdown_choices, profile_dropdown_choices)
  end

  def setup_admin_view(admin_view, profile_question, question_choice, survey, survey_question, survey_question_choice, role)
    setup_db
    ProfileQuestion.where(id: profile_question.id).update_all(source_audit_key: "source_environment_source_seed_202")
    QuestionChoice.where(id: question_choice.id, ref_obj_type: "ProfileQuestion").update_all(source_audit_key: "source_environment_source_seed_208")
    QuestionChoice.where(id: survey_question_choice.id, ref_obj_type: "CommonQuestion").update_all(source_audit_key: "source_environment_source_seed_209")
    Survey.where(id: survey.id).update_all(source_audit_key: "source_environment_source_seed_203")
    SurveyQuestion.where(id: survey_question.id).update_all(source_audit_key: "source_environment_source_seed_204")
    Role.where(id: role.id).update_all(source_audit_key: "source_environment_source_seed_207")
    Program.where(id: [admin_view.program.programs.first.id]).update_all(source_audit_key: "source_environment_source_seed_232")
    filter_params = {"profile"=>{"questions"=>{"questions_1"=>{"question"=>"202", "value"=>"", "choice"=> "208"}}}, "language" => ["0", "206"],  "survey"=>{"user"=>{"users_status"=>"", "survey_id"=>"203"}, "survey_questions"=>{"questions_1"=>{"survey_id"=>"203", "question"=>"answers204", "operator"=>"", "value"=>"", "choice"=>"209"}}}, "program_role_state" => { AdminView::ProgramRoleStateFilterObjectKey::ALL_MEMBERS => false, AdminView::ProgramRoleStateFilterObjectKey::INCLUSION => AdminView::ProgramRoleStateFilterObjectKey::INCLUDE, "filter_conditions" => { "parent_filter_1" => {"child_filter_1" => {"program" => ["232"]}}}}}
    # admin_view.update_attribute(:filter_params, filter_params.to_yaml)
    AdminView.where(id: admin_view.id).update_all(filter_params: filter_params.to_yaml, source_audit_key: "source_environment_source_seed_205")
    filter_params
  end

  def setup_chronus_versions(modifications)
    event_1 = program_events(:birthday_party)
    event_1.update_attributes!(user_id: users(:rahim).id)
    chronus_version = ChronusVersion.where(item_id: event_1.id, item_type: "ProgramEvent").last
    ChronusVersion.where(id: chronus_version.id).update_all(object_changes: modifications.to_yaml, source_audit_key: "source_environment_source_seed_301")
    User.where(id: users(:ram).id).update_all(source_audit_key: "source_environment_source_seed_302")
    User.where(id: users(:rahim).id).update_all(source_audit_key: "source_environment_source_seed_303")
    chronus_version
  end

  def setup_chronus_versions_for_mentoring_model_task_template(modifications)
    program = programs(:albers)
    engagement_survey_1 = surveys(:two)
    engagement_survey_2 = EngagementSurvey.where.not(id: engagement_survey_1.id).where(program_id: program.id).first

    task_template = create_mentoring_model_task_template(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: engagement_survey_1.id)
    task_template.update_attributes!(action_item_id: engagement_survey_2.id)
    chronus_version = ChronusVersion.where(item_id: task_template.id, item_type: "MentoringModel::TaskTemplate").last
    ChronusVersion.where(id: chronus_version.id).update_all(object_changes: modifications.to_yaml, source_audit_key: "source_environment_source_seed_401")
    Survey.where(id: engagement_survey_1.id).update_all(source_audit_key: "source_environment_source_seed_402")
    Survey.where(id: engagement_survey_2.id).update_all(source_audit_key: "source_environment_source_seed_403")
    [chronus_version, [engagement_survey_1, engagement_survey_2]]
  end

  def setup_db
    ActiveRecord::Base.connection.create_table :temp_common_join_table, force: true, temporary: true do |t|
      t.column :table_name, :string
      t.column :source_j_id, :integer
      t.column :target_j_id, :integer
    end
    ActiveRecord::Base.connection.execute("INSERT INTO temp_common_join_table (table_name, source_j_id, target_j_id) VALUES ('languages', '206', '1')")
  end

  def teardown_db
    ActiveRecord::Base.connection.drop_table(:temp_common_join_table, temporary: true)
  end
end