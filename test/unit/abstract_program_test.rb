require_relative './../test_helper.rb'

class AbstractProgramTest < ActiveSupport::TestCase
  # All relevant tests are added for Program and Organization models in their
  # respective unit test files.

  def test_comparable_with
    # Taking 2 similar questions
    p1 = programs(:albers)
    p2 = programs(:albers)
    assert p1.comparable_with?(p2)

    # Questions should belong to the same program
    p1 = programs(:ceg)
    assert !p1.comparable_with?(p2)

    # Organization question should be comparable with the questions in it's
    # program.

    # Org vs Prog question
    p1 = programs(:org_primary)
    assert p1.comparable_with?(p2)

    # Org vs Org question
    p2 = programs(:org_primary)
    assert p1.comparable_with?(p2)

    # Org vs Prog question
    p2 = programs(:albers)
    assert p1.comparable_with?(p2)

    # Prog vs Org question
    p1 = programs(:albers)
    p2 = programs(:org_primary)
    assert p1.comparable_with?(p2)

    # Prog vs some other Org question
    p1 = programs(:albers)
    p2 = programs(:org_anna_univ)
    assert !p1.comparable_with?(p2)

    # Org vs some other Org question
    p1 = programs(:org_primary)
    p2 = programs(:org_anna_univ)
    assert !p1.comparable_with?(p2)

    # Different programs within organization
    p1 = programs(:albers)
    p2 = programs(:nwen)
    assert !p1.comparable_with?(p2)

    # Same program
    p1 = programs(:albers)
    p2 = programs(:albers)
    assert p1.comparable_with?(p2)
  end

  def test_linkedin_imports_feature_enabled
    p = programs(:albers)
    o = programs(:org_primary)

    p.enable_feature(FeatureName::LINKEDIN_IMPORTS, true)
    assert o.linkedin_imports_allowed?
    assert p.linkedin_imports_feature_enabled?

    p.enable_feature(FeatureName::LINKEDIN_IMPORTS, false)
    security_setting = o.security_setting
    security_setting.linkedin_token = ""
    security_setting.save!
    assert_false o.linkedin_imports_allowed?

    assert_equal false, p.linkedin_imports_feature_enabled?
  end

  def test_mailer_template_enable_or_disable
    program = programs(:albers)
    program.mailer_template_enable_or_disable(AdminMessageNotification, true)
    assert_false program.email_template_disabled_for_activity?(AdminMessageNotification)
    program.mailer_template_enable_or_disable(AdminMessageNotification, false)
    assert program.email_template_disabled_for_activity?(AdminMessageNotification)

    org = programs(:org_primary)
    org.mailer_template_enable_or_disable(AdminMessageNotification, true)
    assert_false org.email_template_disabled_for_activity?(AdminMessageNotification)
    org.mailer_template_enable_or_disable(AdminMessageNotification, false)
    assert org.email_template_disabled_for_activity?(AdminMessageNotification)
  end

  def test_mentoring_connection_meetings_feature_enabled
    p = programs(:albers)

    p.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING, true)
    assert p.mentoring_connection_meeting_enabled?

    p.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING, false)
    assert_equal false, p.mentoring_connection_meeting_enabled?
  end

  def test_campaign_management_enabled
    p = programs(:albers)

    p.enable_feature(FeatureName::CAMPAIGN_MANAGEMENT, true)
    assert p.campaign_management_enabled?

    p.enable_feature(FeatureName::CAMPAIGN_MANAGEMENT, false)
    assert_equal false, p.campaign_management_enabled?
  end

  def test_global_reports_v3_applicable
    program = programs(:albers)
    program.enable_feature(FeatureName::GLOBAL_REPORTS_V3, false)

    assert_nil program.global_reports_v3_applicable?
    assert program.global_reports_v3_applicable?(accessing_as_super_admin: true)
    
    member = Member.new(admin: false)
    user = User.new(member: member)
    assert member.stubs(:mentoradmin?).returns(true)
    assert program.global_reports_v3_applicable?(member: member)
    assert program.global_reports_v3_applicable?(user: user)

    assert member.stubs(:mentoradmin?).returns(false)
    assert_false member.admin?
    assert_nil program.global_reports_v3_applicable?(member: member)
    assert_nil program.global_reports_v3_applicable?(user: user)

    member.admin = true
    assert_false program.global_reports_v3_applicable?(member: member)
    program.enable_feature(FeatureName::GLOBAL_REPORTS_V3, true)
    assert program.global_reports_v3_applicable?(member: member)
  end

  def test_skip_and_favorite_profiles_enabled
    p = programs(:albers)
    student_role = p.find_role(RoleConstants::STUDENT_NAME)

    assert student_role.has_permission_name?("view_mentors")
    assert p.skip_and_favorite_profiles_enabled?

    student_role.remove_permission("view_mentors")
    assert_false student_role.has_permission_name?("view_mentors")
    assert_false p.skip_and_favorite_profiles_enabled?

    student_role.add_permission("view_mentors")
    assert student_role.has_permission_name?("view_mentors")

    p.stubs(:matching_by_mentee_alone?).returns(false)
    assert_false p.skip_and_favorite_profiles_enabled?

    p.enable_feature(FeatureName::SKIP_AND_FAVORITE_PROFILES, false)
    assert_false p.skip_and_favorite_profiles_enabled?

    p = programs(:org_primary)
    p.expects(:matching_by_mentee_alone).never
    p.expects(:find_role).never
    p.enable_feature(FeatureName::SKIP_AND_FAVORITE_PROFILES, true)
    assert_false p.skip_and_favorite_profiles_enabled?
  end

  def test_mentoring_connections_v2_feature_enabled
    p = programs(:albers)

    p.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    assert p.mentoring_connections_v2_enabled?

    p.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, false)
    assert_equal false, p.mentoring_connections_v2_enabled?
  end

  def test_career_development_enabled
    p = programs(:org_primary)

    assert_equal false, p.career_development_enabled?
    p.enable_feature(FeatureName::CAREER_DEVELOPMENT, true)
    assert p.career_development_enabled?

    p.enable_feature(FeatureName::CAREER_DEVELOPMENT, false)
    assert_equal false, p.career_development_enabled?
  end

  def test_contract_management_enabled
    p = programs(:albers)

    assert_equal false, p.contract_management_enabled?
    p.enable_feature(FeatureName::CONTRACT_MANAGEMENT, true)
    assert p.contract_management_enabled?

    p.enable_feature(FeatureName::CONTRACT_MANAGEMENT, false)
    assert_equal false, p.contract_management_enabled?
  end

  def test_create_update_feature_record_for_tandem_features
    program = programs(:albers)
    feature_name = FeatureName::CALENDAR_SYNC_V2
    feature = Feature.find_by(name: feature_name)
    
    assert_false program.calendar_sync_v2_enabled?
    assert_false program.enhanced_meeting_scheduler_enabled?
    assert_false program.mentor_offer_enabled?
    assert_false program.organization_wide_calendar_access_enabled?
    assert_nil program.organization_features.find_by(feature_id: feature.id)
    
    program.create_update_feature_record(true, feature, program.organization_features.find_by(feature_id: feature.id))
    assert program.reload.calendar_sync_v2_enabled?
    assert program.enhanced_meeting_scheduler_enabled?
    assert_false program.mentor_offer_enabled?
    assert_false program.organization_wide_calendar_access_enabled?

    program.create_update_feature_record(false, feature, program.organization_features.find_by(feature_id: feature.id))
    assert_false program.reload.calendar_sync_v2_enabled?
    assert_false program.enhanced_meeting_scheduler_enabled?
    assert_false program.mentor_offer_enabled?
    assert_false program.organization_wide_calendar_access_enabled?

    mentor_offer_feature = Feature.find_by(name: FeatureName::OFFER_MENTORING)
    program.create_update_feature_record(true, mentor_offer_feature, program.organization_features.find_by(feature_id: mentor_offer_feature.id))
    assert_false program.reload.calendar_sync_v2_enabled?
    assert_false program.enhanced_meeting_scheduler_enabled?
    assert program.mentor_offer_enabled?
    assert_false program.organization_wide_calendar_access_enabled?

    org_wide_calendar_access_feature = Feature.find_by(name: FeatureName::ORG_WIDE_CALENDAR_ACCESS)
    program.create_update_feature_record(true, org_wide_calendar_access_feature, program.organization_features.find_by(feature_id: org_wide_calendar_access_feature.id))
    Feature.handle_feature_dependency(program.reload)
    assert program.reload.calendar_sync_v2_enabled?
    assert program.enhanced_meeting_scheduler_enabled?
    assert program.mentor_offer_enabled?
    assert program.organization_wide_calendar_access_enabled?
  end

  def test_membership_eligibility_rules_enabled
    p = programs(:albers)

    assert_equal false, p.membership_eligibility_rules_enabled?
    p.enable_feature(FeatureName::MEMBERSHIP_ELIGIBILITY_RULES, true)
    assert p.membership_eligibility_rules_enabled?

    p.enable_feature(FeatureName::MEMBERSHIP_ELIGIBILITY_RULES, false)
    assert_equal false, p.membership_eligibility_rules_enabled?
  end

  def test_language_settings_enabled
    p = programs(:org_primary)

    p.enable_feature(FeatureName::LANGUAGE_SETTINGS, true)
    assert p.language_settings_enabled?

    p.enable_feature(FeatureName::LANGUAGE_SETTINGS, false)
    assert_equal false, p.language_settings_enabled?
  end

  def test_customize_emails_enabled
    p = programs(:org_primary)

    p.enable_feature(FeatureName::CUSTOMIZE_EMAILS, true)
    assert p.customize_emails_enabled?

    p.enable_feature(FeatureName::CUSTOMIZE_EMAILS, false)
    assert_equal false, p.customize_emails_enabled?
  end

  def test_manager_enabled
    p = programs(:org_primary)

    p.enable_feature(FeatureName::MANAGER, true)
    assert_equal true, p.manager_enabled?

    p.enable_feature(FeatureName::MANAGER, false)
    assert_equal false, p.manager_enabled?
  end

  def test_logged_in_pages_enabled
    p = programs(:org_primary)

    p.enable_feature(FeatureName::LOGGED_IN_PAGES, true)
    assert_equal true, p.logged_in_pages_enabled?

    p.enable_feature(FeatureName::LOGGED_IN_PAGES, false)
    assert_equal false, p.logged_in_pages_enabled?
  end

  def test_mobile_view_enabled
    org = programs(:org_primary)

    org.enable_feature(FeatureName::MOBILE_VIEW, true)
    assert org.mobile_view_enabled?

    org.enable_feature(FeatureName::MOBILE_VIEW, false)
    assert_false org.mobile_view_enabled?
  end

  def test_mentor_recommendation_enabled
    p = programs(:org_primary)

    assert_false p.mentor_recommendation_enabled?

    p.enable_feature(FeatureName::MENTOR_RECOMMENDATION, true)
    assert p.mentor_recommendation_enabled?

    p.enable_feature(FeatureName::MENTOR_RECOMMENDATION, false)
    assert_false p.mentor_recommendation_enabled?
  end

  def test_calendar_sync_enabled
    p = programs(:org_primary)

    p.enable_feature(FeatureName::CALENDAR_SYNC, true)
    assert p.calendar_sync_enabled?

    p.enable_feature(FeatureName::CALENDAR_SYNC, false)
    assert_equal false, p.calendar_sync_enabled?
  end

  def test_calendar_sync_v2_enabled
    program = programs(:org_primary)

    program.enable_feature(FeatureName::CALENDAR_SYNC_V2)
    assert program.calendar_sync_v2_enabled?

    program.enable_feature(FeatureName::CALENDAR_SYNC_V2, false)
    assert_false program.calendar_sync_v2_enabled?
  end

  def test_share_progress_reports_enabled
    program = programs(:org_primary)

    program.enable_feature(FeatureName::SHARE_PROGRESS_REPORTS)
    assert program.share_progress_reports_enabled?

    program.enable_feature(FeatureName::SHARE_PROGRESS_REPORTS, false)
    assert_false program.share_progress_reports_enabled?
  end

  def test_calendar_sync_v2_for_member_applicable
    program = programs(:org_primary)

    assert_false program.calendar_sync_v2_enabled?
    assert_false program.calendar_sync_v2_for_member_applicable?
    program.enable_feature(FeatureName::CALENDAR_SYNC_V2)
    assert program.calendar_sync_v2_for_member_applicable?

    program.enable_feature(FeatureName::ORG_WIDE_CALENDAR_ACCESS)
    assert program.organization_wide_calendar_access_enabled?
    assert_false program.calendar_sync_v2_for_member_applicable?
  end

  def test_enhanced_meeting_scheduler_enabled
    program = programs(:org_primary)

    program.enable_feature(FeatureName::ENHANCED_MEETING_SCHEDULER)
    assert program.enhanced_meeting_scheduler_enabled?

    program.enable_feature(FeatureName::ENHANCED_MEETING_SCHEDULER, false)
    assert_false program.enhanced_meeting_scheduler_enabled?
  end

  def test_mentor_to_mentee_matching_enabled
    org = programs(:org_primary)

    org.enable_feature(FeatureName::MENTOR_TO_MENTEE_MATCHING)
    assert org.mentor_to_mentee_matching_enabled?

    org.enable_feature(FeatureName::MENTOR_TO_MENTEE_MATCHING, false)
    assert_false org.mentor_to_mentee_matching_enabled?

    org.enable_feature(FeatureName::MENTOR_TO_MENTEE_MATCHING)
    program = programs(:albers)
    assert program.mentor_to_mentee_matching_enabled?
    program.enable_feature(FeatureName::MENTOR_TO_MENTEE_MATCHING, false)
    assert org.mentor_to_mentee_matching_enabled?
    assert_false program.mentor_to_mentee_matching_enabled?
  end

  def test_match_report_enabled
    org = programs(:org_primary)

    org.enable_feature(FeatureName::MATCH_REPORT)
    assert org.match_report_enabled?

    org.enable_feature(FeatureName::MATCH_REPORT, false)
    assert_false org.match_report_enabled?

    org.enable_feature(FeatureName::MATCH_REPORT)
    program = programs(:albers)
    assert program.match_report_enabled?
    program.enable_feature(FeatureName::MATCH_REPORT, false)
    assert org.match_report_enabled?
    assert_false program.match_report_enabled?
  end

  def test_default_section
    org = programs(:org_primary)
    assert_equal sections(:sections_1), org.default_section
  end

  def test_has_many_customized_terms
    org = programs(:org_primary)
    prog = programs(:albers)

    assert_equal 8, org.customized_terms.count
    assert_equal 5, prog.customized_terms.count
    prog.roles.destroy_all

    assert_difference 'CustomizedTerm.count', -5 do
      prog.destroy
    end
  end

  def test_admin_term_for_program_and_org
    admin_custom_term_at_program = programs(:albers).roles.find_by(name: RoleConstants::ADMIN_NAME).customized_term
    admin_custom_term_at_org = programs(:albers).organization.admin_custom_term
    admin_custom_term_at_program.update_attribute(:term, "Program Admin")
    admin_custom_term_at_org.update_attribute(:term, "Org Admin")
    assert_equal "Org Admin", programs(:albers).organization.admin_custom_term.term
    assert_equal "Org Admin", programs(:albers).organization.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::ADMIN_NAME).term
    assert_equal "Program Admin", programs(:albers).term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::ADMIN_NAME).term
  end

  def test_program_term_for_program_and_org
    program_custom_term_at_org = programs(:albers).organization.customized_terms.find_by(term_type: CustomizedTerm::TermType::PROGRAM_TERM)
    program_custom_term_at_org.update_attribute(:term, "Unique-1 Program")
    assert_equal "Unique-1 Program",  programs(:albers).organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term
    assert_equal "Unique-1 Program", programs(:albers).term_for(CustomizedTerm::TermType::PROGRAM_TERM).term
  end

  def test_student_term
    assert_equal "Mentee", programs(:albers).organization.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).term
    assert_equal "Student", programs(:albers).term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).term
  end

  def test_article_term
    article_custom_term_at_program = programs(:albers).customized_terms.find_by(term_type: CustomizedTerm::TermType::ARTICLE_TERM)
    article_custom_term_at_org = programs(:albers).organization.customized_terms.find_by(term_type: CustomizedTerm::TermType::ARTICLE_TERM)
    article_custom_term_at_program.update_attribute(:term, "Program Article")
    article_custom_term_at_org.update_attribute(:term, "Org Article")

    assert_equal "Org Article", programs(:albers).organization.term_for(CustomizedTerm::TermType::ARTICLE_TERM).term
    assert_equal "Program Article", programs(:albers).term_for(CustomizedTerm::TermType::ARTICLE_TERM).term
  end

  def test_searchable_classes
    classes = programs(:albers).searchable_classes(users(:f_student))
    assert_equal [User, QaQuestion, Article, Resource, Topic], classes

    add_role_permission(fetch_role(:albers, :student), "view_find_new_projects")
    users(:f_student).reload
    classes = programs(:albers).searchable_classes(users(:f_student))
    assert_equal [User, Group, QaQuestion, Article, Resource, Topic], classes
  end

  def test_has_many_resources
    program = programs(:albers)
    organization = programs(:org_primary)
    assert_equal 6, organization.resources.count

    organization_resource = create_resource(organization: organization)
    assert_equal 7, organization.resources.count
  end

  def test_association_has_many_admin_messages
    sender = members(:f_admin)
    receiver = members(:f_mentor)
    program = programs(:albers)
    organization = programs(:org_primary)
    admin_message_1 = create_admin_message(:sender => sender, :receiver => receiver, :program => program)
    admin_message_2 = create_admin_message(:sender => sender, :receiver => receiver, :program => organization)
    assert_equal admin_message_1, program.admin_messages.last
    assert_equal admin_message_2, organization.admin_messages.last
  end

  def test_association_has_many_admin_messages_receiver
    sender = members(:f_admin)
    receiver = members(:f_mentor)
    program = programs(:albers)
    organization = programs(:org_primary)
    admin_message_1 = create_admin_message(:sender => sender, :receiver => receiver, :program => program)
    admin_message_2 = create_admin_message(:sender => sender, :receiver => receiver, :program => organization)

    assert_equal admin_message_1.message_receivers.last, program.admin_message_receivers.last
    assert_equal admin_message_2.message_receivers.last, organization.admin_message_receivers.last
  end

  def test_received_admin_message_ids
    program = programs(:albers)
    m2, m1 = messages(:second_admin_message), messages(:first_admin_message)
    assert_equal_unordered [m2.id, m1.id], program.received_admin_message_ids.map(&:id)
    m2.update_attributes(parent_id: m1.id, root_id: m1.id)
    m2.message_receivers.update_all("message_root_id=#{m1.id}")
    assert_equal_unordered [m1.id, m2.id], program.received_admin_message_ids.map(&:id)
  end

  def test_sent_admin_message_ids
    program = programs(:foster)
    m1 = create_admin_message(sender: members(:foster_admin), receivers: [members(:foster_mentor1), members(:foster_student1)], program: program)
    m2 = create_admin_message(sender: members(:foster_mentor1), program: program)
    assert_equal_unordered [m1.id], program.sent_admin_message_ids.map(&:id)
    m1.message_receivers.delete_all
    assert_equal_unordered [m1.id], program.sent_admin_message_ids.map(&:id)
  end

  def test_admin_messages_unread_count
    admin = members(:f_admin)
    program = programs(:albers)
    assert_equal 0, program.admin_messages_unread_count
    m1 = create_admin_message(:sender => members(:f_student))
    assert_equal 1, program.admin_messages_unread_count
    m1.mark_as_read!(members(:f_admin))
    assert_equal 0, program.admin_messages_unread_count
  end

  def test_mentoring_tip_enabled
    p = programs(:org_primary)

    p.enable_feature(FeatureName::MENTORING_INSIGHTS, true)
    assert p.mentoring_insights_enabled?
    p.programs.each do |prog|
      assert prog.mentoring_insights_enabled?
    end

    prog = programs(:albers)
    p.enable_feature(FeatureName::MENTORING_INSIGHTS, false)
    prog.enable_feature(FeatureName::MENTORING_INSIGHTS, true)
    assert prog.mentoring_insights_enabled?
    assert_false p.mentoring_insights_enabled?
  end

  def test_get_report_alerts_to_notify
    alert = report_alerts(:report_alert_1)
    assert_equal Report::Alert::OperatorType::LESS_THAN, alert.operator
    assert_equal 10, alert.target
    assert (alert.metric.count >  alert.target)
    program = programs(:albers)
    assert_equal [], program.get_report_alerts_to_notify

    alert.update_attribute(:operator, Report::Alert::OperatorType::GREATER_THAN)
    program.reload
    assert_equal [report_alerts(:report_alert_1)], program.get_report_alerts_to_notify
    alert.update_attribute(:target, 1000)
    program.reload
    assert_equal [], program.get_report_alerts_to_notify

    alert.update_attribute(:operator, Report::Alert::OperatorType::LESS_THAN)
    program.reload
    assert (alert.metric.count <  alert.target)
    assert_equal [report_alerts(:report_alert_1)], program.get_report_alerts_to_notify

    alert.update_attribute(:operator, Report::Alert::OperatorType::EQUAL)
    program.reload
    assert_equal [], program.get_report_alerts_to_notify

    alert.update_attribute(:target, alert.metric.count)
    program.reload
    assert_equal [report_alerts(:report_alert_1)], program.get_report_alerts_to_notify
  end

  def test_has_many_ab_tests
    prog = programs(:albers)
    assert_equal [], prog.ab_tests

    test = prog.ab_tests.create!(test: 'Something', enabled: true)
    assert_equal ['Something'], prog.reload.ab_tests.pluck(:test)

    assert_equal "ProgramAbTest", AbstractProgram.reflect_on_association(:ab_tests).class_name
    assert_equal :destroy, AbstractProgram.reflect_on_association(:ab_tests).options[:dependent]
  end

  def test_enable_ab_test
    prog = programs(:albers)
    assert_difference "ProgramAbTest.count", 1 do
      prog.enable_ab_test('something new', true)
    end
    assert_equal ['something new'], prog.reload.ab_tests.pluck(:test)
    assert_equal [true], prog.reload.ab_tests.pluck(:enabled)

    assert_no_difference "ProgramAbTest.count" do
      prog.enable_ab_test('something new', false)
    end
    assert_equal ['something new'], prog.reload.ab_tests.pluck(:test)
    assert_equal [false], prog.reload.ab_tests.pluck(:enabled)
  end

  def test_coach_rating_enabled
    assert_false programs(:albers).coach_rating_enabled?

    #enabling coach rating feature
    programs(:albers).enable_feature(FeatureName::COACH_RATING, true)
    assert programs(:albers).coach_rating_enabled?
  end

  def test_user_csv_import_enabled
    assert_false programs(:albers).user_csv_import_enabled?

    #enabling user csv import feature
    programs(:albers).enable_feature(FeatureName::USER_CSV_IMPORT, true)
    assert programs(:albers).user_csv_import_enabled?
  end

  def test_return_custom_term_hash
    program = programs(:albers)
    custom_term_hash = program.return_custom_term_hash
    assert_equal custom_term_hash[:_mentee], program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).term_downcase
    assert_equal custom_term_hash[:_mentor], program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term_downcase
    assert_equal custom_term_hash[:_admin], program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::ADMIN_NAME).term_downcase
    assert_equal custom_term_hash[:_meeting], program.term_for(CustomizedTerm::TermType::MEETING_TERM).term_downcase
    assert_equal custom_term_hash[:_mentoring], program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase
    assert_equal custom_term_hash[:_article], program.term_for(CustomizedTerm::TermType::ARTICLE_TERM).term_downcase
    assert_equal custom_term_hash[:_resource], program.term_for(CustomizedTerm::TermType::RESOURCE_TERM).term_downcase
    assert_equal custom_term_hash[:_mentoring_connection], program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase
    assert_equal custom_term_hash[:_career_development], program.term_for(CustomizedTerm::TermType::CAREER_DEVELOPMENT_TERM).term_downcase

    org = programs(:org_primary)
    custom_term_hash = org.return_custom_term_hash
    assert_equal custom_term_hash[:_mentee], org.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).term_downcase
    assert_equal custom_term_hash[:_mentor], org.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term_downcase
    assert_equal custom_term_hash[:_admin], org.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::ADMIN_NAME).term_downcase
    assert_equal custom_term_hash[:_meeting], org.term_for(CustomizedTerm::TermType::MEETING_TERM).term_downcase
    assert_equal custom_term_hash[:_mentoring], org.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase
    assert_equal custom_term_hash[:_article], org.term_for(CustomizedTerm::TermType::ARTICLE_TERM).term_downcase
    assert_equal custom_term_hash[:_resource], org.term_for(CustomizedTerm::TermType::RESOURCE_TERM).term_downcase
    assert_equal custom_term_hash[:_mentoring_connection], org.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase
    assert_equal custom_term_hash[:_career_development], org.term_for(CustomizedTerm::TermType::CAREER_DEVELOPMENT_TERM).term_downcase
  end

  def test_return_custom_term_hash_with_third_role
    program = programs(:albers)
    program.stubs(:third_role_hash).returns({fruit: "apple"})
    program.stubs(:return_custom_term_hash).returns({text: "something"})
    custom_term_hash_with_third_role = program.return_custom_term_hash_with_third_role
    assert_equal 2, custom_term_hash_with_third_role.size
    assert_equal "something", custom_term_hash_with_third_role[:text]
    assert_equal "apple", custom_term_hash_with_third_role[:fruit]
  end

  def test_third_role_hash
    program = programs(:albers)
    assert_nil program.roles.find_by(name: RoleConstants::TEACHER_NAME)

    hash = {}
    hash[:_Third_Role] = "feature.custom_terms.teacher".translate
    hash[:_third_role] = "feature.custom_terms.downcase.teacher".translate
    hash[:_Third_Roles] = "feature.custom_terms.pluralize.teacher".translate
    hash[:_a_Third_Role] = "feature.custom_terms.articalize.teacher".translate
    hash[:_a_third_role] = "feature.custom_terms.articalize_downcase.teacher".translate
    hash[:_third_roles] = "feature.custom_terms.pluralize_downcase.teacher".translate

    assert_equal hash, program.third_role_hash

    role = program.roles.first
    role.update_attribute(:name, RoleConstants::TEACHER_NAME)
    program.reload
    role = program.roles.find_by(name: RoleConstants::TEACHER_NAME)
    ct = role.customized_term
    ct.term = "Apple"
    ct.term_downcase = "apple"
    ct.pluralized_term = "Apples"
    ct.articleized_term = "an Apple"
    ct.articleized_term_downcase = "an apple"
    ct.pluralized_term_downcase = "apples"
    ct.save!

    hash[:_Third_Role] = "Apple"
    hash[:_third_role] = "apple"
    hash[:_Third_Roles] = "Apples"
    hash[:_a_Third_Role] = "an Apple"
    hash[:_a_third_role] = "an apple"
    hash[:_third_roles] = "apples"
    assert_equal hash, program.third_role_hash
  end

  def test_theme_vars
    program = programs(:albers)
    program.update_attributes(theme_id: nil)
    assert_false program.active_theme.present?
    assert_equal program.theme_vars, {}

    program.activate_theme(Theme.first)
    assert program.active_theme.present?
    assert_equal program.theme_vars, program.active_theme.vars
  end

  def test_has_many_actioned_rollout_emails
    p = programs(:albers)
    re = p.actioned_rollout_emails.create!
    assert_equal [re], p.actioned_rollout_emails
    assert_equal :destroy, Program.reflect_on_association(:actioned_rollout_emails).options[:dependent]
  end

  def test_translation_settings_sub_categories
    program = programs(:albers)
    assert_equal [{:id=>0, :heading=>"General Settings"}, {:id=>1, :heading=>"Terminology"}, {:id=>2, :heading=>"Membership"}, {:id=>8, :heading=>"Matching Settings"}], program.translation_settings_sub_categories
    assert_equal [{:id=>0, :heading=>"General Settings"}, {:id=>1, :heading=>"Terminology"}], program.organization.translation_settings_sub_categories
  end

  def test_translation_setting_sub_categories_for_portal
    program = programs(:primary_portal)
    assert_equal [{:id=>0, :heading=>"General Settings"}, {:id=>1, :heading=>"Terminology"}, {:id=>2, :heading=>"Membership"}], program.translation_settings_sub_categories
    assert_equal [{:id=>0, :heading=>"General Settings"}, {:id=>1, :heading=>"Terminology"}], program.organization.translation_settings_sub_categories
  end

  def test_reset_mails_content_and_update_rollout_for_action_type
    program = programs(:albers)
    assert_difference "RolloutEmail.count", 1 do
      program.reset_mails_content_and_update_rollout(only_copied_content: true)
    end
    re = RolloutEmail.last
    assert_equal re.action_type, RolloutEmail::ActionType::UPDATE_ALL_NON_CUSTOMIZED

    assert_difference "RolloutEmail.count", 1 do
      program.reset_mails_content_and_update_rollout
    end
    re = RolloutEmail.last
    assert_equal re.action_type, RolloutEmail::ActionType::UPDATE_ALL
  end

  def test_enable_disable_feature
    assert        programs(:albers).has_feature?("answers")
    programs(:albers).enable_disable_feature("answers", false)
    assert_false  programs(:albers).has_feature?("answers")

    programs(:albers).enable_disable_feature("answers", true)
    assert        programs(:albers).has_feature?("answers")
  end

  def test_removed_as_feature_from_ui
    removed_from_ui = [
      FeatureName::OFFER_MENTORING, FeatureName::CALENDAR
    ] + FeatureName.tandem_features
    assert_equal removed_from_ui, programs(:org_primary).removed_as_feature_from_ui
  end

  def test_get_role_names
    assert_equal ["admin", "mentor", "student", "user"], programs(:albers).get_role_names
    assert_equal ["admin", "employee"], programs(:primary_portal).get_role_names
  end

  def test_logo_url
    program = programs(:albers)
    ProgramAsset.find_or_create_by(program_id: program.id)
    program.program_asset.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    program.program_asset.save!
    translation_id = program.program_asset.translation.id
    assert_match(/logos\/#{translation_id}\/original\/test_pic.png/, program.logo_url)
    GlobalizationUtils.run_in_locale("fr-CA") do
      assert_match(/logos\/#{translation_id}\/original\/test_pic.png/, program.logo_url)
    end
  end

  def test_logo_url_non_default_locale
    program = programs(:albers)
    ProgramAsset.find_or_create_by(program_id: program.id)
    program.program_asset.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    program.program_asset.save!
    GlobalizationUtils.run_in_locale("fr-CA") do
      program.program_asset.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
      program.program_asset.save!
      translation_id = program.program_asset.translation.id
      assert_match(/logos\/#{translation_id}\/original\/test_pic.png/, program.logo_url)
    end
  end

  def test_banner_url
    program = programs(:albers)
    ProgramAsset.find_or_create_by(program_id: program.id)
    program.program_asset.banner = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    program.program_asset.save!
    translation_id = program.program_asset.translation.id
    assert_match(/banners\/#{translation_id}\/original\/test_pic.png/, program.banner_url)
    GlobalizationUtils.run_in_locale("fr-CA") do
      assert_match(/banners\/#{translation_id}\/original\/test_pic.png/, program.banner_url)
    end
  end

  def test_banner_url_non_default_locale
    program = programs(:albers)
    ProgramAsset.find_or_create_by(program_id: program.id)
    program.program_asset.banner = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    program.program_asset.save!
    GlobalizationUtils.run_in_locale("fr-CA") do
      program.program_asset.banner = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
      program.program_asset.save!
      translation_id = program.program_asset.translation.id
      assert_match(/banners\/#{translation_id}\/original\/test_pic.png/, program.banner_url)
    end
  end

  def test_translated_fields
    org = programs(:org_primary)
    GlobalizationUtils.run_in_locale(:en) do
      org.agreement = "english agreement"
      org.privacy_policy = "english privacy policy"
      org.browser_warning = "english browser warning"
      org.save!
    end
    GlobalizationUtils.run_in_locale(:"fr-CA") do
      org.agreement = "french agreement"
      org.privacy_policy = "french privacy policy"
      org.browser_warning = "french browser warning"
      org.save!
    end
    GlobalizationUtils.run_in_locale(:en) do
      assert_equal "english agreement", org.agreement
      assert_equal "english privacy policy", org.privacy_policy
      assert_equal "english browser warning", org.browser_warning
    end
    GlobalizationUtils.run_in_locale(:"fr-CA") do
      assert_equal "french agreement", org.agreement
      assert_equal "french privacy policy", org.privacy_policy
      assert_equal "french browser warning", org.browser_warning
    end
  end

  def test_permanently_disabled_features
    org = programs(:org_primary)
    assert_equal [], org.permanently_disabled_features

    program = programs(:albers)
    assert_equal [], program.permanently_disabled_features
  end

  def test_linkedin_imports_allowed
    org = programs(:org_primary)
    assert org.security_setting.linkedin_token.present?
    assert org.security_setting.linkedin_secret.present?
    assert org.linkedin_imports_allowed?

    security_setting = org.security_setting
    security_setting.linkedin_token = ""
    security_setting.save!
    assert_false org.linkedin_imports_allowed?
  end

  def test_campaign_feature_non_editable
    org = programs(:org_primary)
    assert org.campaign_feature_non_editable?
    org.expects(:programs_with_active_user_campaigns_present?).returns(false)
    assert_false org.campaign_feature_non_editable?
  end

  def test_previous_user_csv_import_info_hash
    program = programs(:albers)

    empty_hash = {}

    assert_nil program.user_csv_imports.first
    assert_equal_hash empty_hash, program.previous_user_csv_import_info_hash

    info_hash_1 = {1 => 2, 2=> 3, 3=> 4}

    user_csv_import = program.user_csv_imports.new
    user_csv_import.member = members(:f_admin)
    user_csv_import.attachment = fixture_file_upload("/files/csv_import.csv", "text/csv")
    user_csv_import.local_csv_file_path = Rails.root.to_s + "/test/fixtures/files/csv_import.csv"
    user_csv_import.info = info_hash_1.to_yaml
    user_csv_import.save!

    assert_equal_hash empty_hash, program.previous_user_csv_import_info_hash

    info_hash_2 = {4 => 5, 5=> 6, 6 => 7}

    user_csv_import = program.user_csv_imports.new
    user_csv_import.member = members(:f_admin)
    user_csv_import.attachment = fixture_file_upload("/files/csv_import.csv", "text/csv")
    user_csv_import.local_csv_file_path = Rails.root.to_s + "/test/fixtures/files/csv_import.csv"
    user_csv_import.info = info_hash_2.to_yaml
    user_csv_import.save!

    assert_equal_hash info_hash_1, program.previous_user_csv_import_info_hash
  end

  def test_profile_questions_for_user_csv_import
    program = programs(:albers)

    pqs = program.profile_questions_for(program.roles.collect(&:name), {:default => false, :fetch_all => true})
    pqs = pqs.select{|pq| !pq.file_type? && !pq.education? && !pq.manager? && !pq.experience? && !pq.publication?}
    pqs.first.role_questions.update_all(:private => RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)

    assert_equal program.profile_questions_for_user_csv_import, pqs

    pqs = program.profile_questions_for([RoleConstants::MENTOR_NAME], {:default => false, :fetch_all => true})
    pqs.reject!{|pq| pq.file_type? || pq.education? || pq.manager? || pq.experience? || pq.publication?}

    assert_equal program.profile_questions_for_user_csv_import([RoleConstants::MENTOR_NAME]), pqs

    organization = programs(:org_primary)

    pqs = organization.profile_questions.to_a
    pqs.reject!{|pq| pq.file_type? || pq.education? || pq.manager? || pq.experience? || pq.publication?}

    assert_equal organization.profile_questions_for_user_csv_import, pqs
  end

  def test_translation_import_dependent_destroy
    assert_equal "TranslationImport", Program.reflect_on_association(:translation_imports).class_name
    assert_equal :destroy, Program.reflect_on_association(:translation_imports).options[:dependent]
  end

  def test_has_many_translation_import
    program = programs(:albers)
    organization= programs(:org_primary)
    info_hash = {
      0 => "1,2,3",
      1 => "4,5,6"
    }
    translation_import1 = create_translation_import(program: program, attachment: fixture_file_upload("/files/translation_import.csv", "text/csv"), local_csv_file_path: Rails.root.to_s + "/test/fixtures/files/translation_import.csv", info: info_hash)
    assert_equal translation_import1, program.translation_imports.last
    assert_equal 1, program.translation_imports.count

    translation_import2 = create_translation_import(program: program, attachment: fixture_file_upload("/files/translation_import.csv", "text/csv"), local_csv_file_path: Rails.root.to_s + "/test/fixtures/files/translation_import.csv", info: info_hash)
    assert_equal translation_import2, program.translation_imports.last
    assert_equal 2, program.translation_imports.count

    translation_import3 = create_translation_import(program: organization, attachment: fixture_file_upload("/files/translation_import.csv", "text/csv"), local_csv_file_path: Rails.root.to_s + "/test/fixtures/files/translation_import.csv", info: info_hash)
    assert_equal translation_import3, organization.translation_imports.last
    assert_equal 1, organization.translation_imports.count
  end

  def test_get_accessible_meetings_list_calendar_enabled
    program = programs(:albers)
    programs(:albers).enable_feature(FeatureName::CALENDAR)
    assert_equal [meetings(:upcoming_calendar_meeting), meetings(:past_calendar_meeting), meetings(:completed_calendar_meeting), meetings(:cancelled_calendar_meeting)], program.get_accessible_meetings_list(Meeting.all)
    time = 2.days.from_now
    meeting = create_meeting(force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    assert_equal [meetings(:upcoming_calendar_meeting), meetings(:past_calendar_meeting), meetings(:completed_calendar_meeting), meetings(:cancelled_calendar_meeting), meeting], program.get_accessible_meetings_list(Meeting.all)
  end

  def test_copy_program_asset
    organization = programs(:org_anna_univ)
    organization__program_asset = organization.create_program_asset
    organization__program_asset.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    organization__program_asset.banner = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    organization__program_asset.save!
    GlobalizationUtils.run_in_locale("fr-CA") do
      organization__program_asset.logo = fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png')
      organization__program_asset.banner = fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png')
      organization__program_asset.save!
    end

    assert_difference "ProgramAsset.count", 3 do
      assert_difference "ProgramAsset::Translation.count", 6 do
        organization.copy_program_asset(organization.program_ids)
      end
    end
    program__program_asset = organization.programs.first.program_asset
    assert_equal "test_pic.png", program__program_asset.logo_file_name
    assert_equal "test_pic.png", program__program_asset.banner_file_name
    GlobalizationUtils.run_in_locale("fr-CA") do
      assert_equal "pic_2.png", program__program_asset.logo_file_name
      assert_equal "pic_2.png", program__program_asset.logo_file_name
    end
  end

  def test_copy_program_asset_with_override
    program = programs(:foster)
    organization = program.organization
    program__program_asset = program.create_program_asset
    program__program_asset.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    program__program_asset.banner = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    program__program_asset.save!
    organization__program_asset = organization.create_program_asset
    organization__program_asset.logo = fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png')
    organization__program_asset.save!

    assert_no_difference "ProgramAsset.count" do
      program.copy_program_asset([organization.id], false)
    end
    organization__program_asset.reload
    assert_equal "pic_2.png", organization__program_asset.logo_file_name
    assert_equal "test_pic.png", organization__program_asset.banner_file_name

    assert_no_difference "ProgramAsset.count" do
      program.copy_program_asset([organization.id], true)
    end
    organization__program_asset.reload
    assert_equal "test_pic.png", organization__program_asset.logo_file_name
    assert_equal "test_pic.png", organization__program_asset.banner_file_name
  end

  def test_get_organization
    program = programs(:albers)
    organization = program.organization
    assert_equal organization, program.get_organization
    assert_equal organization, organization.get_organization
  end

  def test_explicit_user_preferences_enabled
    program = programs(:albers)

    program.stubs(:has_feature?).with(FeatureName::EXPLICIT_USER_PREFERENCES).returns(false)
    program.stubs(:matching_by_mentee_alone?).returns(false)
    program.stubs(:only_one_time_mentoring_enabled?).returns(false)
    Role.any_instance.stubs(:has_permission_name?).with("view_mentors").returns(false)
    program.stubs(:get_valid_role_questions_for_explicit_preferences).returns([])
    program.stubs(:career_based?).returns(false)
    assert_false program.explicit_user_preferences_enabled?

    program.stubs(:has_feature?).with(FeatureName::EXPLICIT_USER_PREFERENCES).returns(true)
    assert_false program.explicit_user_preferences_enabled?

    program.stubs(:matching_by_mentee_alone?).returns(true)
    assert_false program.explicit_user_preferences_enabled?

    Role.any_instance.stubs(:has_permission_name?).with("view_mentors").returns(true)
    assert_false program.explicit_user_preferences_enabled?

    program.stubs(:get_valid_role_questions_for_explicit_preferences).returns("something")
    assert_false program.explicit_user_preferences_enabled?

    program.stubs(:career_based?).returns(true)
    assert program.explicit_user_preferences_enabled?

    program.stubs(:has_feature?).with(FeatureName::EXPLICIT_USER_PREFERENCES).never
    assert program.explicit_user_preferences_enabled?
  end

  def test_handle_feature_dependency_mentor_to_mentee_matching_for_program
    program = programs(:albers)
    feature = OrganizationFeature.create!(organization_id: program.id, feature: Feature.find_by(name: FeatureName::MENTOR_TO_MENTEE_MATCHING))
    assert_no_difference 'BulkMatch.count' do
      program.handle_feature_dependency_mentor_to_mentee_matching(true)
    end
    feature.update_column(:enabled, false)
    assert_difference 'BulkMatch.count', -1 do
      program.handle_feature_dependency_mentor_to_mentee_matching(false)
    end
  end

  def test_handle_feature_dependency_mentor_to_mentee_matching_for_organization
    organization = programs(:org_primary)
    feature = OrganizationFeature.create!(organization_id: organization.id, feature: Feature.find_by(name: FeatureName::MENTOR_TO_MENTEE_MATCHING))
    assert_no_difference 'BulkMatch.count' do
      organization.handle_feature_dependency_mentor_to_mentee_matching(true)
    end
    feature.update_column(:enabled, false)
    assert_difference 'BulkMatch.count', -1 do
      organization.handle_feature_dependency_mentor_to_mentee_matching(false)
    end
  end

  def test_handle_feature_dependency_mentor_to_mentee_matching_for_organization_and_program
    organization = programs(:org_primary)
    program = programs(:albers)
    org_feature = OrganizationFeature.create!(organization_id: organization.id, feature: Feature.find_by(name: FeatureName::MENTOR_TO_MENTEE_MATCHING))
    prog_feature = OrganizationFeature.create!(organization_id: program.id, feature: Feature.find_by(name: FeatureName::MENTOR_TO_MENTEE_MATCHING))
    org_feature.update_column(:enabled, false)
    assert_no_difference 'BulkMatch.count' do
      organization.handle_feature_dependency_mentor_to_mentee_matching(false)
    end
    prog_feature.update_column(:enabled, false)
    assert_difference 'BulkMatch.count', -1 do
      program.handle_feature_dependency_mentor_to_mentee_matching(false)
    end
  end

end