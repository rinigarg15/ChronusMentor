require_relative './../../test_helper.rb'

class ProgramObserverTest < ActiveSupport::TestCase

  def test_after_create
    programs(:org_primary).enable_feature(FeatureName::OFFER_MENTORING)
    assert_difference('Survey.count', 2) do
      assert_difference('SurveyQuestion.count', 13) do
        assert_difference('programs(:org_primary).reload.programs_count') do
          assert_difference('Program.count') do
            assert_no_difference('MembershipRequest::Instruction.count') do
              assert_difference('RecentActivity.count', 2) do
                assert_difference('RoleQuestion.count', 29) do
                  assert_no_difference('ProfileQuestion.count') do
                    assert_no_difference('Section.count') do
                      assert_difference 'Role.count', 3 do
                        assert_difference 'CampaignManagement::AbstractCampaign.count', 5 do
                          assert_difference 'AdminView.count', 18 do
                            assert_difference 'GroupView.count' do
                              assert_difference 'GroupViewColumn.count', 18 do
                                assert_difference "ObjectRolePermission.count", 10 do
                                  assert_difference "MentoringModel.count" do
                                    assert_difference "NotificationSetting.count" do
                                      assert_difference "ReportViewColumn.count", 12 do
                                        assert_no_difference "ProgramAsset.count" do
                                          assert_difference "ResourcePublication.count", 4 do
                                            assert_difference "Report::Section.count", 3 do
                                              assert_difference "Report::Metric.count", 15 do
                                                assert_difference "MatchReportAdminView.count", 3 do
                                                  @prog = Program.create!(
                                                    :name => "Program",
                                                    engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING,
                                                    :root => "pragprog",
                                                    :organization => programs(:org_primary))
                                                end
                                              end
                                            end
                                          end
                                        end
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    # newly created program should have the program invitaiton campaign created!
    assert_false @prog.program_invitation_campaign.nil?
    assert_equal "z7hcgs54", @prog.program_invitation_campaign.campaign_messages.first.email_template.uid

    assert_equal_unordered @prog.sections_for([RoleConstants::MENTOR_NAME]).first.profile_questions.collect(&:question_text), ["Name", "Email", "Phone", "Skype ID", "Location"]
    assert_equal_unordered @prog.sections_for([RoleConstants::STUDENT_NAME]).first.profile_questions.collect(&:question_text), ["Name", "Email", "Phone", "Skype ID", "Location"]

    r = RecentActivity.first

    assert_equal(RecentActivityConstants::Type::PROGRAM_CREATION, r.action_type)
    assert_equal([@prog], r.programs)
    assert_equal(RecentActivityConstants::Target::ADMINS, r.target)
    assert_equal(@prog , r.ref_obj)

    # set_default_group_options_on_program_creation
    assert_equal Program::MentorRequestStyle::NONE, @prog.mentor_request_style
    assert_equal Program::DEFAULT_MENTORING_PERIOD, @prog.mentoring_period
    assert_equal 30.days, @prog.inactivity_tracking_period
    assert !@prog.auto_terminate?

    # Check default questions
    assert @prog.has_role_permission?(RoleConstants::MENTOR_NAME, "offer_mentoring")

    # Check Demographic Report View Columns
    assert_equal @prog.demographic_report_view_columns, @prog.report_view_columns.for_demographic_report.collect(&:column_key)
  end

  def test_after_create_with_solution_pack
    assert_no_difference('Survey.count', 1) do
      assert_no_difference('SurveyQuestion.count', 6) do
        assert_difference('programs(:org_primary).reload.programs_count') do
          assert_difference('Program.count') do
            assert_no_difference('MembershipRequest::Instruction.count') do
              assert_difference('RecentActivity.count', 2) do
                assert_no_difference('RoleQuestion.count') do
                  assert_no_difference('ProfileQuestion.count') do
                    assert_no_difference('Section.count') do
                      assert_difference 'Role.count', 3 do
                        assert_no_difference 'CampaignManagement::AbstractCampaign.count' do
                          assert_difference 'AdminView.count', 18 do
                            assert_difference 'GroupView.count' do
                              assert_difference 'GroupViewColumn.count', 18 do
                                assert_difference "ObjectRolePermission.count", 10 do
                                  assert_difference "MentoringModel.count" do
                                    assert_difference "NotificationSetting.count" do
                                      assert_difference "ReportViewColumn.count", 12 do
                                        assert_no_difference "ProgramAsset.count" do
                                          assert_no_difference "ResourcePublication.count" do
                                            assert_difference "Report::Section.count", 3 do
                                              assert_difference "Report::Metric.count", 15 do
                                                @prog = Program.create!(
                                                  :name => "Program",
                                                  engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING,
                                                  :root => "pragprog",
                                                  :organization => programs(:org_primary),
                                                  :creation_way => Program::CreationWay::SOLUTION_PACK)
                                              end
                                            end
                                          end
                                        end
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    r = RecentActivity.first
    assert_equal(RecentActivityConstants::Type::PROGRAM_CREATION, r.action_type)
    assert_equal([@prog], r.programs)
    assert_equal(RecentActivityConstants::Target::ADMINS, r.target)
    assert_equal(@prog , r.ref_obj)

    # set_default_group_options_on_program_creation
    assert_equal Program::MentorRequestStyle::NONE, @prog.mentor_request_style
    assert_equal Program::DEFAULT_MENTORING_PERIOD, @prog.mentoring_period
    assert_equal 30.days, @prog.inactivity_tracking_period
    assert !@prog.auto_terminate?
  end

  def test_after_create_with_solution_pack_standalone
    Organization.any_instance.stubs(:standalone?).returns(true)
    assert_difference "ResourcePublication.count", 4 do
      @prog = Program.create!(
        name: "Program",
        engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING,
        root: "pragprog",
        organization: programs(:org_primary),
        creation_way: Program::CreationWay::SOLUTION_PACK)
    end
  end

  def test_after_create_match_report_section_settings
    Organization.any_instance.stubs(:can_have_match_report?).returns(true)
    assert_difference "MatchReportAdminView.count", 3 do
      @prog = Program.create!(
        name: "Program",
        engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING,
      root: "pragprog",
     organization: programs(:org_primary))
    end
    assert_equal_unordered [@prog.admin_views.find_by(default_view: AbstractView::DefaultType::AVAILABLE_MENTORS).id, @prog.admin_views.find_by(default_view: AbstractView::DefaultType::MENTEES).id, @prog.admin_views.find_by(default_view: AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES).id], @prog.match_report_admin_views.pluck(:admin_view_id)
  end


  def test_after_create_for_default_feedback_question
    Program.any_instance.expects(:create_organization_admins_sub_program_admins).once
    assert_difference "Feedback::Form.count", 1 do
      assert_difference "Feedback::Question.count", 1 do
        @prog = Program.create!(
          name: "Program",
          root: "pragprog",
          engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING,
          organization: programs(:org_primary))
      end
    end
  end

  def test_create_should_not_create_default_sub_objects_if_already_built
    original_program = programs(:albers)
    assert_difference "MentoringTip.count", 1 do
      assert_difference "Forum.count", 1 do
        program = Program.new(
          name: "Program",
          root: "pragprog",
          engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING,
          organization: programs(:org_primary)
        )

        tip = original_program.mentoring_tips.first
        program.mentoring_tips = [tip.dup]
        program.mentoring_tips.each { |t| t.roles = tip.roles }

        forum = original_program.forums.first
        program.forums = [forum.dup]
        program.forums.each { |f| f.program = program; f.access_roles = forum.access_roles }

        survey = surveys(:one)
        program.surveys = [survey.dup_with_translations]
        program.surveys.each { |s| s.program = program; s.recipient_roles = survey.recipient_roles }

        program.save!
      end
    end
  end

  def test_should_create_program_asset
    organization = programs(:org_primary)
    ProgramAsset.create!({program_id: organization.id, logo: fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')})
    assert organization.program_asset.present?
    assert !organization.standalone?
    assert_difference "ProgramAsset.count" do
      Program.create!(:name => "Program1", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, :root => "prog1", :organization => organization)
    end
    program1 = Program.last
    assert program1.logo_url.present?
    assert_equal program1.program_asset.logo_file_name, organization.program_asset.logo_file_name

    assert_difference "ProgramAsset.count" do
      Program.create!(:name => "Program2", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, :root => "prog2", :organization => organization)
    end
    program2 = Program.last
    assert program2.logo_url.present?
    assert_equal program2.program_asset.logo_file_name, organization.program_asset.logo_file_name
  end

  def test_auto_terminate_to_be_false_when_inactivity_tracking_period_is_set_to_nil
    p = programs(:albers)
    p.inactivity_tracking_period_in_days = 180
    p.update_attribute(:auto_terminate_reason_id, p.permitted_closure_reasons.first.id)
    p.save!
    p.inactivity_tracking_period_in_days = nil
    p.save!
    assert_equal false, p.auto_terminate?
  end

  def test_after_create_enable_specific_feature_when_project_based_is_turned_on
    Feature.expects(:handle_specific_feature_dependency).once
    assert_difference 'Program.count' do
      prog = Program.create!(:name => "New name1", :root => "newprogram1", :organization => programs(:org_primary), :engagement_type => Program::EngagementType::PROJECT_BASED)
      assert prog.project_based?

      prog.roles.each do |role|
        Array(RoleConstants::PROJECT_REQUEST_PERMISSIONS[role.name]).each do |permission_name|
          assert role.permissions.collect(&:name).include?(permission_name)
        end
      end

      prog.roles.for_mentoring.each do |role|
        assert role.permissions.collect(&:name).include?(RolePermission::CREATE_PROJECT_WITHOUT_APPROVAL)
      end
    end
  end

  def test_after_create_enable_specific_feature_not_invoked_when_project_based_is_not_changed
    Feature.expects(:handle_specific_feature_dependency).never
    assert_difference 'Program.count' do
      # prog = Program.create!(:name => "New name1", :root => "newprogram1", :organization => programs(:org_primary), :mentor_request_style => Program::MentorRequestStyle::MENTEE_TO_MENTOR)
      prog = Program.create!(:name => "New name1", :root => "newprogram1", :organization => programs(:org_primary), :engagement_type => Program::EngagementType::CAREER_BASED)
      assert_false prog.project_based?

      prog.roles.each do |role|
        Array(RoleConstants::PROJECT_REQUEST_PERMISSIONS[role.name]).each do |permission_name|
          assert_false role.permissions.collect(&:name).include?(permission_name)
        end
      end
    end
  end

  def test_after_update_enable_specific_feature_when_project_based_is_turned_on
    prog = programs(:albers)
    assert_false prog.project_based?

    Feature.expects(:handle_specific_feature_dependency).once
    prog.update_attribute(:engagement_type, Program::EngagementType::PROJECT_BASED)
    assert prog.project_based?

    prog.roles.each do |role|
      Array(RoleConstants::PROJECT_REQUEST_PERMISSIONS[role.name]).each do |permission_name|
        assert role.permissions.collect(&:name).include?(permission_name)
      end
    end
  end

  def test_after_update_enable_specific_feature_not_invoked_when_project_based_is_not_changed
    prog = programs(:albers)
    assert_false prog.project_based?

    Feature.expects(:handle_specific_feature_dependency).never
    prog.update_attribute(:mentor_request_style, Program::MentorRequestStyle::NONE)

    prog.roles.each do |role|
      Array(RoleConstants::PROJECT_REQUEST_PERMISSIONS[role.name]).each do |permission_name|
        assert_false role.permissions.collect(&:name).include?(permission_name)
      end
    end
  end

  def test_after_update_standalone_program_name_and_description
    organization = Organization.find_by(programs_count: 1)
    program = organization.programs.first
    changed_name = "Changed name"
    changed_description = "Changed description"

    program.update_attributes!(name: changed_name, description: changed_description)
    assert_equal changed_name, organization.name
    assert_equal changed_description, organization.description

    organization = Organization.find_by(programs_count: 2)
    program = organization.programs.first
    old_name = organization.name
    old_description = organization.description

    program.update_attributes(name: changed_name, description: changed_description)
    assert_equal old_name, organization.name
    assert_equal old_description, organization.description
  end

  def test_after_create_object_role_permissions_for_admin
    p1 = Program.create!(:name => "New name1",engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, :root => "newprogram1", :organization => programs(:org_primary), :mentor_request_style => Program::MentorRequestStyle::MENTEE_TO_MENTOR)
    mentoring_model = p1.reload.default_mentoring_model
    roles_hash = p1.roles.select([:id, :name]).for_mentoring_models.group_by(&:name)

    assert mentoring_model.send("can_manage_mm_goals?", roles_hash[RoleConstants::ADMIN_NAME].first)
    assert mentoring_model.send("can_manage_mm_tasks?", roles_hash[RoleConstants::ADMIN_NAME].first)
    assert mentoring_model.send("can_manage_mm_messages?", roles_hash[RoleConstants::ADMIN_NAME].first)

    assert mentoring_model.send("can_manage_mm_goals?", roles_hash[RoleConstants::MENTOR_NAME].first)
    assert mentoring_model.send("can_manage_mm_tasks?", roles_hash[RoleConstants::MENTOR_NAME].first)
    assert_false mentoring_model.send("can_manage_mm_messages?", roles_hash[RoleConstants::MENTOR_NAME].first)

    assert mentoring_model.send("can_manage_mm_goals?", roles_hash[RoleConstants::STUDENT_NAME].first)
    assert mentoring_model.send("can_manage_mm_tasks?", roles_hash[RoleConstants::STUDENT_NAME].first)
    assert_false mentoring_model.send("can_manage_mm_messages?", roles_hash[RoleConstants::STUDENT_NAME].first)
  end

  def test_after_create_has_proper_mentor_request_permission
    student_permission_name = "send_mentor_request"
    admin_permission_name = "manage_mentor_requests"

    p1 = Program.create!(:name => "New name1", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, :root => "newprogram1", :organization => programs(:org_primary), :mentor_request_style => Program::MentorRequestStyle::MENTEE_TO_MENTOR)
    assert_equal Program::MentorRequestStyle::MENTEE_TO_MENTOR, p1.mentor_request_style

    student_role = p1.get_role(RoleConstants::STUDENT_NAME)
    admin_role = p1.get_role(RoleConstants::ADMIN_NAME)
    assert student_role.permission_names.include?(student_permission_name)
    assert admin_role.permission_names.include?(admin_permission_name)

    p2 = Program.create!(:name => "New name2", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, :root => "newprogram2", :organization => programs(:org_primary), :mentor_request_style => Program::MentorRequestStyle::MENTEE_TO_ADMIN)
    assert_equal Program::MentorRequestStyle::MENTEE_TO_ADMIN, p2.mentor_request_style

    student_role = p2.get_role(RoleConstants::STUDENT_NAME)
    admin_role = p2.get_role(RoleConstants::ADMIN_NAME)
    assert student_role.permission_names.include?(student_permission_name)
    assert admin_role.permission_names.include?(admin_permission_name)


    p3 = Program.create!(:name => "New name3", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, :root => "newprogram3", :organization => programs(:org_primary), :mentor_request_style => Program::MentorRequestStyle::NONE)
    assert_equal Program::MentorRequestStyle::NONE, p3.mentor_request_style

    student_role = p3.get_role(RoleConstants::STUDENT_NAME)
    admin_role = p3.get_role(RoleConstants::ADMIN_NAME)
    assert_false student_role.permission_names.include?(student_permission_name)
    assert_false admin_role.permission_names.include?(admin_permission_name)
  end

  def test_after_save_adds_permission
    org = programs(:org_primary)
    program_1 = org.programs.create!(name: "New name", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, root: "newprogram")
    assert_equal Program::MentorRequestStyle::NONE, program_1.mentor_request_style

    student_permission_name = "send_mentor_request"
    student_role = program_1.get_role(RoleConstants::STUDENT_NAME)
    admin_permission_name = "manage_mentor_requests"
    admin_role = program_1.get_role(RoleConstants::ADMIN_NAME)

    assert_false student_role.permission_names.include?(student_permission_name)
    assert_false admin_role.permission_names.include?(admin_permission_name)

    assert_difference "RolePermission.count", 2 do
      program_1.update_attribute(:mentor_request_style, Program::MentorRequestStyle::MENTEE_TO_MENTOR)
    end
    assert student_role.reload.permission_names.include?(student_permission_name)
    assert admin_role.reload.permission_names.include?(admin_permission_name)

    program_2 = org.programs.create!(name: "New name 2", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, root: "newprogram2", mentor_request_style: Program::MentorRequestStyle::MENTEE_TO_MENTOR)
    student_role = program_2.get_role(RoleConstants::STUDENT_NAME)
    admin_role = program_2.get_role(RoleConstants::ADMIN_NAME)
    assert student_role.permission_names.include?(student_permission_name)
    assert admin_role.permission_names.include?(admin_permission_name)

    program_3 = org.programs.create!(name: "New name 3", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, root: "newprogram3", mentor_request_style: Program::MentorRequestStyle::MENTEE_TO_ADMIN)
    student_role = program_3.get_role(RoleConstants::STUDENT_NAME)
    admin_role = program_3.get_role(RoleConstants::ADMIN_NAME)
    assert student_role.permission_names.include?(student_permission_name)
    assert admin_role.permission_names.include?(admin_permission_name)
  end

  def test_default_role_questions_duplicates
    org = programs(:org_primary)
    dup_name_q = create_question(:question_text => "Name", :role_names => [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    dup_email_q = create_question(:question_text => "Email", :role_names => [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    assert_equal 2, org.profile_questions_with_email_and_name.where(:question_text => "Name").size
    assert_equal 2, org.profile_questions_with_email_and_name.where(:question_text => "Email").size

    name_prof_question = org.profile_questions_with_email_and_name.name_question.first
    email_prof_question = org.profile_questions_with_email_and_name.email_question.first
    assert_equal 10, name_prof_question.role_questions.size
    assert_equal 10, email_prof_question.role_questions.size

    p = Program.create!(:name => "New name", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, :root => "newprogram", :organization => programs(:org_primary))
    assert_equal 12, name_prof_question.role_questions.size
    assert_equal 12, email_prof_question.role_questions.size
  end

  def test_set_specific_settings_for_project_based_engagements
    prog = programs(:albers)
    assert_false prog.project_based?
    assert_not_equal Program::MentorRequestStyle::NONE, prog.mentor_request_style
    assert_false prog.allow_one_to_many_mentoring

    prog.engagement_type = Program::EngagementType::PROJECT_BASED
    assert_no_emails do
      prog.save!
    end

    assert_equal Program::MentorRequestStyle::NONE, prog.reload.mentor_request_style
    assert prog.allow_one_to_many_mentoring
  end

  def test_create_default_report_view_columns_for_v2
    assert_false programs(:org_primary).mentoring_connections_v2_enabled?
    assert_false programs(:org_primary).mentoring_connection_meeting_enabled?
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    assert_difference "ReportViewColumn.count", 14 do
      Program.create!(
        :name => "Milestones_V2",
        :root => "v2",
        engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING,
        :organization => programs(:org_primary)
      )
    end
  end

  def test_disable_selected_mails_for_new_program_by_default
    p = Program.new(:name => "Test program", :root => "Domain", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, :organization => programs(:org_primary))
    assert p.valid?
    p.save!

    p.reload

    assert_equal p.mailer_templates.where(enabled: false).count, 2

    p.mails_disabled_by_default.each do |mail_class|
      mail = p.mailer_templates.where(uid: mail_class.mailer_attributes[:uid]).first
      assert_false mail.enabled?
    end
  end

  def test_populate_default_static_content_for_globalization
    org = programs(:org_primary)
    program = org.programs.create!(name: "New name", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, root: "newprogram")
    assert_equal 3, program.reload.translations.count
    assert_equal "program_settings_strings.content.zero_match_score_message_placeholder".translate(locale: :en), program.translation_for(:en).zero_match_score_message
    assert_equal "program_settings_strings.content.zero_match_score_message_placeholder".translate(locale: :de), program.translation_for(:de).zero_match_score_message
    assert_equal "Leave a note for the mentor about what you are looking for. The request can be seen only by the mentor and the program administrators.", program.mentor_request_instruction.translation_for(:en).content
    assert_equal "[[ Łéáνé á ɳóťé ƒóř ťĥé mentor áƀóůť ŵĥáť ýóů ářé łóóǩíɳǧ ƒóř. Ťĥé řéƣůéšť čáɳ ƀé šééɳ óɳłý ƀý ťĥé mentor áɳď ťĥé program administrators. ]]", program.mentor_request_instruction.translation_for(:de).content
    assert_equal "Mentors are professionals who guide and advise mentees in their career paths to help them succeed. A mentor's role is to inspire, encourage, and support their mentees.", program.find_role(RoleConstants::MENTOR_NAME).translation_for(:en).description
    assert_equal "[[ Mentors ářé ƿřóƒéššíóɳáłš ŵĥó ǧůíďé áɳď áďνíšé mentees íɳ ťĥéíř čářééř ƿáťĥš ťó ĥéłƿ ťĥéɱ šůččééď. Á mentor'š řółé íš ťó íɳšƿířé, éɳčóůřáǧé, áɳď šůƿƿóřť ťĥéíř mentees. ]]", program.find_role(RoleConstants::MENTOR_NAME).translation_for(:de).description
  end
end
