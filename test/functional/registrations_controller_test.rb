require_relative './../test_helper.rb'

class RegistrationsControllerTest < ActionController::TestCase

  def test_get_new_admin_signup_form_should_redirect_with_invalid_profiles_question
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true
    params = {
      creation_way: Program::CreationWay::MANUAL,
      program: {
        name: 'test',
        student_name: 'Test_mentee',
        mentor_name: 'Test_mentor',
        organization: {
          account_name: "Chronus",
          program_domain: {
            subdomain: 'mydomain'
          },
          subscription_type: Organization::SubscriptionType::BASIC
        }
      },
      profile_questions: fixture_file_upload('files/profile_questions_invalid.csv', 'text/csv')
    }

    post :new_admin, params: params
    assert_redirected_to root_path(program: { name: 'test', student_name: 'Test_mentee', mentor_name: 'Test_mentor', creation_way: Program::CreationWay::MANUAL}, organization: params[:program][:organization])
    assert_equal [], assigns(:enabled_features)
    assert_equal assigns(:program).engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING
    assert_match /Error at line \d+/, flash[:error]
  end

  def test_should_get_new_admin_signup_form_with_the_program_fields
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true
    params = {
      creation_way: Program::CreationWay::MANUAL,
      program: {
        name: 'test',
        student_name: 'Test_mentee',
        mentor_name: 'Test_mentor',
        organization: {
          account_name: "Chronus",
          program_domain: {
            subdomain: 'mydomain'
          },
          subscription_type: Organization::SubscriptionType::BASIC
        }
      }
    }

    get :new_admin, params: params
    assert_response :success
    assert_template 'new_admin'
    assert_not_nil assigns(:program)
    assert_equal 'test', assigns(:program).name
    assert_equal Program.program_root_name, assigns(:program).root
    assert_equal 'test', assigns(:organization).name
    assert_equal 'mydomain', assigns(:program_domain).subdomain
    assert_equal 'Test_mentee', assigns(:program).student_name
    assert_equal 'Test_mentor', assigns(:program).mentor_name
    assert_equal "Chronus", assigns(:organization).account_name
    assert_equal Organization::SubscriptionType::BASIC, assigns(:organization).subscription_type

    assert_select "form#new_member" do
      assert_select "input[type=hidden][name=?][value=test]", 'member[program][name]'
      assert_select "input[type=hidden][name=?][value=mydomain]", 'member[program][organization][program_domain][subdomain]'
      assert_select "input[type=hidden][name=?][value=Chronus]", 'member[program][organization][account_name]'
    end

    # T&C agreement
    assert_select "div.action_set"
    assert_select 'div.agreement#signup_terms_container'
    # There should be no learn more link for admin view
    assert_select "p#program_learn_more", 0
    assert_equal [], assigns(:enabled_features)
    assert_equal assigns(:program).engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING
  end

  def test_new_program_with_engagement
    if ENV['TDDIUM']
      @request.host = DEFAULT_HOST_NAME
    end
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true
    program_params = {
      program: {
        name: 'test',
        student_name: 'Test_menteeUniQ',
        mentor_name: 'Test_mentorUniQ',
        engagement_type: Program::EngagementType::PROJECT_BASED,
        organization: {
          account_name: "Chronus",
          program_domain: {
            subdomain: 'mydomain',
            domain: DEFAULT_DOMAIN_NAME
          },
          subscription_type: Organization::SubscriptionType::PREMIUM
        }
      }
    }
    params = { profile_questions: fixture_file_upload('files/profile_questions.csv', 'text/csv') }.merge(program_params)
    post :new_admin, params: params
    assert_response :success
    assert_nil assigns(:enabled_features)
    assert_equal assigns(:program).engagement_type, Program::EngagementType::PROJECT_BASED
  end

  def test_should_get_new_admin_signup_form_with_the_program_fields_using_solution_pack
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true
    params = {
      creation_way: Program::CreationWay::SOLUTION_PACK,
      program: {
        name: 'test',
        solution_pack_file: fixture_file_upload(File.join('files', 'solution_pack.zip'), "application/zip"),
        enabled_features: 'something random',
        organization: {
          account_name: "Chronus",
          program_domain: {
            subdomain: 'mydomain'
          },
          subscription_type: '0'
        }
      }
    }

    post :new_admin, params: params

    assert_response :success
    assert_template 'new_admin'
    assert_not_nil assigns(:program)
    assert_equal 'test', assigns(:program).name
    assert_equal [], assigns(:enabled_features)
    assert_equal Program.program_root_name, assigns(:program).root
    assert_equal 'test', assigns(:organization).name
    assert_equal 'mydomain', assigns(:program_domain).subdomain
    assert_equal 'Mentee', assigns(:program).student_name
    assert_equal 'Mentor', assigns(:program).mentor_name
    assert_equal Program::CreationWay::SOLUTION_PACK, assigns(:program).creation_way
    assert_equal "Chronus", assigns(:organization).account_name
    assert_equal Organization::SubscriptionType::BASIC, assigns(:organization).subscription_type

    assert_select "form#new_member" do
      assert_select "input[type=hidden][name=?][value=test]", 'member[program][name]'
      assert_select "input[type=hidden][name=?][value=mydomain]", 'member[program][organization][program_domain][subdomain]'
      assert_select "input[type=hidden][name=?][value=Chronus]", 'member[program][organization][account_name]'
    end

    # T&C agreement
    assert_select "div.action_set"
    assert_select 'div.agreement#signup_terms_container'

    # There should be no learn more link for admin view
    assert_select "p#program_learn_more", 0
  end

  def test_new_admin_signup_form_with_existing_program_name_or_domain_should_redirect_back_to_landing_page
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true
    get :new_admin, params: { program: {name: programs(:albers).name, organization: {program_domain: {subdomain: programs(:org_primary).subdomain}}}, creation_way: Program::CreationWay::MANUAL}
    assert_redirected_to root_path(program: {name: programs(:albers).name, creation_way: Program::CreationWay::MANUAL}, organization: {program_domain: {subdomain: programs(:org_primary).subdomain}})
    assert_equal "The given name/subdomain already exists or is invalid (the domain name/web address can contain only alphanumeric characters and dashes or dots). Please register a different name and subdomain.", flash[:error]
  end

  def test_new_admin_signup_form_with_same_mentor_and_mentee_name
    login_as_super_user
    params = {
      creation_way: Program::CreationWay::MANUAL,
      program: {
        name: 'test',
        student_name: 'test_name',
        mentor_name: 'TEST_NAME',
        organization: {
          account_name: "Chronus",
          program_domain: {
            subdomain: 'mydomain'
          },
          subscription_type: '0'
        }
      }
    }
    get :new_admin, params: params

    assert_redirected_to root_path(program: { name: 'test', student_name: 'test_name', mentor_name: 'TEST_NAME', creation_way: Program::CreationWay::MANUAL}, organization: params[:program][:organization])
    assert_equal "Terms for Mentor and Mentee should not be same.", flash[:error]
  end

  def test_engagement_type_check
    if ENV['TDDIUM']
      @request.host = DEFAULT_HOST_NAME
    end
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true
    program_params = {
      program: {
        name: 'test',
        student_name: 'Test_menteeUniQ',
        mentor_name: 'Test_mentorUniQ',
        engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING,
        organization: {
          account_name: "Chronus",
          program_domain: {
            subdomain: 'mydomain',
            domain: DEFAULT_DOMAIN_NAME
          },
          subscription_type: Organization::SubscriptionType::BASIC
        }
      }
    }
    params = { profile_questions: fixture_file_upload('files/profile_questions.csv', 'text/csv') }.merge(program_params)
    post :new_admin, params: params
    assert_response :success
    assert_equal [], assigns(:enabled_features)
    assert_equal assigns(:program).engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING
    assert_instance_of Array, @request.session[:sections]
    assert_equal 2, @request.session[:sections].size
  end

  def test_new_admin_signup_form_with_admin_as_mentor_or_mentee_name
    login_as_super_user
    params = {
      program: {
        name: 'test',
        student_name: 'student',
        mentor_name: 'Administrator',
        organization: {
          account_name: "Chronus",
          program_domain: {
            subdomain: 'mydomain'
          },
          subscription_type: '0'
        }
      },
      creation_way: Program::CreationWay::MANUAL
    }
    get :new_admin, params: params
    assert_redirected_to root_path(program: { name: 'test', student_name: 'student', mentor_name: 'Administrator', creation_way: Program::CreationWay::MANUAL}, organization: params[:program][:organization])
    assert_equal "Terms for Mentor or Mentee cannot be Administrator.", flash[:error]
    params[:program][:student_name] = "Administrator"
    params[:program][:mentor_name] = "Mentor"
    get :new_admin, params: params
    assert_redirected_to root_path(program: { name: 'test', student_name: 'Administrator', mentor_name: 'Mentor', creation_way: Program::CreationWay::MANUAL}, organization: params[:program][:organization])
    assert_equal "Terms for Mentor or Mentee cannot be Administrator.", flash[:error]
  end

  def test_new_admin_signup_form_with_empty_mentor_mentee_names
    login_as_super_user
    params = {
      creation_way: Program::CreationWay::MANUAL,
      program: {
        name: 'test',
        student_name: '',
        mentor_name: '',
        organization: {
          account_name: "Chronus",
          program_domain: {
            subdomain: 'mydomain'
          },
          subscription_type: '0'
        }
      }
    }
    get :new_admin, params: params

    assert_response :success
    track = Program.tracks.last
    assert_equal 'Student', track.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).term
    assert_equal 'Mentor', track.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term
  end

  def test_new_admin_permissions
    assert_permission_denied do
      get :new_admin, params: { program: {name: 'test', student_name: 'Test_mentee', mentor_name: 'Test_mentor'}, organization: {program_domain: {subdomain: 'mydomain'}}}
    end
  end

  def test_engagement_type_check_2
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true
    program_params = {
      program: {
        name: 'test',
        student_name: 'Test_menteeUniQ',
        mentor_name: 'Test_mentorUniQ',
        engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING,
        organization: {
          account_name: "Chronus",
          program_domain: {
            subdomain: 'mydomain',
            domain: DEFAULT_DOMAIN_NAME
          },
          subscription_type: Organization::SubscriptionType::BASIC
        }
      }
    }

    program_params[:program].merge!(enabled_features: "['#{FeatureName::CALENDAR}']")
    member_params = {
      member: {
        email: 'abcd@chronus.com',
        first_name: "Admin",
        last_name: "Name",
        password: 'test123',
        password_confirmation:  'test123'
      }.merge(program_params), signup_terms: "true"
    }

    temp_custom_term = CustomizedTerm.new
    temp_custom_term.stubs(:term_downcase).returns("")
    Organization.any_instance.stubs(:term_for).returns(temp_custom_term)
    https_post :create_admin, params: member_params
    assert Program.last.reload.calendar_enabled?
    assert_equal 'Test_menteeUniQ', Program.last.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).term
    assert_equal 'Test_mentorUniQ', Program.last.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term
    assert_equal 'Article', Program.last.term_for(CustomizedTerm::TermType::ARTICLE_TERM).term
    assert assigns(:member).terms_and_conditions_accepted
  end

  # Signup by admin with errors
  def test_create_admin_failure_should_not_create_program
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true
    assert_nothing_raised do
      assert_no_difference 'Member.count' do
        assert_no_difference 'User.count' do
          https_post :create_admin, params: { member: {
            email: 'a.com', first_name: "Admin", last_name: "Name", password: 'test123', password_confirmation:  'test123', program: {name: 'temp', organization: {program_domain: {subdomain: 'this'}}}}, signup_terms: "true"}
        end
      end
    end
    assert_redirected_to new_admin_registrations_path(program: {name: 'temp'}, organization: {program_domain: {subdomain: 'this'}}, host: DEFAULT_HOST_NAME )
    assert_not_nil assigns(:member)
    assert_nil assigns(:member).terms_and_conditions_accepted
    assert_not_nil assigns(:program)
    assert_not_nil assigns(:organization)
    assert_equal 'temp', assigns(:program).name
    assert_equal 'this', assigns(:organization).program_domains.first.subdomain
  end

  # Signup by admin with errors on program fields. User should not be saved.
  def test_create_admin_failure_due_to_program_errors
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true
    Location.expects(:find_or_create_by_full_address).at_least(0).returns(locations(:chennai))
    assert_nothing_raised do
      assert_no_difference 'Member.count' do
        assert_no_difference 'User.count' do
          assert_no_difference 'Program.count' do
            assert_no_difference 'Organization.count' do
              https_post :create_admin, params: { member: {
                email: 'abcd@chronus.com', first_name: "hello", last_name: "sample", password: 'test123', password_confirmation:  'test123', program: {name: 'temp', organization: {program_domain: {subdomain: programs(:org_primary).subdomain}}}
              }}
            end
          end
        end
      end
    end

    assert_redirected_to root_path(program: {name: 'temp'}, organization: {program_domain: {subdomain:  programs(:org_primary).subdomain}}, host: DEFAULT_HOST_NAME )
  end

    # Signup by admin before creating the program Should be redirected to new program page after signup.
  def test_create_admin_and_program_success
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true

    mail_cnt = ActionMailer::Base.deliveries.size
    Location.expects(:find_or_create_by_full_address).at_least(0).returns(locations(:chennai))
    assert_difference 'AuthConfig.unscoped.count', AuthConfig.attr_value_map_for_default_auths.size do
      assert_difference 'Member.count' do
        assert_difference 'User.count' do
          assert_difference 'Member.count' do
            assert_difference 'Program.count' do
              assert_difference 'Organization.count' do
                https_post :create_admin, params: { member: {
                  email: 'abcd@chronus.com', first_name: "Admin", last_name: "Name",
                  password: 'test123', password_confirmation: 'test123', program: {name: 'temp', engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, organization: {account_name: "Chronus", program_domain: {subdomain: 'this', domain: DEFAULT_DOMAIN_NAME }, subscription_type: Organization::SubscriptionType::BASIC}}}, signup_terms: "true"
                }
              end
            end
          end
        end
      end
    end

    assert_not_equal mail_cnt, ActionMailer::Base.deliveries.size

    user = User.last
    assert user.is_admin?
    assert user.member.admin?
    assert_equal user, assigns(:current_user)
    assert_equal Member.last, assigns(:current_member)

    organization = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME, 'this')
    program = organization.programs.ordered.last
    assert_equal program, assigns(:program)
    assert_equal organization, assigns(:organization)
    assert_equal "Chronus", organization.account_name

    assert_equal 'this', organization.subdomain
    assert_equal Program.program_root_name, program.root

    assert program.admin_users.include?(user)
    assert_equal program, assigns(:current_program)
    assert_equal(DEFAULT_DOMAIN_NAME, assigns(:current_organization).domain)

    # Admin account should be activated by default.
    # https should be enabled by default!
    assert user.active?
    # Last email will be the program creation email.
    delivered_email = ActionMailer::Base.deliveries.last
    assert_equal user.email, delivered_email.to[0]
    assert_match(/Admin, welcome to temp!/, delivered_email.subject)
    assert assigns(:member).terms_and_conditions_accepted
  end

  def test_create_admin_success_with_signup_terms_not_sent
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true

    mail_cnt = ActionMailer::Base.deliveries.size
    Location.expects(:find_or_create_by_full_address).at_least(0).returns(locations(:chennai))
    assert_difference 'AuthConfig.unscoped.count', AuthConfig.attr_value_map_for_default_auths.size do
      assert_difference 'Member.count' do
        assert_difference 'User.count' do
          assert_difference 'Member.count' do
            assert_difference 'Program.count' do
              assert_difference 'Organization.count' do
                https_post :create_admin, params: {member: {
                  email: 'abcd@chronus.com', first_name: "Admin", last_name: "Name",
                  password: 'test123', password_confirmation: 'test123', program: {name: 'temp', engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, organization: {account_name: "Chronus", program_domain: {subdomain: 'this', domain: DEFAULT_DOMAIN_NAME }, subscription_type: Organization::SubscriptionType::BASIC}}}}
              end
            end
          end
        end
      end
    end
    assert_nil assigns(:member).terms_and_conditions_accepted
  end

  def test_create_admin_using_solution_pack
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true
    Location.expects(:find_or_create_by_full_address).at_least(0).returns(locations(:chennai))
    domain = DEFAULT_DOMAIN_NAME
    FileUtils.mkdir_p "tmp/solution_pack/solution_pack_for_test"
    FileUtils::cp "test/fixtures/files/solution_pack.zip", "tmp/solution_pack/solution_pack_for_test"
    assert_difference 'Organization.count' do
      assert_difference 'Program.count' do
        https_post :create_admin, params: { member: {
          email: 'abcd@chronus.com', first_name: "Admin", last_name: "Name",
          password: 'test123', password_confirmation:  'test123', program: {name: 'temp', organization: {account_name: "Chronus", program_domain: {subdomain: 'this', domain: domain}, subscription_type: Organization::SubscriptionType::BASIC}, solution_pack_file: "tmp/solution_pack/solution_pack_for_test/solution_pack.zip", creation_way: Program::CreationWay::SOLUTION_PACK, engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING}}, signup_terms: "true"
        }
      end
    end
    assert "The solution pack was imported and the Program has been successfully setup!", flash[:notice]
    FileUtils::rm_rf  "tmp/solution_pack/solution_pack_for_test"
    assert assigns(:member).terms_and_conditions_accepted
  end

  def test_create_admin_using_solution_pack_and_check_order_of_profilequestion_name_and_email_And_section
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true
    Location.expects(:find_or_create_by_full_address).at_least(0).returns(locations(:chennai))
    domain = DEFAULT_DOMAIN_NAME
    FileUtils.mkdir_p "tmp/solution_pack/solution_pack_for_test"
    FileUtils::cp "test/fixtures/files/solution_pack.zip", "tmp/solution_pack/solution_pack_for_test"
    assert_difference 'Organization.count' do
      assert_difference 'Program.count' do
        https_post :create_admin, params: { member: {
          email: 'abcd@chronus.com', first_name: "Admin", last_name: "Name",
          password: 'test123', password_confirmation:  'test123', program: {name: 'temp', organization: {account_name: "Chronus", program_domain: {subdomain: 'this', domain: domain}, subscription_type: Organization::SubscriptionType::BASIC}, solution_pack_file: "tmp/solution_pack/solution_pack_for_test/solution_pack.zip", creation_way: Program::CreationWay::SOLUTION_PACK, engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING}}
        }
      end
    end
    profile_questions = Program::Domain.get_organization(domain, "this").sections.default_section.first.profile_questions
    assert_equal profile_questions.select{|a| a.position == 1}.first.question_type, ProfileQuestion::Type::NAME
    assert_equal profile_questions.select{|a| a.position == 2}.first.question_type, ProfileQuestion::Type::EMAIL
    assert_equal [1,2,3], Program::Domain.get_organization(domain, "this").sections.collect(&:position)
    FileUtils::rm_rf  "tmp/solution_pack/solution_pack_for_test"
  end

  def test_create_admin_using_solution_pack_with_invalid_surveys_present_in_task_template_and_facilitation_templates
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true
    Location.expects(:find_or_create_by_full_address).at_least(0).returns(locations(:chennai))
    domain = DEFAULT_DOMAIN_NAME
    FileUtils.mkdir_p "tmp/solution_pack/solution_pack_for_test"
    FileUtils::cp "test/fixtures/files/solution_pack_invalid_engagement_survey.zip", "tmp/solution_pack/solution_pack_for_test"
    assert_difference 'Organization.count' do
      assert_difference 'Program.count' do
        https_post :create_admin, params: { member: {
          email: 'abcd@chronus.com', first_name: "Admin", last_name: "Name",
          password: 'test123', password_confirmation:  'test123', program: {name: 'temp', organization: {account_name: "Chronus", program_domain: {subdomain: 'this', domain: domain}, subscription_type: Organization::SubscriptionType::BASIC}, solution_pack_file: "tmp/solution_pack/solution_pack_for_test/solution_pack_invalid_engagement_survey.zip", creation_way: Program::CreationWay::SOLUTION_PACK, engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING}}
        }
      end
    end
    assert "The solution pack was imported and the Program has been successfully setup! Please note that some invalid data in mentoring model was deleted", flash[:notice]
    FileUtils::rm_rf  "tmp/solution_pack/solution_pack_for_test"
  end

  def test_create_admin_using_solution_pack_error
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true
    Location.expects(:find_or_create_by_full_address).at_least(0).returns(locations(:chennai))
    domain = DEFAULT_DOMAIN_NAME
    RegistrationsController.any_instance.expects(:import_solution_pack).raises(->{StandardError.new("Some error")})

    FileUtils.mkdir_p "tmp/solution_pack/solution_pack_for_test"
    FileUtils::cp "test/fixtures/files/solution_pack.zip", "tmp/solution_pack/solution_pack_for_test"
    assert_no_difference 'Organization.count' do
      assert_no_difference 'Program.count' do
        https_post :create_admin, params: { member: {
          email: 'abcd@chronus.com', first_name: "Admin", last_name: "Name",
          password: 'test123', password_confirmation:  'test123', program: {name: 'temp', organization: {account_name: "Chronus", program_domain: {subdomain: 'this', domain: domain}, subscription_type: Organization::SubscriptionType::BASIC}, solution_pack_file: "tmp/solution_pack/solution_pack_for_test/solution_pack.zip", creation_way: Program::CreationWay::SOLUTION_PACK, engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING}}
        }
      end
    end
    assert_redirected_to root_path
    assert_equal "Failed to create the program using solution pack", flash[:error]
    FileUtils::rm_rf  "tmp/solution_pack/solution_pack_for_test"
  end

  ### INVITATION ###

  def test_new_when_invalid_invite_code
    setup_program_invitation

    get :new, params: { invite_code: "invalid"}
    assert_redirected_to root_path
    assert_match(/The invitation code you provided is not valid. Please contact the .*program administrator.*/, flash[:error])
    assert_program_invitation
  end

  def test_new_when_member_suspended
    setup_program_invitation(true)
    @member.suspend!(members(:f_admin), "Reason")

    get :new, params: { invite_code: @program_invitation.code}
    assert_redirected_to root_path
    assert_equal "You do not have access to this program. Please contact the administrator for more information.", flash[:error]
    assert_program_invitation(@program_invitation)
  end

  def test_new_when_member_with_auth_config
    setup_program_invitation(true)

    session[:auth_config_id] = {}
    get :new, params: { invite_code: @program_invitation.code}
    assert_redirected_to login_path(auth_config_ids: [@organization.chronus_auth.id])
    assert_match(/Please .*login.* to join the program/, flash[:info])
    assert_program_invitation(@program_invitation, invite_code_in_session: true)
    assert_nil session[:auth_config_id]
  end

  def test_new_when_expired_invite
    setup_program_invitation
    @program_invitation.update_attribute(:expires_on, 5.days.ago)

    get :new, params: { invite_code: @program_invitation.code}
    assert_redirected_to root_path
    assert_match(/The invitation code you provided is not valid. Please contact the .*program administrator.*/, flash[:error])
    assert_program_invitation(@program_invitation)
  end

  def test_new_when_invite_already_used
    setup_program_invitation
    @program_invitation.update_attribute(:use_count, 1)

    get :new, params: { invite_code: @program_invitation.code}
    assert_redirected_to root_path
    assert_match(/The invitation code you provided is not valid. Please contact the .*program administrator.*/, flash[:error])
    assert_program_invitation(@program_invitation)
  end

  def test_new_when_email_mismatch_on_external_auth
    setup_program_invitation

    session[:new_custom_auth_user] = { @organization.id => @program_invitation.sent_to, auth_config_id: @organization.google_oauth.id }
    session[:new_user_import_data] = { @organization.id => { "Member" => { "email" => "emailmismatch@example.com" } } }
    get :new, params: { invite_code: @program_invitation.code}
    assert_redirected_to root_path
    assert_match(/We are unable to complete the signup process because the email address provided during signup does not match the email address the invitation was sent to. Please contact the .*program administrator.* to get access to the program./, flash[:error])
    assert_program_invitation(@program_invitation)
  end

  def test_new_when_email_mismatch_on_linkedin_oauth
    setup_program_invitation
    linkedin_oauth = @organization.linkedin_oauth

    session[:new_custom_auth_user] = { @organization.id => @program_invitation.sent_to, auth_config_id: linkedin_oauth.id }
    session[:new_user_import_data] = { @organization.id => { "Member" => { "email" => "emailmismatch@example.com" } } }
    mock_and_assert_invitation_form(linkedin_oauth) do
      get :new, params: { invite_code: @program_invitation.code}
    end
  end

  def test_new_when_email_mismatch_on_external_auth_using_email_for_uid
    setup_program_invitation
    auth_config = @organization.google_oauth

    session[:new_custom_auth_user] = { @organization.id => "emailmismatch@example.com", auth_config_id: auth_config.id, is_uid_email: true }
    session[:new_user_import_data] = { @organization.id => { "Member" => { "email" => @program_invitation.sent_to } } }
    get :new, params: { invite_code: @program_invitation.code}
    assert_program_invitation(@program_invitation, invite_code_in_session: true)
  end

  def test_new_when_loggedin_as_different_member
    setup_program_invitation
    current_member_is members(:f_admin)

    get :new, params: { invite_code: @program_invitation.code}
    assert_redirected_to new_registration_path(invite_code: @program_invitation.code)
    assert_program_invitation(@program_invitation)
    assert_false assigns(:current_member)
  end

  def test_new_when_signedup_user_already_has_invite_roles
    setup_program_invitation(true)
    @user.promote_to_role!(@program_invitation.role_names, users(:f_admin))

    get :new, params: { invite_code: @program_invitation.code}
    assert_redirected_to root_path
    assert_equal "You are already part of the program. Please login using the credentials used during signup.", flash[:info]
    assert_program_invitation(@program_invitation)
  end

  def test_new_when_suspended_signedup_user_already_has_invite_roles
    setup_program_invitation(true)
    @user.promote_to_role!(@program_invitation.role_names, users(:f_admin))
    @user.suspend_from_program!(users(:f_admin), "Reason")

    get :new, params: { invite_code: @program_invitation.code}
    assert_redirected_to login_path(auth_config_ids: [@organization.chronus_auth.id])
    assert_match(/Please .*login.* to join the program/, flash[:info])
    assert_program_invitation(@program_invitation, invite_code_in_session: true)
  end

  def test_new_when_loggedin_suspended_user_already_has_invite_roles
    setup_program_invitation(true)
    @user.promote_to_role!(@program_invitation.role_names, users(:f_admin))
    @user.suspend_from_program!(users(:f_admin), "Reason")

    current_member_is @member
    Timecop.freeze(Time.now) do
      User.expects(:send_at).with(30.minutes.from_now, :send_welcome_email, @user.id, []).once
      assert_no_difference "@user.roles.count" do
        get :new, params: { invite_code: @program_invitation.code}
      end
    end
    assert_redirected_to edit_member_path(@member, first_visit: @user.role_names.join(COMMON_SEPARATOR), ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
    assert_equal "Welcome to #{@user.program.name}. Please complete your online profile to proceed.", flash[:notice]
    assert_program_invitation(@program_invitation, used: true)
    assert_equal @user, assigns(:current_user)
  end

  def test_new_when_loggedin_and_assign_type
    setup_program_invitation(true)

    current_user_is @user
    Timecop.freeze(Time.now) do
      User.expects(:send_at).with(30.minutes.from_now, :send_welcome_email, @user.id, @program_invitation.role_names).once
      assert_difference "@user.roles.count" do
        get :new, params: { invite_code: @program_invitation.code}
      end
    end
    assert_redirected_to edit_member_path(@member, first_visit: @user.role_names.join(COMMON_SEPARATOR), ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
    assert_equal "Welcome to #{@user.program.name}. Please complete your online profile to proceed.", flash[:notice]
    assert_program_invitation(@program_invitation, used: true)
  end

  def test_new_when_logged_in_assign_type_and_invite_error
    setup_program_invitation(true)

    mock_and_assert_invitation_form do
      get :new, params: { invite_code: @program_invitation.code, invite_error: true}
    end
  end

  def test_new_when_loggedin_and_allow_type
    setup_program_invitation(true)
    @program_invitation.update_attribute(:role_type, ProgramInvitation::RoleType::ALLOW_ROLE)

    mock_and_assert_invitation_form do
      get :new, params: { invite_code: @program_invitation.code}
    end
  end

  def test_new_when_authenticated_externally
    setup_program_invitation
    auth_config = @organization.linkedin_oauth

    session[:new_custom_auth_user] = { @organization.id => "uid", auth_config_id: auth_config.id }
    session[:new_user_import_data] = { @organization.id => { "Member" => { "first_name" => "Sundar", "last_name" => "Raja" }, "ProfileAnswer" => { "1" => "answer text" } } }
    mock_and_assert_invitation_form(auth_config) do
      get :new, params: { invite_code: @program_invitation.code}
    end
    assert_equal "Sundar", assigns(:member).first_name
    assert_equal "Raja", assigns(:member).last_name
    assert_equal( { "1" => "answer text" }, assigns(:profile_answers_map))
  end

  def test_new
    setup_program_invitation
    custom_auth = @organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)

    mock_and_assert_invitation_form(nil) do
      get :new, params: { invite_code: @program_invitation.code}
    end
    assert_equal [custom_auth], assigns(:login_sections)[0][:auth_configs]
    assert_equal AuthConfig.attr_value_map_for_default_auths.size, assigns(:login_sections)[1][:auth_configs].size
    assert_nil assigns(:member).first_name
    assert_nil assigns(:member).last_name
    assert_nil assigns(:profile_answers_map)
  end

  def test_create_when_invalid_invite_code
    setup_program_invitation

    https_post :create, xhr: true, params: { invite_code: "invalid"}
    assert_xhr_redirect root_path
    assert_match(/The invitation code you provided is not valid. Please contact the .*program administrator.*/, flash[:error])
    assert_program_invitation
  end

  def test_create_when_validation_errors
    setup_program_invitation

    assert_no_difference "Member.count" do
      https_post :create, xhr: true, params: { invite_code: @program_invitation.code, member: { first_name: "Ajay7", last_name: "Thakur", time_zone: "Asia/Kolkata" }}
    end
    assert_response :success
    assert_false assigns(:member).valid?
    assert_program_invitation(@program_invitation, invite_code_in_session: true)
  end

  def test_create_when_cannot_signin
    setup_program_invitation

    assert_no_difference "Member.count" do
      https_post :create, xhr: true, params: { invite_code: @program_invitation.code, member: { first_name: "Ajay", last_name: "Thakur", time_zone: "Asia/Kolkata" }}
    end
    assert_response :success
    assert assigns(:member).valid?
    assert_false assigns(:member).can_signin?
    assert_nil assigns(:member).terms_and_conditions_accepted
    assert_program_invitation(@program_invitation, invite_code_in_session: true)
  end

  def test_create_when_authenticated_externally
    setup_program_invitation
    linkedin_oauth = @organization.linkedin_oauth
    education_question = profile_questions(:education_q)
    gender_question = profile_questions(:profile_questions_9)
    text_question = profile_questions(:string_q)

    session[:new_custom_auth_user] = { @organization.id => "uid", auth_config_id: linkedin_oauth.id }
    session[:linkedin_access_token] = "li12345"
    assert_new_program_invitation_user(linkedin_oauth) do
      https_post :create, xhr: true, params: { invite_code: @program_invitation.code, member: { first_name: "Ajay", last_name: "Thakur", time_zone: "Asia/Kolkata" }, profile_answers: { "#{education_question.id}" => "test1@gmail.com", "#{text_question.id}" => "005i0000000xuCt", "#{gender_question.id}" => "Male" }, signup_terms: "true"}
    end
    member = assigns(:current_member)
    assert_equal ["uid"], member.login_identifiers.pluck(:identifier)
    assert_equal "li12345", member.linkedin_access_token
    assert_equal "005i0000000xuCt", member.answer_for(text_question).answer_text
    assert_equal "Male", member.answer_for(gender_question).answer_text
    assert_nil member.answer_for(education_question)
    assert member.terms_and_conditions_accepted
  end

  def test_create_when_invite_is_for_admin_of_standalone_program
    user = users(:foster_mentor1)
    member = user.member
    program_invitation = create_program_invitation(email: member.email, program: user.program, role_names: [RoleConstants::ADMIN_NAME])
    assert_false member.admin?
    member.update_attribute(:terms_and_conditions_accepted, nil)
    current_user_is user
    assert_no_difference "Member.count" do
      assert_no_difference "User.count" do
        https_post :create, params: { invite_code: program_invitation.code, signup_terms: "true"}
      end
    end
    assert user.reload.is_admin?
    assert member.reload.admin?
    assert_program_invitation(program_invitation, used: true)
    assert member.reload.terms_and_conditions_accepted
  end

  def test_create_when_chronus_auth
    setup_program_invitation
    @program_invitation.role_type = ProgramInvitation::RoleType::ALLOW_ROLE
    @program_invitation.role_names = [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]
    @program_invitation.save!
    chronus_auth = @organization.chronus_auth

    assert_new_program_invitation_user(chronus_auth, [RoleConstants::STUDENT_NAME]) do
      https_post :create, xhr: true, params: { invite_code: @program_invitation.code, roles: [RoleConstants::STUDENT_NAME], member: { first_name: "Ajay", last_name: "Thakur", time_zone: "Asia/Kolkata", password: "monkey", password_confirmation: "monkey" }, signup_terms: "true"}
    end
    assert assigns(:current_member).crypted_password.present?
    assert assigns(:current_member).terms_and_conditions_accepted
  end

  def test_create_signup_terms_not_sent
    setup_program_invitation
    @program_invitation.role_type = ProgramInvitation::RoleType::ALLOW_ROLE
    @program_invitation.role_names = [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]
    @program_invitation.save!
    chronus_auth = @organization.chronus_auth

    https_post :create, xhr: true, params: {invite_code: @program_invitation.code, roles: [RoleConstants::STUDENT_NAME], member: { first_name: "Ajay", last_name: "Thakur", time_zone: "Asia/Kolkata", password: "monkey", password_confirmation: "monkey" }}
    assert_nil assigns(:current_member).terms_and_conditions_accepted
    assert assigns(:current_member).crypted_password.present?
  end

  def test_create_when_loggedin_user_with_roles
    member = members(:f_mentor)
    program = programs(:no_mentor_request_program)
    member.time_zone = "America/Los_Angeles"
    member.save!

    assert_difference "CampaignManagement::AbstractCampaignMessageJob.count", 2 do
      assert_difference "CampaignManagement::ProgramInvitationCampaignStatus.count" do
        @program_invitation = create_program_invitation(program: program, role_type: ProgramInvitation::RoleType::ALLOW_ROLE, role_names: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], email: member.email)
      end
    end

    current_member_is member
    current_program_is program
    assert_difference "CampaignManagement::AbstractCampaignMessageJob.count", -2 do
      assert_difference "CampaignManagement::ProgramInvitationCampaignStatus.count", -1 do
        assert_no_difference "Member.count" do
          assert_difference "member.users.count" do
            https_post :create, xhr: true, params: { invite_code: @program_invitation.code, roles: [RoleConstants::MENTOR_NAME], member: { first_name: "Ajay", last_name: "Thakur", time_zone: "Asia/Kolkata" }}
          end
        end
      end
    end
    assert_xhr_redirect edit_member_path(member, first_visit: RoleConstants::MENTOR_NAME, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
    assert_equal [RoleConstants::MENTOR_NAME], assigns(:current_user).role_names
    assert_equal "America/Los_Angeles", member.reload.time_zone
    assert_program_invitation(@program_invitation, used: true)
  end

  ### INVITATION - END ###

  def test_accept_terms_and_conditions
    f_mentor = members(:f_mentor)
    f_mentor.terms_and_conditions_accepted = nil
    f_mentor.time_zone = nil
    f_mentor.save!

    current_program_is :albers
    current_member_is f_mentor
    put :accept_terms_and_conditions, params: { time_zone: "Asia/Kolkata"}
    assert_redirected_to program_root_path
    assert_false f_mentor.reload.terms_and_conditions_accepted.nil?
    assert_equal "Asia/Kolkata", f_mentor.time_zone

    put :accept_terms_and_conditions, params: { time_zone: "Asia/Tokyo"}
    assert_redirected_to program_root_path
    assert_equal "Asia/Kolkata", f_mentor.time_zone
  end

  ### NEW USER FOLLOWUP ###

  def test_update_when_invalid_code
    setup_new_user_followup

    current_program_is @program
    https_patch :update, xhr: true, params: { id: @member.id, reset_code: "invalid" }
    assert_xhr_redirect program_root_path
  end

  def test_update_when_validation_errors
    setup_new_user_followup

    current_program_is @program
    @controller.expects(:welcome_the_new_user).never
    @controller.expects(:welcome_the_new_member).never
    assert_no_difference "Password.count" do
      https_patch :update, xhr: true, params: { id: @member.id, reset_code: @password.reset_code, member: { first_name: "A1", last_name: "S2" } }
    end
    assert_response :success
    assert_template "registrations/create"
    assert_false assigns(:current_member)
    assert_false assigns(:member).valid?
  end

  def test_update_when_cannot_signin
    setup_new_user_followup

    current_program_is @program
    @controller.expects(:welcome_the_new_user).never
    @controller.expects(:welcome_the_new_member).never
    assert_no_difference "Password.count" do
      https_patch :update, xhr: true, params: { id: @member.id, reset_code: @password.reset_code, member: { first_name: "Ajay", last_name: "Thakur" }}
    end
    assert_response :success
    assert_template "registrations/create"
    assert_false assigns(:current_member)
    assert assigns(:member).valid?
    assert_false assigns(:member).can_signin?
  end

  def test_update_when_authenticated_externally
    setup_new_user_followup
    linkedin_oauth = @organization.linkedin_oauth
    @member.time_zone = "America/Los_Angeles"
    @member.save!

    Language.expects(:set_for_member).once
    @controller.expects(:welcome_the_new_user).never
    session[:new_custom_auth_user] = { @organization.id => "uid", auth_config_id: linkedin_oauth.id }
    session[:linkedin_access_token] = "li12345"
    current_organization_is @organization
    assert_difference "@member.passwords.count", -1 do
      https_patch :update, xhr: true, params: { id: @member.id, reset_code: @password.reset_code, member: { first_name: "Ajay", last_name: "Thakur", time_zone: "Asia/Kolkata" }}
    end
    assert_xhr_redirect root_organization_path
    assert_equal "Welcome! Your account has been successfully created", flash[:notice]
    assert_nil assigns(:current_user)
    assert_equal @member.reload, assigns(:current_member)
    assert_equal "Ajay", @member.first_name
    assert_equal "Thakur", @member.last_name
    assert_equal ["uid"], @member.login_identifiers.pluck(:identifier)
    assert_equal "li12345", @member.linkedin_access_token
    assert @member.terms_and_conditions_accepted?
    assert_nil @member.crypted_password
    assert_equal "America/Los_Angeles", @member.time_zone
    assert_nil session[:reset_code]
  end

  def test_update_when_chronus_auth
    setup_new_user_followup

    Language.expects(:set_for_member).once
    current_program_is @program
    Timecop.freeze(Time.now) do
      User.expects(:send_at).with(30.minutes.from_now, :send_welcome_email, @user.id, @user.role_names)
      assert_difference "@member.passwords.count", -1 do
        https_patch :update, xhr: true, params: { id: @member.id, reset_code: @password.reset_code, member: { first_name: "Ajay", last_name: "Thakur", time_zone: "Asia/Kolkata", password: "chronus", password_confirmation: "chronus" }}
      end
    end
    assert_xhr_redirect edit_member_path(@member, first_visit: @user.role_names.join(COMMON_SEPARATOR), ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
    assert_equal @user, assigns(:current_user)
    assert_equal "Ajay", @member.reload.first_name
    assert_equal "Thakur", @member.last_name
    assert_equal [@organization.chronus_auth], @member.auth_configs
    assert @member.terms_and_conditions_accepted?
    assert @member.crypted_password.present?
    assert_equal "Asia/Kolkata", @member.time_zone
    assert_nil session[:reset_code]
  end

  ### NEW USER FOLLOWUP - END ###

  def test_should_not_allow_non_logged_in_user_to_access_create_enrollment
    current_organization_is :org_primary
    programs(:org_primary).enable_feature(FeatureName::ENROLLMENT_PAGE)
    assert programs(:org_primary).enrollment_page_enabled?
    mentor_role = programs(:albers).find_role(RoleConstants::MENTOR_NAME)
    student_role = programs(:albers).find_role(RoleConstants::STUDENT_NAME)
    update_join_setting_for_role(mentor_role, RoleConstants::JoinSetting::JOIN_DIRECTLY)
    update_join_setting_for_role(student_role, RoleConstants::JoinSetting::JOIN_DIRECTLY_ONLY_WITH_SSO)

    post :create_enrollment, params: { roles: RoleConstants::MENTOR_NAME, program: programs(:albers).id}
    assert_redirected_to root_organization_path

    post :create_enrollment, params: { roles: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], program: programs(:albers).id}
    assert_redirected_to root_organization_path
  end

  def test_mentor_to_get_welcome_mentee_mail_when_enrolling_for_mentee
    current_organization_is :org_primary
    current_member_is :f_mentor
    programs(:org_primary).enable_feature(FeatureName::ENROLLMENT_PAGE)
    student_role = programs(:albers).find_role(RoleConstants::STUDENT_NAME)
    update_join_setting_for_role(student_role, RoleConstants::JoinSetting::JOIN_DIRECTLY)

    assert_emails do
      assert_nothing_raised do
        post :create_enrollment, params: { roles: RoleConstants::STUDENT_NAME, program: programs(:albers).id}
      end
    end
    assert_equal programs(:albers), assigns(:program)
    email = ActionMailer::Base.deliveries.last
    assert_equal "#{members(:f_mentor).first_name}, welcome to Albers Mentor Program!", email.subject
    assert_match "You are now a student", get_text_part_from(email)

    post :create_enrollment, params: { roles: [], program: programs(:albers).id}
    assert_redirected_to enrollment_path
    assert_match "Role(s) can't be blank", flash[:error]
  end

  def test_create_enrollment_for_suspended_user
    current_organization_is :org_primary
    current_member_is :inactive_user
    programs(:org_primary).enable_feature(FeatureName::ENROLLMENT_PAGE)
    student_role = programs(:albers).find_role(RoleConstants::STUDENT_NAME)
    update_join_setting_for_role(student_role, RoleConstants::JoinSetting::JOIN_DIRECTLY)
    Program.any_instance.stubs(:allow_join_directly_in_enrollment?).returns(true)
    post :create_enrollment, params: { roles: RoleConstants::STUDENT_NAME, program: programs(:psg).id}
    assert_redirected_to enrollment_path
  end

  def test_create_enrollment_mail_for_mentor_joining_as_mentee
    current_organization_is :org_primary
    current_member_is :f_mentor
    programs(:org_primary).enable_feature(FeatureName::ENROLLMENT_PAGE)
    student_role = programs(:albers).find_role(RoleConstants::STUDENT_NAME)
    update_join_setting_for_role(student_role, RoleConstants::JoinSetting::JOIN_DIRECTLY)

    assert_emails do
      assert_nothing_raised do
        post :create_enrollment, params: { roles: RoleConstants::STUDENT_NAME, program: programs(:albers).id}
      end
    end
    assert_equal programs(:albers), assigns(:program)
    assert_redirected_to edit_member_path(members(:f_mentor), root: programs(:albers).root, first_visit: true, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
    email = ActionMailer::Base.deliveries.last
    assert_equal "#{members(:f_mentor).first_name}, welcome to Albers Mentor Program!", email.subject
    assert_match "You are now a student", get_text_part_from(email)
  end

  private

  def setup_program_invitation(with_member = nil)
    @program_invitation = program_invitations(:student)
    program = @program_invitation.program
    @organization = program.organization

    if with_member
      @member = members(:f_mentor)
      @program_invitation.update_attribute(:sent_to, @member.email)
      @user = @member.user_in_program(program)
    end
    current_program_is program
  end

  def assert_program_invitation(program_invitation = nil, options = {})
    if program_invitation.present?
      old_count = program_invitation.use_count
      assert_equal program_invitation, assigns(:program_invitation)
      assert_equal(@member, assigns(:member)) if program_invitation.sent_to == @member.try(:email)
      assert_equal (options[:used] ? (old_count + 1) : old_count), program_invitation.reload.use_count
    else
      assert_nil assigns(:program_invitation)
      assert_nil assigns(:member)
    end

    if options[:invite_code_in_session]
      assert_equal program_invitation.code, session[:invite_code]
    else
      assert_nil session[:invite_code]
    end
  end

  def mock_and_assert_invitation_form(auth_config = nil)
    skip_login_sections = auth_config.present? || @user.present?
    @controller.expects(:initialize_login_sections).never if skip_login_sections
    current_user_is(@user) if @user.present?
    assert_no_difference "#{@user.present? ? '@user.roles.count' : 'Member.count'}" do
      yield
    end
    assert_response :success
    assert_program_invitation(@program_invitation, invite_code_in_session: true)

    if @member.blank?
      assert assigns(:member).new_record?
      assert_equal @program_invitation.sent_to, assigns(:member).email
    end
    if auth_config.nil?
      assert_nil assigns(:auth_config)
    else
      assert_equal auth_config, assigns(:auth_config)
    end
    assert_not_nil assigns(:login_sections) unless skip_login_sections
  end

  def assert_new_program_invitation_user(auth_config, role_names = [])
    role_names = @program_invitation.assign_type? ? @program_invitation.role_names : role_names

    Language.expects(:set_for_member).once
    assert_difference "Member.count" do
      assert_difference "User.count" do
        assert_emails do
          yield
        end
      end
    end
    user = assigns(:current_user)
    member = user.member
    assert_xhr_redirect edit_member_path(member, first_visit: role_names.join(COMMON_SEPARATOR), ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
    assert_equal "Ajay", member.first_name
    assert_equal "Thakur", member.last_name
    assert_equal @program_invitation.sent_to, member.email
    assert auth_config.in?(member.auth_configs)
    assert_equal "Asia/Kolkata", member.time_zone
    assert member.terms_and_conditions_accepted?
    assert_equal role_names, user.role_names
    assert_program_invitation(@program_invitation, used: true)
  end
end