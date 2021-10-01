require_relative './../../../test_helper'
load 'feed_migrator.rake'

class TestLogs
  # To Stub the CloudWatch Logs.
  def initialize(logger_group, logger_name)
    @logs = []
  end

  def log(text)
    @logs << text.to_s
  end

  def pull_logs
    @logs
  end

  def push_logs
  end

  def delete_log_stream
  end
end

class ChronusSftpFeed::MigratorTest < ActiveSupport::TestCase

  def setup
    super
    ChronusSftpFeed::Migrator.expects(:logger).at_least_once.returns(nil)
    ChronusSftpFeed::Configuration.any_instance.stubs(:logger).returns("TestLogs")
    @organization = programs(:org_primary)
    @file = get_file_path("user_import_success")
    @options = {
      import_file_name: @file,
      secondary_questions_map: {}
    }
    @options = ActiveSupport::HashWithIndifferentAccess.new(@options)
    @feed_import = FeedImportConfiguration.create!(organization: @organization, frequency: 1.day.to_i, enabled: true, sftp_user_name: "org_primary")
    @feed_import.set_config_options!(@options)
  end

  def test_migrator
    assert_nil @organization.feed_import_configuration.get_config_options[:imported_profile_question_texts]
    migrator1 = ChronusSftpFeed::Migrator.new(@file, @feed_import)
    migrator1.run
    assert_equal 4, migrator1.info[:created_count]
    assert_equal 0, migrator1.info[:updated_count]
    assert_equal 0, migrator1.info[:suspended_count]
    assert_empty migrator1.info[:duplicate_keys]
    assert_empty migrator1.info[:invalid_rows_data]
    assert_equal_unordered ["About Me", "Email", "Gender", "Current Education", "Phone", "Entire Education", "Current Experience", "Work Experience", "Current Publication", "New Publication", "Language", "Current Manager"], @organization.feed_import_configuration.reload.get_config_options[:imported_profile_question_texts]

    migrator2 = ChronusSftpFeed::Migrator.new(@file, @feed_import)
    migrator2.run
    assert_equal 0, migrator2.info[:created_count]
    assert_equal 0, migrator2.info[:updated_count]
    assert_equal 0, migrator2.info[:suspended_count]
    assert_empty migrator2.info[:duplicate_keys]
    assert_empty migrator2.info[:invalid_rows_data]
  end

  def test_migrator_with_suspension_enabled
    @feed_import.set_config_options!(@options.merge(suspension_required: true))
    all_csv_email = CSV.read(@file)[1..-1].collect { |record| record[2] }
    to_suspend_count = @organization.members.where("admin = ? AND email NOT IN (?)", false, all_csv_email).count
    migrator = ChronusSftpFeed::Migrator.new(@file, @feed_import)
    migrator.run
    assert_equal 4, migrator.info[:created_count]
    assert_equal 0, migrator.info[:updated_count]
    assert_equal to_suspend_count, migrator.info[:suspended_count]
    assert_empty migrator.info[:duplicate_keys]
    assert_empty migrator.info[:invalid_rows_data]
  end

  def test_elasticsearch_dj_enqueue_for_migrator_with_suspension_enabled
    @feed_import.set_config_options!(@options.merge(suspension_required: true))
    @file = get_file_path("user_import_fail1")
    all_csv_email = CSV.read(@file)[1..-1].collect { |record| record[2] }
    to_suspend_count = @organization.members.where("admin = ? AND email NOT IN (?)", false, all_csv_email).count
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    create_mentor_offer(:mentor => users(:f_mentor), :group => groups(:mygroup), :max_connection_limit => 2)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, any_parameters).at_least_once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Member, any_parameters).at_least_once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(MentorRequest, any_parameters).at_least_once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(MeetingRequest, any_parameters).at_least_once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(MentorOffer, any_parameters).at_least_once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(UserStateChange, any_parameters).at_least_once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(MentorRecommendation, any_parameters).at_least_once
    migrator = ChronusSftpFeed::Migrator.new(@file, @feed_import)
    migrator.run
    assert_equal 0, migrator.info[:created_count]
    assert_equal 0, migrator.info[:updated_count]
    assert_equal to_suspend_count, migrator.info[:suspended_count]
    assert_empty migrator.info[:duplicate_keys]
    assert_equal 3, migrator.info[:invalid_rows_data].count
  end

  def test_skip_migration_run_test
    migrator = ChronusSftpFeed::Migrator.new(@file, @feed_import)
    AccountMonitor::MonitoringSftp.stubs(:sftp_monitor).returns(false)
    assert_equal false, migrator.run
    migrator = ChronusSftpFeed::Migrator.new(@file, @feed_import)
    AccountMonitor::MonitoringSftp.stubs(:sftp_monitor).returns(true)
    assert_equal true, migrator.run
    migrator = ChronusSftpFeed::Migrator.new(@file, @feed_import)
    AccountMonitor::MonitoringSftp.stubs(:sftp_monitor).returns(false)
    assert_equal true, migrator.run(true)
    migrator = ChronusSftpFeed::Migrator.new(@file, @feed_import)
    AccountMonitor::MonitoringSftp.stubs(:sftp_monitor).returns(true)
    assert_equal true, migrator.run(true)
  end

  def test_migrator_with_suspend_reactivate_logic_map
    # Case 1: Suspend using suspend logic map
    @file = get_file_path("user_suspend_reactivate1")
    @feed_import.set_config_options!(@options.merge(import_file_name: get_file_path("user_suspend_reactivate1"), suspension_required: true, suspend_logic_map: {"Status" => ["Inactive", "Suspended"]}, reactivate_suspended_users: true, reactivate_logic_map: {"Status" => "Active"}))
    all_csv_email = CSV.read(get_file_path("user_suspend_reactivate1"))[1..-1].collect{|record| record[2]}

    migrator_1 = ChronusSftpFeed::Migrator.new(@file, @feed_import)
    migrator_1.run
    assert_equal 3, migrator_1.info[:created_count]
    assert_equal 1, migrator_1.info[:suspended_count]
    assert_equal 3, @organization.members.suspended.where("admin = ? AND email IN (?)", false, all_csv_email).count
    assert_equal ["test_1@example.com"], @organization.members.non_suspended.where("admin = ? AND email IN (?)", false, all_csv_email).pluck(:email)

    # Case 2: Reactivate using reactivate logic map
    @feed_import.set_config_options!(@options.merge(import_file_name: get_file_path("user_suspend_reactivate2"), suspension_required: true, suspend_logic_map: {"Status" => ["Inactive", "Suspended"]}, reactivate_suspended_users: true, reactivate_logic_map: {"Status" => "Active"}))
    @file = get_file_path("user_suspend_reactivate2")
    migrator_2 = ChronusSftpFeed::Migrator.new(@file, @feed_import)
    migrator_2.run
    assert_equal ["test_3@example.com"], @organization.members.suspended.where("admin = ? AND email IN (?)", false, all_csv_email).pluck(:email)
    assert_equal Member::Status::ACTIVE, @organization.members.find_by(email: "rahim@example.com").state
    assert_equal Member::Status::DORMANT, @organization.members.find_by(email: "test_2@example.com").state
    assert_equal 2, migrator_2.info[:updated_count]

    # Case 3: Reactivate without reactivate logic map
    @feed_import.set_config_options!(@options.merge(import_file_name: get_file_path("user_suspend_reactivate2"), suspension_required: true, suspend_logic_map: {"Status" => ["Inactive", "Suspended"]}, reactivate_suspended_users: true))

    migrator_3 = ChronusSftpFeed::Migrator.new(@file, @feed_import)
    migrator_3.run
    assert_empty @organization.members.suspended
    assert_equal 1, migrator_3.info[:updated_count]
  end

  def test_migrator_with_manager_update
    @feed_import.set_config_options!(@options.merge!(secondary_questions_map: { ProfileQuestion::Type::MANAGER.to_s => "Current Manager" }, allow_manager_updates: true ))
    migrator = ChronusSftpFeed::Migrator.new(@file, @feed_import)

    assert_difference "Manager.count", 4 do
      migrator.run
    end
    assert_equal 4, migrator.info[:created_count]
    assert_equal 0, migrator.info[:updated_count]
    assert_equal 0, migrator.info[:suspended_count]
    assert_empty migrator.info[:duplicate_keys]
    assert_empty migrator.info[:invalid_rows_data]
  end

  def test_migrator_with_import_question
    pq = @organization.profile_questions.create!(question_text: ChronusSftpFeed::Constant::IMPORT_QUESTION_TEXT, question_type: ProfileQuestion::Type::SINGLE_CHOICE, section: @organization.sections.default_section.first)
    ["Yes" ,"No"].each {|text| pq.question_choices.create!(text: text)}
    @feed_import.set_config_options!(@options.merge!(allow_import_question: true, import_question_text: ChronusSftpFeed::Constant::IMPORT_QUESTION_TEXT))
    migrator = ChronusSftpFeed::Migrator.new(@file, @feed_import)

    migrator.run
    assert_equal 4, migrator.info[:created_count]
    assert_equal 0, migrator.info[:updated_count]
    assert_equal 0, migrator.info[:suspended_count]
    assert_empty migrator.info[:duplicate_keys]
    assert_empty migrator.info[:invalid_rows_data]

    imported_question = @organization.profile_questions.joins(:translations).where("profile_question_translations.question_text = ? AND locale = ?", ChronusSftpFeed::Constant::IMPORT_QUESTION_TEXT, I18n.default_locale.to_s).first
    profile_answer = Member.last.profile_answers.where(profile_question_id: imported_question.id).first
    assert_equal ChronusSftpFeed::Constant::IMPORT_QUESTION_ANSWER, profile_answer.answer_value
  end

  def test_migrator_with_ignore_column_headers
    @feed_import.set_config_options!(@options.merge!(ignore_column_headers: ["About Me"]))
    migrator = ChronusSftpFeed::Migrator.new(@file, @feed_import)
    migrator.run
    assert_equal 4, migrator.info[:created_count]
    assert_equal 0, migrator.info[:updated_count]
    assert_equal 0, migrator.info[:suspended_count]
    assert_empty migrator.info[:duplicate_keys]
    assert_empty migrator.info[:invalid_rows_data]
    assert_equal ["First Name", "Last Name", "Email", "Phone", "Gender", "Language", "Current Education", "Entire Education", "Current Experience", "Work Experience", "Current Publication", "New Publication", "Current Manager"], migrator.instance_variable_get("@header")

    @feed_import.set_config_options!(@options.merge!(ignore_column_headers: nil))
    migrator = ChronusSftpFeed::Migrator.new(@file, @feed_import)
    migrator.run
    assert_equal ["First Name", "Last Name", "Email", "Phone", "About Me", "Gender", "Language", "Current Education", "Entire Education", "Current Experience", "Work Experience", "Current Publication", "New Publication", "Current Manager"], migrator.instance_variable_get("@header")
  end

  def test_migrator_with_login_identifiers
    custom_auth = @organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    @feed_import.set_config_options!(@options.merge!(login_identifier_header: "Phone"))
    migrator = ChronusSftpFeed::Migrator.new(@file, @feed_import)

    assert_difference "custom_auth.login_identifiers.count", 3 do
      migrator.run
    end
    assert_equal 4, migrator.info[:created_count]
    assert_equal 0, migrator.info[:updated_count]
    assert_equal 0, migrator.info[:suspended_count]
    assert_empty migrator.info[:duplicate_keys]
    assert_empty migrator.info[:invalid_rows_data]

    login_identifier = custom_auth.login_identifiers.last
    identifier = login_identifier.identifier
    login_identifier.update_attribute(:identifier, "#{identifier}-updated")
    migrator = ChronusSftpFeed::Migrator.new(@file, @feed_import)
    assert_no_difference "LoginIdentifier.count" do
      migrator.run
    end
    assert_equal 0, migrator.info[:created_count]
    assert_equal 1, migrator.info[:updated_count]
    assert_equal 0, migrator.info[:suspended_count]
    assert_equal identifier, login_identifier.reload.identifier
  end

  def test_migrator_error_file
    @organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)

    file = "test/fixtures/files/feed_migrator/20130205043201_rc_create_fast_invalid.csv"
    options = {
      organization: @organization,
      import_file_name: file,
      csv_options: {
        key_mapping: {
          "Email Address" => ChronusSftpFeed::Constant::EMAIL
        }
      },
      login_identifier_header: "Personnel Number",
      use_login_identifier: true
    }
    @feed_import.set_config_options!(options)

    migrator = ChronusSftpFeed::Migrator.new(file, @feed_import)
    migrator.run
    assert_equal 1, migrator.info[:invalid_rows_data].count
    assert_equal ["10", "1629114972", "Gender", "Mal", "Answer text contains an invalid choice"], migrator.info[:invalid_rows_data][0]

    error_data = CSV.read(migrator.info[:error_file_name])
    assert_equal 2, error_data.size
    assert_equal ["row_number", "primary_key", "error_column_heading", "error_data", "error_message"], error_data[0]
    assert_equal ["10", "1629114972", "Gender", "Mal", "Answer text contains an invalid choice"], error_data[1]
  end

  def test_migrator_education_experience_answer_create_success
    member = members(:f_admin)
    @file = get_file_path("member_education_experience_import")
    @feed_import.set_config_options!(@options.merge(import_file_name: get_file_path("member_education_experience_import"), secondary_questions_map: nil))
    migrator = ChronusSftpFeed::Migrator.new(@file, @feed_import)

    assert_difference "ProfileAnswer.count", 4 do
      assert_difference "Education.count", 3 do
        assert_difference "Experience.count", 4 do
          migrator.run
        end
      end
    end
    assert_equal 1, migrator.info[:updated_count]
    single_education_answer = member.profile_answers.where(profile_question_id: profile_questions(:education_q).id).first
    multi_education_answer = member.profile_answers.where(profile_question_id: profile_questions(:multi_education_q).id).first

    single_experience_answer = member.profile_answers.where(profile_question_id: profile_questions(:experience_q).id).first
    multi_experience_answer = member.profile_answers.where(profile_question_id: profile_questions(:multi_experience_q).id).first
    assert_equal "Loyola, B.Sc, CSC", single_education_answer.answer_text
    assert_equal "CEG, BE, CSE\n MIT, MTech, IT", multi_education_answer.answer_text
    assert_equal "SDE, Chronus", single_experience_answer.answer_text
    assert_equal "SDE-II, Chronus\n SDE-II, Chronus\n SDE, Amazon", multi_experience_answer.answer_text
  end

  def test_migrator_education_experience_answer_update_success
    member = members(:f_admin)
    @file = get_file_path("member_education_experience_import")
    @feed_import.set_config_options!(@options.merge(import_file_name: get_file_path("member_education_experience_import"), secondary_questions_map: nil))
    migrator = ChronusSftpFeed::Migrator.new(@file, @feed_import)
    # following single education and single experience will be updated
    create_education(member, profile_questions(:education_q), school_name: "Loyola", degree: "B.Sc")
    create_experience(member, profile_questions(:experience_q), company: "Chronus", job_title: "SDE", start_month: 0, start_year: "")
    # following education and experience will be deleted
    create_education(member, profile_questions(:multi_education_q), school_name: "Loyola", degree: "B.Sc")
    create_experience(member, profile_questions(:multi_experience_q), company: "Chronus", job_title: "SDE")

    assert_no_difference "ProfileAnswer.count" do
      assert_difference "Education.count" do
        assert_difference "Experience.count", 2 do
          migrator.run
        end
      end
    end
    assert_equal 1, migrator.info[:updated_count]
    education_answer = member.profile_answers.where(profile_question_id: profile_questions(:education_q).id).first
    experience_answer = member.profile_answers.where(profile_question_id: profile_questions(:experience_q).id).first
    assert_equal "Loyola, B.Sc, CSC", education_answer.answer_text
    assert_equal "SDE, Chronus", experience_answer.answer_text
    multi_experience_answer =  member.profile_answers.where(profile_question_id: profile_questions(:multi_experience_q).id).first
    assert_equal "SDE, Amazon\n SDE-II, Chronus\n SDE-II, Chronus", multi_experience_answer.answer_text
  end

  def test_migrator_education_experience_answer_delete_success
    member = members(:f_mentor)
    education_question = profile_questions(:education_q)
    experience_question = profile_questions(:experience_q)

    @file = get_file_path("member_education_experience_delete")
    @feed_import.set_config_options!(@options.merge(import_file_name: get_file_path("member_education_experience_delete"), secondary_questions_map: nil))
    migrator = ChronusSftpFeed::Migrator.new(@file, @feed_import)
    
    assert_difference "ProfileAnswer.count", -2 do
      assert_difference "Education.count", -1 do
        assert_difference "Experience.count", -1 do
          migrator.run
        end
      end
    end
    assert_equal 1, migrator.info[:updated_count]
    assert_nil member.profile_answers.find_by(profile_question_id: education_question.id)
    assert_nil member.profile_answers.find_by(profile_question_id: experience_question.id)
  end

  def test_migrator_user_tags
    @file = get_file_path("user_tags_import")
    @feed_import.set_config_options!(@options.merge(import_file_name: get_file_path("user_tags_import"), secondary_questions_map: nil, import_user_tags: true, data_map: {"Albers Mentor Program" => "albers"}))
    migrator = ChronusSftpFeed::Migrator.new(@file, @feed_import)

    assert_difference "ActsAsTaggableOn::Tag.count", 2 do
      migrator.run
    end
    assert_equal ["admin", "albers_admin"], users(:f_admin).tag_list
  end

  def test_migrator_prevent_name_override
    member = @organization.members.first
    first_name = member.first_name
    last_name = member.last_name

    file_path = get_file_path_for_prevent_name_override("#{first_name}-updated", "#{last_name}-updated", member.email)
    @feed_import.set_config_options!(@options.merge(import_file_name: file_path))
    ChronusSftpFeed::Migrator.new(file_path, @feed_import).run
    assert_equal "#{first_name}-updated", member.reload.first_name
    assert_equal "#{last_name}-updated", member.last_name

    file_path = get_file_path_for_prevent_name_override(first_name, last_name, member.email)
    @feed_import.set_config_options!(@options.merge(import_file_name: file_path, prevent_name_override: true))
    ChronusSftpFeed::Migrator.new(file_path, @feed_import).run
    assert_equal "#{first_name}-updated", member.reload.first_name
    assert_equal "#{last_name}-updated", member.last_name
  end

  private

  def get_file_path(file)
    "test/fixtures/files/data_importer/#{file}.csv"
  end

  def get_file_path_for_prevent_name_override(first_name, last_name, email)
    file_path = "tmp/prevent_name_override.csv"
    CSV.open(file_path, "wb") do |csv|
      csv << ["First Name", "Last Name", "Email"]
      csv << [first_name, last_name, email]
    end
    file_path
  end
end