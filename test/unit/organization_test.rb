require_relative './../test_helper.rb'

class OrganizationTest < ActiveSupport::TestCase
  include CareerDevTestHelper

  #-----------------------------------------------------------------------------
  # CREATION
  #-----------------------------------------------------------------------------

  def test_create_success
    assert_difference "AuthConfig.unscoped.count", AuthConfig.attr_value_map_for_default_auths.size do
      assert_difference "Organization.count" do
        @organization = Organization.create!(name: "Some Organization")
      end
    end

    assert @organization.auth_configs.all?(&:default?)
    connection_customized_term = @organization.customized_terms.find_by(term_type: CustomizedTerm::TermType::MENTORING_CONNECTION_TERM)
    assert_equal connection_customized_term.term, "Connection"
    assert_equal  @organization.security_setting.linkedin_token, APP_CONFIG[:linkedin_token]
    assert_equal  @organization.security_setting.linkedin_secret, APP_CONFIG[:linkedin_secret]
  end

  def test_should_have_name
    org = Organization.new
    assert_false org.valid?

    assert_equal ["can't be blank"], org.errors[:name]
  end

  def test_standalone
    assert_false programs(:org_primary).standalone?
    assert_false programs(:org_anna_univ).standalone?
    assert programs(:org_foster).standalone?
  end

  def test_standalone_published
    assert_false programs(:org_anna_univ).standalone_published?
    programs(:org_anna_univ).programs.first.update_attributes!(published: false)
    programs(:org_anna_univ).programs.last.update_attributes!(published: false)
    assert programs(:org_anna_univ).standalone_published?
    programs(:org_anna_univ).programs.first.update_attributes!(published: true)
    programs(:org_anna_univ).programs.last.update_attributes!(published: true)
  end


  #-----------------------------------------------------------------------------
  # VALIDATIONS
  #-----------------------------------------------------------------------------

  def test_subscription_type_premium
    org = Organization.create!({name: "Ar En Ar Caterers"})
    assert_equal_unordered(
      [FeatureName::ANSWERS, FeatureName::ARTICLES, FeatureName::PROFILE_COMPLETION_ALERT,
       FeatureName::RESOURCES, FeatureName::MENTORING_CONNECTIONS_V2,
       FeatureName::FLAGGING, FeatureName::STICKY_TOPIC, FeatureName::ORGANIZATION_PROFILES, FeatureName::SKIP_AND_FAVORITE_PROFILES,
       FeatureName::SKYPE_INTERACTION, FeatureName::PROGRAM_EVENTS, FeatureName::LINKEDIN_IMPORTS, FeatureName::MENTORING_INSIGHTS,
       FeatureName::EXECUTIVE_SUMMARY_REPORT, FeatureName::FORUMS, FeatureName::CAMPAIGN_MANAGEMENT, FeatureName::MOBILE_VIEW,
       FeatureName::CALENDAR_SYNC, FeatureName::WORK_ON_BEHALF, FeatureName::EXPLICIT_USER_PREFERENCES
      ],
      org.reload.enabled_features
    )
  end

  def test_subscription_type_basic
    org = Organization.create!(name: "Ar En Ar Caterers", subscription_type: Organization::SubscriptionType::BASIC)
    assert_equal_unordered(
      [FeatureName::PROFILE_COMPLETION_ALERT, FeatureName::BULK_MATCH, FeatureName::RESOURCES, FeatureName::MOBILE_VIEW, FeatureName::CALENDAR_SYNC, FeatureName::WORK_ON_BEHALF],
      org.reload.enabled_features
    )
  end

  def test_subscription_type_enterprise
    org = Organization.create!(name: "Ar En Ar Caterers", subscription_type: Organization::SubscriptionType::ENTERPRISE)
    assert_equal_unordered(
      [FeatureName::ANSWERS, FeatureName::ARTICLES, FeatureName::PROFILE_COMPLETION_ALERT,
       FeatureName::RESOURCES, FeatureName::MENTORING_CONNECTIONS_V2,
       FeatureName::FLAGGING, FeatureName::STICKY_TOPIC, FeatureName::ORGANIZATION_PROFILES, FeatureName::SKIP_AND_FAVORITE_PROFILES,
       FeatureName::SKYPE_INTERACTION, FeatureName::PROGRAM_EVENTS, FeatureName::LINKEDIN_IMPORTS, FeatureName::MENTORING_INSIGHTS,
       FeatureName::EXECUTIVE_SUMMARY_REPORT, FeatureName::FORUMS, FeatureName::CAMPAIGN_MANAGEMENT, FeatureName::MOBILE_VIEW,
       FeatureName::CALENDAR_SYNC, FeatureName::WORK_ON_BEHALF, FeatureName::EXPLICIT_USER_PREFERENCES
      ],
      org.reload.enabled_features
    )
  end
  #-----------------------------------------------------------------------------
  # ASSOCIATIONS
  #-----------------------------------------------------------------------------

  def test_has_many_programs
    assert_equal_unordered [programs(:ceg),  programs(:cit), programs(:psg)], programs(:org_anna_univ).programs
  end

  def test_has_many_articles
    assert_equal [programs(:ceg).articles, programs(:psg).articles + programs(:cit).articles].flatten.uniq.sort_by(&:id),
      programs(:org_anna_univ).articles
  end

  def test_has_many_users
    assert_equal [programs(:ceg).users, programs(:psg).users + programs(:cit).users].flatten.sort_by(&:id),
      programs(:org_anna_univ).users
  end

  def test_scopes_on_users
    assert_equal [programs(:ceg).users.mentors, programs(:psg).users.mentors + programs(:cit).users.mentors].flatten.sort_by(&:id),
      programs(:org_anna_univ).users.mentors.sort_by(&:id)
  end

  def test_has_many_qa_questions
    create_qa_question(program: programs(:psg), user: users(:psg_mentor))
    assert_equal [programs(:ceg).qa_questions, programs(:psg).qa_questions + programs(:cit).qa_questions].flatten.sort_by(&:id),
      programs(:org_anna_univ).qa_questions
  end

  def test_has_many_forums
    assert_equal [programs(:ceg).forums, programs(:psg).forums + programs(:cit).forums].flatten.sort_by(&:id),
      programs(:org_anna_univ).forums
  end

  def test_has_many_groups
    create_group(
      program: programs(:psg),
      mentor: users(:psg_mentor),
      student: users(:psg_student1))
    create_group(
      program: programs(:ceg),
      mentor: users(:f_mentor_ceg),
      student: users(:arun_ceg))

    assert_equal [programs(:ceg).groups, programs(:psg).groups].flatten.sort_by(&:id),
      programs(:org_anna_univ).groups
  end

  def test_has_many_roles
    assert_equal [
        fetch_role(:org_anna_univ, :admin),
        fetch_role(:org_anna_univ, :mentor),
        fetch_role(:org_anna_univ, :student)],
      programs(:org_anna_univ).roles
  end

  def test_has_many_questions
    # Program level questions
    p_q1 = create_question(program: programs(:psg), organization: programs(:org_anna_univ))
    p_q2 = create_question(program: programs(:ceg), organization: programs(:org_anna_univ))

    assert programs(:org_anna_univ).reload.profile_questions.include?(p_q1)
    assert programs(:org_anna_univ).profile_questions.include?(p_q2)
  end

  def test_has_many_organization_languages
    org = programs(:org_primary)
    org_lang1 = organization_languages(:hindi)
    org_lang2 = organization_languages(:telugu)
    assert_equal [org_lang1, org_lang2], org.reload.organization_languages
  end

  def test_default_questions
    org = programs(:org_primary)
    name_question = org.name_question
    email_question = org.email_question

    name_or_email_questions = org.default_questions
    assert_equal [name_question, email_question], name_or_email_questions
  end

  def test_has_many_features_and_organization_features
    OrganizationFeature.destroy_all
    o = programs(:org_primary)
    assert o.enabled_db_features.blank?
    assert o.organization_features.blank?

    f = Feature.find_by(name: FeatureName::ARTICLES)
    of = create_organization_feature(feature: f, organization_id: o.id)
    create_organization_feature(feature: f, organization_id: programs(:org_anna_univ).id)

    assert_equal [f], o.reload.enabled_db_features
    assert_equal [of], o.organization_features
  end

  def test_has_many_three_sixty_competencies
    org = programs(:org_primary)
    assert_equal 5, org.three_sixty_competencies.size
    assert_equal "ThreeSixty::Competency", Organization.reflect_on_association(:three_sixty_competencies).class_name
    assert_equal :destroy, Organization.reflect_on_association(:three_sixty_competencies).options[:dependent]
  end

  def test_has_many_three_sixty_questions
    org = programs(:org_primary)
    assert_equal 10, org.three_sixty_questions.size
    assert_equal "ThreeSixty::Question", Organization.reflect_on_association(:three_sixty_questions).class_name
    assert_equal :destroy, Organization.reflect_on_association(:three_sixty_questions).options[:dependent]
  end

  def test_has_many_three_sixty_oeqs
    assert_equal 3, programs(:org_primary).three_sixty_oeqs.size
  end

  def test_has_many_three_sixty_surveys
    org = Organization.create!({name: 'new prog'})
    org.three_sixty_surveys.create!(title: "Test")
    assert_equal 1, org.three_sixty_surveys.size
    assert_equal "ThreeSixty::Survey", Organization.reflect_on_association(:three_sixty_surveys).class_name
    assert_equal :destroy, Organization.reflect_on_association(:three_sixty_surveys).options[:dependent]
  end

  def test_has_many_three_sixty_survey_assessees
    org = programs(:org_primary)
    assert_equal 15, org.three_sixty_survey_assessees.size
  end

  def test_has_many_three_sixty_reviewer_groups
    org = programs(:org_primary)
    assert_equal 5, org.three_sixty_reviewer_groups.size
    assert_equal "ThreeSixty::ReviewerGroup", Organization.reflect_on_association(:three_sixty_reviewer_groups).class_name
    assert_equal :destroy, Organization.reflect_on_association(:three_sixty_reviewer_groups).options[:dependent]
  end

  def test_has_many_three_sixty_published_three_sixty_surveys
    org = programs(:org_primary)
    org.three_sixty_surveys.published.destroy_all
    survey = org.three_sixty_surveys.first
    survey.publish!
    survey = org.three_sixty_surveys.last
    survey.publish!
    org.reload
    assert_equal [org.three_sixty_surveys.first, org.three_sixty_surveys.last], org.published_three_sixty_surveys
  end

  def test_has_many_published_three_sixty_survey_assessees
    org = programs(:org_primary)
    org.three_sixty_surveys.published.destroy_all
    survey = org.three_sixty_surveys.first
    survey.publish!
    org.reload
    assert_not_nil org.three_sixty_surveys.first.survey_assessees
    assert_equal org.three_sixty_surveys.first.survey_assessees, org.published_three_sixty_survey_assessees
  end

  def test_has_feed_exporter
    feed_exporter = FeedExporter.create!(program_id: programs(:org_primary).id)
    assert_equal feed_exporter, programs(:org_primary).feed_exporter
  end

  def test_has_one_feed_import_configuration
    org = programs(:org_primary)
    feed_import_configuration = org.create_feed_import_configuration!(frequency: 1.day.to_i, enabled: true, sftp_user_name: "org_primary")
    assert_equal feed_import_configuration, org.feed_import_configuration
  end

  #-----------------------------------------------------------------------------
  # DEFAULT ASSOCIATIONS
  #-----------------------------------------------------------------------------

  def test_should_assign_default_theme
    assert_difference('Page.count', 3 ) do
      assert_difference 'OrganizationFeature.count', 20 do
        assert_difference 'Organization.count' do
          @org = Organization.create!(
            {name: 'new prog'})
        end
      end
    end
    assert_equal_unordered(
      [FeatureName::ANSWERS, FeatureName::ARTICLES, FeatureName::PROFILE_COMPLETION_ALERT,
       FeatureName::RESOURCES, FeatureName::MENTORING_CONNECTIONS_V2,
       FeatureName::FLAGGING, FeatureName::STICKY_TOPIC, FeatureName::ORGANIZATION_PROFILES, FeatureName::SKIP_AND_FAVORITE_PROFILES,
       FeatureName::SKYPE_INTERACTION, FeatureName::PROGRAM_EVENTS, FeatureName::LINKEDIN_IMPORTS, FeatureName::MENTORING_INSIGHTS,
       FeatureName::EXECUTIVE_SUMMARY_REPORT, FeatureName::FORUMS, FeatureName::CAMPAIGN_MANAGEMENT, FeatureName::MOBILE_VIEW,
       FeatureName::CALENDAR_SYNC, FeatureName::WORK_ON_BEHALF, FeatureName::EXPLICIT_USER_PREFERENCES
      ],
      @org.reload.enabled_features
    )

    assert_equal @org.active_theme , Theme.global.default.first

    pages = @org.pages
    pages.each { |page| assert_equal(@org, page.program) }
    assert_equal_unordered(
      [ "General Overview",
        "For Mentors",
        "For Mentees"],
      pages.collect(&:title))
  end

  def test_create_default_roles
    programs(:org_no_subdomain).programs.each{|p| p.roles.destroy_all}
    programs(:org_no_subdomain).roles.destroy_all

    # 3 roles per program
    assert_difference 'Role.count', 3 do
      # 5 RolePermission mappings per program
      assert_difference 'RolePermission.count', 68 do
        programs(:org_no_subdomain).create_default_roles
      end
    end
  end

  def test_build_default_roles
    organization = programs(:org_no_subdomain)
    organization.programs.each{|p| p.roles.destroy_all}
    organization.roles.destroy_all

    assert_equal [], organization.roles

    assert_no_difference 'Role.count' do
      assert_no_difference 'RolePermission.count' do
        organization.build_default_roles
      end
    end
    assert_equal RoleConstants::DEFAULT_ROLE_NAMES, organization.roles.collect(&:name)
  end

  def test_create_default_admin_views
    org = programs(:org_anna_univ)
    org.admin_views.destroy_all
    assert_difference 'AdminView.count', 2 do
      Organization.create_default_admin_views(org.id)
    end
    org.reload
    assert_equal [true, true], org.admin_views.pluck(:favourite)
    assert_equal_unordered ["All Members", "Users Counting Against License"], org.admin_views.pluck(:title)
    filter_hash = {"program_role_state" => {AdminView::ProgramRoleStateFilterObjectKey::INCLUSION =>AdminView::ProgramRoleStateFilterObjectKey::INCLUDE, "filter_conditions" => {"parent_filter_1" => {"child_filter_1" => {AdminView::ProgramRoleStateFilterObjectKey::STATE=>[User::Status::ACTIVE]}}}}}
    assert_equal filter_hash, org.admin_views.find_by(title: "Users Counting Against License").filter_params_hash
    all_members_filter_hash = {"program_role_state"=>{AdminView::ProgramRoleStateFilterObjectKey::ALL_MEMBERS=>true}}
    assert_equal all_members_filter_hash, org.admin_views.find_by(title: "All Members").filter_params_hash
  end

  def test_role_users
    assert_equal_unordered programs(:ceg).mentor_users + programs(:psg).mentor_users + programs(:cit).mentor_users,
        programs(:org_anna_univ).mentor_users

    assert_equal_unordered programs(:ceg).student_users + programs(:psg).student_users + programs(:cit).student_users,
        programs(:org_anna_univ).student_users
  end

  def test_restricted_sti_attributes
    assert_equal Organization::PROGRAM_ATTRIBUTES.map(&:to_s), Organization.restricted_sti_attributes
    assert_equal Organization::PROGRAM_ATTRIBUTES.map(&:to_s), Organization.get_restricted_sti_attributes

    Organization::PROGRAM_ATTRIBUTES.each do |attribute|
      organization = programs(:org_primary)
      organization.stubs("#{attribute}_changed?").returns(true)
      assert_false organization.valid?
      assert_equal ["is invalid"], organization.errors.messages[attribute]
    end
  end

  #-----------------------------------------------------------------------------
  # THEMES
  #-----------------------------------------------------------------------------

  def test_active_theme
    assert_equal themes(:wcag_theme), programs(:org_primary).active_theme
    css_file = fixture_file_upload(File.join('files', 'test_file.css'), 'text/css')
    theme_1 = programs(:org_primary).themes.new(
      {name: 'Blue theme', css: css_file}
    )
    theme_1.temp_path = fixture_file_upload(File.join('files', 'test_file.css'), 'text/css').path
    theme_1.save!
    programs(:org_primary).update_attributes(active_theme: theme_1)
    assert_equal theme_1, programs(:org_primary).reload.active_theme
  end

  #-----------------------------------------------------------------------------
  # PRODUCT DASHBOARD
  #-----------------------------------------------------------------------------

  def test_ytd_time_objects
    Timecop.freeze do
      assert_equal [Time.now.utc.beginning_of_year, Time.now.utc], programs(:org_primary).ytd_time_objects
    end
  end

  def test_get_program_ids_ary
    assert_equal programs(:org_primary).program_ids, programs(:org_primary).get_program_ids_ary
  end

  def test_current_active_connection_ids
    organization = programs(:org_primary)
    
    assert_equal_unordered [1, 2, 3, 5, 6, 8, 9, 18, 26], organization.current_active_connection_ids
    assert_equal_unordered [1, 2, 3, 5, 6, 9], organization.current_active_connection_ids(program_ids: [organization.programs.first.id])
  end

  def test_completed_connections_ytd_query
    organization = programs(:org_primary)
    group_closure_reason_ids = GroupClosureReason.completed.where(program_id: organization.program_ids).pluck(:id).join(COMMA_SEPARATOR)

    Timecop.freeze do
      assert_equal "SELECT `groups`.* FROM `groups` WHERE `groups`.`program_id` IN (#{organization.program_ids.join(", ")}) AND (groups.closure_reason_id IN (#{group_closure_reason_ids})) AND (groups.published_at is not NULL) AND (`groups`.`closed_at` BETWEEN '#{organization.ytd_time_objects[0].to_s(:db)}' AND '#{organization.ytd_time_objects[1].to_s(:db)}')", organization.completed_connections_ytd_query.to_sql
    end
  end

  def test_completed_connections_ytd_count
    assert_equal 1, programs(:org_primary).completed_connections_ytd_count
  end

  def test_get_positive_outcome_groups_ytd_query
    assert_equal "SELECT groups.id as group_id, connection_memberships.user_id as connection_membership_user_id FROM `groups` INNER JOIN `connection_memberships` ON `connection_memberships`.`group_id` = `groups`.`id` WHERE 1=0", programs(:org_primary).get_positive_outcome_groups_ytd_query.to_sql
  end

  def test_successful_completed_connections_ytd_count
    assert_equal 0, programs(:org_primary).successful_completed_connections_ytd_count
  end

  def test_sandbox
    org = programs(:org_primary)
    org.account_name = "abc"
    assert_false org.sandbox?
    org.account_name = "www abcsandboxorg"
    assert_false org.sandbox?
    org.account_name = "sandBox abc"
    assert org.sandbox?
    org.account_name = "   sandbox abc"
    assert org.sandbox?
    org.account_name = " Sandbox abc"
    assert org.sandbox?
    org.account_name = "SANDBOX"
    assert org.sandbox?
  end

  def test_status_string
    org = programs(:org_primary)
    assert org.active
    assert_equal "Active", org.status_string
    assert_equal "something", org.status_string("something")
    org.active = false
    assert_equal "Inactive", org.status_string
  end

  def test_tracks_count
    assert_equal programs(:org_primary).programs.size, programs(:org_primary).tracks_count
  end

  def test_current_users_with_unpublished_or_published_profiles_count
    assert_equal 57, programs(:org_primary).current_users_with_unpublished_or_published_profiles_count
  end

  def test_current_users_with_published_profiles_count
    assert_equal 56, programs(:org_primary).current_users_with_published_profiles_count
  end

  def test_current_connected_users_count
    assert_equal 11, programs(:org_primary).current_connected_users_count
    assert_equal 8, programs(:org_primary).current_connected_users_count(program_ids: [programs(:albers).id])
  end

  def test_current_active_connections_count
    assert_equal 9, programs(:org_primary).current_active_connections_count
  end

  def test_last_login
    assert_equal programs(:org_primary).programs.map{|p| p.users.pluck(:last_seen_at)}.flatten.compact.max, programs(:org_primary).last_login
  end

  def test_users_with_unpublished_or_published_profiles_ytd_count
    org = programs(:org_primary)
    assert_equal User.where(id: org.programs.map{|program| User.get_ids_of_users_active_between(program, *org.ytd_time_objects, include_unpublished: true) }.flatten).pluck(:member_id).uniq.size, org.users_with_unpublished_or_published_profiles_ytd_count
  end

  def test_users_with_published_profiles_ytd_count
    org = programs(:org_primary)
    assert_equal User.where(id: org.programs.map{|program| User.get_ids_of_users_active_between(program, *org.ytd_time_objects) }.flatten).pluck(:member_id).uniq.size, org.users_with_published_profiles_ytd_count
  end

  def test_users_with_published_profiles_in_date_range
    org = programs(:org_primary)
    assert_equal User.where(id: org.programs.collect{|program| User.get_ids_of_users_active_between(program, *org.ytd_time_objects) }.flatten).pluck(:member_id).uniq.size, org.users_with_published_profiles_in_date_range(org.ytd_time_objects)
  end

  def test_users_with_published_profiles_in_date_range_for_organization
    org = programs(:org_primary)
    assert_equal User.where(id: org.programs.collect{|program| User.get_ids_of_users_active_between(program, *org.ytd_time_objects) }.flatten).pluck(:member_id).uniq, org.users_with_published_profiles_in_date_range_for_organization(org.ytd_time_objects)
    selected_program_ids = org.programs[0..0].map(&:id)
    assert_equal User.where(id: org.programs[0..0].collect{|program| User.get_ids_of_users_active_between(program, *org.ytd_time_objects) }.flatten).pluck(:member_id).uniq, org.users_with_published_profiles_in_date_range_for_organization(org.ytd_time_objects, program_ids: selected_program_ids)
    role_ids = Role.where(program_id: selected_program_ids).pluck(:id)
    assert_equal User.where(id: org.programs[0..0].collect{|program| User.get_ids_of_users_active_between(program, *org.ytd_time_objects, role_ids: role_ids) }.flatten).pluck(:member_id).uniq, org.users_with_published_profiles_in_date_range_for_organization(org.ytd_time_objects, program_ids: selected_program_ids, role_ids: role_ids)
  end

  def test_connections_in_date_range
    org = programs(:org_primary)
    assert_equal org.programs.collect{|program| program.connections_in_date_range(org.ytd_time_objects) }.sum, org.connections_in_date_range(org.ytd_time_objects)
  end

  def test_connections_in_date_range_for_organization
    org = programs(:org_primary)
    assert_equal org.programs.collect{|program| program.connections_in_date_range(org.ytd_time_objects) }.sum, org.connections_in_date_range_for_organization(org.ytd_time_objects).size
  end

  def test_users_connected_ytd_count
    org = programs(:org_primary)
    assert_equal User.where(id: org.programs.map { |program| User.get_ids_of_connected_users_active_between(program, *org.ytd_time_objects) }.flatten).pluck(:member_id).uniq.size, org.users_connected_ytd_count
  end

  def test_connections_ytd_count
    org = programs(:org_primary)
    assert_equal org.programs.map(&:connections_ytd_count).inject(:+), org.connections_ytd_count
  end

  def test_users_completed_connections_ytd_count
    org = programs(:org_primary)
    assert_equal User.where(id: ActiveRecord::Base.connection.exec_query(org.completed_connections_ytd_query.joins(:memberships).select("connection_memberships.user_id").to_sql).rows.flatten.uniq).pluck(:member_id).uniq.size, org.users_completed_connections_ytd_count
  end

  def test_users_successful_completed_connections_ytd_count
    org = programs(:org_primary)
    user_ids = ActiveRecord::Base.connection.exec_query(org.get_positive_outcome_groups_ytd_query.to_sql).to_hash.map{|hsh| hsh["connection_membership_user_id"]}.uniq
    assert_equal User.where(id: user_ids).pluck(:member_id).uniq.size, org.users_successful_completed_connections_ytd_count
  end

  def test_get_flash_meeting_requested_ytd_count
    Timecop.travel(Time.now - 1.minute)
    org = programs(:org_primary)
    program = programs(:albers)
    create_meeting(force_non_group_meeting: true)
    Timecop.return
    meeting = Meeting.last
    meeting.update_attribute(:owner_id, meeting.mentee_id)
    count = org.get_flash_meeting_requested_ytd_count
    meeting.update_attribute(:owner_id, meeting.member_meetings.where.not(member_id: meeting.mentee_id).first.member_id)
    assert_equal count - 1, org.get_flash_meeting_requested_ytd_count
    meeting.update_attribute(:owner_id, meeting.mentee_id)
    assert_equal count, org.get_flash_meeting_requested_ytd_count
    meeting.update_attribute(:created_at, (Time.now.beginning_of_year - 1.day))
    assert_equal count - 1, org.get_flash_meeting_requested_ytd_count
  end

  def test_get_flash_meeting_accepted_ytd_count
    org = programs(:org_primary)
    program = programs(:albers)
    create_meeting(force_non_group_meeting: true)
    meeting = program.meetings.last
    meeting.update_attribute(:owner_id, meeting.mentee_id)
    meeting.meeting_request.update_attributes!(accepted_at: (Time.now.beginning_of_year + 1.day), status: AbstractRequest::Status::ACCEPTED)
    assert_equal 1, org.get_flash_meeting_accepted_ytd_count
    meeting.update_attribute(:owner_id, meeting.member_meetings.where.not(member_id: meeting.mentee_id).first.member_id)
    assert_equal 0, org.get_flash_meeting_accepted_ytd_count
    meeting.update_attribute(:owner_id, meeting.mentee_id)
    meeting.meeting_request.update_attribute(:accepted_at, (Time.now.beginning_of_year + 1.day))
    assert_equal 1, org.get_flash_meeting_accepted_ytd_count
    meeting.meeting_request.update_attribute(:accepted_at, (Time.now.beginning_of_year - 1.day))
    assert_equal 0, org.get_flash_meeting_accepted_ytd_count
  end

  def test_get_flash_meeting_completed_ytd_count
    org = programs(:org_primary)
    program = programs(:albers)
    create_meeting(force_non_group_meeting: true)
    meeting = program.meetings.last
    meeting.update_attributes!(state: Meeting::State::COMPLETED, state_marked_at: (Time.now - 2.hours))
    assert_equal 1, org.get_flash_meeting_completed_ytd_count
    meeting.update_attribute(:state_marked_at, (Time.now.beginning_of_year - 1.day))
    assert_equal 0, org.get_flash_meeting_completed_ytd_count
    meeting.update_attribute(:state_marked_at, (Time.now - 2.hours))
    assert_equal 1, org.get_flash_meeting_completed_ytd_count
    meeting.update_attribute(:state, Meeting::State::CANCELLED)
    assert_equal 0, org.get_flash_meeting_completed_ytd_count
  end

  def test_users_with_accepted_flash_meeting_ytd_count
    org = programs(:org_primary)
    program = programs(:albers)
    create_meeting(force_non_group_meeting: true)
    meeting = program.meetings.last
    meeting.update_attribute(:owner_id, meeting.mentee_id)
    meeting.meeting_request.update_attributes!(accepted_at: (Time.now.beginning_of_year + 1.day), status: AbstractRequest::Status::ACCEPTED)
    assert_equal 2, org.users_with_accepted_flash_meeting_ytd_count
    meeting.meeting_request.update_attribute(:accepted_at, (Time.now.beginning_of_year - 1.day))
    assert_equal 0, org.users_with_accepted_flash_meeting_ytd_count
    meeting.meeting_request.update_attribute(:accepted_at, (Time.now.beginning_of_year + 1.day))
    assert_equal 2, org.users_with_accepted_flash_meeting_ytd_count
    meeting.meeting_request.update_attribute(:status, AbstractRequest::Status::REJECTED)
    assert_equal 0, org.users_with_accepted_flash_meeting_ytd_count
  end

  def test_users_with_completed_flash_meeting_ytd_count
    org = programs(:org_primary)
    program = programs(:albers)
    create_meeting(force_non_group_meeting: true)
    meeting = program.meetings.last
    meeting.update_attributes!(state: Meeting::State::COMPLETED, state_marked_at: (Time.now - 2.hours))
    assert_equal 2, org.users_with_completed_flash_meeting_ytd_count
    meeting.update_attribute(:state_marked_at, (Time.now.beginning_of_year - 1.day))
    assert_equal 0, org.users_with_completed_flash_meeting_ytd_count
  end

  def test_closed_connections_ytd_arel
    org = programs(:org_primary)
    Timecop.freeze do
      assert_equal "SELECT `groups`.* FROM `groups` WHERE `groups`.`program_id` IN (#{org.get_program_ids_ary.join(", ")}) AND `groups`.`status` = 2 AND (`groups`.`closed_at` BETWEEN '#{org.ytd_time_objects[0].to_s(:db)}' AND '#{org.ytd_time_objects[1].to_s(:db)}')", org.closed_connections_ytd_arel.to_sql
    end
  end

  def test_closed_connections_ytd_count
    assert_equal 1, programs(:org_primary).closed_connections_ytd_count
  end

  def test_users_closed_connections_ytd_count
    assert_equal 2, programs(:org_primary).users_closed_connections_ytd_count
  end

  #-----------------------------------------------------------------------------
  # FEATURES
  #-----------------------------------------------------------------------------

  def test_has_feature
    assert programs(:org_primary).has_feature?(FeatureName::ANSWERS)
    programs(:org_primary).enable_feature(FeatureName::ANSWERS, false)
    programs(:org_primary).enabled_db_features.reload
    assert_false programs(:org_primary).reload.has_feature?(FeatureName::ANSWERS)
  end

  def test_languages_filter_enabled
    org = programs(:org_primary)
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    assert org.languages.count > 0
    assert org.languages_filter_enabled?
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS, false)
    assert_false org.languages_filter_enabled?
    org.languages.each{|l| l.destroy}
    assert_false org.languages.count > 0
    assert_false org.languages_filter_enabled?
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    assert_false org.languages_filter_enabled?
  end

  def test_enable_feature
    assert programs(:org_primary).has_feature?(FeatureName::ANSWERS)

    # Disabling should delete the feature record.
    assert_no_difference 'OrganizationFeature.count' do
      programs(:org_primary).enable_feature(FeatureName::ANSWERS, false)
    end

    programs(:org_primary).enabled_db_features.reload

    # Enabling should create a new feature record.
    assert_no_difference 'OrganizationFeature.count' do
      programs(:org_primary).enable_feature(FeatureName::ANSWERS)
    end
  end

  def test_enabled_organization_languages_including_english
    organization = programs(:org_primary)
    assert organization.organization_languages.enabled.where(language_name: "es").exists?
    organization.organization_languages.where(language_name: "es").update_all(enabled: false)
    assert_equal_unordered ["English", "Hindi (Hindilu)"], organization.enabled_organization_languages_including_english.map(&:to_display)
  end

  def test_enabled_disabled_features
    assert programs(:org_primary).enabled_features.include?(FeatureName::ANSWERS)
    assert programs(:org_primary).enabled_features.include?(FeatureName::ARTICLES)
    assert_false programs(:org_primary).disabled_features.include?(FeatureName::ANSWERS)
    assert_false programs(:org_primary).disabled_features.include?(FeatureName::ARTICLES)

    programs(:org_primary).enable_feature(FeatureName::ANSWERS, false)
    programs(:org_primary).enabled_db_features.reload
    assert_false programs(:org_primary).enabled_features.include?(FeatureName::ANSWERS)
    assert programs(:org_primary).enabled_features.include?(FeatureName::ARTICLES)
    assert programs(:org_primary).disabled_features.include?(FeatureName::ANSWERS)
    assert_false programs(:org_primary).disabled_features.include?(FeatureName::ARTICLES)

    programs(:org_primary).enable_feature(FeatureName::ANSWERS)
    programs(:org_primary).enabled_db_features.reload
    assert programs(:org_primary).enabled_features.include?(FeatureName::ANSWERS)
    assert programs(:org_primary).enabled_features.include?(FeatureName::ARTICLES)
    assert_false programs(:org_primary).disabled_features.include?(FeatureName::ANSWERS)
    assert_false programs(:org_primary).disabled_features.include?(FeatureName::ARTICLES)
  end

  def test_enabled_features_settor
    OrganizationFeature.destroy_all
    assert programs(:org_primary).enabled_features.empty?
    programs(:org_primary).enabled_features = [FeatureName::ANSWERS, FeatureName::ARTICLES]

    assert_equal_unordered(
      [FeatureName::ANSWERS, FeatureName::ARTICLES],
      programs(:org_primary).reload.enabled_features
    )

    programs(:org_primary).enabled_features = [FeatureName::ANSWERS]
    assert_equal_unordered(
      [FeatureName::ANSWERS],
      programs(:org_primary).reload.enabled_features
    )

    programs(:org_primary).enabled_features = [""]
    assert programs(:org_primary).reload.enabled_features.empty?

    org = programs(:org_primary)
    assert_false org.calendar_sync_v2_enabled?
    assert_false org.enhanced_meeting_scheduler_enabled?
    org.enabled_features = [FeatureName::ANSWERS, FeatureName::ARTICLES, FeatureName::CALENDAR_SYNC_V2]
    assert org.reload.calendar_sync_v2_enabled?
    assert org.enhanced_meeting_scheduler_enabled?
  end

  def test_skype_enabled
    org = programs(:org_primary)
    assert org.skype_enabled?
    org.enable_feature(FeatureName::SKYPE_INTERACTION, false)
    programs(:org_primary).enabled_db_features.reload
    assert_false org.skype_enabled?
  end

  def test_connection_profiles_enabled
    org = programs(:org_primary)
    prog = programs(:albers)
    assert_false org.connection_profiles_enabled?
    assert_false prog.connection_profiles_enabled?

    org.enable_feature(FeatureName::CONNECTION_PROFILE, true)
    programs(:org_primary).enabled_db_features.reload
    assert org.connection_profiles_enabled?
    assert prog.reload.connection_profiles_enabled?

    prog.enable_feature(FeatureName::CONNECTION_PROFILE, false)
    programs(:org_primary).enabled_db_features.reload
    assert org.connection_profiles_enabled?
    assert_false prog.reload.connection_profiles_enabled?

    org.enable_feature(FeatureName::CONNECTION_PROFILE, false)
    programs(:org_primary).enabled_db_features.reload
    assert_false org.connection_profiles_enabled?
    assert_false prog.reload.connection_profiles_enabled?
  end

  def test_calendar_enabled
    org = programs(:org_primary)
    assert_false org.calendar_enabled?
    org.enable_feature(FeatureName::CALENDAR, true)
    programs(:org_primary).enabled_db_features.reload
    assert org.calendar_enabled?
  end

  def test_mentor_offer_enabled
    org = programs(:org_primary)
    assert_false org.mentor_offer_enabled?
    org.enable_feature(FeatureName::OFFER_MENTORING, true)
    programs(:org_primary).enabled_db_features.reload
    assert org.mentor_offer_enabled?
  end

  def test_mentoring_connections_V2_enabled
    org = programs(:org_primary)
    assert_false org.mentoring_connections_v2_enabled?

    org.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    programs(:org_primary).enabled_db_features.reload
    assert org.mentoring_connections_v2_enabled?

    org.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, false)
    programs(:org_primary).enabled_db_features.reload
    assert_false org.mentoring_connections_v2_enabled?
  end

  def test_resources_enabled
    org = programs(:org_primary)
    assert org.resources_enabled?

    org.enable_feature(FeatureName::RESOURCES, false)
    programs(:org_primary).enabled_db_features.reload
    assert_false org.resources_enabled?

    org.enable_feature(FeatureName::RESOURCES, true)
    programs(:org_primary).enabled_db_features.reload
    assert org.resources_enabled?
  end

  def test_resources_enabled_any
    org = programs(:org_primary)
    org.enable_feature(FeatureName::RESOURCES, false)
    programs(:org_primary).enabled_db_features.reload
    programs(:albers).enable_feature(FeatureName::RESOURCES, true)
    programs(:albers).enabled_db_features.reload
    assert org.resources_enabled_any?
  end


  def test_pages_dependent_destroy
    assert_equal 3, programs(:org_anna_univ).pages.size
    assert_difference "programs(:org_anna_univ).pages.count", -3 do
      programs(:org_anna_univ).destroy
    end
  end

  def test_has_many_photos_with_latest_first
    organization = programs(:org_anna_univ)
    photos = []

    3.times do
      pic = Ckeditor::Picture.new(data: fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))
      pic.organization = organization
      pic.save!
      photos << pic
    end
    assert_equal photos, organization.ckassets
    thumb_style = {content: "575>", thumb: "80x80#"}
    assert_equal thumb_style, organization.ckassets.first.data.options[:styles]
    assert_equal thumb_style, organization.ckassets.last.data.options[:styles]
  end

  def test_email_template_disabled_for_activity
    org = programs(:org_anna_univ)
    mailer = EmailChangeNotification
    uid = mailer.mailer_attributes[:uid]

    t1 = mailer.org_template(org)
    assert t1.nil?
    assert_false org.email_template_disabled_for_activity?(mailer)

    t1 = org.mailer_templates.create!(uid: uid, enabled: false)
    assert_false t1.enabled?
    assert org.email_template_disabled_for_activity?(mailer)

    t1.update_attributes!(enabled: true)
    assert t1.enabled?
    assert_false org.email_template_disabled_for_activity?(mailer)
  end

  def test_login_expiry_disabled
    org = programs(:org_primary)
    org.security_setting.update_attribute(:login_expiry_period, Organization::DISABLE_LOGIN_EXPIRY)
    assert org.login_expiry_disabled?
    org.security_setting.update_attribute(:login_expiry_period, 100)
    programs(:org_primary).reload
    assert_false org.login_expiry_disabled?
  end

  def test_active
    programs(:org_primary).active = false
    programs(:org_primary).save!

    assert_false Organization.active.include?(programs(:org_primary))
    assert Program.active.include?(programs(:foster))
  end

  def test_has_many_features_should_include_only_enabled_ones
    programs(:org_primary).enable_feature(FeatureName::ARTICLES, false)
    assert_false programs(:org_primary).enabled_db_features.collect(&:name).include?(FeatureName::ARTICLES)

    assert_no_difference "OrganizationFeature.count" do
      programs(:org_primary).enable_feature(FeatureName::ARTICLES)
    end

    assert programs(:org_primary).enabled_db_features.collect(&:name).include?(FeatureName::ARTICLES)
  end

  def test_login_attempts_enabled
    assert_false programs(:org_primary).login_attempts_enabled?
    programs(:org_primary).security_setting.maximum_login_attempts = 1
    assert programs(:org_primary).login_attempts_enabled?
    programs(:org_primary).security_setting.maximum_login_attempts = 0
    assert_false programs(:org_primary).login_attempts_enabled?
  end

  def test_email_question
    org = programs(:org_primary)
    assert_equal org.default_questions.find{|pq| pq.email_type?}, org.email_question
  end

  def test_name_question
    org = programs(:org_primary)
    assert_equal org.default_questions.find{|pq| pq.name_type?}, org.name_question
  end

  def test_email_question_help_text
    org = programs(:org_primary)
    email_question = org.email_question
    assert_nil email_question.help_text
    assert_equal '', org.email_question_help_text
    assert_equal 'aaa', org.email_question_help_text('aaa')
    email_question.update_attributes({help_text: 'sss'})
    assert_equal 'sss', org.email_question_help_text
    assert_equal 'sss', org.email_question_help_text('aaa')
    email_question.update_attributes({help_text: '<b>help text<b><a href=\"https://www.chronus.com\"> chronus </a>'})
    assert_equal '<b>help text<b><a href=\"https://www.chronus.com\"> chronus </a>', org.email_question_help_text
    assert_equal '<b>help text<b><a href=\"https://www.chronus.com\"> chronus </a>', org.email_question_help_text('sss')
  end

  def test_create_default_name_profile_question
    org = programs(:org_primary)
    org.default_questions.destroy_all
    assert_nil org.name_question

    assert_difference "ProfileQuestion.count" do
      org.create_default_name_profile_question!
    end
    name_q = ProfileQuestion.last
    assert_equal org, name_q.organization
    assert_match "Name", name_q.question_text
    assert_equal ProfileQuestion::Type::NAME, name_q.question_type
    assert_equal 1, name_q.position
    assert_equal org.sections.default_section.first, name_q.section
  end

  def test_fluid_layout
    organization = programs(:org_primary)
    assert_false organization.fluid_layout?
  end

  def test_default_domain
    assert_equal program_domains(:org_primary), programs(:org_primary).default_program_domain
    assert_equal program_domains(:org_primary).domain, programs(:org_primary).domain
    assert_equal program_domains(:org_primary).subdomain, programs(:org_primary).subdomain

    program_domains(:org_primary).update_attribute(:is_default, false)

    npd = programs(:org_primary).program_domains.new()
    npd.subdomain = "secondary"
    npd.domain = "kick.com"
    npd.save!

    assert npd.is_default?
    assert_equal npd, programs(:org_primary).reload.default_program_domain
    assert_equal "kick.com", programs(:org_primary).domain
    assert_equal "secondary", programs(:org_primary).subdomain
  end

  def test_has_custom_domain
    assert_false programs(:org_primary).has_custom_domain?
    assert programs(:org_custom_domain).has_custom_domain?

    npd = programs(:org_primary).program_domains.new()
    npd.subdomain = "secondary"
    npd.domain = "kick.com"
    npd.is_default = false
    npd.save!

    assert_false npd.is_default?
    assert programs(:org_primary).reload.has_custom_domain?
  end

  def test_create_default_auth_configs
    organization = programs(:org_primary)
    organization.auth_configs.destroy_all
    assert_difference "AuthConfig.unscoped.count", AuthConfig.attr_value_map_for_default_auths.size do
      organization.create_default_auth_configs
    end
    [:indigenous?, :linkedin_oauth?, :google_oauth?].each do |auth_method|
      assert organization.auth_configs.find(&auth_method).present?
    end
  end

  def test_password_auto_expire_enabled
    security_setting = programs(:org_primary).security_setting
    assert_false programs(:org_primary).password_auto_expire_enabled?
    security_setting.update_attributes!(password_expiration_frequency: 2)
    assert programs(:org_primary).password_auto_expire_enabled?
    security_setting.update_attributes!(password_expiration_frequency: nil)
    assert_false programs(:org_primary).password_auto_expire_enabled?
  end

  def test_password_history_enabled
    security_setting = programs(:org_primary).security_setting
    assert_false programs(:org_primary).password_history_enabled?
    security_setting.update_attributes!(password_history_limit: 2)
    assert programs(:org_primary).password_history_enabled?
    security_setting.update_attributes!(password_history_limit: nil)
    assert_false programs(:org_primary).password_history_enabled?
  end

  def test_get_next_program_root
    organization = programs(:org_primary)
    # prepare data - change all program roots to p1, p2, ...
    last_n = organization.programs.count
    organization.programs.each_with_index do |program, i|
      program.update_attribute(:root, "p#{i+1}")
    end
    program = organization.tracks.new
    assert_equal "p#{last_n+1}", organization.get_next_program_root(program)

    organization = programs(:org_nch)
    last_n = organization.portals.count
    organization.portals.each_with_index do |portal, i|
      portal.update_attribute(:root, "cd#{i+1}")
    end
    portal = organization.portals.new
    assert_equal "cd#{last_n+1}", organization.get_next_program_root(portal)
  end

  def test_role_profile_questions
    organization = programs(:org_primary)
    prof_ques = create_profile_question(organization: organization)

    role_question = create_role_question(program: organization, role_names: RoleConstants::STUDENT_NAME, profile_question: prof_ques, available_for: RoleQuestion::AVAILABLE_FOR::BOTH)
    assert organization.reload.role_profile_questions.include?(prof_ques)

    role_question.update_attribute(:available_for, RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS)
    assert_false organization.reload.role_profile_questions.include?(prof_ques)

    role_question.update_attribute(:available_for, RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS)
    assert organization.reload.role_profile_questions.include?(prof_ques)
  end

  def test_get_locked_out_members_auto_expiry_enabled
    organization = programs(:org_primary)
    member = members(:student_0)
    member1 = members(:student_1)
    setting = organization.security_setting
    setting.update_attributes!({auto_reactivate_account: 1.0})
    assert organization.auto_reactivate_enabled?

    locked_members = organization.get_locked_out_members
    assert locked_members.empty?

    member.update_attributes(failed_login_attempts: 5, account_locked_at: Time.now.utc - 10.minute)
    member1.update_attributes(failed_login_attempts: 5, account_locked_at: Time.now.utc - 2.hours)

    locked_members = organization.get_locked_out_members
    assert_equal [member], locked_members
  end

  def test_get_locked_out_members_auto_expiry_disabled
    organization = programs(:org_primary)
    member = members(:student_0)
    member1 = members(:student_1)
    setting = organization.security_setting
    setting.update_attributes!({auto_reactivate_account: Organization::DISABLE_AUTO_REACTIVATE_PASSWORD})
    assert_false organization.auto_reactivate_enabled?

    locked_members = organization.get_locked_out_members
    assert locked_members.empty?

    member.update_attributes(failed_login_attempts: 5, account_locked_at: Time.now.utc - 10.minute)
    member1.update_attributes(failed_login_attempts: 5, account_locked_at: Time.now.utc - 2.hours)

    locked_members = organization.get_locked_out_members
    assert_equal [member, member1], locked_members
  end

  def test_create_competency_and_questions
    organization = programs(:org_primary)
    organization.three_sixty_competencies.destroy_all
    assert_difference "ThreeSixty::Competency.count", 14 do
      assert_difference "ThreeSixty::Question.count", 70 do
        organization.create_competency_and_questions!
      end
    end
  end

  def test_validate_email_from_address
    e = assert_raise(ActiveRecord::RecordInvalid) do
      organization = programs(:org_primary)
      organization.email_from_address = "abcdef"
      organization.save!
    end

    assert_match(/is not a valid email address/, e.message)
  end

  def test_validate_programs_listing_visibility
    org = programs(:org_primary)
    assert org.valid?

    org.programs_listing_visibility = nil
    assert_nil org.programs_listing_visibility
    assert_false org.valid?

    org.programs_listing_visibility = 9999
    assert_false org.valid?

    Organization::ProgramsListingVisibility.all.each do |type|
      org.programs_listing_visibility = type
      assert org.valid?
    end
  end

  def test_get_protocol_should_return_http_for_normal_prog
    organization = programs(:org_primary)
    assert_equal "http", organization.get_protocol
    Rails.application.config.stubs(:force_ssl).returns(true)
    assert_equal "https", organization.get_protocol
  end

  def test_get_programs_with_feature_disabled
    organization = programs(:org_primary)
    programs_ids = organization.programs.pluck(:id)
    feature = Feature.find_by(name: FeatureName::CALENDAR_SYNC)
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR_SYNC, true)
    program.enable_feature(FeatureName::CALENDAR_SYNC, false)
    assert_equal [program.id], organization.reload.get_programs_with_feature_disabled(feature)

    programs(:albers).enable_feature(FeatureName::CALENDAR_SYNC, true)
    assert_equal [], organization.reload.get_programs_with_feature_disabled(feature)
  end

  def test_chronus_default_domain_for_normal_org
    organization = programs(:org_primary)
    pd = organization.chronus_default_domain
    assert_equal DEFAULT_DOMAIN_NAME, pd.domain
  end

  def test_chronus_default_domain_for_custom_org
    organization = programs(:org_custom_domain)
    pd = organization.chronus_default_domain
    assert_nil pd

    prog_domain = organization.program_domains.new
    prog_domain.domain = DEFAULT_DOMAIN_NAME
    prog_domain.subdomain = "abcd"
    prog_domain.is_default = false
    prog_domain.save!

    pd = organization.reload.chronus_default_domain
    assert_equal DEFAULT_DOMAIN_NAME, pd.domain
  end

  def test_populate_default_customized_terms
    CustomizedTerm.destroy_all
    org = programs(:org_primary)

    assert_difference 'CustomizedTerm.count', 8 do
      org.populate_default_customized_terms
    end
    assert_equal [CustomizedTerm::TermType::MENTORING_CONNECTION_TERM, CustomizedTerm::TermType::MEETING_TERM, CustomizedTerm::TermType::PROGRAM_TERM,
                  CustomizedTerm::TermType::RESOURCE_TERM, CustomizedTerm::TermType::ARTICLE_TERM, CustomizedTerm::TermType::ADMIN_TERM,
                  CustomizedTerm::TermType::MENTORING_TERM, CustomizedTerm::TermType::CAREER_DEVELOPMENT_TERM], CustomizedTerm.pluck(:term_type)
    assert_equal org, CustomizedTerm.first.ref_obj

    assert_no_difference 'CustomizedTerm.count' do
      org.populate_default_customized_terms
    end
  end

  def test_get_terms_for_view
    org = programs(:org_primary)
    program_term = org.term_for(CustomizedTerm::TermType::PROGRAM_TERM)
    admin_term = org.admin_custom_term
    assert_equal_unordered [program_term, admin_term], org.get_terms_for_view

    org = programs(:org_foster)
    program_term = org.term_for(CustomizedTerm::TermType::PROGRAM_TERM)
    admin_term = org.admin_custom_term
    program_terms = [programs(:foster).term_for(CustomizedTerm::TermType::RESOURCE_TERM)] + [programs(:foster).term_for(CustomizedTerm::TermType::MENTORING_TERM)] + [programs(:foster).term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM), programs(:foster).term_for(CustomizedTerm::TermType::ARTICLE_TERM), programs(:foster).term_for(CustomizedTerm::TermType::MEETING_TERM)] + programs(:foster).roles.where(name: RoleConstants::MENTORING_ROLES).collect(&:customized_term)

    assert_equal_unordered [program_term, admin_term]+program_terms, org.get_terms_for_view

    org = programs(:org_nch)
    program_term = org.term_for(CustomizedTerm::TermType::PROGRAM_TERM)
    career_development_term = org.term_for(CustomizedTerm::TermType::CAREER_DEVELOPMENT_TERM)
    admin_term = org.admin_custom_term
    assert_equal_unordered [program_term, career_development_term, admin_term], org.get_terms_for_view
  end

  def test_programs_listing_visible_to_all
    org = programs(:org_primary)
    assert_equal Organization::ProgramsListingVisibility::ALL, org.programs_listing_visibility
    assert org.programs_listing_visible_to_all?
  end

  def test_programs_listing_visible_to_only_logged_in_users
    org = programs(:org_primary)
    org.programs_listing_visibility = Organization::ProgramsListingVisibility::ONLY_LOGGED_IN_USERS
    assert_equal Organization::ProgramsListingVisibility::ONLY_LOGGED_IN_USERS, org.programs_listing_visibility
    assert org.programs_listing_visible_to_only_logged_in_users?
  end

  def test_programs_listing_visible_to_none
    org = programs(:org_primary)
    org.programs_listing_visibility = Organization::ProgramsListingVisibility::NONE
    assert_equal Organization::ProgramsListingVisibility::NONE, org.programs_listing_visibility
    assert org.programs_listing_visible_to_none?
  end

  def test_programs_listing_visible_to_logged_in_users
    org = programs(:org_primary)
    assert_equal Organization::ProgramsListingVisibility::ALL, org.programs_listing_visibility
    assert org.programs_listing_visible_to_logged_in_users?

    org.programs_listing_visibility = Organization::ProgramsListingVisibility::ONLY_LOGGED_IN_USERS
    assert_equal Organization::ProgramsListingVisibility::ONLY_LOGGED_IN_USERS, org.programs_listing_visibility
    assert org.programs_listing_visible_to_logged_in_users?
  end

  def test_get_enrollment_content
    member = members(:f_student)
    org = programs(:org_primary)
    _programs_allowing_roles = Role.where(program_id: org.programs.published_programs.collect(&:id)).non_administrative.allowing_join_now.group_by(&:program_id)
    _users = member.users.group_by(&:program_id)
    program_ids = (_users.keys + _programs_allowing_roles.keys).uniq
    _visible_programs = org.programs.ordered.select(['programs.id, root, parent_id, show_multiple_role_option']).find(program_ids)

    users, programs_allowing_roles, visible_programs = org.get_enrollment_content(member)
    assert_equal _users, users
    assert_equal _programs_allowing_roles, programs_allowing_roles
    assert_equal _visible_programs, visible_programs

    users, programs_allowing_roles, visible_programs_ids = org.get_enrollment_content(member, ids_only: true)
    assert_equal _users, users
    assert_equal _programs_allowing_roles, programs_allowing_roles
    assert_equal program_ids, visible_programs_ids
  end

  def test_reorder_programs
    org = programs(:org_primary)
    ordered_program_ids = org.programs.ordered.pluck(:id)
    org.reorder_programs(ordered_program_ids)
    new_ordered_program_ids = org.programs.ordered.pluck(:id)
    assert_equal ordered_program_ids, new_ordered_program_ids

    ordered_program_ids = org.programs.order('position DESC').map{|p| p.id.to_s}
    org.reorder_programs(ordered_program_ids)
    new_ordered_program_ids = org.programs.ordered.map{|p| p.id.to_s}
    assert_equal ordered_program_ids, new_ordered_program_ids
  end

  def test_get_from_email_address_should_return_custom_from_address_if_configured
    org = programs(:org_primary)
    org.email_from_address = 'no-reply@example.com'
    org.save!
    assert_equal 'no-reply@example.com', org.get_from_email_address
  end

  def test_get_from_email_address_should_return_default_in_case_it_is_not_customized
    org = programs(:org_primary)
    assert_nil org.email_from_address
    assert_equal 'no-reply@chronus.com', org.get_from_email_address
  end

  def test_url
    org = programs(:org_primary)
    assert_equal "primary.#{DEFAULT_DOMAIN_NAME}", org.url
  end

  def test_publicise_ckassets
    org = programs(:org_primary)
    asset1 = create_ckasset
    asset2 = create_ckasset(Ckeditor::Picture)
    asset3 = create_ckasset(Ckeditor::Picture)
    assert asset1.login_required?
    assert asset2.login_required?
    assert asset3.login_required?

    org.update_attributes(privacy_policy: "Attachment: #{asset1.url_content}", agreement: "Attachment: #{asset2.url_content}", footer_code: "Attachment: #{asset3.url_content}")
    assert_false asset1.reload.login_required?
    assert_false asset2.reload.login_required?
    assert_false asset3.reload.login_required?
  end

  def test_languages
    org = programs(:org_primary)
    assert_equal org.languages, org.organization_languages.collect(&:language)
  end

  def test_ab_test_enabled_for_default_enabled
    ProgramAbTest.stubs(:experiment).with('example').returns(Experiments::Example)
    assert Experiments::Example.enabled?

    org = programs(:org_primary)
    assert org.ab_test_enabled?('example')

    org.ab_tests.create!(test: 'example', enabled: false)
    assert_false org.reload.ab_test_enabled?('example')

    org.enable_ab_test('example', true)
    assert org.reload.ab_test_enabled?('example')
  end

  def test_ab_test_enabled_for_default_disabled
    ProgramAbTest.stubs(:experiment).with('example').returns(Experiments::Example)
    Experiments::Example.stubs(:enabled?).returns(false)
    assert_false Experiments::Example.enabled?

    org = programs(:org_primary)
    assert_false org.ab_test_enabled?('example')

    org.ab_tests.create!(test: 'example', enabled: true)
    assert org.reload.ab_test_enabled?('example')

    org.enable_ab_test('example', false)
    assert_false org.reload.ab_test_enabled?('example')
  end

  def test_email_priamry_color
    org = programs(:org_primary)
    assert_false org.email_theme_override.present?
    theme_vars = {EmailTheme::PRIMARY_COLOR => "#111112"}
    Organization.any_instance.stubs(:theme_vars).returns(theme_vars)
    assert_equal org.email_priamry_color, "#111112"
    org.update_attribute(:email_theme_override, "#222222")
    assert_equal org.email_priamry_color, "#222222"
  end

  def test_tracks_and_portals_association
    organization = programs(:org_primary)
    organization.programs.destroy_all
    organization.reload

    assert_equal 0, organization.tracks.count
    assert_equal 0, organization.portals.count

    program = Program.new(name: "Test program", root: "Domain", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, program_type: Program::ProgramType::CHRONUS_MENTOR, organization: organization)
    program.save!
    organization.reload
    assert_equal 1, organization.tracks.count
    assert_equal 0, organization.portals.count
    assert_equal 1, organization.programs.count
    assert_equal program, organization.tracks.first

    portal = create_career_dev_portal

    organization.reload
    assert_equal 1, organization.tracks.count
    assert_equal 1, organization.portals.count
    assert_equal 2, organization.programs.count
    assert_equal portal, organization.portals.first
  end

  def test_can_show_portals
    organization = programs(:org_nch)
    assert organization.can_show_portals?

    disable_career_development_feature(organization)
    assert_false organization.can_show_portals?

    enable_career_development_feature(organization)
    assert organization.can_show_portals?

    organization.programs.destroy_all
    organization.reload

    assert_false organization.can_show_portals?
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

  def test_programs_with_active_user_campaigns_present
    org = programs(:org_no_subdomain)
    assert_false org.programs_with_active_user_campaigns_present?
    campaign = org.programs.first.user_campaigns.first
    campaign.state = CampaignManagement::AbstractCampaign::STATE::ACTIVE
    campaign.save!
    assert org.programs_with_active_user_campaigns_present?
  end

  def test_user_csv_import_association
    organization = programs(:albers)

    assert_equal organization.user_csv_imports, []

    user_csv_import = organization.user_csv_imports.new
    user_csv_import.member = members(:f_admin)
    user_csv_import.attachment = fixture_file_upload("/files/csv_import.csv", "text/csv")
    user_csv_import.save!

    user_csv_import.update_attribute(:local_csv_file_path, UserCsvImport.save_user_csv_to_be_imported(fixture_file_upload("/files/csv_import.csv", "text/csv").read, "csv_import.csv", user_csv_import.id))

    assert_equal organization.user_csv_imports, [user_csv_import]
  end

  def test_hostnames
    org = programs(:org_primary)
    assert_equal ["primary."+DEFAULT_HOST_NAME], org.hostnames
    pd = org.program_domains.new
    pd.domain = "abc.com"
    pd.is_default = false
    pd.save!
    org.reload
    assert_equal_unordered ["primary."+DEFAULT_HOST_NAME, "abc.com"], org.hostnames
  end

  def test_clone_program_asset
    organization = programs(:org_anna_univ)
    assert_no_difference "ProgramAsset.count" do
      Organization.clone_program_asset!(organization.id)
    end

    organization__program_asset = organization.create_program_asset
    organization__program_asset.logo = fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png')
    organization__program_asset.banner = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    organization__program_asset.save!
    assert_difference "ProgramAsset.count", 3 do
      Organization.clone_program_asset!(organization.id)
    end
    program__program_asset = organization.programs.first.program_asset
    assert_equal "pic_2.png", program__program_asset.logo_file_name
    assert_equal "test_pic.png", program__program_asset.banner_file_name
  end

  def test_transition_global_objects_to_standalone_program
    standalone_program = programs(:foster)
    standalone_organization = standalone_program.organization
    organization_admin_message = create_admin_message(program: standalone_organization, sender: members(:foster_admin), receivers: [members(:foster_mentor1)])
    program_admin_message = create_admin_message(program: standalone_program, sender: members(:foster_admin), receivers: [members(:foster_mentor1)])
    organization_non_default_resource = create_resource(organization: standalone_organization)
    organization_default_resource = create_resource(organization: standalone_organization, default: true)
    program_resource = create_resource(organization: standalone_program, programs: [standalone_program])

    assert_no_difference "AdminMessage.count" do
      assert_no_difference "RoleResource.count" do
        assert_difference "ResourcePublication.count", 1 do
          assert_no_difference "Resource.count" do
            Organization.transition_global_objects_to_standalone_program(standalone_organization.id)
          end
        end
      end
    end
    assert_equal standalone_program, organization_admin_message.reload.program
    assert_equal standalone_program, program_admin_message.reload.program
    assert_equal standalone_program, organization_non_default_resource.reload.organization
    assert_equal 1, organization_non_default_resource.resource_publications.size
    assert_equal standalone_organization, organization_default_resource.reload.organization
    assert_equal standalone_program, program_resource.reload.organization
  end

  def test_transition_standalone_program_objects_to_organization
    standalone_organization = programs(:org_foster)

    Program.any_instance.expects(:handle_program_asset_of_standalone_program).once
    Program.any_instance.expects(:handle_organization_features_of_standalone_program).once
    Program.any_instance.expects(:handle_pages_of_standalone_program).once
    Organization.transition_standalone_program_objects_to_organization(standalone_organization.id)
    assert_equal standalone_organization.reload.programs.first.name, standalone_organization.name
    assert_equal standalone_organization.programs.first.description, standalone_organization.description
  end

  def test_has_many_user_activities
    organization = programs(:org_primary)
    assert_equal 0, organization.user_activities.count

    UserActivity.create!(organization_id: organization.id)
    assert_equal 1, organization.user_activities.count
  end

  def test_chronus_admin
    organization = programs(:org_primary)
    member = members(:f_mentor)
    assert_nil organization.chronus_admin

    member.email = SUPERADMIN_EMAIL
    member.save!
    assert_nil organization.chronus_admin

    member.admin = true
    member.save!
    assert_equal member, organization.chronus_admin
  end

  def test_admin_custom_term
    assert_equal customized_terms(:customized_terms_6), programs(:org_primary).admin_custom_term
    assert_raise NoMethodError do
      programs(:albers).admin_custom_term
    end
  end

  def test_can_preview_membership_questions_for_any_program
    organization = programs(:org_primary)
    enable_membership_request!(organization)
    assert organization.can_preview_membership_questions_for_any_program?
    disable_membership_request!(organization)
    assert_false organization.can_preview_membership_questions_for_any_program?
  end

  def test_ongoing_enabled_programs_present
    organization = programs(:org_primary)
    assert organization.ongoing_enabled_programs_present?

    organization = programs(:org_no_subdomain)
    organization.programs.first.update_attributes!(engagement_type: Program::EngagementType::CAREER_BASED)
    assert_false organization.ongoing_enabled_programs_present?
  end

  def test_auth_configs
    organization = programs(:org_primary)
    chronus_auth = organization.auth_configs.find(&:indigenous?)
    linkedin_oauth = organization.auth_configs.find(&:linkedin_oauth?)
    google_oauth = organization.auth_configs.find(&:google_oauth?)

    assert_equal chronus_auth, organization.chronus_auth
    assert_equal linkedin_oauth, organization.linkedin_oauth
    assert_equal google_oauth, organization.google_oauth
    assert_equal chronus_auth, organization.chronus_auth(true)
    assert_equal linkedin_oauth, organization.linkedin_oauth(true)
    assert_equal_unordered [chronus_auth, linkedin_oauth, google_oauth], organization.auth_configs
    assert_equal_unordered [chronus_auth, linkedin_oauth, google_oauth], organization.auth_configs(true)

    chronus_auth.disable!
    linkedin_oauth.disable!
    organization.reload
    assert_nil organization.chronus_auth
    assert_nil organization.linkedin_oauth
    assert_equal chronus_auth, organization.chronus_auth(true)
    assert_equal linkedin_oauth, organization.linkedin_oauth(true)
    assert_equal [google_oauth], organization.auth_configs
    assert_equal_unordered [chronus_auth, linkedin_oauth, google_oauth], organization.auth_configs(true)
  end

  def test_chronussupport_auth_config
    chronus_auth = programs(:org_primary).chronussupport_auth_config
    assert chronus_auth.indigenous?
    assert chronus_auth.readonly?
  end

  def test_chronussupport_auth_config_google_oauth
    google_oauth = programs(:org_primary).chronussupport_auth_config(true)
    assert google_oauth.google_oauth?
    assert google_oauth.readonly?
  end

  def test_standalone_auth
    organization = programs(:org_primary)
    assert_false organization.standalone_auth?

    organization.auth_configs[1..-1].map(&:disable!)
    assert organization.reload.standalone_auth?
  end

  def test_saml_auth
    organization = programs(:org_primary)
    assert_nil organization.saml_auth
    assert_false organization.has_saml_auth?

    saml_auth = organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    assert_equal saml_auth, organization.saml_auth
    assert organization.has_saml_auth?
  end

  def test_get_and_cache_custom_auth_config_ids
    organization = programs(:org_primary)
    custom_auth = organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    assert_equal [custom_auth.id], organization.get_and_cache_custom_auth_config_ids
    assert_equal [custom_auth.id], organization.instance_variable_get("@custom_auth_config_ids")[organization.id]
  end

  def test_get_admin_programs_hash
    organization = programs(:org_primary)
    all_programs = organization.programs.to_a
    admin_programs_hash = organization.get_admin_programs_hash
    assert_equal_unordered all_programs, admin_programs_hash.find{ |member, _| member.admin? }.second
    member, programs = admin_programs_hash.find{ |member, _| !member.admin? }
    assert member.users.where(program_id: programs.collect(&:id)).map(&:is_admin?).all?
    assert_false member.users.where.not(program_id: programs.collect(&:id)).map(&:is_admin?).any?
  end

    def test_get_program_alerts_hash
    organization = programs(:org_primary)
    all_programs = organization.programs.to_a
    Report::Alert.any_instance.stubs(:can_notify_alert?).returns(true)
    program_alerts_hash = organization.get_program_alerts_hash
    assert_equal_unordered all_programs.select{ |p| p.get_report_alerts_to_notify.present? }, program_alerts_hash.keys
    assert_equal_unordered program_alerts_hash.keys.first.get_report_alerts_to_notify, program_alerts_hash.values.first
  end
end