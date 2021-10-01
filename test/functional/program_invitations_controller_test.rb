# encoding: utf-8

require_relative './../test_helper.rb'

class ProgramInvitationsControllerTest < ActionController::TestCase

  def test_should_be_accessible_only_to_admin
    current_user_is :f_mentor

    assert_permission_denied { get :index }
  end

  def test_should_be_accessible_only_to_admin
    current_user_is :portal_employee

    assert_permission_denied { get :index }
  end

  def test_new_should_not_be_accessible_for_non_admins_when_invite_is_disabled
    current_user_is :f_mentor
    programs(:albers).update_join_settings({RoleConstants::MENTOR_NAME => [RoleConstants::JoinSetting::INVITATION,RoleConstants::InviteRolePermission::MENTEE_CAN_INVITE],
                                            RoleConstants::STUDENT_NAME => [RoleConstants::JoinSetting::INVITATION,RoleConstants::InviteRolePermission::MENTEE_CAN_INVITE]})
    assert_false users(:f_mentor).reload.can_invite_students?
    assert_false users(:f_mentor).can_invite_mentors?
    
    assert_permission_denied { get :new }
  end


  def test_new_should_not_be_accessible_for_employee_when_invite_is_disabled
    current_user_is :portal_employee

    assert_permission_denied { get :new }
  end


  def test_new_should_be_accessible_for_admins
    current_user_is :f_admin

    get :new, params: { :recipient_email => "user@chronus.com", :invitation_roles => [RoleConstants::MENTOR_NAME]}
    assert_response :success
    assert_equal assigns(:recipient_email), "user@chronus.com"
    assert_equal assigns(:invite_for_roles), [RoleConstants::MENTOR_NAME]
  end


  def test_new_should_be_accessible_for_portal_admin_when_invite_is_enabled
    current_user_is :portal_admin

    get :new, params: { :from => "admin"}
    assert_response :success
    assert_nil assigns(:recipient_email)
    assert_nil assigns(:invite_for_roles)
  end

  def test_new_should_be_accessible_for_portal_employee_when_invite_is_enabled
    current_user_is :portal_employee
    u = users(:portal_employee)
    employee_role = u.roles.first
    employee_role.add_permission("invite_employees")
    employee_role.add_permission("view_employees")
    u.reload
    get :new
    assert_response :success
  end

  def test_new_should_be_accessible_for_mentors_when_invite_is_enabled
    current_user_is :f_mentor
    assert users(:f_mentor).can_invite_mentors?

    get :new
    assert_response :success
  end

  def test_index_with_src
    current_user_is :f_admin
    get :index, params: { :src => ReportConst::ManagementReport::SourcePage}
    assert_response :success
    assert_equal ReportConst::ManagementReport::SourcePage, assigns(:src_path)
  end

  def test_index_no_src
    current_user_is :f_admin
    get :index
    assert_response :success
    assert_nil assigns(:src_path)
  end

  def test_index_with_src
    current_user_is :portal_admin
    get :index, params: { :src => ReportConst::ManagementReport::SourcePage}
    assert_response :success
    assert_equal ReportConst::ManagementReport::SourcePage, assigns(:src_path)
  end

  def test_index_no_src
    current_user_is :portal_admin
    get :index
    assert_response :success
    assert_nil assigns(:src_path)
  end


  def test_create_should_not_be_accessible_for_non_admins_when_invite_is_disabled
    programs(:albers).update_join_settings({RoleConstants::MENTOR_NAME => [RoleConstants::JoinSetting::INVITATION,RoleConstants::InviteRolePermission::MENTEE_CAN_INVITE], 
                                            RoleConstants::STUDENT_NAME => [RoleConstants::JoinSetting::INVITATION,RoleConstants::InviteRolePermission::MENTOR_CAN_INVITE]})
    current_user_is :f_mentor
    assert_false users(:f_mentor).is_student?
    assert_false users(:f_mentor).reload.can_invite_mentors?
    assert users(:f_mentor).can_invite_students?

    assert_no_difference 'ProgramInvitation.count' do
      assert_permission_denied {
        post :create, params: {
        :recipients => "test@chronus.com",
        :message => 'I am inviting you.',
        :role => "assign_roles",
        :assign_roles => [RoleConstants::MENTOR_NAME]
      }}
    end
  end

  def test_create_should_not_be_accessible_for_employees_when_invite_is_disabled
    current_user_is :portal_employee

    assert_no_difference 'ProgramInvitation.count' do
      assert_permission_denied {
        post :create, params: {
        :recipients => "test@chronus.com",
        :message => 'I am inviting you.',
        :role => "assign_roles",
        :assign_roles => [RoleConstants::EMPLOYEE_NAME]
      }}
    end
  end

  def test_create_should_be_accessible_for_admins
    current_user_is :f_admin

    assert_difference 'ProgramInvitation.count' do
      post :create, params: {
        :recipients => "test@chronus.com",
        :message => 'I am inviting you.',
        :role => "assign_roles",
        :assign_roles => [RoleConstants::MENTOR_NAME]
      }
      assert_redirected_to program_invitations_path
    end
  end

  def test_create_should_be_accessible_for_protal_admins
    current_user_is :portal_admin

    assert_difference 'ProgramInvitation.count' do
      post :create, params: {
        :recipients => "test@chronus.com",
        :message => 'I am inviting you.',
        :role => "assign_roles",
        :assign_roles => [RoleConstants::EMPLOYEE_NAME]
      }
      assert_redirected_to program_invitations_path
    end
  end


  def test_create_should_be_accessible_for_protal_employee
    current_user_is :portal_employee
    program = programs(:primary_portal)
    employee_role = program.roles.find_by(name: RoleConstants::EMPLOYEE_NAME)
    employee_role.add_permission("invite_employees")
    employee_role.add_permission("view_employees")
    assert_difference 'ProgramInvitation.count' do
      post :create, params: {
        :recipients => "test@chronus.com",
        :message => 'I am inviting you.',
        :role => "assign_roles",
        :assign_roles => [RoleConstants::EMPLOYEE_NAME]
      }
      assert_redirected_to program_root_path
    end
  end

  def test_create_should_not_create_duplicate_invitations_for_already_existing_users
    current_user_is :f_admin
    ProgramInvitation.any_instance.expects(:invitee_already_member?).never
    ProgramInvitation.any_instance.expects(:send_invitation).never
    assert_no_difference 'ProgramInvitation.count' do
      post :create, params: {
        :recipients => "robert@example.com",
        :role => "assign_roles",
        :assign_roles => [RoleConstants::MENTOR_NAME]
      }
      assert_redirected_to program_invitations_path
      assert_equal assigns(:existing_members).collect(&:email), ["robert@example.com"]
      assert_equal "Invitations won't be sent to email id(s) listed below as they are invalid or correspond to existing users: robert@example.com",  flash[:error]
    end
  end

  def test_create_should_not_create_invitations_for_invalid_emails_and_emails_with_invalid_domain
    current_user_is :f_admin
    security_setting = programs(:org_primary).security_setting
    security_setting.update_attribute :email_domain, " chronus.com "
    assert_difference 'ProgramInvitation.count' do
      post :create, params: {
        :recipients => "abcd@abcd.com, abcd@chronus.com, abcdefg",
        :role => "assign_roles",
        :assign_roles => [RoleConstants::MENTOR_NAME]
      }
      assert_redirected_to program_invitations_path
      assert_equal assigns(:invalid_domain_emails), ["abcd@abcd.com"]
      assert_equal assigns(:invalid_emails), ["abcdefg"]
      assert_equal "Invitations will be sent to 1 out of the 3 entered email ids and the 'Invitations Sent' listing will also get updated shortly. Invitations won't be sent to email id(s) listed below as they are invalid or correspond to existing users or doesn't fall under allowed domains( chronus.com ): abcdefg, abcd@abcd.com",  flash[:error]
    end
  end

  def test_create_send_mails
    current_user_is :f_admin
    assert_difference "ActionMailer::Base.deliveries.size", 2 do
      assert_difference 'ProgramInvitation.count', 2 do
        post :create, params: {
          :recipients => "testnouserexist_1@example.com,testnouserexist_2@example.com",
          :role => "assign_roles",
          :assign_roles => [RoleConstants::MENTOR_NAME]
        }
      end
    end
    assert_redirected_to program_invitations_path
    assert_equal assigns(:existing_members).collect(&:email), []
    assert_equal "Invitations will be sent. The 'Invitations Sent' listing under 'Track Invitation Status' will update shortly.",  flash[:notice]
  end

  def test_create_send_mails_in_prefered_locale
    current_user_is :f_admin
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      assert_difference 'ProgramInvitation.count', 1 do
        post :create, params: {
          :recipients => "testnouserexist_1@example.com",
          :role => "assign_roles",
          :assign_roles => [RoleConstants::MENTOR_NAME],
          :locale => "de"
        }
      end
    end
    program_invitation = ProgramInvitation.last
    mail = ActionMailer::Base.deliveries.last
    assert_equal "de", program_invitation.locale
    mail_text = get_text_part_from(mail)
    assert_match /Čóɳťáčť Administrator/, mail_text
    assert_match /p\/albers\/contact_admin\?set_locale=de\&src=email/, mail_text
    assert_equal "Invitations will be sent. The 'Invitations Sent' listing under 'Track Invitation Status' will update shortly.",  flash[:notice]
  end

  def test_create_should_not_create_duplicate_invitations_for_already_existing_portal_users
    current_user_is :portal_admin

    assert_no_difference 'ProgramInvitation.count' do
      post :create, params: {
        :recipients => "nch_employee@example.com",
        :role => "assign_roles",
        :assign_roles => [RoleConstants::EMPLOYEE_NAME]
      }
      assert_redirected_to program_invitations_path
      assert_equal "Invitations won't be sent to email id(s) listed below as they are invalid or correspond to existing users: nch_employee@example.com", flash[:error]
    end
  end

  def test_create_with_vulnerable_content_with_version_v1
    current_user_is :f_admin
    current_program_is :albers
    programs(:albers).organization.security_setting.update_attribute(:sanitization_version, "v1")
    assert_difference 'ProgramInvitation.count' do
      assert_no_difference 'VulnerableContentLog.count' do
        post :create, params: {
          :recipients => "test@chronus.com",
          :message => 'I am inviting you.<script>alert("10");</script>',
          :role => "assign_roles",
          :assign_roles => [RoleConstants::MENTOR_NAME]
        }
        assert_redirected_to program_invitations_path
      end
    end
  end

  def test_create_with_vulnerable_content_with_version_v2
    current_user_is :f_admin
    current_program_is :albers
    programs(:albers).organization.security_setting.update_attribute(:sanitization_version, "v2")
    assert_difference 'ProgramInvitation.count' do
      assert_difference 'VulnerableContentLog.count' do
        post :create, params: {
          :recipients => "test@chronus.com",
          :message => 'I am inviting you.<script>alert("10");</script>',
          :role => "assign_roles",
          :assign_roles => [RoleConstants::MENTOR_NAME]
        }
        assert_redirected_to program_invitations_path
      end
    end
  end

  def test_create_should_be_accessible_for_mentors_when_invite_is_enabled
    current_user_is :f_mentor

    assert_difference 'ProgramInvitation.count' do
      post :create, params: {
        :recipients => "test@chronus.com",
        :message => 'I am inviting you.',
        :role => "assign_roles",
        :assign_roles => [RoleConstants::MENTOR_NAME]
      }

      assert_redirected_to  program_root_path
    end
  end

  def test_create_with_no_roles_selected
    current_user_is :f_admin
    
    assert_no_difference 'ProgramInvitation.count' do
      post :create, params: {
        :recipients => "test@chronus.com",
        :role => "assign_roles"
      }
      assert_redirected_to invite_users_path
      assert_equal "test@chronus.com", session[:program_invitations_recipient_email_ids]
    end
  end

  def test_create_should_retain_emails
    current_user_is :f_admin
    session[:program_invitations_recipient_email_ids] = "test@chronus.com"
    get :new
    assert_equal("test@chronus.com", assigns(:recipient_email))
  end

  def test_should_not_resend_for_used_invite
    current_user_is :f_admin
    invite = ProgramInvitation.create!(
        sent_to: "abc_0@chronus.com",
        user: users(:f_admin),
        program: programs(:albers),
        role_names: [RoleConstants::MENTOR_NAME],
        role_type: ProgramInvitation::RoleType::ASSIGN_ROLE,
        use_count: 1
        )
    put :bulk_update, xhr: true, params: { selected_ids: invite.id.to_s}
    assert_false assigns(:program_invitations).present?
    assert_nil assigns(:message)
  end

  def test_should_resend_invitation
    current_user_is :f_admin
    program = programs(:albers)
    invite = ProgramInvitation.create!(
        sent_to: "abc@chronus.com",
        user: users(:f_admin),
        program: program,
        role_names: [RoleConstants::MENTOR_NAME],
        role_type: ProgramInvitation::RoleType::ASSIGN_ROLE
        )
    invitation_ids = program.program_invitations.pluck(:id).join(", ")

    put :bulk_update, xhr: true, params: { selected_ids: invitation_ids}

    expected_ids = [program_invitations(:mentor).id, invite.id]
    assert_equal(expected_ids, assigns(:program_invitation_ids_to_resend))
    assert_equal("Selected invitation(s) will be resent.", assigns(:message))
  end

  def test_should_list_all_invites
    current_user_is :f_admin
    all_invites = create_dummy_invites([RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    # mark a few invites 'accepted'
    invites = ProgramInvitation.all.order("sent_on DESC")
    invites[0].update_attribute(:use_count, 1)
    invites[-1].update_attribute(:use_count, 1)

    get :index, params: { :page => 1}
    assert_template 'index'
    assert_equal_unordered invites, assigns(:program_invitations)
    assert_tab TabConstants::MANAGE

    assert_equal_hash({all_program_invitations: invites, pending_program_invitations: invites.pending.non_expired, accepted_program_invitations: invites.accepted, expired_program_invitations: invites.pending.expired}, assigns(:program_invitations_hash))
  end

  def test_should_list_all_invites_json
    current_user_is :f_admin
    invites = create_dummy_invites([RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    # mark a few invites 'accepted'
    invites[0].update_attribute(:use_count, 1)
    invites[-1].update_attribute(:use_count, 1)
    invites = ProgramInvitation.all.order("sent_on DESC")

    get :index, params: { :page => 1, :format => :json}
    assert_template 'index'
    assert_equal_unordered invites, assigns(:program_invitations)
    assert_equal_hash({all_program_invitations: invites, pending_program_invitations: invites.pending.non_expired, accepted_program_invitations: invites.accepted, expired_program_invitations: invites.pending.expired}, assigns(:program_invitations_hash))
  end

  def test_should_list_all_invites_sent_by_admin_for_current_program
    current_user_is :f_admin
    forign_program_invites = [ProgramInvitation.create!(
            :sent_to => "abc_1@chronus.com",
            :user => users(:f_admin),
            :program => programs(:ceg),
            :role_names => [RoleConstants::MENTOR_NAME],
            :role_type => ProgramInvitation::RoleType::ASSIGN_ROLE,
            :message => 'some message')]
    get :index

    assert_equal_unordered [program_invitations(:mentor)], assigns(:program_invitations)
  end

  def test_should_list_all_invites_sent_by_non_admin_for_current_program
    current_user_is :f_admin
    forign_program_invites = [ProgramInvitation.create!(
            :sent_to => "abc_1@chronus.com",
            :user => users(:f_admin),
            :program => programs(:ceg),
            :role_names => [RoleConstants::MENTOR_NAME],
            :role_type => ProgramInvitation::RoleType::ASSIGN_ROLE,
            :message => 'some message')]
    get :index, params: { :other_invitations => true}

    assert_equal_unordered [program_invitations(:student)], assigns(:program_invitations)
    assert_nil assigns(:program_invitations_hash)
  end

  def test_index_should_include_admin_sent_notifications_irrespective_of_expired_or_not
    current_user_is :f_admin
    program_invitations = programs(:albers).program_invitations
    assert_equal 2, program_invitations.size
    expired_invite = program_invitations[0]
    expired_invite.update_attribute(:expires_on, Time.new(1900))
    assert expired_invite.expired?
    get :index, params: { page: 1}
    assert assigns(:program_invitations).include?(expired_invite)
    program_invitations = programs(:albers).program_invitations.where(:user_id => users(:f_admin).id)
    assert_equal_hash({all_program_invitations: program_invitations, pending_program_invitations: program_invitations.pending.non_expired, accepted_program_invitations: program_invitations.accepted, expired_program_invitations: program_invitations.pending.expired}, assigns(:program_invitations_hash))
  end

  def test_filter_params_with_views
    current_user_is :f_admin
    view = ProgramInvitationView::DefaultViews.create_for(programs(:albers)).first
    view.filter_params = {include_expired_invitations: true}.to_yaml.gsub(/--- \n/, "")
    view.save!
    get :index, params: { page: 1, :view_id => view.id}
    assert assigns(:filter_hash)[:include_expired_invitations].present?

    view.filter_params = {random_parameter: "harry potter"}.to_yaml.gsub(/--- \n/, "")
    view.save!

    get :index, params: { page: 1, :view_id => view.id}
    assert_equal "harry potter", assigns(:filter_hash)[:random_parameter]
    assert_false assigns(:filter_hash)[:include_expired_invitations].present?
  end

  def test_filter_params_with_views_and_alert
    current_user_is :f_admin
    program = programs(:albers)
    view = ProgramInvitationView::DefaultViews.create_for(program).first
    view.filter_params = {include_expired_invitations: true}.to_yaml.gsub(/--- \n/, "")
    view.save!
    section = program.report_sections.first
    metric = section.metrics.create(title: "Metric Title", description: "Program Invitations", abstract_view_id: view.id)
    alert_params = {target: 20, description: "alert description", operator: Report::Alert::OperatorType::LESS_THAN, filter_params: {cjs_alert_filter_params_0: {name: FilterUtils::ProgramInvitationViewFilters::FILTERS.first[1][:value], operator: FilterUtils::DateRange::IN_LAST, value: "10"}}.to_yaml.gsub(/--- \n/, "")}
    alert = create_alert_for_metric(metric, alert_params)

    get :index, params: { page: 1, :view_id => view.id, :alert_id => alert.id}
    assert assigns(:filter_hash)[:include_expired_invitations].present?
    assert_response :success
    assert_not_nil assigns(:filter_hash)[:sent_between]

    get :index, params: { page: 1, :view_id => view.id}
    assert_response :success
    assert_nil assigns(:filter_hash)[:sent_between]
  end

  def test_invite_students
    current_user_is :f_admin
    users(:f_admin).program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).update_attribute(:term, "Apprentice")

    # Default role to student
    get :new
    assert_response :success
    assert_template 'new'
    assert_select 'html'
    assert_blank assigns(:role)
    assert_tab TabConstants::MANAGE
  end

  def test_invite_students_by_student
    current_user_is :f_student

    # Default role to student
    get :new
    assert_response :success
    assert_template 'new'
    assert_select 'html'
    assert_blank assigns(:role)
    assert_nil flash[:error]

    assert_no_inner_tabs
  end

  def test_invite_mentors_by_mentor
    current_user_is make_member_of(:albers, :f_mentor)

    get :new
    assert_response :success
    assert_template 'new'
    assert_blank assigns(:role)
    assert_select 'html'
    assert_no_inner_tabs
  end

  def test_invite_users_by_a_mentor_mentee_user
    current_user_is make_member_of(:albers, :f_mentor_student)

    get :new
    assert_response :success
    assert_template 'new'
    assert_blank assigns(:role)

    assert_no_inner_tabs
  end


  def test_send_invites_with_empty_recipients
    current_user_is make_member_of(:albers)

    assert_no_difference 'ProgramInvitation.count' do
      post :create, params: {
        :recipients => "",
        :message => 'I am inviting you.',
        :role => "assign_roles",
        :assign_roles => [RoleConstants::MENTOR_NAME]
      }

      assert_equal "Recipients cannot be empty",
        flash[:error]
      assert_redirected_to invite_users_path
    end
  end

  def test_should_not_take_returns_for_separate
    current_user_is :f_admin
    recipients = (1..5).collect{|i| "abcd#{i}@chronus.com"}
    assert_difference 'ProgramInvitation.count', 5 do
      post :create, params: {
        :recipients => recipients.join(","),
        :message => 'I am inviting you.',
        :role => "assign_roles",
        :assign_roles => [RoleConstants::MENTOR_NAME]
      }
      assert_equal "Invitations will be sent. The 'Invitations Sent' listing under 'Track Invitation Status' will update shortly.",  flash[:notice]
    end
  end

  def test_program_invitations_view_title
    current_user_is :f_admin
    program = programs(:albers)

    view = program.abstract_views.where(default_view: AbstractView::DefaultType::PENDING_INVITES).first
    section = program.report_sections.first
    metric = section.metrics.create(title: "Metric Title", description: "Pending invites", abstract_view_id: view.id)

    get :index, params: { :metric_id => metric.id}
    assert_response :success

    assert_not_nil assigns(:metric)
    assert_page_title(metric.title)
  end

  # Empty recipients list should render the form again with a proper error
  # message
  #
  def test_send_invites_with_invalid_recipient_ids
    current_user_is make_member_of(:albers)

    assert_difference 'ProgramInvitation.count', 1 do
      post :create, params: {
        :recipients => "abcd, abcd@xyz.com",
        :message => 'I am inviting you.',
        :role => "assign_roles",
        :assign_roles => [RoleConstants::MENTOR_NAME]
      }

      assert_redirected_to  program_invitations_path
      assert_equal "Invitations will be sent to 1 out of the 2 entered email ids and the 'Invitations Sent' listing will also get updated shortly. Invitations won't be sent to email id(s) listed below as they are invalid or correspond to existing users: abcd", flash[:error]
    end
  end

  def test_send_invites_to_students
    current_user_is make_member_of(:albers)

    recipients = (1..10).collect{|i| "abcd#{i}@chronus.com"}
    assert_difference 'ProgramInvitation.count', 10 do
      # Adding deliberate white spaces to make sure they are stripped.
      post :create, params: {
        :recipients => recipients.join(" , "),
        :role => "assign_roles",
        :assign_roles => [RoleConstants::STUDENT_NAME]
      }
      assert_redirected_to  program_invitations_path
    end


    created_invitations = ProgramInvitation.all.last(10)

    # Make sure the records are created with the email ids we passed.
    assert_equal_unordered recipients,
      created_invitations.collect(&:sent_to)

    unique_roles = created_invitations.collect(&:role_names).flatten.uniq

    # All roles should have been RoleConstants::STUDENT_NAME
    assert_equal 1, unique_roles.size
    assert_equal RoleConstants::STUDENT_NAME, unique_roles.first

    # Just sample one of the emails and check whether the message is added to
    # the email body.
  end

  def test_send_invites_to_mentors
    current_user_is make_member_of(:albers)

    recipients = (1..10).collect{|i| "abcd#{i}@chronus.com"}
    assert_difference 'ProgramInvitation.count', 10 do
      post :create, params: {
        :recipients => recipients.join(","),
        :message => 'I am inviting you.',
        :role => "assign_roles",
        :assign_roles => [RoleConstants::MENTOR_NAME]
      }

      assert_redirected_to program_invitations_path
    end

    created_invitations = ProgramInvitation.all.last(10)

    # Make sure the records are created with the email ids we passed.
    assert_equal_unordered recipients,
      created_invitations.collect(&:sent_to)

    unique_roles = created_invitations.collect(&:role_names).flatten.uniq

    # All roles should have been RoleConstants::MENTOR_NAME
    assert_equal 1, unique_roles.size
    assert_equal RoleConstants::MENTOR_NAME, unique_roles.first
  end

  def test_student_can_send_invites_to_mentors
    current_user_is :f_student
    recipients = (1..3).collect{|i| "abcd#{i}@chronus.com"}
    all_student_roles = Role.where(name: RoleConstants::STUDENT_NAME)
    all_student_roles.each do |role|
      role.add_permission('invite_mentors')
    end

    assert_difference 'ProgramInvitation.count', 3 do
      post :create, params: {
        :recipients => recipients.join(","),
        :message => 'I am inviting you.',
        :role => "assign_roles",
        :assign_roles => [RoleConstants::MENTOR_NAME]
      }
      assert_redirected_to  program_root_path
    end
    created_invitations = ProgramInvitation.all.last(3)

    # Make sure the records are created with the email ids we passed.
    assert_equal_unordered recipients,
      created_invitations.collect(&:sent_to)

    unique_roles = created_invitations.collect(&:role_names).flatten.uniq

    # All roles should be RoleConstants::MENTOR_NAME
    assert_equal 1, unique_roles.size
    assert_equal RoleConstants::MENTOR_NAME, unique_roles.first
  end

  def test_mentor_can_send_invites_to_students
    current_user_is :f_mentor
    recipients = (1..3).collect{|i| "abcd#{i}@chronus.com"}
    all_mentor_roles = Role.where(name: RoleConstants::MENTOR_NAME)
    all_mentor_roles.each do |role|
      role.add_permission('invite_students')
    end

    assert_difference 'ProgramInvitation.count', 3 do
      post :create, params: {
        :recipients => recipients.join(","),
        :message => 'I am inviting you.',
        :role => "assign_roles",
        :assign_roles => [RoleConstants::STUDENT_NAME]
      }

      assert_redirected_to  program_root_path
    end
    created_invitations = ProgramInvitation.all.last(3)

    # Make sure the records are created with the email ids we passed.
    assert_equal_unordered recipients,
      created_invitations.collect(&:sent_to)

    unique_roles = created_invitations.collect(&:role_names).flatten.uniq

    # All roles should be RoleConstants::MENTOR_NAME
    assert_equal 1, unique_roles.size
    assert_equal RoleConstants::STUDENT_NAME, unique_roles.first
  end

  def test_send_invites_to_mentors_and_student_permission_denied_for_mentor
    current_user_is :f_mentor
    recipients = "abcd1@chronus.com"    
    
    assert_permission_denied do 
      post :create, params: {
        :recipients => recipients,
        :message => 'I am inviting you.',
        :role => "assign_roles",
        :assign_roles => [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]
      }
    end
  end

  def test_send_invites_to_mentors_and_student_permission_denied_for_student
    current_user_is :f_student
    recipients = "abcd1@chronus.com"    
    
    assert_permission_denied do 
      post :create, params: {
        :recipients => recipients,
        :message => 'I am inviting you.',
        :role => "assign_roles",
        :assign_roles => [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]
      }
    end
  end

  def test_send_invites_to_mentors_and_student_for_admin
    current_user_is :f_admin
    recipients = (1..3).collect{|i| "abcd#{i}@chronus.com"}
    all_mentor_roles = Role.where(name: RoleConstants::MENTOR_NAME)
    all_mentor_roles.each do |role|
      role.add_permission('invite_students')
    end

    assert_difference 'ProgramInvitation.count', 3 do      
      post :create, params: {
        :recipients => recipients.join(","),
        :message => 'I am inviting you.',
        :role => "assign_roles",
        :assign_roles => [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]
      }
      assert_redirected_to program_invitations_path
    end
    created_invitations = ProgramInvitation.all.last(3)

    # Make sure the records are created with the email ids we passed.
    assert_equal_unordered recipients,
      created_invitations.collect(&:sent_to)

    created_invitations.each do |invite|
      # All roles should be both RoleConstants::MENTOR_NAME and RoleConstants::STUDENT_NAME
      assert_equal_unordered [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], invite.role_names      
    end
  end
  
  def test_send_invites_to_mentors_and_student_for_dual_permission_user
    current_user_is :f_mentor
    recipients = (1..3).collect{|i| "abcd#{i}@chronus.com"}
    all_mentor_roles = Role.where(name: RoleConstants::MENTOR_NAME)
    all_mentor_roles.each do |role|
      role.add_permission('invite_students')
    end

    assert_difference 'ProgramInvitation.count', 3 do      
      post :create, params: {
        :recipients => recipients.join(","),
        :message => 'I am inviting you.',
        :role => "assign_roles",
        :assign_roles => [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]
      }
      assert_redirected_to program_root_path
    end
    created_invitations = ProgramInvitation.all.last(3)

    # Make sure the records are created with the email ids we passed.
    assert_equal_unordered recipients,
      created_invitations.collect(&:sent_to)

    created_invitations.each do |invite|
      # All roles should be both RoleConstants::MENTOR_NAME and RoleConstants::STUDENT_NAME
      assert_equal_unordered [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], invite.role_names      
    end
  end

  def test_gs_feedback_link_presence
    @manager_role = create_role(:name => 'manager_role')
    p = Permission.create!(name: 'invite_manager_roles')
    add_role_permission(@manager_role, p.name)
    add_role_permission(@manager_role, 'customize_program')
    Permission.all_permissions << p.name unless Permission.exists_with_name? p.name
    @prog_manager = create_user(:name => 'prog_manager', :role_names => ['manager_role'])
    current_user_is @prog_manager
    add_role_permission(@manager_role, 'invite_mentors')
    get :new, params: { :role => RoleConstants::MENTOR_NAME}
    assert_no_match(/getsatisfaction\.com/, @response.body)
  end

  def test_delete_invite
    current_user_is :f_admin
    invite = program_invitations(:mentor)

    assert_difference 'ProgramInvitation.count', -1 do
      post :bulk_destroy, xhr: true, params: { selected_ids: invite.id.to_s}
    end
    assert_equal "The invitation has been successfully deleted.", assigns[:message]

    invite = program_invitations(:student)
    invite.update_attributes(use_count: 1)

    assert_difference 'ProgramInvitation.count', -1 do
      post :bulk_destroy, xhr: true, params: { selected_ids: invite.id.to_s}
    end
    assert_equal "The invitation has been successfully deleted.", assigns[:message]
  end

  def test_index_view_other_invitation_show_list_invites_by_end_user
    current_user_is :f_admin
    program_invitations = programs(:albers).program_invitations
    assert_equal 2, program_invitations.size

    get :index
    assert_response :success

    assert_equal 1, assigns(:program_invitations).size
    invitations = assigns(:program_invitations)
    assert invitations.first.is_sender_admin?

    get :index, params: { :other_invitations => true}
    assert_response :success

    assert_equal 1, assigns(:program_invitations).size
    invitations = assigns(:program_invitations)
    assert_false invitations.first.is_sender_admin?
  end

  def test_index_sent_to_filter
    current_user_is :f_admin
    invites = create_dummy_invites(RoleConstants::ADMIN_NAME)
    invites.first.update_attributes!(:sent_to => "join@chronus.com")
    get :index, params: { :filter => {
      :filters => {
        0 => {
          :field => "sent_to",
          :value => "join",
          :operator => "contains"
        }
      }
    }, :format => :json}

    assert_response :success
    assert_equal [invites.first.id], assigns(:program_invitations).collect(&:id)
    assert_equal 1, assigns(:total_count)
  end

  def test_index_date_filter
    current_user_is :f_admin
    invites = create_dummy_invites(RoleConstants::ADMIN_NAME)
    invites.last.update_attributes!(:sent_on => DateTime.new(1987, 7, 28))
    get :index, params: { :filter => {
      :filters => {
        0 => {
          :field => "sent_on",
          :value => "7/29/1987",
          :operator => "lte"
        }
      }
    }, :format => :json}

    assert_response :success
    assert_equal [invites.last.id], assigns(:program_invitations).collect(&:id)
    assert_equal 1, assigns(:total_count)  
  end

  def test_index_date_range_filter
    current_user_is :f_admin
    invites = create_dummy_invites(RoleConstants::ADMIN_NAME)
    invites.last.update_attributes!(:sent_on => DateTime.new(1987, 7, 28))
    get :index, params: { :filter => {
      :filters => {
        0 => {
          :filters => {
            0 => {
              :field => "sent_on",
              :value => "7/27/1987",
              :operator => "gte"
            },
            1 => {
              :field => "sent_on",
              :value => "7/29/1987",
              :operator => "lte"
            }
          }
        }
      }
    }, :format => :json}

    assert_response :success
    assert_equal [invites.last.id], assigns(:program_invitations).collect(&:id)
    assert_equal 1, assigns(:total_count)
  end

  def test_index_roles_name_filter
    current_user_is :f_admin
    # This function creates 2 program invitations with roles sent to mentor
    invites = create_dummy_invites(RoleConstants::STUDENT_NAME)
    invites.first.update_attributes!(:role_names => [RoleConstants::MENTOR_NAME])
    get :index, params: { :filter => {
      :filters => {
        0 => {
          :field => "roles_name",
          :value => "mentor",
        }
      }
    }, :format => :json}

    assert_response :success
    assert_equal 3, assigns(:total_count)  
  end

  #this test is to make sure role based filter works based on role's name instead of custom term
  def test_index_roles_name_filters_works_with_role_name
    current_user_is :f_admin
    invites = create_dummy_invites(RoleConstants::ADMIN_NAME)
    invites.first.update_attributes!(:role_names => [RoleConstants::MENTOR_NAME])

    program = programs(:albers)
    assert_equal ["admin", "mentor", "student", "user"], program.roles.pluck(:name)
    assert_equal ["Administrator", "Mentor", "Student", "User"], program.roles.collect{|x| x.customized_term.term}
   
    #display string in the filter is "Administrator" but posted_as "admin" to the controller
    get :index, params: { :filter => {
      :filters => {
        0 => {
          :field => "roles_name",
          :value => "admin",
        }
      }
    }, :format => :json}

    assert_response :success
    assert_equal 4, assigns(:total_count)
  end

  def test_index_sender_name_filter
    current_user_is :f_admin
    # This function creates 2 program invitations with roles sent to mentor
    invites = create_dummy_invites(RoleConstants::STUDENT_NAME)
    invites.first.update_attributes!(:user_id => users(:ram).id)
    get :index, params: { :filter => {
      :filters => {
        0 => {
          :field => "sender",
          :value => "Rama",
        }
      }
    }, :format => :json}

    assert_response :success
    assert_equal [invites.first.id], assigns(:program_invitations).collect(&:id)
    assert_equal 1, assigns(:total_count)
  end

  def test_index_sent_to_sort
    current_user_is :f_admin
    # This function creates 2 program invitations with roles sent to mentor
    invites = create_dummy_invites(RoleConstants::ADMIN_NAME)
    invites.first.update_attributes!(:user_id => users(:ram).id)
    get :index, params: { :sort => {
      '0' => {
        :field => "sent_to",
        :dir => "desc"
      }
    }, :format => :json}

    assert_response :success
    assert_equal ["abc_4@chronus.com", "abc_3@chronus.com", "abc_2@chronus.com", "abc_1@chronus.com", "abc_0@chronus.com",], assigns(:program_invitations).collect(&:sent_to)
    assert_equal 5, assigns(:total_count)
  end

  # Assuming that the generic kendo presenter has extensive test coverage, which it has!
  def test_index_should_call_generic_kendo_presenter
    current_user_is :f_admin
    # This function creates 2 program invitations with roles sent to mentor
    invites = create_dummy_invites(RoleConstants::ADMIN_NAME)
    invites = ProgramInvitation.all

    presenter_mock1 = mock
    presenter_mock1.expects(:total_count).returns(5)
    presenter_mock1.expects(:list).returns(invites)
    GenericKendoPresenter.expects(:new).returns(presenter_mock1)
    get :index
  end

  def test_status_filter_and_sort_by_sent_to
    current_user_is :f_admin
    invites = create_dummy_invites(RoleConstants::STUDENT_NAME)
    invites.first.update_attributes!(:role_names => [RoleConstants::MENTOR_NAME])
    get :index, params: { :filter => {
      :filters => {
        0 => {
          :field => "status",
          :value => "Pending",
        }
      }
    }, :format => :json}

    assert_response :success
    assert_equal 7, assigns(:total_count)  
    assert_equal_unordered ["abc_1@chronus.com", "abc_2@chronus.com", "abc_3@chronus.com", "abc_4@chronus.com", "mentor_student_0@chronus.com", "mentor_student_1@chronus.com", "abc_0@chronus.com"], assigns(:program_invitations).pluck(:sent_to)

    get :index, params: { :sort => {
      '0' => {
        :field => "sent_to",
        :dir => "asc"
        }
      }, 
      :filter => {
        :logic => "and", 
        :filters => {
          0 => { :logic => "or",
            :filters => { 
              0 => { 
                :field => "statuses",
                :operator => "eq", 
                :value => "Pending"
              }
            }
          }
        }
      }, :format => :json}

    assert_response :success
    assert_equal 7, assigns(:total_count)  
    assert_equal ["abc_0@chronus.com", "abc_1@chronus.com", "abc_2@chronus.com", "abc_3@chronus.com", "abc_4@chronus.com", "mentor_student_0@chronus.com", "mentor_student_1@chronus.com"], assigns(:program_invitations).pluck(:sent_to)
  end

  def test_select_all_ids
    user = users(:f_admin)
    current_user_is user
    current_program_is user.program

    get :select_all_ids, params: { sent_by_admin: true}
    assert_response :success
    result = YAML::load(@response.body)
    assert_equal [program_invitations(:mentor).id.to_s], result["ids"]
    assert_equal 1, result["total_count"].to_i

    get :select_all_ids
    assert_response :success
    result = YAML::load(@response.body)
    assert_equal [program_invitations(:student).id.to_s], result["ids"]
    assert_equal 1, result["total_count"].to_i
  end

  def test_export_csv
    user = users(:f_admin)
    program = user.program
    current_user_is user
    current_program_is program

    ChronusS3Utils::S3Helper.stubs(:transfer).returns(["program_invitations.csv", "/test/path"])

    get :export_csv, params: { format: 'csv', selected_ids: program.program_invitation_ids.join(", ")}
    assert_response :success
    assert assigns(:program_invitation_ids).present?
    assert_equal 2, assigns(:program_invitation_ids).size
    content = @response.body.split("\n")
    assert_equal "﻿Recipient,Sent,Valid until,Role(s),Sender,Status", content[0]
    assert_equal_unordered ["mentor@chronus.com", "mentee@chronus.com"], content[1..-1].collect { |row| row.split(",")[0] }
  end

  private
  def create_dummy_invites(role_name)
    ProgramInvitation.destroy_all
    invites = []

    5.times do |i|
      invites << ProgramInvitation.create!(
        :sent_to => "abc_#{i}@chronus.com",
        :user => users(:f_admin),
        :program => programs(:albers),
        :role_names => [role_name],
        :role_type => ProgramInvitation::RoleType::ASSIGN_ROLE,
        :message => 'some message')
    end

    unless role_name == RoleConstants::ADMIN_NAME
      # Create a couple of mentor student requests
      2.times do |j|
        invites << ProgramInvitation.create!(
          :sent_to => "mentor_student_#{j}@chronus.com",
          :user => users(:f_admin),
          :program => programs(:albers),
          :role_names => [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME],
          :role_type => ProgramInvitation::RoleType::ASSIGN_ROLE,
          :message => 'some message')
      end
    end
    

    return invites
  end
  
  def assert_invitation_tab(tab_name)
    assert_select 'div.inner_tabs' do
      assert_select 'li.sel', :text => tab_name
    end
  end

end