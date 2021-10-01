require_relative './../../test_helper.rb'

class CareerDev::PortalTest < ActiveSupport::TestCase
  include CareerDevTestHelper

	def test_program_type_constant
		assert				CareerDev::Portal::ProgramType.all.include?(CareerDev::Portal::ProgramType::CHRONUS_CAREER)
		assert_false 	CareerDev::Portal::ProgramType.all.include?(Program::ProgramType::CHRONUS_MENTOR)
		assert_false 	CareerDev::Portal::ProgramType.all.include?(Program::ProgramType::CHRONUS_COACH)
		assert_false 	CareerDev::Portal::ProgramType.all.include?(Program::ProgramType::CHRONUS_LEARN)
	end

	def test_disable_program_observer
		assert 	CareerDev::Portal.new.disable_program_observer
	end

  def test_is_career_developement_program
    assert  CareerDev::Portal.new.is_career_developement_program?
  end

  def test_default_role_names
    assert_equal [RoleConstants::ADMIN_NAME, RoleConstants::EMPLOYEE_NAME], programs(:primary_portal).default_role_names
  end

  def test_default_survey_types
    assert_equal [Survey::Type::PROGRAM], programs(:primary_portal).default_survey_types
  end

	def test_create_default_roles
		# Creates default roles
		portal = nil

		assert_difference "Role.count", 2 do
			portal = create_career_dev_portal
		end

		# Gets the roles
		assert_difference "Role.count", 0 do
			portal.create_default_roles
		end

		assert_equal_unordered [RoleConstants::EMPLOYEE_NAME, RoleConstants::ADMIN_NAME], portal.roles.collect(&:name)
		employee = portal.roles.where("name = ?", RoleConstants::EMPLOYEE_NAME).first
		assert 				employee.invitation?
		assert_false 		employee.membership_request?

		permissions = %w(
			view_articles rate_answer ask_question view_questions follow_question answer_question view_ra
		)
		has_permissions?(employee, permissions)
		assert_false 	employee.permissions.collect(&:name).include?('view_mentors')
		assert_false 	employee.permissions.collect(&:name).include?('view_students')
		assert_false 	employee.permissions.collect(&:name).include?('send_mentor_request')
		assert_false 	employee.permissions.collect(&:name).include?('view_mentoring_calendar')

		assert employee.role_questions.present?

		admin = portal.roles.where("name = ?", RoleConstants::ADMIN_NAME).first
		assert 				admin.invitation?
		assert_false 	admin.membership_request?
		permissions = %w(manage_admins manage_announcements write_article view_articles manage_articles
			view_audit_logs manage_forums manage_membership_forms approve_membership_request manage_custom_pages
			invite_admins create_program customize_program rate_answer manage_answers ask_question view_questions
			follow_question answer_question manage_questions manage_profile_forms view_reports manage_surveys manage_themes access_themes
			add_non_admin_profiles  update_profiles manage_user_states work_on_behalf manage_email_templates view_ra manage_translations
		)
		has_permissions?(admin, permissions)
		assert_false admin.role_questions.present?
	end

	def test_disable_features_by_default
		CareerDev::Portal.observers.disable :all
		portal = create_career_dev_portal
		portal.disable_features_by_default
		# Feature Disabled
    [
  		FeatureName::MENTORING_CONNECTIONS_V2, FeatureName::EXECUTIVE_SUMMARY_REPORT, FeatureName::PROGRAM_OUTCOMES_REPORT,
  		FeatureName::CONNECTION_PROFILE, FeatureName::CALENDAR, FeatureName::MENTORING_CONNECTION_MEETING, FeatureName::OFFER_MENTORING,
  		FeatureName::BULK_MATCH, FeatureName::COACHING_GOALS, FeatureName::MENTORING_INSIGHTS,
      FeatureName::CONTRACT_MANAGEMENT, FeatureName::COACH_RATING, FeatureName::MENTOR_RECOMMENDATION
  	].each do |feature_name|
  		assert_false portal.has_feature?(feature_name)
  	end
  	CareerDev::Portal.observers.enable :all
	end

  def test_removed_as_feature_from_ui
    portal = create_career_dev_portal
    disabled_features = FeatureName::permenantly_disabled_career_dev_features + [FeatureName::CAREER_DEVELOPMENT]
    assert_equal FeatureName.removed_as_feature_from_ui.concat(disabled_features), portal.removed_as_feature_from_ui
  end

  def test_portal_ordered_scope
    org = programs(:org_nch)
    portal = programs(:primary_portal)
    program = programs(:nch_mentoring)
    new_portal = create_career_dev_portal(:organization => org)
    portal.update_attributes(:position => 20)
    new_portal.update_attributes(:position => 10)
    program.update_attributes(:position => -10)

    assert_equal [new_portal, portal], org.portals.ordered
    assert_equal [program, new_portal, portal], org.programs.ordered
  end

  def test_portal_set_position
    org = programs(:org_primary)
    org.portals.destroy_all
    org.reload
    portal = create_career_dev_portal(organization: org)
    org.reload
    assert_equal -1, portal.position
  end

  def test_get_calendar_slot_time
    assert_equal Meeting::SLOT_TIME_IN_MINUTES, programs(:primary_portal).get_calendar_slot_time
  end


  def test_send_welcome_email_employee
    user = users(:portal_employee)
    added_by = users(:portal_admin)
    ChronusMailer.expects(:welcome_message_to_portal_user).with(user, added_by).once.returns(stub(:deliver_now))
    user.program.send_welcome_email(user, added_by)
  end

  def test_create_default_admin_views_and_its_dependencies
    program = programs(:primary_portal)
    program.abstract_views.destroy_all
    program.abstract_campaigns.destroy_all
    assert_difference 'AbstractView.count', 6 do
      assert_difference 'CampaignManagement::AbstractCampaign.count', 1 do
        Program.create_default_admin_views_and_its_dependencies(program.id)
      end
    end
    assert_equal [
      "All Users",
      "All Administrators",
      "All Employees",
      "Users With Low Profile Scores",
      "Flagged Content",
      "Pending Membership Applications"], program.reload.abstract_views.collect(&:title)
  end

  def test_create_default_admin_views
    program = programs(:primary_portal)
    program.admin_views.destroy_all
    assert_difference 'AdminView.count', 3 do
      program.create_default_admin_views
    end
    assert_equal ["All Users", "All Administrators", "All Employees"], program.reload.admin_views.collect(&:title)

    program.admin_views.last.destroy
    assert_equal ["All Users", "All Administrators"], program.reload.admin_views.collect(&:title)

    assert_difference 'AdminView.count', 1 do
      program.create_default_admin_views
    end
    assert_equal ["All Users", "All Administrators", "All Employees"], program.reload.admin_views.collect(&:title)
  end

  def test_create_default_abstract_views_for_program_management_report
    program = programs(:primary_portal)
    program.abstract_views.destroy_all
    program.create_default_abstract_views_for_program_management_report
    assert_equal [
      "Users With Low Profile Scores",
      "Flagged Content",
      "Pending Membership Applications"
    ], program.reload.abstract_views.map(&:title)
  end

  def test_management_report_related_custom_term_interpolations
    assert_equal_hash({program: "program", Program: "Program"}, programs(:primary_portal).management_report_related_custom_term_interpolations)
  end

  def test_program_root_name
    assert_equal "cd1", CareerDev::Portal.program_root_name
    assert_equal "cd8", CareerDev::Portal.program_root_name(8)
  end


  def test_should_import_and_setup_campaign
    program = programs(:primary_portal)
    program.program_invitation_campaign.destroy

    program.abstract_campaigns.destroy_all
    assert_difference 'CampaignManagement::AbstractCampaign.count', 1 do
      program.populate_default_campaigns
    end
    assert_equal CampaignManagement::AbstractCampaign.last.title, "Program Invitations to sign up"
    program.reload
    assert program.program_invitation_campaign.featured
    template = program.program_invitation_campaign.campaign_messages.first.email_template
    assert_equal ProgramInvitationCampaignEmailNotification.mailer_attributes[:uid], template.uid
  end

  def test_notify_employee_role_added
    user = users(:portal_employee)

    added_by = users(:portal_admin)
    ChronusMailer.expects(:portal_member_with_set_of_roles_added_notification).once.returns(stub(:deliver_now))
    user.program.notify_added_user(user, added_by)
  end

  def test_notify_pending_employee_role_added
    user = users(:portal_employee)
    user.state = User::Status::PENDING
    user.save!
    user.reload
    added_by = users(:portal_admin)
    ChronusMailer.expects(:portal_member_with_set_of_roles_added_notification_to_review_profile).once.returns(stub(:deliver_now))
    user.program.notify_added_user(user, added_by)
  end

  def test_notify_admin_role_added
    user = users(:portal_admin)

    added_by = user
    ChronusMailer.expects(:admin_added_directly_notification).once.returns(stub(:deliver_now))
    user.program.notify_added_user(user, added_by)
  end

  def test_get_program_health_url
    program = programs(:primary_portal)
    assert_equal program.get_program_health_url, "http://chronusmentor.chronus.com/entries/29618078-Measuring-the-health-of-your-program"
  end

  def test_get_admin_weekly_status_hash
    p = programs(:primary_portal)

    User.where("id in (?)", p.employee_users.pluck(:id)).update_all({:created_at => 1.day.ago})

    member = members(:nch_mentor)
    p.roles.find_by(name: RoleConstants::EMPLOYEE_NAME).update_attributes(membership_request: true)
    MembershipRequest.create!(:member => member, :email => member.email, :program => programs(:primary_portal), :first_name => member.first_name, :last_name => member.last_name, :role_names => [RoleConstants::EMPLOYEE_NAME])

    ac = ArticleContent.create!(:title => "What", :type => "text", :status => ArticleContent::Status::PUBLISHED)
    Article.create!({:article_content => ac, :author => members(:nch_admin), :organization => programs(:org_nch), :published_programs => [programs(:primary_portal)]})

    p.reload
    hash = p.get_admin_weekly_status_hash

    assert_equal hash[:membership_requests][:since], p.membership_requests.size
    assert_equal hash[:employee_users][:since], p.employee_users.size
    assert_equal hash[:articles][:since], p.articles.published.size

    assert_nil hash[:admin_users]
    assert_nil hash[:mentor_users]
    assert_nil hash[:student_users]
    assert_nil hash[:mentor_requests]
    assert_nil hash[:pending_mentor_requests]
    assert_nil hash[:meeting_requests]
    assert_nil hash[:active_meeting_requests]

    assert_false hash[:membership_requests][:values_not_changed]
    assert_false hash[:articles][:values_not_changed]

    User.where("id IN (?)", p.employee_users.pluck(:id)).update_all({:created_at => 3.weeks.ago})
    p.membership_requests.destroy_all
    Article.where("id IN (?)", p.articles.pluck(:id)).update_all({:created_at => 3.weeks.ago})


    p.reload
    hash = p.get_admin_weekly_status_hash

    assert_equal hash[:membership_requests][:week_before], 0
    assert_equal hash[:employee_users][:week_before], 0
    assert_equal hash[:articles][:week_before], 0

    assert_nil hash[:mentor_requests]
    assert_nil hash[:meeting_requests]
    assert_nil hash[:pending_mentor_requests]
    assert_nil hash[:active_meeting_requests]


    assert hash[:membership_requests][:values_not_changed]
    assert hash[:employee_users][:values_not_changed]
    assert hash[:articles][:values_not_changed]
  end


  def test_should_send_admin_weekly_status
    program = programs(:primary_portal)
    program.membership_requests.destroy_all
    User.where("id IN (?)", program.employee_users.pluck(:id)).update_all({:created_at => 3.weeks.ago})
    Article.where("id IN (?)", program.articles.pluck(:id)).update_all({:created_at => 3.weeks.ago})
    assert_false program.should_send_admin_weekly_status?
    member = members(:nch_mentor)
    MembershipRequest.create!(:member => member, :email => member.email, :program => programs(:primary_portal), :first_name => member.first_name, :last_name => member.last_name, :role_names => [RoleConstants::EMPLOYEE_NAME])
    program.reload
    assert program.should_send_admin_weekly_status?
    program.membership_requests.destroy_all
    User.where("id IN (?)", program.employee_users.pluck(:id)).update_all({:created_at => 1.days.ago})
    program.reload
    assert program.should_send_admin_weekly_status?

    User.where("id IN (?)", program.employee_users.pluck(:id)).update_all({:created_at => 3.weeks.ago})
    Article.where("id IN (?)", program.articles.pluck(:id)).update_all({:created_at => 1.day.ago})
    program.reload
    assert program.should_send_admin_weekly_status?
  end

  def test_populate_default_static_content_for_globalization
    program = programs(:primary_portal)

    employee_role = program.roles.find_by(name: RoleConstants::EMPLOYEE_NAME)
    employee_role.translations.destroy_all
    employee_role.reload

    admin_role = program.roles.find_by(name: RoleConstants::ADMIN_NAME)
    assert_equal [], employee_role.translations
    assert_equal [], admin_role.translations

    CareerDev::Portal.populate_default_static_content_for_globalization(program.id)
    program.reload
    employee_role.reload

    locales = [I18n.default_locale] + program.organization.languages.collect(&:language_name)
    assert_equal 2, employee_role.translations.size
    assert_equal ["en", "de"], employee_role.translations.pluck(:locale)
    assert_equal [], admin_role.translations

  end

  def test_populate_zero_match_score_message_with_default_value_if_nil
    program = programs(:primary_portal)
    GlobalizationUtils.run_in_locale(:en) do
      assert_nil program.zero_match_score_message
    end
    GlobalizationUtils.run_in_locale(:"fr-CA") do
      assert_nil program.zero_match_score_message
    end

    program.populate_zero_match_score_message_with_default_value_if_nil([:en, :"fr-CA"])
    program.reload

    GlobalizationUtils.run_in_locale(:en) do
      assert_nil program.zero_match_score_message
    end
    GlobalizationUtils.run_in_locale(:"fr-CA") do
      assert_nil program.zero_match_score_message
    end
  end

  def test_permanently_disabled_features
    program = programs(:primary_portal)
    disabled_features = [
      FeatureName::MENTORING_CONNECTIONS_V2, FeatureName::EXECUTIVE_SUMMARY_REPORT, FeatureName::PROGRAM_OUTCOMES_REPORT,
      FeatureName::CONNECTION_PROFILE, FeatureName::CALENDAR, FeatureName::MENTORING_CONNECTION_MEETING, FeatureName::OFFER_MENTORING,
      FeatureName::BULK_MATCH, FeatureName::COACHING_GOALS, FeatureName::MANAGER, FeatureName::MENTORING_INSIGHTS,
      FeatureName::CONTRACT_MANAGEMENT, FeatureName::COACH_RATING, FeatureName::MENTOR_RECOMMENDATION, FeatureName::SKIP_AND_FAVORITE_PROFILES
    ]
    assert_equal disabled_features, program.permanently_disabled_features
  end

  def test_restricted_sti_attributes
    assert_nil CareerDev::Portal.restricted_sti_attributes
    assert_equal Program::ORGANIZATION_ATTRIBUTES.map(&:to_s), CareerDev::Portal.get_restricted_sti_attributes

    Program::ORGANIZATION_ATTRIBUTES.each do |attribute|
      program = programs(:primary_portal)
      program.stubs("#{attribute}_changed?").returns(true)
      assert_false program.valid?
      assert_equal ["is invalid"], program.errors.messages[attribute]
    end
  end
end