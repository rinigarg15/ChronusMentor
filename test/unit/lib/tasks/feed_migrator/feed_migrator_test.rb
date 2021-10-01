require_relative './../../../../test_helper'
require_relative './../../../../../lib/chronus_sftp_feed/migrator.rb'
class FeedMigratorTest < ActiveSupport::TestCase
  include FeedMigrator

  def test_generate_general_error_notification
    Airbrake.expects(:notify).times(1)
    expects(:puts).times(1).returns(nil)
    generate_general_error_notification("File not found")
  end

  def test_create_data_import_summary
    login = "primary"
    status = DataImport::Status::SUCCESS
    file = fixture_file_upload(File.join("files","20130205043201_data_feed.csv"), "csv")
    information = {created_count: 0, updated_count: 1, suspended_count: 2}
    organization = programs(:org_primary)

    # success
    status = DataImport::Status::SUCCESS
    di = create_data_import_summary(organization, status, file, information)
    assert_equal organization, di.organization
    assert_equal status, di.status
    assert_equal information[:created_count], di.created_count
    assert_equal information[:updated_count], di.updated_count
    assert_equal information[:suspended_count], di.suspended_count
    assert_equal "20130205043201_data_feed.csv", di.source_file_file_name

    # skipped
    status = DataImport::Status::SKIPPED
    di = create_data_import_summary(organization, status, file, information)
    assert_equal organization, di.organization
    assert_equal status, di.status
    assert_equal information[:created_count], di.created_count
    assert_equal information[:updated_count], di.updated_count
    assert_equal information[:suspended_count], di.suspended_count
    assert_equal "20130205043201_data_feed.csv", di.source_file_file_name

    # fail
    status = DataImport::Status::FAIL
    information[:failure_message] = "Fail msg"
    di = create_data_import_summary(organization, status, file, information)
    assert_equal organization, di.organization
    assert_equal status, di.status
    assert_equal information[:failure_message], di.failure_message
    assert_equal "20130205043201_data_feed.csv", di.source_file_file_name
  end

  def test_unsupported_profile_question_type
    organization = programs(:org_primary)
    unsupported_profile_questions = organization.profile_questions[0..5]
    begin
      raise UnsupportedProfileQuestiontype, unsupported_profile_questions
    rescue => error
      assert_equal unsupported_profile_questions, error.invalid_profile_questions
      assert_equal "FeedMigrator::UnsupportedProfileQuestiontype", error.class.name
      assert_equal "Unsupported Type Questions: "+error.invalid_profile_questions.collect{|pq| "'#{pq.question_text}'"}.to_sentence, get_failure_message_from_error(error)
    end
  end

  def test_fill_org_level_migration_status_if_absent
    organization = Organization.first
    sftp_user_name = "org1"
    org_level_migration_status = {}
    fill_org_level_migration_status_if_absent(org_level_migration_status, sftp_user_name, organization)
    assert_equal [], org_level_migration_status[sftp_user_name][:skipped_migrations]
    assert_equal [], org_level_migration_status[sftp_user_name][:main_migration]
    assert_equal organization, org_level_migration_status[sftp_user_name][:organization]
  end

  def test_get_source_keys_directory
    sftp_user_name = "org1"
    source_info = {}
    dir1, key1 = get_source_keys_directory(sftp_user_name, source_info)
    assert_equal "org1/latest/", dir1
    assert_equal "org1/secret_keys", key1
  end

  def test_get_objects_to_be_archived
    t = mock()
    source_directory = "dir1"
    t.expects(:with_prefix).returns([])
    t2 = mock()
    t2.expects(:objects).returns(t)
    assert_equal [], get_objects_to_be_archived(t2, source_directory)
  end

  def test_get_keys_for_migration
    t = mock()
    keys_directory = "dir1"
    t.expects(:with_prefix).returns([])
    t2 = mock()
    t2.expects(:objects).returns(t)
    assert_equal [], get_objects_to_be_archived(t2, keys_directory)
  end

  def test_get_local_file_name
    sftp_user_name = "org1"
    object = mock()
    object.expects(:key).returns("test1")
    assert_equal "/tmp/org1_tmp_test1", get_local_file_name(sftp_user_name, object)
  end

  def test_get_objects_to_be_archived_and_keys_for_migration
    bucket = mock()
    sftp_user_name = "org1"
    source_info = {}
    self.expects(:get_objects_to_be_archived).with(bucket, "org1/latest/").returns("object")
    self.expects(:get_keys_for_migration).with(bucket, "org1/secret_keys").returns("keys")
    objects_to_be_archived, keys_for_migration = get_objects_to_be_archived_and_keys_for_migration(bucket, sftp_user_name, source_info)
    assert_equal "object", objects_to_be_archived
    assert_equal "keys", keys_for_migration
  end

  def test_run_feed_migration_for_organization_with_login
    org = Organization.first
    bucket = mock()
    org_level_migration_status = {}
    feed_import = mock()
    feed_import.expects(:sftp_user_name).returns("org1")
    feed_import.expects(:organization).returns(org)
    feed_import.expects(:get_source_options).returns({ :source_list => [{ :encrypted => true }]})
    t = mock()
    self.stubs(:get_objects_to_be_archived_and_keys_for_migration).returns([t, []])
    t.expects(:empty?).returns(false)
    AccountMonitor::MonitoringSftp.stubs(:clear_skip_feed_migration).returns(true)
    self.stubs(:get_feed_object_from_objects_to_be_archived).returns(t)
    self.stubs(:get_local_file_name).returns("test_file.txt")
    self.stubs(:feed_migrator_logger)
    File.stubs(:open)
    t2 = mock()
    t2.expects(:run).returns(false)
    t2.stubs(:info).returns([{:suspended_count => 0}])
    self.stubs(:update_main_and_skipped_migrations).never
    ChronusSftpFeed::Migrator.expects(:new).returns(t2)
    AccountMonitor::MonitoringSftp.expects(:skip_feed_migration).returns(true)
    AccountMonitor::MonitoringSftp.expects(:skip_feed_migration_status).returns(true)
    run_feed_migration_for_organization_with_login(feed_import, bucket, org_level_migration_status)
  end

  def test_invalid_row_data
    organization = programs(:org_primary)
    profile_questions = organization.profile_questions
    e1 = InvalidRowData::Error.new({error_obj: profile_questions[0], row: 2, message: "Invalid answers"})
    e2 = InvalidRowData::Error.new({error_obj: profile_questions[1], row: 5, message: "Invalid answers"})
    errors = [e1, e2]
    begin
      raise InvalidRowData, errors
    rescue => error
      assert_equal "FeedMigrator::InvalidRowData", error.class.name
      assert_equal errors, error.error_objects
      assert_equal 2, error.error_objects[0].row
      assert_equal "Invalid answers", error.error_objects[0].message
      assert_equal profile_questions[0], error.error_objects[0].error_object
    end
  end

  def test_feed_migrator_logger
    expects(:puts).times(1).returns(nil)
    feed_migrator_logger "test"
  end

  def test_update_main_and_skipped_migrations
    self.expects(:create_data_import_summary_and_delete_file).returns("test")
    organization = Organization.first
    sftp_user_name = "org1"
    org_level_migration_status = {}
    org_level_migration_status[sftp_user_name] = {}
    org_level_migration_status[sftp_user_name][:organization] = organization
    org_level_migration_status[sftp_user_name][:skipped_migrations] = []
    org_level_migration_status[sftp_user_name][:main_migration] = []
    object = mock()
    options = { :sftp_user_name => sftp_user_name, :organization => organization, :status => true, :info => {} }
    update_main_and_skipped_migrations(org_level_migration_status, [object], object, options)
    assert_equal ["test"], org_level_migration_status[sftp_user_name][:main_migration]
    assert_equal [], org_level_migration_status[sftp_user_name][:skipped_migrations]
  end

  def test_get_failure_message_from_error
    malformed_csv_error = CSV::MalformedCSVError.new("Explanation")
    assert_equal "Malformed CSV File: Explanation", get_failure_message_from_error(malformed_csv_error)
    sample_profile_questions = [profile_questions(:multi_choice_q), profile_questions(:private_q)]
    unsupported_profile_questions_error = UnsupportedProfileQuestiontype.new(sample_profile_questions)
    assert_equal "Unsupported Type Questions: 'What is your name' and 'What is your favorite location stop'", get_failure_message_from_error(unsupported_profile_questions_error)
    invalid_rows_error = InvalidRowData.new([
        InvalidRowData::Error.new({error_obj: sample_profile_questions[0], row: 2, message: "Response 1"}),
        InvalidRowData::Error.new({error_obj: sample_profile_questions[1], row: 5, message: "Pesponse 2"})
    ])
    assert_equal "The following rows contains invalid data:\nRow 2. Response 1 \nRow 5. Pesponse 2 \n", get_failure_message_from_error(invalid_rows_error)
  end

  def test_send_email_notification_ok
    params = {}
    login = "primary_org"
    organization = programs(:org_primary)
    params[login] = {}
    params[login][:skipped_migrations] = []
    params[login][:organization] = organization
    params[login][:main_migration] = [create_data_import]
    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      send_email_notification(params)
      mail = ActionMailer::Base.deliveries.last
      assert_equal "Customer Feed Migration Status Report", mail.subject
      mail_body = mail.body
      assert_match mail_body, /#{organization.name}/
      assert_match mail_body, /#{organization.subdomain}/
      assert params[login][:main_migration][0].success?
      assert_match mail_body, /Success/
    end
  end

  def test_send_email_notification_fail
    params = {}
    login = "primary_org"
    organization = programs(:org_primary)
    params[login] = {}
    params[login][:skipped_migrations] = []
    params[login][:organization] = organization
    fail_reason = "fail reason"
    params[login][:main_migration] = [create_data_import({status: DataImport::Status::FAIL, failure_message: fail_reason})]
    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      send_email_notification(params)
      mail = ActionMailer::Base.deliveries.last
      assert_equal "Customer Feed Migration Status Report", mail.subject
      mail_body = mail.body
      assert_match mail_body, /#{organization.name}/
      assert_match mail_body, /#{organization.subdomain}/
      assert_false params[login][:main_migration][0].success?
      assert_match mail_body, /Failed/
      assert_match mail_body, /#{fail_reason}/
    end
  end

  def test_send_email_notification_multi_org
    params = {}

    # org 1
    org1 = programs(:org_primary)
    setup_params(params, "primary_org", org1)

    # org 2
    org2 = programs(:org_anna_univ)
    setup_params(params, "annauniv", org2)

    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      send_email_notification(params)
      mail = ActionMailer::Base.deliveries.last
      assert_equal "Customer Feed Migration Status Report", mail.subject
      mail_body = mail.body
      assert_match mail_body, /#{org1.name}/
      assert_match mail_body, /#{org1.subdomain}/
      assert_match mail_body, /#{org2.name}/
      assert_match mail_body, /#{org2.subdomain}/
    end
  end

  def test_send_email_notification_failure
    InternalMailer.expects(:data_feed_migration_status_notification_to_chronus).times(1).raises("Some Network Error")
    expects(:feed_migrator_logger).times(1).returns(nil)
    send_email_notification({})
  end

  def test_send_email_notification_success_when_migration_failure
    params = {}
    login = "primary_org"
    organization = programs(:org_primary)
    params[login] = {}
    params[login][:skipped_migrations] = []
    params[login][:organization] = organization
    fail_reason = "fail reason"
    params[login][:main_migration] = []
    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      send_email_notification(params)
    end
  end

  def test_feed_migrator_daily_feed_success
    params = {}
    org1 = programs(:org_primary)
    org1.create_feed_import_configuration!(frequency: 1.day.to_i, enabled: true, sftp_user_name: "coke")
    setup_params(params, "coke", org1)
    stub_feed_migrator(params, true)
    self.stubs(:run_feed_migration_for_organization_with_login).returns(true)
    migrate(false, "coke")
    mail = ActionMailer::Base.deliveries.last
    assert_equal "Customer Feed Migration Status Report", mail.subject
    mail_body = mail.body
    assert_match mail_body, /Success/
  end

  def test_feed_migrator_daily_feed_fail
    params = {}
    login = "coke"
    setup_params(params, "coke", programs(:org_primary))
    programs(:org_primary).create_feed_import_configuration!(frequency: 1.day.to_i, enabled: true, sftp_user_name: "coke")
    params[login] = {}
    params[login][:organization] = programs(:org_primary)

    fail_reason = "test fail reason"
    params[login][:main_migration] = [create_data_import({status: DataImport::Status::FAIL, failure_message: fail_reason})]
    stub_feed_migrator(params, false)
    self.stubs(:run_feed_migration_for_organization_with_login).raises(UnsupportedProfileQuestiontype)

    Airbrake.expects(:notify).times(1)
    expects(:puts).times(1).returns(nil)
    migrate(false, "coke")
    mail = ActionMailer::Base.deliveries.last
    mail_body = mail.body
    assert_match mail_body, /Failed/
  end

  private

  def setup_params(params, login, org)
    params[login] = {}
    params[login][:skipped_migrations] = [create_data_import(status: DataImport::Status::SKIPPED, organization_id: org.id)]
    params[login][:organization] = org
    params[login][:main_migration] = [create_data_import(organization_id: org.id)]
  end

  def stub_feed_migrator(params, success)
    self.stubs(:set_credentials_and_get_bucket_name).returns("Dummy")
    self.stubs(:send_email_notification).returns(InternalMailer.data_feed_migration_status_notification_to_chronus(params, true).deliver_now)
  end

end