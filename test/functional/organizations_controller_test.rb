require_relative './../test_helper.rb'

class OrganizationsControllerTest < ActionController::TestCase
  include CareerDevTestHelper

  def setup
    @default_params = {organization_level: true}
    super
  end

  def test_edit_default_tab
    current_member_is members(:f_admin)
    get :edit, params: @default_params
    assert_response :success
    assert_equal ProgramsController::SettingsTabs::GENERAL, assigns(:tab)
  end

  def test_edit_with_invalid_argument
    current_member_is members(:f_admin)

    assert_permission_denied do
      get :edit, params: @default_params.merge({ :tab => ProgramsController::SettingsTabs::PERMISSIONS})
    end
  end

  def test_edit_with_unsupported_tab
    current_member_is members(:f_admin)

    assert_permission_denied do
      get :edit, params: @default_params.merge({ :tab => ProgramsController::SettingsTabs::MEMBERSHIP})
    end

    assert_permission_denied do
      get :edit, params: @default_params.merge({ :tab => ProgramsController::SettingsTabs::CONNECTION})
    end
  end

  def test_edit_accepts_given_tab
    current_member_is members(:f_admin)

    get :edit, params: @default_params.merge({ :tab => ProgramsController::SettingsTabs::TERMINOLOGY})
    assert_response :success
    assert_equal ProgramsController::SettingsTabs::TERMINOLOGY, assigns(:tab)
  end

  def test_non_super_user_cannot_edit_super_user_settings
    current_member_is members(:f_admin)

    get :edit, params: @default_params.merge({ :tab => ProgramsController::SettingsTabs::GENERAL})
    assert_response :success
    assert_select "div#program_form" do
      assert_select "input#organization_name"
      assert_select "input#organization_logo"
      assert_select "input#organization_programs_listing_visibility_0"
      assert_select "input#organization_programs_listing_visibility_1"
      assert_select "input#organization_programs_listing_visibility_2"
      assert_select "input#program_organization_browser_warning"
      assert_select "input#program_organization_privacy"
      # super_user_settings
      assert_no_select "input#organization_account_name"
      assert_no_select "input#organization_notification_setting_messages_notification_0"
    end
  end

  def test_update_terms_and_conditions_failure_if_display_custom_terms_only_flag_present
    organization = programs(:org_primary)
    assert_nil organization.privacy_policy
    assert_nil organization.agreement
    organization.update_attribute(:display_custom_terms_only, true)

    current_member_is members(:f_admin)
    post :update, params: @default_params.merge({ id: organization.id, tab: 0, organization: {
      name: "Updated Name",
      agreement: "My agreement",
      privacy_policy: "My Policy"
    }})
    assert assigns(:v2_page)
    assert_nil organization.reload.agreement
    assert_nil organization.privacy_policy
  end

  def test_update_terms_and_conditions_success_if_display_custom_terms_only_flag_not_set
    current_member_is members(:f_admin)
    prev_policy = programs(:org_primary).privacy_policy
    prev_agreement = programs(:org_primary).agreement
    assert_nil prev_policy
    assert_nil prev_agreement
    post :update, params: @default_params.merge({ :id => programs(:org_primary).id, :tab => 0, :organization => {
      :name => "Updated Name",
      :agreement => "My agreement",
      :privacy_policy => "My Policy"
    }})
    assert_equal programs(:org_primary).reload.agreement, "My agreement"
    assert_equal programs(:org_primary).privacy_policy, "My Policy"
  end

  def test_edit_when_disallow_edit_for_custom_terms_alone_true
    current_member_is members(:f_admin)
    org = programs(:org_primary)
    org.agreement = "test"
    org.privacy_policy = "test"
    assert_false programs(:org_primary).display_custom_terms_only
    org.display_custom_terms_only = true
    org.save!
    get :edit, params: @default_params.merge({ :id => programs(:org_primary).id})
    assert_response :success
    assert_equal ProgramsController::SettingsTabs::GENERAL, assigns(:tab)
    assert_select "div#agreement_actions", count: 0
    assert_select "div#privacy_actions", count: 0
    assert_select "div#cur_agreement[class=\"well square-well scroll-1 no-margin input-class-disabled\"]"
  end

  def test_disallow_edit_for_custom_terms_false
    current_member_is members(:f_admin)
    get :edit, params: @default_params.merge({ :id => programs(:org_primary).id})
    assert_response :success
    assert_select "div#agreement_actions"
    assert_select "div#privacy_actions"
    assert_select "div#cur_agreement[class=\"well square-well scroll-1 no-margin \"]"
  end

  def test_update_settings
    organization = programs(:org_primary)
    current_member_is members(:f_admin)
    login_as_super_user
    feed_exporter = FeedExporter.create!(program_id: organization.id)
    FileUploader.expects(:get_file_path).with(ProgramAsset::Type::BANNER, organization.id, "#{DROPZONE::TEMP_BASE_PATH}/#{ProgramAsset::TEMP_BASE_PATH}", "code" => "xyz", "file_name" => "banner").returns(fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png'))
    FileUploader.expects(:get_file_path).with(ProgramAsset::Type::LOGO, organization.id, "#{DROPZONE::TEMP_BASE_PATH}/#{ProgramAsset::TEMP_BASE_PATH}", "code" => "xyz", "file_name" => "logo").returns(fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))
    FileUploader.expects(:get_file_path).with(ProgramAsset::Type::MOBILE_LOGO, organization.id, "#{DROPZONE::TEMP_BASE_PATH}/#{ProgramAsset::TEMP_BASE_PATH}", "code" => "xyz", "file_name" => "mobile_logo").returns(fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))

    post :update, params: @default_params.merge({ id: organization.id, tab: 0, organization: {
      name: "Updated Name",
      agreement: "My agreement",
      activate_feed_export: "true",
      feed_export_frequency: FeedExporter::Frequency::WEEKLY,
      banner: { file_name: "banner", code: "xyz" },
      logo: { file_name: "logo", code: "xyz" },
      mobile_logo: { file_name: "mobile_logo", code: "xyz" }
    },
    })

    assert_equal "My agreement", organization.agreement
    assert_equal "Updated Name", organization.name
    assert_match /test_pic\.png/, organization.reload.logo_url
    assert_match /pic_2\.png/, organization.banner_url
    assert_match /test_pic\.png/, organization.mobile_logo_url
    assert_equal FeedExporter.first, organization.feed_exporter
    assert_equal FeedExporter::Frequency::WEEKLY, organization.feed_exporter.frequency
    assert_redirected_to edit_organization_path(tab: 0)
    assert_equal  "Your changes have been saved", flash[:notice]

    post :update, params: @default_params.merge({ id: organization.id, tab: 0, organization: {
      banner: { file_name: "banner" },
      logo: { file_name: "logo" },
      mobile_logo: { file_name: "mobile_logo" }
    }
    })

    assert_match /test_pic\.png/, organization.logo_url
    assert_match /pic_2\.png/, organization.banner_url
    assert_match /test_pic\.png/, organization.mobile_logo_url

    post :update, params: @default_params.merge({ id: organization.id, tab: 0, organization: {
      banner: { file_name: "" },
      logo: { file_name: "" },
      mobile_logo: { file_name: "" }
    }
    })

    assert_nil organization.reload.program_asset.logo.path
    assert_nil organization.program_asset.banner.path
    assert_nil organization.program_asset.mobile_logo.path
  end

  def test_career_dev_manage_portals_banner_fallback_when_logo_is_not_present
    organization = programs(:org_nch)
    assert organization.can_show_portals?
    program = organization.programs.first
    setup_banner_fallback(organization, program)

    current_member_is :nch_admin
    get :manage, params: @default_params
    assert_response :success
    assert_select ".link_box_icon.pic-col-md-4 img[src='#{TEST_ASSET_HOST + organization.banner_url}']", count: (organization.portals.size + organization.tracks.size - 1)
    assert_select ".link_box_icon.pic-col-md-4 img[src='#{TEST_ASSET_HOST + program.logo_url}']", count: 1
  end

  def test_show_action_banner_fallback_when_logo_is_not_present
    organization = programs(:org_primary)
    program = organization.programs.first
    setup_banner_fallback(organization, program)

    current_member_is :f_admin
    get :show, params: @default_params
    assert_response :success
    assert assigns(:show_pendo_launcher_in_all_devices)
    assert_select "div.program_logo_or_banner", count: organization.programs.size
    assert_select "div.program_logo_or_banner img[src='#{TEST_ASSET_HOST + organization.banner_url}']", count: organization.programs.size - 1
    assert_select "div.program_logo_or_banner img[src='#{TEST_ASSET_HOST + program.logo_url}']", count: 1
    assert_not_nil assigns(:managed_programs)
    assert_equal organization.programs.count, assigns(:managed_programs).size
    rollup_info = assigns(:rollup_info)
    assert_equal_unordered [:ongoing_engagements], rollup_info.keys
    assert_nil rollup_info[:ongoing_engagements][:total_active_count]
    assert_nil rollup_info[:ongoing_engagements][:meetings_rollup]
    assert_false rollup_info[:show_meeting_rollup]
  end


  def test_configure_dashboards_tab
    organization = programs(:org_primary)
    organization.enable_feature(FeatureName::GLOBAL_REPORTS_V3, true)
    current_member_is :f_admin
    get :show, params: @default_params
    assert_response :success
    dashboards_tab = @controller.tab_info["Dashboards"]
    sub_tabs = dashboards_tab.subtabs
    assert_equal ["executive_dashboard"], sub_tabs["links_list"]
  end

  def test_get_global_dashboard_program_info_box_stats
    organization = programs(:org_primary)
    program = organization.programs.first
    current_member_is :f_admin
    get :get_global_dashboard_program_info_box_stats, xhr: true, params: @default_params.merge(program_id: program.id)
    assert_equal program, assigns(:program)
  end

  def test_get_global_dashboard_org_current_status_stats
    current_member_is :f_admin
    get :get_global_dashboard_org_current_status_stats, xhr: true, params: @default_params.merge(active_licenses: true, ongoing_engagements: true, connected_members_count: true)
    rollup_info = assigns(:rollup_info)
    assert_equal_unordered [:active_licenses, :ongoing_engagements, :connected_members_info], rollup_info.keys
    assert_equal_hash({"total_count"=>56, "mentors_count"=>25, "students_count"=>24}, rollup_info[:active_licenses])
    assert_equal 9, rollup_info[:ongoing_engagements][:total_active_count]
    assert_nil rollup_info[:ongoing_engagements][:meetings_rollup]
    assert_equal_hash({"count"=>11, "mentors_count"=>6, "students_count"=>7}, rollup_info[:connected_members_info])
  end

  def test_get_global_dashboard_org_current_status_stats_for_multi_track_admin
    member = members(:f_student)
    current_member_is member
    
    Member.any_instance.stubs(:show_admin_dashboard?).returns(true)
    Member.any_instance.stubs(:admin_only_at_track_level?).returns(true)
    Member.any_instance.stubs(:managing_programs).returns(Program.where(id: member.program_ids))

    get :get_global_dashboard_org_current_status_stats, xhr: true, params: @default_params.merge(active_licenses: true, ongoing_engagements: true, connected_members_count: true)
    rollup_info = assigns(:rollup_info)
    assert_equal_unordered [:active_licenses, :ongoing_engagements, :connected_members_info], rollup_info.keys
    assert_equal_hash({"total_count"=>50, "mentors_count"=>23, "students_count"=>22}, rollup_info[:active_licenses])
    assert_equal 8, rollup_info[:ongoing_engagements][:total_active_count]
    assert_nil rollup_info[:ongoing_engagements][:meetings_rollup]
    assert_equal_hash({"count"=>9, "mentors_count"=>5, "students_count"=>6}, rollup_info[:connected_members_info])
  end

  def test_get_global_dashboard_org_current_status_stats_multiple_ajax
    member = members(:f_student)
    current_member_is member
    
    Member.any_instance.stubs(:show_admin_dashboard?).returns(true)
    Member.any_instance.stubs(:admin_only_at_track_level?).returns(true)
    Member.any_instance.stubs(:managing_programs).returns(Program.where(id: member.program_ids))

    get :get_global_dashboard_org_current_status_stats, xhr: true, params: @default_params.merge(active_licenses: true)
    rollup_info = assigns(:rollup_info)
    assert_equal [:active_licenses], rollup_info.keys
    
    get :get_global_dashboard_org_current_status_stats, xhr: true, params: @default_params.merge(ongoing_engagements: true, connected_members_count: true)
    rollup_info = assigns(:rollup_info)
    assert_equal [:ongoing_engagements, :connected_members_info], rollup_info.keys
  end

  def test_show_calendar_rollup_info
    organization = programs(:org_primary)
    organization.enable_feature(FeatureName::CALENDAR, true)
    current_member_is :f_admin
    get :show, params: @default_params
    assert_response :success
    assert assigns(:rollup_info)[:ongoing_engagements][:show_meeting_rollup]
  end

  def test_show_calendar_rollup_info_for_multi_track_admin
    organization = programs(:org_primary)
    member = members(:f_student)
    member.stubs(:managing_programs).returns(Program.where(id: member.programs.first))
    organization.enable_feature(FeatureName::CALENDAR, true)
    current_member_is member
    OrganizationsController.any_instance.stubs(:wob_member).returns(member)
    get :show, params: @default_params
    assert_response :success
    assert assigns(:rollup_info)[:ongoing_engagements][:show_meeting_rollup]
  end

  def test_enrollment_banner_fallback_when_logo_is_not_present
    organization = programs(:org_primary)
    program = organization.programs.first
    setup_banner_fallback(organization, program)

    current_member_is :f_admin
    get :enrollment, params: @default_params
    assert_response :success
    assert_select ".clearfix.row.hidden-xs div.program_logo_or_banner", :count => organization.programs.size
    assert_select ".clearfix.row.hidden-xs div.program_logo_or_banner img[src='#{TEST_ASSET_HOST + organization.banner_url}']", count: organization.programs.size - 1
    assert_select ".clearfix.row.hidden-xs div.program_logo_or_banner img[src='#{TEST_ASSET_HOST + program.logo_url}']", count: 1
  end

  def test_org_manage_banner_fallback_when_logo_is_not_present
    organization = programs(:org_primary)
    program = organization.programs.first
    setup_banner_fallback(organization, program)

    current_member_is :f_admin
    get :manage, params: @default_params
    assert_response :success
    assert assigns(:show_pendo_launcher_in_all_devices)
    assert_tab 'Manage'
    assert_select "li.program_logo_or_banner", :count => 1
    assert_select "#sidebarLeft li.program_logo_or_banner img[src='#{TEST_ASSET_HOST + organization.banner_url}']", :count => 1, :alt => "Program Banner"
    assert_select ".link_box_icon.pic-col-md-4 img[src='#{TEST_ASSET_HOST + organization.banner_url}']", count: organization.programs.size - 1
    assert_select ".link_box_icon.pic-col-md-4 img[src='#{TEST_ASSET_HOST + program.logo_url}']", count: 1
  end

  def test_update_other_settings_and_check_if_feed_exporter_is_present
    organization = programs(:org_primary)
    organization.create_feed_exporter!

    current_member_is :f_admin
    login_as_super_user
    post :update, params: @default_params.merge({ id: organization.id, tab: ProgramsController::SettingsTabs::FEATURES, organization: { enabled_features: [""] } })
    assert organization.reload.feed_exporter
  end

  def test_update_email_theme_override_success
    current_member_is members(:f_admin)
    login_as_super_user

    post :update, params: @default_params.merge({ :id => programs(:org_primary).id, :tab => 0, :organization => {
      :email_theme_override => "#111112"
    }})

    programs(:org_primary).reload

    assert_equal "#111112", programs(:org_primary).email_theme_override
  end

  def test_update_email_theme_override_without_logged_in_as_super_console
    current_member_is members(:f_admin)

    post :update, params: @default_params.merge({ :id => programs(:org_primary).id, :tab => 0, :organization => {
      :email_theme_override => "#111112"
    }})

    programs(:org_primary).reload

    assert_nil programs(:org_primary).email_theme_override
  end

  def test_update_settings_with_vulnerable_content_with_version_v1
    current_member_is members(:f_admin)
    login_as_super_user
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")
    assert_difference 'VulnerableContentLog.count', 0 do
      post :update, params: @default_params.merge({ :id => programs(:org_primary).id, :tab => 0, :organization => {
        :agreement => "My agreement <script>alert('Hai!!!')</script>",
        :privacy_policy => "My Privacy Policy <script>alert('Hai!!!')</script>",
        :browser_warning => "My Browser Warning <script>alert('Hai!!!')</script>",
      }})
    end
    programs(:org_primary).reload
    assert_equal "My agreement <script>alert('Hai!!!')</script>", programs(:org_primary).agreement
    assert_equal "My Privacy Policy <script>alert('Hai!!!')</script>", programs(:org_primary).privacy_policy
    assert_equal "My Browser Warning <script>alert('Hai!!!')</script>", programs(:org_primary).browser_warning
  end

  def test_update_settings_with_vulnerable_content_with_version_v2
    current_member_is members(:f_admin)
    login_as_super_user
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")
    assert_difference 'VulnerableContentLog.count', 3 do
      post :update, params: @default_params.merge({ :id => programs(:org_primary).id, :tab => 0, :organization => {
        :agreement => "My agreement <script>alert('Hai!!!')</script>",
        :privacy_policy => "My Privacy Policy <script>alert('Hai!!!')</script>",
        :browser_warning => "My Browser Warning <script>alert('Hai!!!')</script>",
      }})
    end
    programs(:org_primary).reload
    assert_equal "My agreement <script>alert('Hai!!!')</script>", programs(:org_primary).agreement
    assert_equal "My Privacy Policy <script>alert('Hai!!!')</script>", programs(:org_primary).privacy_policy
    assert_equal "My Browser Warning <script>alert('Hai!!!')</script>", programs(:org_primary).browser_warning
  end

  def test_deactivate_feed_export
    current_member_is members(:f_admin)
    login_as_super_user
    feed_exporter = FeedExporter.create!(program_id: programs(:org_primary).id)
    assert_equal feed_exporter, programs(:org_primary).feed_exporter

    post :update, params: @default_params.merge({ :id => programs(:org_primary).id, :tab => 0, :organization => {
      :name => "Updated Name",
      :agreement => "My agreement",
      :activate_feed_export => "false"
    }})

    assert_nil programs(:org_primary).reload.feed_exporter
  end

  def test_create_feed_export_with_invalid_frequency_created_with_default_frequency
    member = members(:f_admin)
    organization = member.organization

    current_member_is member
    login_as_super_user
    post :update, params: @default_params.merge(id: organization.id, tab: ProgramsController::SettingsTabs::GENERAL, organization: {
      name: "Updated Name",
      activate_feed_export: "true",
      feed_export_frequency: FeedExporter::Frequency::DAILY
    } )
    assert_equal FeedExporter::Frequency::DAILY, organization.feed_exporter.frequency
  end

  def test_update_invalid_logo_banner_failure
    organization = programs(:org_primary)
    FileUploader.expects(:get_file_path).returns(fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')).times(3)

    current_member_is members(:f_admin)

    post :update, params: @default_params.merge({ id: organization.id, tab: 0, organization: {
      name: "Updated Name",
      logo: { file_name: "logo", code: "xyz" }
    }})

    #Update Unsucessful
    assert_equal "Primary Organization", organization.name
    assert_match /Logo content type is not one of image\/pjpeg/, flash[:error]

    login_as_super_user
    post :update, params: @default_params.merge({ id: organization.id, tab: 0, organization: {
      banner: { file_name: "banner", code: "xyz" }
    }})
    assert_match /Banner content type is not one of image\/pjpeg/, flash[:error]

    post :update, params: @default_params.merge({ id: organization.id, tab: 0, organization: {
      mobile_logo: { file_name: "mobile_logo", code: "xyz" }
    }})
    assert_match /Mobile logo content type is not one of image\/pjpeg/, flash[:error]
  end

  #-----------------------------------------------------------------------------
  # FEATURES
  #-----------------------------------------------------------------------------

  def test_update_enabled_features_all_disabled_for_last_tab
    organization = programs(:org_primary)
    assert_equal_unordered [
      FeatureName::ANSWERS, FeatureName::ARTICLES, FeatureName::SKYPE_INTERACTION, FeatureName::RESOURCES,
      FeatureName::PROFILE_COMPLETION_ALERT, FeatureName::STICKY_TOPIC, FeatureName::ORGANIZATION_PROFILES, FeatureName::SKIP_AND_FAVORITE_PROFILES,
      FeatureName::PROGRAM_EVENTS, FeatureName::FLAGGING, FeatureName::LINKEDIN_IMPORTS, FeatureName::MANAGER, FeatureName::MENTORING_INSIGHTS,
      FeatureName::EXECUTIVE_SUMMARY_REPORT, FeatureName::FORUMS, FeatureName::CAMPAIGN_MANAGEMENT, FeatureName::MOBILE_VIEW, FeatureName::CALENDAR_SYNC, FeatureName::WORK_ON_BEHALF
    ], organization.enabled_features
    profile_questions(:manager_q).destroy

    current_member_is :f_admin
    login_as_super_user
    post :update, params: @default_params.merge({ id: organization.id, tab: ProgramsController::SettingsTabs::FEATURES, organization: { enabled_features: [""] } })
    assert_redirected_to edit_organization_path(tab: ProgramsController::SettingsTabs::FEATURES)
    assert_empty organization.reload.enabled_features
  end

  def test_super_user_should_be_able_to_edit_su_features
    organization = programs(:org_primary)
    assert organization.has_feature?(FeatureName::WORK_ON_BEHALF)
    assert organization.has_feature?(FeatureName::FORUMS)
    assert_false organization.has_feature?(FeatureName::THREE_SIXTY)

    current_member_is :f_admin
    login_as_super_user
    assert_nothing_raised do
      post :update, params: @default_params.merge({ tab: ProgramsController::SettingsTabs::FEATURES, "organization" => { "enabled_features" => ["", "articles", "answers", "manager", "three_sixty"] }, features_tab: "true" })
    end
    organization.reload
    assert_false organization.has_feature?(FeatureName::WORK_ON_BEHALF)
    assert_false organization.has_feature?(FeatureName::FORUMS)
    assert organization.has_feature?(FeatureName::THREE_SIXTY)
  end

  def test_non_super_user_should_not_be_able_enable_a_su_features
    organization = programs(:org_primary)
    assert organization.has_feature?(FeatureName::WORK_ON_BEHALF)
    assert organization.has_feature?(FeatureName::FORUMS)
    assert_false organization.has_feature?(FeatureName::THREE_SIXTY)

    current_member_is :f_admin
    assert_permission_denied do
      post :update, params: @default_params.merge({ tab: ProgramsController::SettingsTabs::FEATURES, "organization" => { "enabled_features" => ["", "articles", "answers", "three_sixty"] }, features_tab: "true" })
    end
    organization.reload
    assert organization.has_feature?(FeatureName::WORK_ON_BEHALF)
    assert organization.has_feature?(FeatureName::FORUMS)
    assert_false organization.has_feature?(FeatureName::THREE_SIXTY)
  end

  def test_non_super_user_should_not_be_able_disable_a_su_features
    organization = programs(:org_primary)
    assert organization.has_feature?(FeatureName::FORUMS)
    assert_false organization.has_feature?(FeatureName::THREE_SIXTY)

    current_member_is :f_admin
    assert_nothing_raised do
      post :update, params: @default_params.merge({ tab: ProgramsController::SettingsTabs::FEATURES, "organization" => { "enabled_features" => ["", "", "articles", "answers"] }, features_tab: "true" })
    end
    organization.reload
    assert organization.has_feature?(FeatureName::FORUMS)
    assert_false organization.has_feature?(FeatureName::THREE_SIXTY)
  end

  def test_enable_subprogram_creation
    current_member_is members(:f_admin)
    login_as_super_user
    profile_questions(:manager_q).destroy
    post :update, params: @default_params.merge({ :id => programs(:org_primary).id, :tab => ProgramsController::SettingsTabs::FEATURES, :organization => {
      :enabled_features => [FeatureName::SUBPROGRAM_CREATION]
    }})
    assert_equal_unordered(
      [FeatureName::SUBPROGRAM_CREATION],
      programs(:org_primary).enabled_features
    )
  end

  def test_update_enabled_features
    current_member_is :f_admin
    login_as_super_user

    assert_equal_unordered(
      [
        FeatureName::ANSWERS, FeatureName::ARTICLES, FeatureName::SKYPE_INTERACTION, FeatureName::RESOURCES,
        FeatureName::PROFILE_COMPLETION_ALERT, FeatureName::STICKY_TOPIC, FeatureName::ORGANIZATION_PROFILES, FeatureName::SKIP_AND_FAVORITE_PROFILES,
        FeatureName::PROGRAM_EVENTS, FeatureName::FLAGGING, FeatureName::LINKEDIN_IMPORTS, FeatureName::MANAGER, FeatureName::MENTORING_INSIGHTS,
        FeatureName::EXECUTIVE_SUMMARY_REPORT, FeatureName::FORUMS, FeatureName::CAMPAIGN_MANAGEMENT, FeatureName::MOBILE_VIEW, FeatureName::CALENDAR_SYNC, FeatureName::WORK_ON_BEHALF
      ],
      programs(:org_primary).enabled_features
    )

    post :update, params: @default_params.merge({ :id => programs(:org_primary).id, :tab => ProgramsController::SettingsTabs::FEATURES, :organization => {
      :enabled_features => [FeatureName::ANSWERS, FeatureName::MANAGER]
    }})

    assert_equal_unordered(
      [FeatureName::ANSWERS, FeatureName::MANAGER], programs(:org_primary).reload.enabled_features
    )

    assert_redirected_to edit_organization_path(:tab => ProgramsController::SettingsTabs::FEATURES)
  end

  def test_remove_manager_feature_when_manager_question_is_present
    current_member_is :f_admin
    login_as_super_user
    org = programs(:org_primary)

    assert org.enabled_features.include?(FeatureName::MANAGER)
    assert org.profile_questions.manager_questions.any?

    post :update, params: @default_params.merge({ :id => org.id, :tab => ProgramsController::SettingsTabs::FEATURES, :organization => {
      :enabled_features => org.enabled_features - [FeatureName::MANAGER]
    }})

    assert_equal "Manager feature cannot be disabled when Manager type profile question is present", flash[:error]
    assert org.enabled_features.include?(FeatureName::MANAGER)
  end

  def test_dashboard_access_without_login
    current_organization_is :org_primary

    get :show, params: @default_params
    assert_redirected_to about_path
  end

  def test_redirect_to_program_root_if_standalone
    current_member_is :foster_mentor5

    get :show, params: @default_params
    assert_equal programs(:foster), assigns(:current_program)
    assert_equal programs(:org_foster), assigns(:current_organization)
    assert_redirected_to program_root_path(:root => programs(:foster).root)
  end

  def test_user_trying_to_access_invalid_ip_should_logout_and_redirect_to_root_path
    current_member_is :f_student
    configure_allowed_ips_to_restrict
    setup_admin_custom_term
    get :show, params: @default_params
    assert_redirected_to root_organization_path
    assert_false assigns(:current_member)
    assert_equal "This is a restricted site. You must log in to this site through an authorized network. Please contact your super admin if you need further help.", flash[:error]
  end

  def test_user_trying_to_access_valid_ip_should_not_logout_or_redirect
    current_member_is :f_student
    configure_allowed_ips
    get :show, params: @default_params
    assert_response :success
    assert_equal members(:f_student), assigns(:current_member)
  end

  def test_redirect_to_program_root_if_member_belongs_to_single_sub_program
    current_member_is :psg_student1
    assert_equal 1, members(:psg_student1).programs.size

    get :show, params: @default_params
    assert_redirected_to program_root_path(:root => programs(:psg).root)
  end

  def test_dashboard_access_for_mentor
    current_member_is :anna_univ_mentor

    # For triggering an RA.
    create_announcement(:program => programs(:psg), :admin => users(:psg_admin), :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))
    article1 = create_article(:author => members(:anna_univ_mentor), :published_programs => [programs(:psg)], :organization => programs(:org_anna_univ))
    question = create_qa_question(:user => users(:mentor_3), :program => programs(:albers))

    get :show, params: @default_params
    assert_response :success
    assert assigns(:is_recent_activities_present)
    assert_equal_unordered [programs(:ceg), programs(:psg)], assigns(:my_programs)
    assert assigns(:my_meetings).blank?
    assert_nil assigns(:rollup_info)
  end

  def test_dashboard_access_for_mentor_calendar_feature_enabled
    programs(:org_anna_univ).enable_feature(FeatureName::CALENDAR, true)
    current_member_is :anna_univ_mentor

    # For triggering an RA.
    create_announcement(:program => programs(:psg), :admin => users(:psg_admin), :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))
    article1 = create_article(:author => members(:anna_univ_mentor), :published_programs => [programs(:psg)], :organization => programs(:org_anna_univ))
    question = create_qa_question(:user => users(:mentor_3), :program => programs(:albers))

    get :show, params: @default_params
    assert_response :success
    assert assigns(:is_recent_activities_present)
    assert_equal_unordered [programs(:ceg), programs(:psg)], assigns(:my_programs)
  end

  def test_dashboard_access_for_student
    org = programs(:org_primary)
    current_member_is :f_student

    create_announcement(:program => programs(:albers), :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))
    article1 = create_article(:published_programs => [programs(:albers)])
    question = create_qa_question(:user => users(:ceg_mentor), :program => programs(:ceg))

    get :show, params: @default_params
    assert_response :success
    assert assigns(:is_recent_activities_present)
    assert_equal [programs(:albers), programs(:nwen), programs(:pbe)], assigns(:my_programs)
    assert_nil assigns(:programs)

    assert_no_select "div.program_tile_content"
  end

  def test_dashboard_access_for_admin_mentoring_connections_v2_disabled
    Program.any_instance.stubs(:mentoring_connections_v2_enabled?).returns(false)
    current_member_is :f_admin
    get :show, params: @default_params

    response_text = ActionController::Base.helpers.strip_tags(response.body).squish
    assert_no_match(/Overdue/, response_text)
    assert_no_match(/On Track/, response_text)
  end

  def test_cannot_view_ra_if_no_permission
    current_member_is :f_student
    fetch_role(:albers, :student).remove_permission('view_ra')
    fetch_role(:pbe, :student).remove_permission('view_ra')
    fetch_role(:nwen, :student).remove_permission('view_ra')
    fetch_role(:nwen, :mentor).remove_permission('view_ra')
    assert_false users(:f_student).can_view_ra?
    assert_false users(:f_student_pbe).can_view_ra?
    assert_false users(:f_student_nwen_mentor).can_view_ra?
    assert_false members(:f_student).can_view_ra?

    get :show, params: @default_params
    assert_response :success
    assert_false assigns(:is_recent_activities_present)
    assert_no_select "#recent_activities"
  end

  def test_get_manage_page
    current_member_is :f_admin

    get :manage, params: @default_params
    assert_response :success
    assert_tab 'Manage'
  end

  def test_should_show_support_for_admin_in_manage_page_zendesk
    current_member_is :f_admin
    get :manage, params: @default_params
    assert_select 'div#manage' do
      assert_select 'div.ibox' do
        assert_select 'a[href=?]', zendesk_session_path(src: 'manage')
      end
    end
  end

  def test_disallow_manage_page_for_non_admins
    current_member_is :ram

    assert_permission_denied do
      get :manage, params: @default_params
    end
  end

  def test_do_not_show_new_program_link_when_feature_disabled
    o = programs(:org_primary)
    current_member_is :f_admin

    assert_false o.subprogram_creation_enabled?
    get :manage, params: @default_params
    assert_response :success
    assert_tab 'Manage'
    assert_select "a", :text => "New Program", :count => 0
  end

  def test_do_show_new_program_link_when_feature_enabled
    o = programs(:org_primary)
    o.enable_feature(FeatureName::SUBPROGRAM_CREATION, true)
    current_member_is :f_admin

    assert o.reload.subprogram_creation_enabled?
    get :manage, params: @default_params
    assert_response :success
    assert_tab 'Manage'
    assert_select "a", :text => "New Program"
  end

  def test_do_not_show_program_listing_visibility_setting_for_standalone_orgs
    current_member_is :foster_admin

    get :edit, params: @default_params
    assert_response :success
    assert_no_select "input#organization_programs_listing_visibility_0"
    assert_no_select "input#organization_programs_listing_visibility_1"
    assert_no_select "input#organization_programs_listing_visibility_2"
  end

  def test_show_all_activities
    current_member_is :anna_univ_mentor

    members(:anna_univ_mentor).expects(:activities_to_show).with(:actor => members(:anna_univ_mentor)).never
    members(:anna_univ_mentor).expects(:activities_to_show).at_least(0).returns([])
    get :show_activities, xhr: true, params: @default_params
    assert assigns(:recent_activities_with_user)
    assert_response :success
    assert @response.body.include?("show_more_all_activities")
  end

  def test_show_my_activities
    current_member_is :anna_univ_mentor

    members(:anna_univ_mentor).expects(:activities_to_show).with(:actor => members(:anna_univ_mentor)).at_least(0).returns([])
    get :show_activities, xhr: true, params: @default_params.merge({ :my => 1})
    assert assigns(:recent_activities_with_user)
    assert_response :success
    assert @response.body.include?("show_more_my_activities")
  end

  def test_show_my_activities_with_offset
    current_member_is :anna_univ_mentor

    members(:anna_univ_mentor).expects(:activities_to_show).with(:offset_id => 25, :actor => members(:anna_univ_mentor)).at_least(0).returns([])
    get :show_activities, xhr: true, params: @default_params.merge({ :my => 1, :offset_id => 25})
    assert assigns(:recent_activities_with_user)
    assert_response :success
    assert @response.body.include?("show_more_my_activities")
  end

  def test_get_recent_activities_for_mentor_one_common_program
    create_qa_question(:user => users(:f_mentor), :program => programs(:albers))
    create_qa_question(:user => users(:f_mentor_nwen_student), :program => programs(:nwen))
    current_user_is :nwen_admin
    get :show_activities, xhr: true, params: @default_params
    assert_equal assigns(:recent_activities_with_user), [{ :act => RecentActivity.last, :user => users(:nwen_admin)}]
    assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::QA_QUESTION_CREATION
  end

  def test_get_recent_activities_for_mentor_two_common_programs
    u1 = users(:f_student_nwen_mentor)
    RecentActivity.destroy_all
    create_qa_question(:user => users(:f_mentor), :program => programs(:albers))
    create_qa_question(:user => users(:f_mentor_nwen_student), :program => programs(:nwen))
    current_user_is :f_student_nwen_mentor
    get :show_activities, xhr: true, params: @default_params
    assert_equal assigns(:recent_activities_with_user), [{:user => u1, :act => RecentActivity.last}, {:user => users(:f_student), :act => RecentActivity.all[-2]}]
    assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::QA_QUESTION_CREATION
    assert_equal RecentActivity.all[-2].action_type, RecentActivityConstants::Type::QA_QUESTION_CREATION
  end

  def test_suspended_program
    programs(:org_primary).active = false
    programs(:org_primary).save!

    current_organization_is programs(:org_primary)
    get :show, params: @default_params

    assert_redirected_to inactive_organization_path
  end

  def test_inactive_redirection
    current_organization_is programs(:org_primary)
    get :inactive, params: @default_params

    assert_redirected_to root_organization_path
  end

  def test_inactive
    programs(:org_primary).active = false
    programs(:org_primary).save!

    current_organization_is programs(:org_primary)
    get :inactive, params: @default_params

    assert_response :success
    get :inactive, params: @default_params.merge({ format: :ics})

    assert_response :success
  end

  #SECURITY
  def test_should_change_login_expiry_period
    current_member_is members(:f_admin)
    post :update, params: @default_params.merge({ :tab => ProgramsController::SettingsTabs::SECURITY, :login_exp_per_enable => "1",:organization => {
      :security_setting_attributes => {:login_expiry_period => "100"}
      }})
    programs(:org_primary).reload
    assert_equal 100, programs(:org_primary).security_setting.login_expiry_period
    assert_equal "Your changes have been saved", flash[:notice]
  end

  def test_should_set_login_expiry_period_to_default_if_login_exp_per_enable_is_false
    current_member_is members(:f_admin)
    post :update, params: @default_params.merge({ :tab => ProgramsController::SettingsTabs::SECURITY, :login_exp_per_enable => false, :organization => {}
    })
    programs(:org_primary).reload
    assert_equal "Your changes have been saved", flash[:notice]
  end

  def test_activity_log_should_not_log_in_organization_view
    current_member_is :anna_univ_mentor

    assert_no_difference 'ActivityLog.count' do
      get :show, params: @default_params
      assert_response :success
    end
  end

  def test_should_fail_for_invalid_ips_or_domains
    current_member_is :f_admin
    org = programs(:org_primary)
    assert_nil org.security_setting.allowed_ips
    org.security_setting.allowed_ips = "0.0.0.0"
    org.save!
    assert_equal "0.0.0.0", org.security_setting.allowed_ips

    allowed_ips = [
      { from: '127.0.0.1', to: '' },
      { from: '127.0.0.258', to: '192.168.0.225' },
      { from: 'example.com', to: '' }
    ]

    post :update, params: @default_params.merge({ tab: ProgramsController::SettingsTabs::SECURITY, login_exp_per_enable: true, organization: {
      security_setting_attributes: { allowed_ips: allowed_ips, :id => org.security_setting.id }
    }})
    org.reload
    assert_equal "0.0.0.0", org.security_setting.allowed_ips
  end

  def test_update_security_settings_with_super_user
    current_member_is :f_admin
    login_as_super_user
    org = programs(:org_primary)
    assert_false org.login_attempts_enabled?
    assert org.security_setting.can_contain_login_name?
    assert org.security_setting.allow_search_engine_indexing?

    allowed_ips = [
      { from: '127.0.0.1', to: '' },
      { from: '192.168.0.1', to: '192.168.0.225' }
    ]

    post :update, params: @default_params.merge({ :tab => ProgramsController::SettingsTabs::SECURITY, :account_lockout => "1", :reactivate_account => "1", :auto_password_expiry => "1", "organization" => {
      "security_setting_attributes"=>{"reactivation_email_enabled"=>"true", "maximum_login_attempts"=>"2",
        "auto_reactivate_account"=>"0.5", "can_contain_login_name"=>"false",
        "can_show_remember_me"=>"false", "password_expiration_frequency"=>"30",
        "allowed_ips" => allowed_ips, "allow_search_engine_indexing" => "0", "id"=>org.security_setting.id }
      }})

    org.reload
    assert_equal 2, org.security_setting.maximum_login_attempts
    assert org.login_attempts_enabled?
    assert org.security_setting.reactivation_email_enabled?
    assert_equal 0.5, org.security_setting.auto_reactivate_account
    assert_false org.security_setting.can_contain_login_name?
    assert_equal 30, org.security_setting.password_expiration_frequency
    assert_false org.security_setting.can_show_remember_me?
    assert_equal "127.0.0.1,192.168.0.1:192.168.0.225", org.security_setting.allowed_ips
    assert_false org.security_setting.allow_search_engine_indexing?
  end

  def test_update_security_settings
    current_member_is :f_admin
    login_as_super_user
    org = programs(:org_primary)
    assert_false org.login_attempts_enabled?
    assert org.security_setting.can_contain_login_name?
    assert org.security_setting.can_show_remember_me?
    assert_nil org.security_setting.allowed_ips

    post :update, params: @default_params.merge({ :tab => ProgramsController::SettingsTabs::SECURITY, :account_lockout => "1", :reactivate_account => "1", :auto_password_expiry => "1", "organization" => {
      "security_setting_attributes"=>{"reactivation_email_enabled"=>"true", "maximum_login_attempts"=>"2",
        "auto_reactivate_account"=>"0.5", "id"=>org.security_setting.id }
      }})

    org.reload
    assert_equal 2, org.security_setting.maximum_login_attempts
    assert org.login_attempts_enabled?
    assert org.security_setting.reactivation_email_enabled?
    assert_equal 0.5, org.security_setting.auto_reactivate_account
    assert org.security_setting.can_contain_login_name?
    assert org.security_setting.can_show_remember_me?
    assert_nil org.security_setting.allowed_ips
  end

  def test_cannot_access_enrollment_page_without_logging_in
    current_organization_is programs(:org_primary)
    get :enrollment, params: @default_params
    assert_redirected_to new_session_path
  end

  def test_cannot_access_enrollment_page_without_logging_in_program
    current_program_is programs(:albers)
    get :enrollment, params: @default_params
    assert_redirected_to new_session_path
  end

  def test_logged_in_user_can_access_enrollment_page_from_program_level_without_logging_in_at_that_program
    current_member_is members(:moderated_student)
    current_program_is programs(:albers)
    get :enrollment, params: @default_params
    assert :success
  end

  def test_can_access_enrollment_page
    current_user_is users(:f_student)
    get :enrollment, params: @default_params
    assert :success
    member = users(:f_student).member
    programs_allowing_roles = Role.where(:program_id => programs(:org_primary).programs.ordered.published_programs.collect(&:id)).non_administrative.allowing_join_now.group_by(&:program_id)
    users = member.users.group_by(&:program_id)
    program_ids = (users.keys + programs_allowing_roles.keys).uniq
    visible_programs = Program.select(['programs.id, root, parent_id, show_multiple_role_option']).find(program_ids.uniq)
    membership_requests = member.membership_requests.pending
    assert_equal_unordered visible_programs, assigns(:tracks)
    assert_equal programs_allowing_roles, assigns(:programs_allowing_roles)
    assert_equal users, assigns(:users)
    assert_equal_unordered membership_requests, assigns(:membership_requests)
  end

  def test_can_acces_enrollement_page_protal
    current_user_is users(:portal_employee)
    get :enrollment, params: @default_params
    assert :success
    member = users(:portal_employee).member
    programs_allowing_roles = Role.where(:program_id => programs(:org_nch).programs.ordered.published_programs.collect(&:id)).non_administrative.allowing_join_now.group_by(&:program_id)
    users = member.users.group_by(&:program_id)
    program_ids = (users.keys + programs_allowing_roles.keys).uniq
    tracks = Program.select(['programs.id, root, parent_id, show_multiple_role_option']).tracks.where(id: program_ids.uniq)
    portals = CareerDev::Portal.select(['programs.id, root, parent_id, show_multiple_role_option']).portals.where(id: program_ids.uniq)
    membership_requests = member.membership_requests.pending
    assert_equal_unordered tracks, assigns(:tracks)
    assert_equal_unordered portals, assigns(:portals)
    assert_equal programs_allowing_roles, assigns(:programs_allowing_roles)
    assert_equal users, assigns(:users)
    assert_equal_unordered membership_requests, assigns(:membership_requests)
  end

  def test_enrollment_popup
    member = members(:f_mentor)
    program = programs(:albers)
    assert program.find_role(RoleConstants::MENTOR_NAME).membership_request?
    assert program.find_role(RoleConstants::STUDENT_NAME).membership_request?

    current_member_is member
    get :enrollment_popup, xhr: true, params: @default_params.merge({ format: :js, program: program.id, roles: [RoleConstants::STUDENT_NAME]})
    assert_response :success
    assert_equal [], assigns(:join_roles)
    assert_equal_unordered [RoleConstants::STUDENT_NAME], assigns(:membership_roles)
  end

  def test_enrollment_popup_suspended_user
    user = users(:f_mentor)
    program = programs(:albers)
    program.find_role(RoleConstants::MENTOR_NAME).update_attributes(membership_request: false, join_directly: true)
    program.find_role(RoleConstants::STUDENT_NAME).update_attributes(membership_request: false, join_directly: true)
    suspend_user(user)

    current_member_is user.member
    get :enrollment_popup, xhr: true, params: @default_params.merge({ format: :js, program: program.id, roles: [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME]})
    assert_response :success
    assert_equal [], assigns(:join_roles)
    assert_equal_unordered [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], assigns(:membership_roles)
  end

  def test_features_dependencies_with_mentoring_connections_v2
    current_user_is users(:f_admin)
    login_as_super_user

    organization = programs(:org_primary)
    assert_false organization.has_feature?(FeatureName::MENTORING_CONNECTIONS_V2)

    post :update, params: @default_params.merge({ :tab => ProgramsController::SettingsTabs::FEATURES, "organization"=>{"enabled_features"=>["", "mentoring_connections_v2", "manager"]}, :features_tab=>"true"})

    organization.reload
    assert organization.has_feature?(FeatureName::MENTORING_CONNECTIONS_V2)
    assert organization.has_feature?(FeatureName::MENTORING_CONNECTION_MEETING)
  end

  def test_should_show_quick_link_to_three_sixty_survey_for_assessee
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_student

    get :show, params: @default_params
    assert_response :success

    assert_select "ul#quick_links" do
      assert_select 'a', :href => three_sixty_my_surveys_path, :text => 'My Three Sixty Degree Surveys', :count => 1
    end

    three_sixty_survey_assessees(:three_sixty_survey_assessees_14).destroy
    get :show, params: @default_params
    assert_response :success
    assert_select "ul#quick_links", :count => 0

  end

  def test_update_three_sixty_settings_login_required
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    post :update_three_sixty_settings
    assert_redirected_to new_session_path
  end

  def test_update_three_sixty_settings_non_admin_failure
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :ram

    assert_permission_denied do
      post :update_three_sixty_settings, xhr: true
    end
  end

  def test_update_three_sixty_settings_feature_disabled_failure
    assert_false programs(:org_primary).has_feature?(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    assert_permission_denied do
      post :update_three_sixty_settings, xhr: true
    end
  end

  def test_update_three_sixty_settings_success
    assert programs(:org_primary).show_text_type_answers_per_reviewer_category?
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    post :update_three_sixty_settings, xhr: true
    assert_false programs(:org_primary).reload.show_text_type_answers_per_reviewer_category?
    assert_response :success

    post :update_three_sixty_settings, xhr: true
    assert programs(:org_primary).reload.show_text_type_answers_per_reviewer_category?
    assert_response :success
  end

  def test_set_uniq_cookie_token
    get :show, params: @default_params
    uniq_token =  @request.env["action_dispatch.cookies"]['uniq_token']
    assert uniq_token.present?

    get :show, params: @default_params
    assert_equal uniq_token,  @request.env["action_dispatch.cookies"]['uniq_token']
  end

  def test_deactivate_login_required
    current_organization_is :org_primary

    post :deactivate, params: @default_params
    assert_redirected_to super_login_path
  end

  def test_deactivate_success
    login_as_super_user
    current_organization_is :org_primary
    org = programs(:org_primary)
    post :deactivate, params: @default_params.merge({ organization: {:active => "0"}})
    assert org.active?

    internal_mailer_mock = mock
    internal_mailer_mock.expects(:deliver_now).returns
    InternalMailer.expects(:deactivate_organization_notification).with(org.name, org.account_name, org.url).returns(internal_mailer_mock)
    post :deactivate, params: @default_params.merge({ organization: {:active => "1"}})
    assert_false org.reload.active?
  end

  def test_deactivate_success_with_disable_feed_importer
    login_as_super_user
    current_organization_is :org_primary
    org = programs(:org_primary)
    feed_import = org.create_feed_import_configuration!(frequency: 1.day.to_i, enabled: true, sftp_user_name: "org")
    post :deactivate, params: @default_params.merge({ organization: {:active => "0"}})
    assert org.active?
    assert feed_import.enabled?

    post :deactivate, params: @default_params.merge({ organization: {:active => "1"}})
    assert_false org.reload.active?
    assert_false feed_import.reload.enabled?
  end

  def test_manage_portals
    current_member_is members(:f_admin)
    current_organization_is :org_primary
    org = programs(:org_primary)
    get :manage, params: @default_params
    assert_response :success
    assert_not_nil assigns(:portals)
    assert_false assigns(:can_create_portal)
    assert_false assigns(:show_manage_portal)
    login_as_super_user
    get :manage, params: @default_params
    assert_response :success
    assert_not_nil assigns(:portals)
    assert_false assigns(:can_create_portal)
    assert_false assigns(:show_manage_portal)
    logout_as_super_user
    enable_career_development_feature(org)

    get :manage, params: @default_params
    assert_response :success
    assert_not_nil assigns(:portals)
    assert_false assigns(:can_create_portal)
    assert_false assigns(:show_manage_portal)
    login_as_super_user
    get :manage, params: @default_params
    assert_response :success
    assert_not_nil assigns(:portals)
    assert assigns(:can_create_portal)
    assert assigns(:show_manage_portal)
    logout_as_super_user


    portal = create_career_dev_portal

    get :manage, params: @default_params
    assert_response :success
    assert_not_nil assigns(:portals)
    assert_false assigns(:can_create_portal)
    assert assigns(:show_manage_portal)
    login_as_super_user
    get :manage, params: @default_params
    assert_response :success
    assert_not_nil assigns(:portals)
    assert assigns(:can_create_portal)
    assert assigns(:show_manage_portal)
  end
end
