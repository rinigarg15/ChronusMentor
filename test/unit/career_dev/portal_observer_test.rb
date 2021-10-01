require_relative './../../test_helper.rb'

class CareerDev::PortalObserverTest < ActiveSupport::TestCase
  include CareerDevTestHelper

  def test_after_create
  	portal = nil
	  assert_difference('programs(:org_primary).reload.programs_count') do
	  	assert_difference('Program.count') do
	  		assert_difference('RecentActivity.count', 2) do
	  			assert_difference('RoleQuestion.count', 2) do
	  				assert_difference 'Role.count', 2 do
              assert_difference 'AbstractView.count', 6 do
                assert_difference 'CampaignManagement::AbstractCampaign.count', 1 do
                  assert_difference "NotificationSetting.count" do
                    assert_no_difference "ProgramAsset.count" do
                      assert_difference "ReportViewColumn.count", 3 do
                      # assert_difference "ResourcePublication.count", 4 do
                        portal = create_career_dev_portal
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
    assert_equal([portal], r.programs)
    assert_equal(RecentActivityConstants::Target::ADMINS, r.target)
    assert_equal(portal , r.ref_obj)

    # Feature Disabled
    [
  		FeatureName::MENTORING_CONNECTIONS_V2, FeatureName::EXECUTIVE_SUMMARY_REPORT, FeatureName::PROGRAM_OUTCOMES_REPORT,
  		FeatureName::CONNECTION_PROFILE, FeatureName::CALENDAR, FeatureName::MENTORING_CONNECTION_MEETING, FeatureName::OFFER_MENTORING, FeatureName::BULK_MATCH, FeatureName::COACHING_GOALS, FeatureName::MENTORING_INSIGHTS, 
  		FeatureName::CONTRACT_MANAGEMENT, FeatureName::COACH_RATING
  	].each do |feature_name|
  		assert_false portal.has_feature?(feature_name)
  	end

    # Role Creation
    assert_equal_unordered [RoleConstants::EMPLOYEE_NAME, RoleConstants::ADMIN_NAME], portal.roles.collect(&:name)
		employee = portal.roles.where("name = ?", RoleConstants::EMPLOYEE_NAME).first
		assert 				employee.invitation?
		assert_false 		employee.membership_request?

		# Role Questions
		assert_equal_unordered [ProfileQuestion::Type::EMAIL, ProfileQuestion::Type::NAME], employee.role_questions.collect(&:profile_question).collect(&:question_type)

		# Permission
		permissions = %w(
			view_articles rate_answer ask_question view_questions follow_question answer_question view_ra
		)
		has_permissions?(employee, permissions)
		assert_false 	employee.permissions.collect(&:name).include?('view_mentors')
		assert_false 	employee.permissions.collect(&:name).include?('view_students')
		assert_false 	employee.permissions.collect(&:name).include?('send_mentor_request')
		assert_false 	employee.permissions.collect(&:name).include?('view_mentoring_calendar')


		admin = portal.roles.where("name = ?", RoleConstants::ADMIN_NAME).first
		assert 				admin.invitation?
		assert_false 		admin.membership_request?
		permissions = %w(manage_admins manage_announcements write_article view_articles manage_articles 
			view_audit_logs manage_forums manage_membership_forms approve_membership_request manage_custom_pages 
			invite_admins create_program customize_program rate_answer manage_answers ask_question view_questions 
			follow_question answer_question manage_questions manage_profile_forms view_reports manage_surveys manage_themes access_themes 
			add_non_admin_profiles  update_profiles manage_user_states work_on_behalf manage_email_templates view_ra manage_translations
		)

		has_permissions?(admin, permissions)

    # Abstract Views
    assert_equal [
      "All Users",
      "All Administrators",
      "All Employees",
      "Users With Low Profile Scores",
      "Flagged Content",
      "Pending Membership Applications"], portal.abstract_views.collect(&:title)

    # Check Demographic Report View Columns
    assert_equal portal.demographic_report_view_columns, portal.report_view_columns.for_demographic_report.collect(&:column_key)
  end
end