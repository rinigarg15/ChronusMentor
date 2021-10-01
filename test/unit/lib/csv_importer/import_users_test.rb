require_relative './../../../test_helper'

class CsvImporter::ImportUsersTest < ActiveSupport::TestCase
  def setup
    super
    @user_csv_import = UserCsvImport.new
    @user_csv_import.stubs(:local_csv_file_path).returns("test/fixtures/files/csv_import.csv")
    @user_csv_import.stubs(:id).returns(777)
    @filename = "test/fixtures/files/csv_import.csv"
    @organization = programs(:org_primary)
    @program = programs(:albers)
    @options = { current_user: users(:f_admin), role_names: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], questions: @organization.profile_questions.except_email_and_name_question, is_super_console: true }
    @pr1 = CsvImporter::ProcessedRow.new({UserCsvImport::CsvMapColumns::EMAIL.to_sym => "email1"}, "something")
    @pr2 = CsvImporter::ProcessedRow.new({UserCsvImport::CsvMapColumns::EMAIL.to_sym => "email2"}, "something")
    @pr3 = CsvImporter::ProcessedRow.new({UserCsvImport::CsvMapColumns::EMAIL.to_sym => "email3"}, "something")
    @pr4 = CsvImporter::ProcessedRow.new({UserCsvImport::CsvMapColumns::EMAIL.to_sym => "email4"}, "something")
    CsvImporter::Cache.delete(@user_csv_import)
  end

  def test_initialize
    @pr1.user_to_be_invited = true
    @pr2.user_to_be_updated = true
    @pr3.errors = "somenting"
    @pr4.errors = "somenting"
    CsvImporter::Cache.write(@user_csv_import, [@pr1, @pr2, @pr3, @pr4])
    assert_difference "ProgressStatus.count", 1 do
      @importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    end
    assert_equal @organization, @importer.organization
    assert_equal @program, @importer.program
    assert_equal [], @importer.failed_rows
    assert_equal @options, @importer.options
    assert_equal @options[:questions], @importer.questions
    assert_equal 0, @importer.progress_count
    ps = @importer.progress
    assert_equal ProgressStatus::For::CsvImports::IMPORT_DATA, ps.for
    assert_equal @user_csv_import, ps.ref_obj
    assert_equal 2, ps.maximum
    assert_equal 0, ps.completed_count
  end

  def test_import
    CsvImporter::Cache.write(@user_csv_import, [@pr1, @pr2, @pr3, @pr4])
    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    importer.stubs(:add_users).once.returns
    importer.stubs(:update_users).once.returns
    importer.stubs(:invite_users).once.returns
    assert_equal [], importer.import

    importer2 = CsvImporter::ImportUsers.new(@user_csv_import, @organization, nil, @options)
    importer2.stubs(:add_users).once.returns
    importer2.stubs(:update_users).once.returns
    importer2.stubs(:invite_users).never.returns
    assert_equal [], importer2.import
  end

  def test_es_delta_indexing_for_import
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, any_parameters).at_least_once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Member, any_parameters).at_least_once
    @pr1 = CsvImporter::ProcessedRow.new({UserCsvImport::CsvMapColumns::EMAIL.to_sym => "email1@gmail.com", UserCsvImport::CsvMapColumns::LAST_NAME.to_sym => "emailone", UserCsvImport::CsvMapColumns::FIRST_NAME.to_sym => "test", UserCsvImport::CsvMapColumns::ROLES.to_sym => "mentor"}, "something")
    CsvImporter::Cache.write(@user_csv_import, [@pr1])
    importer3 = CsvImporter::ImportUsers.new(@user_csv_import, @organization, nil, @options)
    assert importer3.import
  end

  def test_program_level
    CsvImporter::Cache.write(@user_csv_import, [@pr1, @pr2, @pr3, @pr4])
    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    assert importer.send(:program_level?)

    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, nil, @options)
    assert_false importer.send(:program_level?)
  end

  def test_add_users
    @pr1.user_to_be_invited = true
    @pr2.user_to_be_invited = true
    CsvImporter::Cache.write(@user_csv_import, [@pr1, @pr2, @pr3, @pr4])
    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    importer.stubs(:initialize_member_information).once.returns
    importer.stubs(:members_map).returns({"email1" => members(:f_student)})
    importer.stubs(:increment_progress_count).times(1).returns
    importer.stubs(:create_or_update_member).times(2).returns(true)
    importer.send(:add_users)
    assert_equal 0, importer.failed_rows.size

    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    importer.stubs(:initialize_member_information).once.returns
    importer.stubs(:members_map).returns({"email1" => members(:f_student)})
    importer.stubs(:increment_progress_count).times(1).returns
    importer.stubs(:create_or_update_member).times(2).returns(false)
    importer.send(:add_users)
    assert_equal 2, importer.failed_rows.size
  end

  def test_update_users
    @pr1.user_to_be_updated = true
    @pr2.user_to_be_updated = true
    CsvImporter::Cache.write(@user_csv_import, [@pr1, @pr2, @pr3, @pr4])
    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    importer.stubs(:initialize_member_information).once.returns
    importer.stubs(:members_map).returns({"email1" => members(:f_student)})
    importer.stubs(:increment_progress_count).times(1).returns
    importer.stubs(:update_member_information).times(2).returns(true)
    importer.send(:update_users)
    assert_equal 0, importer.failed_rows.size

    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    importer.stubs(:initialize_member_information).once.returns
    importer.stubs(:members_map).returns({"email1" => members(:f_student)})
    importer.stubs(:increment_progress_count).times(1).returns
    importer.stubs(:update_member_information).times(2).returns(false)
    importer.send(:update_users)
    assert_equal 2, importer.failed_rows.size
  end

  def test_invite_users
    @pr1.user_to_be_invited = true
    @pr2.user_to_be_invited = true
    CsvImporter::Cache.write(@user_csv_import, [@pr1, @pr2, @pr3, @pr4])
    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    importer.stubs(:increment_progress_count).times(1)
    importer.stubs(:invite_user).with({UserCsvImport::CsvMapColumns::EMAIL.to_sym => "email1"}).returns(true)
    importer.stubs(:invite_user).with({UserCsvImport::CsvMapColumns::EMAIL.to_sym => "email2"}).returns(false)
    importer.send(:invite_users)
    assert_equal 1, importer.failed_rows.size
  end

  def test_create_or_update_member
    CsvImporter::Cache.write(@user_csv_import, [@pr1, @pr2, @pr3, @pr4])
    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    importer.stubs(:create_member).with({UserCsvImport::CsvMapColumns::EMAIL.to_sym => "email1"}).once.returns("something")
    importer.stubs(:create_or_update_profile).with("something", {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "email1"}).once.returns
    importer.stubs(:create_user).with("something", @pr1, false).once.returns
    assert importer.send(:create_or_update_member, nil, @pr1)

    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    importer.stubs(:update_member).with(members(:f_student), {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "email1"}).once
    importer.stubs(:create_or_update_profile).with(members(:f_student), {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "email1"}).once.returns
    importer.stubs(:create_user).with(members(:f_student), @pr1, true).once.returns
    assert importer.send(:create_or_update_member, members(:f_student), @pr1)

    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, nil, @options)
    importer.stubs(:create_member).with({UserCsvImport::CsvMapColumns::EMAIL.to_sym => "email1"}).once.returns("something")
    importer.stubs(:create_or_update_profile).with("something", {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "email1"}).once.returns
    importer.stubs(:create_user).with("something", @pr1, false).never
    assert importer.send(:create_or_update_member, nil, @pr1)

    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    assert_false importer.send(:create_or_update_member, nil, nil)
  end

  def test_update_member_information
    member = members(:f_student)
    CsvImporter::Cache.write(@user_csv_import, [@pr1, @pr2, @pr3, @pr4])
    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    importer.stubs(:update_member).with(member, {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "email1"}).once.returns
    importer.stubs(:create_or_update_profile).with(member, {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "email1"}).once.returns
    importer.stubs(:create_or_update_user).with(member, @pr1).once.returns
    importer.send(:update_member_information, member, @pr1)

    CsvImporter::Cache.write(@user_csv_import, [@pr1, @pr2, @pr3, @pr4])
    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, nil, @options)
    importer.stubs(:update_member).with(member, {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "email1"}).once.returns
    importer.stubs(:create_or_update_profile).with(member, {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "email1"}).once.returns
    importer.stubs(:create_or_update_user).with(member, @pr1).never
    importer.send(:update_member_information, member, @pr1)

    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    assert_false importer.send(:update_member_information, nil, nil)
  end

  def test_update_member
    member = members(:f_student)
    custom_auth = @organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    login_identifier = member.login_identifiers.create!(auth_config: custom_auth, identifier: "12345")

    CsvImporter::Cache.write(@user_csv_import, [@pr1, @pr2, @pr3, @pr4])
    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)

    row = { UserCsvImport::CsvMapColumns::FIRST_NAME.to_sym => "first", UserCsvImport::CsvMapColumns::LAST_NAME.to_sym => "last", UserCsvImport::CsvMapColumns::UUID.to_sym => "something" }
    assert_no_difference "LoginIdentifier.count" do
      importer.send(:update_member, member, row)
    end
    member.reload
    assert_equal "first", member.first_name
    assert_equal "last", member.last_name
    assert_equal "something", login_identifier.reload.identifier

    assert_raise ActiveRecord::RecordInvalid do
      importer.send(:update_member, member, UserCsvImport::CsvMapColumns::FIRST_NAME.to_sym => "first11")
    end
  end

  def test_create_member_active
    custom_auth_1 = @organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    custom_auth_2 = @organization.auth_configs.create!(auth_type: AuthConfig::Type::SOAP)

    CsvImporter::Cache.write(@user_csv_import, [@pr1, @pr2, @pr3, @pr4])
    @options[:is_super_console] = false
    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    row = { UserCsvImport::CsvMapColumns::EMAIL.to_sym => "someemail1@example.com", UserCsvImport::CsvMapColumns::FIRST_NAME.to_sym => "first", UserCsvImport::CsvMapColumns::LAST_NAME.to_sym => "last", UserCsvImport::CsvMapColumns::UUID.to_sym => "something" }

    assert_difference "Member.count", 1 do
      importer.send(:create_member, row)
    end
    member = Member.last
    assert_equal @organization, member.organization
    assert_equal "someemail1@example.com", member.email
    assert_equal "first", member.first_name
    assert_equal "last", member.last_name
    assert_equal Member::Status::ACTIVE, member.state
    assert_false member.auth_configs.present?
    assert_false member.login_identifiers.present?

    @options[:is_super_console] = true
    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    row = { UserCsvImport::CsvMapColumns::EMAIL.to_sym => "someemail2@example.com", UserCsvImport::CsvMapColumns::FIRST_NAME.to_sym => "first", UserCsvImport::CsvMapColumns::LAST_NAME.to_sym => "last", UserCsvImport::CsvMapColumns::UUID.to_sym => "something" }
    assert_difference "Member.count", 1 do
      importer.send(:create_member, row)
    end
    member = Member.last
    assert_equal @organization, member.organization
    assert_equal "someemail2@example.com", member.email
    assert_equal "first", member.first_name
    assert_equal "last", member.last_name
    assert_equal Member::Status::ACTIVE, member.state
    assert_equal_unordered [custom_auth_1, custom_auth_2], member.auth_configs
    assert_equal ["something", "something"], member.login_identifiers.pluck(:identifier)
  end

  def test_create_member_dormant
    CsvImporter::Cache.write(@user_csv_import, [@pr1, @pr2, @pr3, @pr4])
    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)

    row2 = {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "someemail2@example.com", UserCsvImport::CsvMapColumns::FIRST_NAME.to_sym => "first", UserCsvImport::CsvMapColumns::LAST_NAME.to_sym => "last", UserCsvImport::CsvMapColumns::UUID.to_sym => "something2"}
    importer.stubs(:program_level?).returns(false)
    assert_difference "Member.count", 1 do
      importer.send(:create_member, row2)
    end
    member = Member.last
    assert_equal Member::Status::DORMANT, member.state

    assert_raise(ActiveRecord::RecordInvalid) do
      importer.send(:create_member, row2)
    end
  end

  def test_create_or_update_profile
    member = members(:f_student)
    questions = @organization.profile_questions.first(3)
    member.profile_answers.where(profile_question_id: questions.collect(&:id)).delete_all
    @options[:questions] = questions
    CsvImporter::Cache.write(@user_csv_import, [@pr1, @pr2, @pr3, @pr4])
    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    q1 = questions.first
    pa = member.profile_answers.create!(profile_question: q1, answer_text: "Not Ans1")
    importer.stubs(:answers_map).returns({member.id => {q1.id => pa}})
    row = {UserCsvImport::CsvMapColumns::PROFILE_QUESTION_COLUMN_KEY.call(questions[0].id).to_sym => "Ans1", UserCsvImport::CsvMapColumns::PROFILE_QUESTION_COLUMN_KEY.call(questions[1].id).to_sym => "Ans2", UserCsvImport::CsvMapColumns::PROFILE_QUESTION_COLUMN_KEY.call(questions[2].id).to_sym => "Ans3"}

    assert_difference "ProfileAnswer.count", 2 do
      importer.send(:create_or_update_profile, member, row)
    end
    assert_equal "Ans1", pa.answer_text

    row = {UserCsvImport::CsvMapColumns::PROFILE_QUESTION_COLUMN_KEY.call(questions[0].id).to_sym => "Ans1", UserCsvImport::CsvMapColumns::PROFILE_QUESTION_COLUMN_KEY.call(questions[1].id).to_sym => ""}
    importer.stubs(:answers_map).returns({})
    assert_no_difference "ProfileAnswer.count" do
      importer.send(:create_or_update_profile, member, row)
    end

    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    hash = {}
    member.profile_answers.each do |answer|
      hash[answer.profile_question_id] = answer
    end
    importer.stubs(:answers_map).returns({member.id => hash})
    assert_difference "ProfileAnswer.count", -2 do
      importer.send(:create_or_update_profile, member, row)
    end

    pq = profile_questions(:profile_questions_9)
    assert pq.choice_based?
    questions = [pq]
    member.profile_answers.where(profile_question_id: questions.collect(&:id)).delete_all
    @options[:questions] = questions
    CsvImporter::Cache.write(@user_csv_import, [@pr1, @pr2, @pr3, @pr4])
    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    importer.stubs(:answers_map).returns({})
    row = {UserCsvImport::CsvMapColumns::PROFILE_QUESTION_COLUMN_KEY.call(pq.id).to_sym => "something that is not a choice"}
    assert_raise(ActiveRecord::RecordInvalid) do
      importer.send(:create_or_update_profile, member, row)
    end
  end

  def test_create_or_update_user
    member = members(:f_student)
    CsvImporter::Cache.write(@user_csv_import, [@pr1, @pr2, @pr3, @pr4])
    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    importer.stubs(:users_map).returns({})
    row = "something"
    importer.stubs(:create_user).with(member, row, true).returns(1)
    assert_equal 1, importer.send(:create_or_update_user, member, row)

    @options[:role_names] = nil
    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    importer.stubs(:users_map).returns({member.id => users(:f_student)})
    users(:f_student).stubs(:promote_to_role!).with([RoleConstants::MENTOR_NAME], users(:f_admin)).once
    row = CsvImporter::ProcessedRow.new({UserCsvImport::CsvMapColumns::ROLES.to_sym => "mentor"}, "something")
    importer.send(:create_or_update_user, member, row)
  end

  def test_create_user
    member = members(:rahim)
    program = programs(:nwen)
    CsvImporter::Cache.write(@user_csv_import, [@pr1, @pr2, @pr3, @pr4])
    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, program, @options)
    row = CsvImporter::ProcessedRow.new({UserCsvImport::CsvMapColumns::ROLES.to_sym => "mentor,student"}, "something")
    row.stubs(:state).returns(User::Status::ACTIVE)
    assert_difference "User.count", 1 do
      importer.send(:create_user, member, row)
    end
    user = User.last
    assert_equal member, user.member
    assert_equal User::Status::ACTIVE, user.state
    assert_equal ["mentor", "student"], user.role_names
  end

  def test_invite_user
    CsvImporter::Cache.write(@user_csv_import, [@pr1, @pr2, @pr3, @pr4])
    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    row_data = {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "someemail1@example.com", UserCsvImport::CsvMapColumns::ROLES.to_sym => "mentor"}
    assert_difference('ActionMailer::Base.deliveries.size') do
      assert_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count', 2 do
        assert_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count', 1 do
          assert_difference "ProgramInvitation.count", 1 do
            assert importer.send(:invite_user, row_data)
          end
        end
      end
    end
    row_data = {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "bad@com", UserCsvImport::CsvMapColumns::ROLES.to_sym => "mentor"}
    assert_false importer.send(:invite_user, row_data)

    @options[:current_user] = nil
    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    row_data = {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "someemail1@example.com", UserCsvImport::CsvMapColumns::ROLES.to_sym => "mentor"}
    assert_difference "ProgramInvitation.count", 1 do
      assert_no_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count' do
        assert_no_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count' do
          assert importer.send(:invite_user, row_data)
        end
      end
    end
  end

  def test_initialize_member_information
    member = members(:f_mentor)
    members(:rahim).profile_answers.destroy_all
    pa = member.profile_answers.last
    question = pa.profile_question
    row1 = CsvImporter::ProcessedRow.new({UserCsvImport::CsvMapColumns::EMAIL.to_sym => member.email.capitalize}, "something")
    row2 = CsvImporter::ProcessedRow.new({UserCsvImport::CsvMapColumns::EMAIL.to_sym => members(:rahim).email.capitalize}, "something")
    row3 = CsvImporter::ProcessedRow.new({UserCsvImport::CsvMapColumns::EMAIL.to_sym => "somethingThatIsnotThereInTheOrg@example.com"}, "something")
    rows = [row1, row2, row3]
    program = programs(:nwen)
    CsvImporter::Cache.write(@user_csv_import, [@pr1, @pr2, @pr3, @pr4])
    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, program, @options)
    importer.send(:initialize_member_information, rows)
    assert_equal 2, importer.members_map.size
    assert_equal member, importer.members_map[member.email]

    assert_equal 1, importer.answers_map.size
    assert_equal pa, importer.answers_map[member.id][question.id]

    assert_equal 1, importer.users_map.size
    assert_equal users(:f_mentor_nwen_student), importer.users_map[member.id]

    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, nil, @options)
    importer.send(:initialize_member_information, rows)
    assert_equal 2, importer.members_map.size
    assert_equal member, importer.members_map[member.email]

    assert_equal 1, importer.answers_map.size
    assert_equal member.profile_answers.size, importer.answers_map[member.id].size

    assert_equal 0, importer.users_map.size
  end

  def test_progress_batch_size
    CsvImporter::Cache.write(@user_csv_import, [@pr1, @pr2, @pr3, @pr4])
    importer = CsvImporter::ImportUsers.new(@user_csv_import, @organization, @program, @options)
    progress = importer.progress
    progress.stubs(:maximum).returns(1000)
    assert_equal CsvImporter::Constants::PROGRESS_BATCH_SIZE, importer.send(:progress_batch_size)

    progress.stubs(:maximum).returns(20)
    assert_equal 2, importer.send(:progress_batch_size)
  end
end