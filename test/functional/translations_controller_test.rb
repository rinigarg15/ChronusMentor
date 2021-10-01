require_relative './../test_helper.rb'

class TranslationsControllerTest < ActionController::TestCase
  include CampaignManagement::CampaignsHelper

  def test_index_mentor_permission_needed
    current_member_is :f_mentor
    assert_permission_denied do
      get :index
    end
    programs(:org_primary).enable_feature(FeatureName::LANGUAGE_SETTINGS)
    assert_permission_denied do
      get :index
    end
    current_user_is :f_mentor
    assert_permission_denied do
      get :index
    end
  end

  def test_index_student_permission_needed
    current_member_is :f_student
    assert_permission_denied do
      get :index
    end
    programs(:org_primary).enable_feature(FeatureName::LANGUAGE_SETTINGS)
    assert_permission_denied do
      get :index
    end
    current_user_is :f_student
    assert_permission_denied do
      get :index
    end
  end

  def test_index_admin_permission_needed
    current_member_is :f_admin

    assert_permission_denied do
      get :index
    end

    programs(:org_primary).enable_feature(FeatureName::LANGUAGE_SETTINGS)
    get :index, params: { locale: :de}
    assert_response :success
    assert_equal [programs(:org_primary).id] + programs(:org_primary).programs.ordered.pluck(:id), assigns(:progs).collect(&:id)

    current_user_is :f_admin
    get :index, params: { locale: :de}
    assert_response :success
    assert_equal [programs(:org_primary).id] + programs(:org_primary).programs.ordered.pluck(:id), assigns(:progs).collect(&:id)
  end

  def test_index_mentor_permission_needed_ajax
    current_member_is :f_mentor
    assert_permission_denied do
      get :show_category_content, xhr: true
    end
    programs(:org_primary).enable_feature(FeatureName::LANGUAGE_SETTINGS)
    assert_permission_denied do
      get :show_category_content, xhr: true
    end

    current_user_is :f_mentor
    assert_permission_denied do
      get :show_category_content, xhr: true
    end
  end

  def test_index_student_permission_needed_ajax
    current_member_is :f_student
    assert_permission_denied do
      get :index, xhr: true
    end
    programs(:org_primary).enable_feature(FeatureName::LANGUAGE_SETTINGS)
    assert_permission_denied do
      get :index, xhr: true
    end

    current_user_is :f_student
    assert_permission_denied do
      get :index, xhr: true
    end
  end

  def test_index_admin_permission_needed_ajax
    current_member_is :f_admin

    assert_permission_denied do
      get :index
    end
    programs(:org_primary).enable_feature(FeatureName::LANGUAGE_SETTINGS)
    get :index, xhr: true, params: { locale: :de}
    assert_response :success

    current_user_is :f_admin
    get :index, xhr: true, params: { locale: :de}
    assert_response :success
  end

  def test_get_second_locale
    org = programs(:org_primary)
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_user_is :f_admin
    get :index, params: { locale: :de}
    assert_equal :de, assigns(:second_locale)
    assert_equal [programs(:org_primary).id] + programs(:org_primary).programs.ordered.pluck(:id), assigns(:progs).collect(&:id)
  end

  def test_index
    org = programs(:org_primary)
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    get :index, params: { locale: :de, examined_object: ["Page", 1]}
    showed_obj = org.pages.first
    assert_equal :de, assigns(:second_locale)
    assert_equal org, assigns(:level_obj)
    assert_equal LocalizableContent::OVERVIEW_PAGES, assigns[:category]
    assert_equal showed_obj.id, assigns(:base_id)

    assert_equal LocalizableContent::OVERVIEW_PAGES, assigns(:category)
    assert_equal org.pages.collect{|p| {:id => p.id, :heading => p.title}}.map{|a| a[:id]}, assigns(:category_with_items).map{|a| a[:id]}
    assert_equal org.pages.collect{|p| {:id => p.id, :heading => p.title}}.map{|a| a[:heading]}, assigns(:category_with_items).map{|a| a[:heading]}

    showed_obj_trans_content = [[{:category => LocalizableContent::OVERVIEW_PAGES, :id => showed_obj.id, :klass => showed_obj.class.to_s, :attribute => :title, :higher_hierarchy => [[showed_obj.class.to_s, showed_obj.id]], :en => showed_obj.title, :de => showed_obj.globalize.send(:fetch_attribute, :de, :title)}]]

    assert_equal_hash showed_obj_trans_content.first.first, assigns(:translatable_content).first.first
    assert_equal assigns(:examined_object), {:klass => Page, :id => 1}
  end

  def test_get_second_locale
    org = programs(:org_primary)
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_user_is :f_admin
    get :index, params: { locale: :de}
    assert_equal :de, assigns(:second_locale)
    assert_equal [programs(:org_primary).id] + programs(:org_primary).programs.ordered.pluck(:id), assigns(:progs).collect(&:id)
  end

  def test_get_import_errors
    org = programs(:org_primary)
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_user_is :f_admin
    get :index, params: { import_id: 1}
  end

  def test_index
    org = programs(:org_primary)
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    get :index, params: { locale: :de, examined_object: ["Page", 1]}
    showed_obj = org.pages.first
    assert_equal :de, assigns(:second_locale)
    assert_equal org, assigns(:level_obj)
    assert_equal LocalizableContent::OVERVIEW_PAGES, assigns[:category]
    assert_equal showed_obj.id, assigns(:base_id)

    assert_equal LocalizableContent::OVERVIEW_PAGES, assigns(:category)
    assert_equal org.pages.collect{|p| {:id => p.id, :heading => p.title}}.map{|a| a[:id]}, assigns(:category_with_items).map{|a| a[:id]}
    assert_equal org.pages.collect{|p| {:id => p.id, :heading => p.title}}.map{|a| a[:heading]}, assigns(:category_with_items).map{|a| a[:heading]}

    showed_obj_trans_content = [[{:category => LocalizableContent::OVERVIEW_PAGES, :id => showed_obj.id, :klass => showed_obj.class.to_s, :attribute => :title, :higher_hierarchy => [[showed_obj.class.to_s, showed_obj.id]], :en => showed_obj.title, :de => showed_obj.globalize.send(:fetch_attribute, :de, :title)}]]

    assert_equal_hash showed_obj_trans_content.first.first, assigns(:translatable_content).first.first
    assert_equal assigns(:examined_object), {:klass => Page, :id => 1}
  end

  def test_index_with_incorrect_examined_object
    org = programs(:org_primary)
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    assert_raise Authorization::PermissionDenied, "Tried to constantize unsafe string SolutionPack" do
      get :index, params: { locale: :de, examined_object: ["SolutionPack", 1]}
    end
  end

  def test_export_csv_mentor_permission_needed
    current_member_is :f_mentor
    assert_permission_denied do
      get :export_csv
    end
    current_user_is :f_mentor
    assert_permission_denied do
      get :export_csv
    end

    programs(:org_primary).enable_feature(FeatureName::LANGUAGE_SETTINGS)
    assert_permission_denied do
      get :export_csv
    end
    current_user_is :f_mentor
    assert_permission_denied do
      get :export_csv
    end
  end

  def test_export_csv_student_permission_needed
    current_member_is :f_student
    assert_permission_denied do
      get :export_csv
    end
    current_user_is :f_student
    assert_permission_denied do
      get :export_csv
    end
    programs(:org_primary).enable_feature(FeatureName::LANGUAGE_SETTINGS)
    assert_permission_denied do
      get :export_csv
    end
    current_user_is :f_student
    assert_permission_denied do
      get :export_csv
    end
  end

  def test_export_csv_admin_permission_needed
    current_member_is :f_admin
    assert_permission_denied do
      get :export_csv
    end
    programs(:org_primary).enable_feature(FeatureName::LANGUAGE_SETTINGS)
    get :export_csv
    assert_redirected_to translations_path

    current_user_is :f_admin
    get :export_csv
    assert_redirected_to translations_path
    
    login_as_super_user
    current_member_is :f_admin
    get :export_csv
    assert_response :success

    current_user_is :f_admin
    get :export_csv
    assert_response :success
  end

  def test_export_csv_level_obj
    login_as_super_user
    current_member_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::LANGUAGE_SETTINGS)
    get :export_csv
    assert_response :success
    assert_equal programs(:org_primary), assigns(:level_obj)

    current_user_is :f_admin
    get :export_csv
    assert_response :success
    assert_equal programs(:org_primary).programs.first, assigns(:level_obj)
  end

  def test_export_csv_params
    org = programs(:org_primary)
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    login_as_super_user
    current_member_is :f_admin
    get :export_csv, params: { locale: :es}
    assert_response :success
    assert_equal :es, assigns(:second_locale)

    get :export_csv
    assert_response :success
    assert_equal :de, assigns(:second_locale)
  end

  def test_import_csv_non_admin_permission_needed
    programs(:org_primary).enable_feature(FeatureName::LANGUAGE_SETTINGS)

    current_member_is :f_mentor
    assert_permission_denied do
      post :import_csv
    end

    current_user_is :f_mentor
    assert_permission_denied do
      post :import_csv
    end
  end

  def test_import_csv_admin_permission_needed
    current_member_is :f_admin
    assert_permission_denied do
      post :import_csv
    end

    programs(:org_primary).enable_feature(FeatureName::LANGUAGE_SETTINGS)
    post :import_csv
    assert_redirected_to translations_path

    login_as_super_user
    post :import_csv
    assert_redirected_to translations_path

    current_user_is :f_admin
    post :import_csv
    assert_redirected_to translations_path
  end

  def test_import_csv_level_obj
    organization = programs(:org_primary)
    organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)

    current_member_is :f_admin
    login_as_super_user
    post :import_csv
    assert_redirected_to translations_path
    assert_equal organization, assigns(:level_obj)

    current_user_is :f_admin
    post :import_csv
    assert_redirected_to translations_path
    assert_equal organization.programs.first, assigns(:level_obj)
  end

  def test_import_csv_redirection
    organization = programs(:org_primary)
    organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)

    current_member_is :f_admin
    login_as_super_user
    post :import_csv, params: { user_csv: fixture_file_upload("/files/translation_import.csv", "text/csv") }
    assert_redirected_to translations_path

    organization.languages.where(id: 1).first.update_attributes!(title: "Canadian French", display_title: "French", enabled: true)
    post :import_csv, params: { user_csv: fixture_file_upload("/files/translation_import.csv", "text/csv") }
    assert_redirected_to translations_path(locale: :de)
  end

  def test_show_category_content
    org = programs(:org_primary) #not standalone
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    showed_obj = org.pages.last
    get :show_category_content, xhr: true, params: { locale: :de, abstract_program_id: org.id, category: LocalizableContent::OVERVIEW_PAGES, id: showed_obj.id}
    assert_equal :de, assigns(:second_locale)
    assert_equal org, assigns(:level_obj)
    assert_equal LocalizableContent::OVERVIEW_PAGES, assigns[:category]
    assert_equal showed_obj.id, assigns(:base_id)

    showed_obj_trans_content = [[{"category"=>LocalizableContent::OVERVIEW_PAGES, "id"=>showed_obj.id, "klass"=>showed_obj.class.to_s, "attribute"=>:title, "higher_hierarchy"=>[[showed_obj.class.to_s, showed_obj.id]], "en"=> showed_obj.title, :de=> showed_obj.globalize.send(:fetch_attribute, :de, :title)}]]

    assert_equal_hash showed_obj_trans_content.first.first, assigns(:translatable_content).first.first
  end

  def test_show_category_content_program_settings_terminology_tab
    org = programs(:org_primary) #not standalone
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    get :show_category_content, xhr: true, params: { abstract_program_id: org.id, category: LocalizableContent::PROGRAM_SETTINGS, id: ProgramsController::SettingsTabs::TERMINOLOGY}
    assert_equal :de, assigns(:second_locale)
    assert_equal org, assigns(:level_obj)
    assert_equal LocalizableContent::PROGRAM_SETTINGS, assigns[:category]
    assert_equal ProgramsController::SettingsTabs::TERMINOLOGY, assigns(:base_id)
    showed_obj_trans_content = assigns(:translatable_content)
    org.get_terms_for_view.each do |showed_obj|
      object = showed_obj_trans_content.shift
      LocalizableContent.attributes_for_model(category: LocalizableContent::PROGRAM_SETTINGS, tab: ProgramsController::SettingsTabs::TERMINOLOGY)[showed_obj.class].each do |attribute|
        a = {:category => LocalizableContent::PROGRAM_SETTINGS, :id => showed_obj.id, :klass => showed_obj.class.to_s, :attribute => attribute, :higher_hierarchy =>[[org.class.to_s, org.id],[showed_obj.class.to_s, showed_obj.id]], :en => showed_obj[attribute], :de => showed_obj.globalize.send(:fetch_attribute, :de, attribute)}
        assert_equal a, object.shift
      end
    end
  end

  def test_show_category_content_program_settings_engagement_tab
    org = programs(:albers) #not standalone
    org.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_user_is :f_admin
    get :show_category_content, xhr: true, params: { abstract_program_id: org.id, category: LocalizableContent::PROGRAM_SETTINGS, id: ProgramsController::SettingsTabs::CONNECTION}
    assert_equal :de, assigns(:second_locale)
    assert_equal org, assigns(:level_obj)
    assert_equal LocalizableContent::PROGRAM_SETTINGS, assigns[:category]
    assert_equal ProgramsController::SettingsTabs::CONNECTION, assigns(:base_id)
    showed_obj_trans_content = assigns(:translatable_content)
    org.group_closure_reasons.each do |showed_obj|
      object = showed_obj_trans_content.shift
      LocalizableContent.attributes_for_model(category: LocalizableContent::PROGRAM_SETTINGS, tab: ProgramsController::SettingsTabs::CONNECTION)[showed_obj.class].each do |attribute|
        a = {:category => LocalizableContent::PROGRAM_SETTINGS, :id =>  showed_obj.id, :klass => showed_obj.class.to_s, :attribute =>  attribute, :higher_hierarchy => [[org.class.to_s, org.id],[showed_obj.class.to_s, showed_obj.id]], :en => showed_obj[attribute], :de => showed_obj.globalize.send(:fetch_attribute, :de, attribute)}
        assert_equal a, object.shift
      end
    end
  end

  def test_show_category_content_program_settings_membership_tab
    org = programs(:albers) #not standalone
    org.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_user_is :f_admin
    get :show_category_content, xhr: true, params: { abstract_program_id: org.id, category: LocalizableContent::PROGRAM_SETTINGS, id: ProgramsController::SettingsTabs::MEMBERSHIP}
    assert_equal :de, assigns(:second_locale)
    assert_equal org, assigns(:level_obj)
    assert_equal LocalizableContent::PROGRAM_SETTINGS, assigns[:category]
    assert_equal ProgramsController::SettingsTabs::MEMBERSHIP, assigns(:base_id)
    showed_obj_trans_content = assigns(:translatable_content)
    org.roles_without_admin_role.each do |showed_obj|
      object = showed_obj_trans_content.shift
      LocalizableContent.attributes_for_model(category: LocalizableContent::PROGRAM_SETTINGS, tab: ProgramsController::SettingsTabs::MEMBERSHIP)[showed_obj.class].each do |attribute|
        a = {:category => LocalizableContent::PROGRAM_SETTINGS, :id => showed_obj.id, :klass => showed_obj.class.to_s, :attribute => attribute, :higher_hierarchy =>[[org.class.to_s, org.id],[showed_obj.class.to_s, showed_obj.id]], :en => showed_obj[attribute], :de => showed_obj.globalize.send(:fetch_attribute, :de, attribute)} unless attribute == :name
        a = {:klass => showed_obj.class.to_s, :id => showed_obj.id, :en => showed_obj.customized_term.term, :for_heading => true} if attribute == :name
        assert_equal a, object.shift
      end
    end
  end

  def test_show_category_content_program_settings_general_tab
    org = programs(:albers) #not standalone
    org.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_user_is :f_admin
    get :show_category_content, xhr: true, params: { abstract_program_id: org.id, category: LocalizableContent::PROGRAM_SETTINGS, id: ProgramsController::SettingsTabs::GENERAL}
    assert_equal :de, assigns(:second_locale)
    assert_equal org, assigns(:level_obj)
    assert_equal LocalizableContent::PROGRAM_SETTINGS, assigns[:category]
    assert_equal ProgramsController::SettingsTabs::GENERAL, assigns(:base_id)
    object = assigns(:translatable_content).first
    LocalizableContent.attributes_for_model(category: LocalizableContent::PROGRAM_SETTINGS, tab: ProgramsController::SettingsTabs::GENERAL)[org.class].each do |attribute|
      a = {:category => LocalizableContent::PROGRAM_SETTINGS, :id => org.id, :klass => org.class.to_s, :attribute => attribute, :higher_hierarchy => [[org.class.to_s, org.id]], :en => org[attribute], :de => org.globalize.send(:fetch_attribute, :de, attribute)}
      assert_equal a, object.shift
    end
  end

  def test_show_category_content_program_settings_general_tab_at_org_level
    org = programs(:org_primary) #not standalone
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    org.update_attributes!(agreement: "Eng agreement", privacy_policy: "Eng privacy_policy", :browser_warning => "Eng browser_warning")
    current_member_is :f_admin
    get :show_category_content, xhr: true, params: { abstract_program_id: org.id, category: LocalizableContent::PROGRAM_SETTINGS, id: ProgramsController::SettingsTabs::GENERAL}
    assert_equal :de, assigns(:second_locale)
    assert_equal org, assigns(:level_obj)
    assert_equal LocalizableContent::PROGRAM_SETTINGS, assigns[:category]
    assert_equal ProgramsController::SettingsTabs::GENERAL, assigns(:base_id)
    object = assigns(:translatable_content).first
    attributes_by_model = LocalizableContent.attributes_for_model(category: LocalizableContent::PROGRAM_SETTINGS, tab: ProgramsController::SettingsTabs::GENERAL)
    attributes_by_model[AbstractProgram].each do |attribute|
      a = {:category => LocalizableContent::PROGRAM_SETTINGS, :id => org.id, :klass => org.class.to_s, :attribute => attribute, :higher_hierarchy => [[org.class.to_s, org.id]], :en => org[attribute], :de => org.globalize.send(:fetch_attribute, :de, attribute)}
      assert_equal a, object.shift
    end

    object = assigns(:translatable_content)[1..3].flatten
    attributes_by_model[org.class].each do |attribute|
      a = {:category => LocalizableContent::PROGRAM_SETTINGS, :id => org.id, :klass => org.class.to_s, :attribute => attribute, :higher_hierarchy => [[org.class.to_s, org.id]], :en => org[attribute], :de => org.globalize.send(:fetch_attribute, :de, attribute), :heading => "program_settings_strings.header.#{LocalizableContent::organization_attributes_translations[attribute]}".translate}
      assert_equal a, object.shift
    end
  end

  def test_show_category_content_program_settings_general_tab_for_standalone
    org = programs(:org_foster)
    prog = org.programs.first
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    org.update_attributes!(agreement: "Eng agreement", privacy_policy: "Eng privacy_policy", :browser_warning => "Eng browser_warning")
    current_member_is :foster_admin
    create_organization_language( {:organization => org, :enabled => true, :language => languages(:hindi)})
    get :show_category_content, xhr: true, params: { abstract_program_id: org.id, category: LocalizableContent::PROGRAM_SETTINGS, id: ProgramsController::SettingsTabs::GENERAL}
    assert_equal :de, assigns(:second_locale)
    assert_equal org, assigns(:level_obj)
    assert_equal LocalizableContent::PROGRAM_SETTINGS, assigns[:category]
    assert_equal ProgramsController::SettingsTabs::GENERAL, assigns(:base_id)
    object = assigns(:translatable_content).first
    attributes_by_model = LocalizableContent.attributes_for_model(category: LocalizableContent::PROGRAM_SETTINGS, tab: ProgramsController::SettingsTabs::GENERAL)
    attributes_by_model[prog.class].each do |attribute|
      a = {:category => LocalizableContent::PROGRAM_SETTINGS, :id => prog.id, :klass => prog.class.to_s, :attribute => attribute, :higher_hierarchy => [[prog.class.to_s, prog.id]], :en => prog[attribute], :de => prog.globalize.send(:fetch_attribute, :de, attribute)}
      assert_equal a, object.shift
    end
    object = assigns(:translatable_content)[1..3].flatten
    attributes_by_model[org.class].each do |attribute|
      a = {:category => LocalizableContent::PROGRAM_SETTINGS, :id => org.id, :klass => org.class.to_s, :attribute => attribute, :higher_hierarchy => [[org.class.to_s, org.id]], :en => org[attribute], :de => org.globalize.send(:fetch_attribute, :de, attribute), :heading => "program_settings_strings.header.#{LocalizableContent::organization_attributes_translations[attribute]}".translate}
      assert_equal a, object.shift
    end
  end

  def test_show_category_content_program_settings_matching_tab
    prog = programs(:albers) #not standalone
    prog.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_user_is :f_admin
    get :show_category_content, xhr: true, params: { abstract_program_id: prog, category: LocalizableContent::PROGRAM_SETTINGS, id: ProgramsController::SettingsTabs::MATCHING}
    assert_equal :de, assigns(:second_locale)
    assert_equal prog, assigns(:level_obj)
    assert_equal LocalizableContent::PROGRAM_SETTINGS, assigns[:category]
    assert_equal ProgramsController::SettingsTabs::MATCHING, assigns(:base_id)
    object = assigns(:translatable_content).first
    LocalizableContent.attributes_for_model(category: LocalizableContent::PROGRAM_SETTINGS, tab: ProgramsController::SettingsTabs::MATCHING)[prog.class].each do |attribute|
      a = {:category => LocalizableContent::PROGRAM_SETTINGS, :id => prog.id, :klass => prog.class.to_s, :attribute => attribute, :higher_hierarchy => [[prog.class.to_s, prog.id]], :en => prog[attribute], :de => prog.globalize.send(:fetch_attribute, :de, attribute)}
      assert_equal a, object.shift
    end
  end

  def test_find_object_to_update_program_settings_general_tab
    org = programs(:org_primary) #not standalone
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    prev_title = org.name
    TranslationsController.any_instance.expects(:expire_fragment).times(18)
    #2(stylesheets ) + 6(programs)*3(locales)
    put :update, xhr: true, params: { locale: :de, id: ProgramsController::SettingsTabs::GENERAL, value: "test title", abstract_program_id: org.id, category: LocalizableContent::PROGRAM_SETTINGS, object: {id: org.id, attribute: :name, higher_hierarchy: [[org.class.to_s, org.id]]}.to_json}
    assert_response :success
    assert_equal :de, assigns(:second_locale)
    assert_equal org, assigns(:level_obj)
    assert_equal LocalizableContent::PROGRAM_SETTINGS, assigns[:category]
    assert_equal ProgramsController::SettingsTabs::GENERAL, assigns(:base_id)
    assert_equal "test title", org.reload.translations.find_by(locale: :de)[:name]
    assert_not_equal "test title", org.translations.find_by(locale: :en)[:name]
    assert_equal prev_title, org.translations.find_by(locale: :en)[:name]
    (LocalizableContent.all - [LocalizableContent::PROGRAM_SETTINGS]).each do |category|
      assert_nil assigns(:category_with_items)[category]
    end
    category_details = {:sub_heading => [{:id => 0, :heading => "General Settings", :score => [1, 3]}, {:id => 1, :heading => "Terminology", :score => [0, 6]}], :score => [1, 9]}
    assert_equal category_details, assigns(:category_with_items)[LocalizableContent::PROGRAM_SETTINGS]
  end

  def test_find_object_to_update_agreement_program_settings_general_tab
    org = programs(:org_primary) #not standalone
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    org.update_attributes!(agreement: "prev agreement")
    prev_agreement = org.agreement
    post :update_content, params: { locale: :de, id: ProgramsController::SettingsTabs::GENERAL, abstract_program_id: org.id, category: LocalizableContent::PROGRAM_SETTINGS, object: {id: org.id, attribute: :agreement, higher_hierarchy: [[org.class.to_s, org.id]]}.to_json, object_content: "test agreement"}
    assert_equal :de, assigns(:second_locale)
    assert_equal org, assigns(:level_obj)
    assert_equal LocalizableContent::PROGRAM_SETTINGS, assigns[:category]
    assert_equal ProgramsController::SettingsTabs::GENERAL, assigns(:base_id)
    assert_equal "test agreement", org.reload.translations.find_by(locale: :de)[:agreement]
    assert_not_equal "test title", org.translations.find_by(locale: :en)[:agreement]
    assert_equal prev_agreement, org.translations.find_by(locale: :en)[:agreement]
  end

  def test_find_object_to_update_browser_warning_program_settings_general_tab
    org = programs(:org_primary) #not standalone
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    org.update_attributes!(browser_warning: "prev browser_warning")
    prev_browser_warning = org.browser_warning
    post :update_content, params: { locale: :de, id: ProgramsController::SettingsTabs::GENERAL, abstract_program_id: org.id, category: LocalizableContent::PROGRAM_SETTINGS, object: {id: org.id, attribute: :browser_warning, higher_hierarchy: [[org.class.to_s, org.id]]}.to_json, object_content: "test browser_warning"}
    assert_equal :de, assigns(:second_locale)
    assert_equal org, assigns(:level_obj)
    assert_equal LocalizableContent::PROGRAM_SETTINGS, assigns[:category]
    assert_equal ProgramsController::SettingsTabs::GENERAL, assigns(:base_id)
    assert_equal "test browser_warning", org.reload.translations.find_by(locale: :de)[:browser_warning]
    assert_not_equal "test title", org.translations.find_by(locale: :en)[:browser_warning]
    assert_equal prev_browser_warning, org.translations.find_by(locale: :en)[:browser_warning]
  end

  def test_find_object_to_update_program_settings_general_tab_program
    prog = programs(:albers) #not standalone
    prog.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    prog.update_attribute(:zero_match_score_message, "apple")
    current_user_is :f_admin
    prev_title = prog.name
    TranslationsController.any_instance.expects(:expire_fragment).times(3)
    put :update, xhr: true, params: { locale: :de, id: ProgramsController::SettingsTabs::GENERAL, value: "test title", abstract_program_id: prog.id, category: LocalizableContent::PROGRAM_SETTINGS, object: {id: prog.id, attribute: :name, higher_hierarchy: [[prog.class.to_s, prog.id]]}.to_json}
    assert_response :success
    assert_equal :de, assigns(:second_locale)
    assert_equal prog, assigns(:level_obj)
    assert_equal LocalizableContent::PROGRAM_SETTINGS, assigns[:category]
    assert_equal ProgramsController::SettingsTabs::GENERAL, assigns(:base_id)
    assert_equal "test title", prog.reload.translations.find_by(locale: :de)[:name]
    assert_not_equal "test title", prog.translations.find_by(locale: :en)[:name]
    assert_equal prev_title, prog.translations.find_by(locale: :en)[:name]
    (LocalizableContent.all - [LocalizableContent::PROGRAM_SETTINGS]).each do |category|
      assert_nil assigns(:category_with_items)[category]
    end
    # CD-125 CareerDev Test Falling as key for french is not availble uncomment it once the key is there
    # category_details = {"sub_heading"=>[{"id"=>0, "heading"=>"General Settings", "score"=>[1, 2]}, {"id"=>1, "heading"=>"Terminology", "score"=>[0, 24]}, {"id"=>2, "heading"=>"Membership", "score"=>[2, 2]}, {"id"=>8, "heading"=>"Matching Settings", "score"=>[1, 1]}], "score"=>[4, 29]}
    # assert_equal category_details, assigns(:category_with_items)[LocalizableContent::PROGRAM_SETTINGS]
  end

  def test_find_object_to_update_program_settings_engagement_tab
    program = programs(:albers) #not standalone
    program.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_user_is :f_admin
    closure_reason = program.group_closure_reasons.first
    prev = closure_reason.reason
    put :update, xhr: true, params: { locale: :de, id: ProgramsController::SettingsTabs::CONNECTION, value: "test reason", abstract_program_id: program.id, category: LocalizableContent::PROGRAM_SETTINGS, object: {id: closure_reason.id, attribute: :reason, higher_hierarchy: [[program.class.to_s, program.id], [closure_reason.class.to_s, closure_reason.id]]}.to_json}
    assert_response :success
    assert_equal :de, assigns(:second_locale)
    assert_equal program, assigns(:level_obj)
    assert_equal LocalizableContent::PROGRAM_SETTINGS, assigns[:category]
    assert_equal ProgramsController::SettingsTabs::CONNECTION, assigns(:base_id)
    assert_equal "test reason", closure_reason.reload.translations.find_by(locale: :de)[:reason]
    assert_not_equal "test reason", closure_reason.translations.find_by(locale: :en)[:reason]
    assert_equal prev, closure_reason.translations.find_by(locale: :en)[:reason]
  end

  def test_find_object_to_update_program_settings_terminology_tab
    program = programs(:albers) #not standalone
    program.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_user_is :f_admin
    term = program.get_terms_for_view.first
    prev = term.pluralized_term
    put :update, xhr: true, params: { locale: :de, id: ProgramsController::SettingsTabs::TERMINOLOGY, value: "TEst plural term in hindi", abstract_program_id: program.id, category: LocalizableContent::PROGRAM_SETTINGS, object: {id: term.id, attribute: :pluralized_term, higher_hierarchy: [[program.class.to_s, program.id], [term.class.to_s, term.id]]}.to_json}
    assert_response :success
    assert_equal :de, assigns(:second_locale)
    assert_equal program, assigns(:level_obj)
    assert_equal LocalizableContent::PROGRAM_SETTINGS, assigns[:category]
    assert_equal ProgramsController::SettingsTabs::TERMINOLOGY, assigns(:base_id)
    assert_equal "TEst plural term in hindi", term.reload.translations.find_by(locale: :de)[:pluralized_term]
    assert_equal "test plural term in hindi", term.reload.translations.find_by(locale: :de)[:pluralized_term_downcase]
    assert_not_equal "TEst plural term in hindi", term.translations.find_by(locale: :en)[:pluralized_term]
    assert_equal prev, term.translations.find_by(locale: :en)[:pluralized_term]
  end

  def test_find_object_to_update_program_settings_role_description_edit_content_error
    program = programs(:albers) #not standalone
    program.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_user_is :f_admin
    role = program.roles_without_admin_role.first
    assert_raise RuntimeError do
      get :edit_content, params: { id: ProgramsController::SettingsTabs::MEMBERSHIP , abstract_program_id: program.id, category: LocalizableContent::PROGRAM_SETTINGS, object: {id: role.id, attribute: :name, higher_hierarchy: [[program.class.to_s, program.id], [role.class.to_s, role.id]]}.to_json}
    end
  end

  def test_find_object_to_update_program_settings_role_description_edit_content
    program = programs(:albers) #not standalone
    program.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_user_is :f_admin
    role = program.roles_without_admin_role.first
    get :edit_content, params: { id: ProgramsController::SettingsTabs::MEMBERSHIP , abstract_program_id: program.id, category: LocalizableContent::PROGRAM_SETTINGS, object: {id: role.id, attribute: :description, higher_hierarchy: [[program.class.to_s, program.id], [role.class.to_s, role.id]]}.to_json}
    assert_response :success
    assert_equal :de, assigns(:second_locale)
    assert_equal program, assigns(:level_obj)
    assert_equal LocalizableContent::PROGRAM_SETTINGS, assigns[:category]
    assert_equal ProgramsController::SettingsTabs::MEMBERSHIP, assigns(:base_id)

    showed_obj_trans_content = {:category => LocalizableContent::PROGRAM_SETTINGS, :id => role.id, :klass => role.class.to_s, :attribute => "description", :higher_hierarchy => [[program.class.to_s, program.id], [role.class.to_s, role.id]], :en => role.description, :de => role.globalize.send(:fetch_attribute, :de, :description), :heading => role.name, :ckeditor_type => LocalizableContent.ckeditor_type[Role][:description]}

    showed_obj_trans_content.keys.each do |key|
      assert_equal showed_obj_trans_content[key], assigns(:object_details)[key]
    end
  end

  def test_show_category_content_wrong_hier
    org = programs(:org_primary) #not standalone
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    showed_obj = org.pages.last
    assert_raise NoMethodError do
      get :show_category_content, xhr: true, params: { abstract_program_id: org.programs.first.id, category: LocalizableContent::OVERVIEW_PAGES, id: showed_obj.id}
    end
  end

  def test_show_category_content_for_profile
    org = programs(:org_primary) #not standalone
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    showed_obj = org.sections.first
    get :show_category_content, xhr: true, params: { locale: :de, abstract_program_id: org.id, category: LocalizableContent::USER_PROFILE, id: showed_obj.id}
    assert_equal :de, assigns(:second_locale)
    assert_equal org, assigns(:level_obj)
    assert_equal LocalizableContent::USER_PROFILE, assigns[:category]
    assert_equal showed_obj.id, assigns(:base_id)
    showed_obj_trans_content = []
    showed_obj_trans_content << [ { category: LocalizableContent::USER_PROFILE, id: showed_obj.id, klass: Section.name, attribute: :title, higher_hierarchy: [[Section.name, showed_obj.id]], en: "Basic Information", :de => nil },
      { category: LocalizableContent::USER_PROFILE, id: showed_obj.id, klass: Section.name, attribute: :description, higher_hierarchy: [[Section.name, showed_obj.id]], en: nil, :de => nil } ]
    assert_equal showed_obj_trans_content, assigns(:translatable_content)
  end

  def test_show_category_content_for_profile_question
    org = programs(:org_primary) #not standalone
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    showed_obj = org.profile_questions.where(question_type: [ProfileQuestion::Type::SINGLE_CHOICE, ProfileQuestion::Type::MULTI_CHOICE, ProfileQuestion::Type::RATING_SCALE, ProfileQuestion::Type::ORDERED_SINGLE_CHOICE, ProfileQuestion::Type::ORDERED_OPTIONS]).first
    get :show_category_content, xhr: true, params: { locale: :de, abstract_program_id: org.id, category: LocalizableContent::PROFILE_QUESTION, id: showed_obj.id}
    assert_equal :de, assigns(:second_locale)
    assert_equal org, assigns(:level_obj)
    assert_equal LocalizableContent::PROFILE_QUESTION, assigns[:category]
    assert_equal showed_obj.id, assigns(:base_id)
    showed_obj_trans_content = []
    showed_obj_trans_content << [{ category: LocalizableContent::PROFILE_QUESTION, id: showed_obj.id, klass: ProfileQuestion.name, attribute: :question_text, higher_hierarchy: [[ProfileQuestion.name, showed_obj.id]], en: "Gender", :de => nil }, {:category=>LocalizableContent::PROFILE_QUESTION, :id=>showed_obj.id, :klass=>ProfileQuestion.name, :attribute=>:help_text, :higher_hierarchy=>[[ProfileQuestion.name, showed_obj.id]], :en=>nil, :de=>nil}]
    
    showed_obj.question_choices.each do |choice|
      showed_obj_trans_content << [{:category => LocalizableContent::PROFILE_QUESTION, :id => choice.id, :klass => choice.class.to_s, :attribute => :text, :higher_hierarchy => [[showed_obj.class.to_s, showed_obj.id], [choice.class.to_s, choice.id]], :en => choice.text, :de => choice.globalize.send(:fetch_attribute, :de, :text)}]
    end

    assert_equal showed_obj_trans_content, assigns(:translatable_content)
  end

  def test_update_page
    org = programs(:org_primary) #not standalone
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    showed_obj = org.pages.last
    prev_title = showed_obj.title
    put :update, xhr: true, params: { id: showed_obj.id, locale: :de, value: "test title", abstract_program_id: org.id, category: LocalizableContent::OVERVIEW_PAGES, object: {id: showed_obj.id, attribute: :title, higher_hierarchy: [[showed_obj.class.to_s, showed_obj.id]]}.to_json}
    assert_response :success
    assert_equal :de, assigns(:second_locale)
    assert_equal org, assigns(:level_obj)
    assert_equal LocalizableContent::OVERVIEW_PAGES, assigns[:category]
    assert_equal showed_obj.id, assigns(:base_id)
    assert_equal "test title", showed_obj.reload.translations.find_by(locale: :de)[:title]
    assert_not_equal "test title", showed_obj.translations.find_by(locale: :en)[:title]
    assert_equal prev_title, showed_obj.translations.find_by(locale: :en)[:title]
    (LocalizableContent.all - [LocalizableContent::OVERVIEW_PAGES]).each do |category|
      assert_nil assigns(:category_with_items)[category]
    end
  end

  def test_update_hierarchy
    org = programs(:org_primary) #not standalone
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    profile_question = org.profile_questions.where(question_type: ProfileQuestion::Type.choice_based_types).first
    showed_obj = profile_question.question_choices.first
    prev_title = showed_obj.text
    org.programs.each do |prog|
      TranslationsController.any_instance.expects(:expire_user_filters).with(prog.id).once
    end
    put :update, xhr: true, params: { id: showed_obj.id, locale: :de, value: "how many nazguls are there?", abstract_program_id: org.id, category: LocalizableContent::PROFILE_QUESTION, object: {id: showed_obj.id, attribute: :text, higher_hierarchy: [[profile_question.class.to_s, profile_question.id], [showed_obj.class.to_s, showed_obj.id]]}.to_json}
    assert_response :success
    assert_equal :de, assigns(:second_locale)
    assert_equal org, assigns(:level_obj)
    assert_equal LocalizableContent::PROFILE_QUESTION, assigns[:category]
    assert_equal showed_obj.id, assigns(:base_id)
    assert_equal "how many nazguls are there?", showed_obj.reload.translations.find_by(locale: :de)[:text]
    assert_not_equal "how many nazguls are there?", showed_obj.translations.find_by(locale: :en)[:text]
    assert_equal prev_title, showed_obj.translations.find_by(locale: :en)[:text]
    (LocalizableContent.all - [LocalizableContent::PROFILE_QUESTION]).each do |category|
      assert_nil assigns(:category_with_items)[category]
    end
  end

  def test_update_section_and_expect_cache_clearing
    org = programs(:org_primary) #not standalone
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    section = org.sections.where(:default_field => false).first
    prev_title = section.title
    org.programs.each do |prog|
      TranslationsController.any_instance.expects(:expire_user_filters).with(prog.id).once
    end
    put :update, xhr: true, params: { id: section.id, locale: :de, value: "how many nazguls are there?", abstract_program_id: org.id, category: LocalizableContent::USER_PROFILE, object: {id: section.id, attribute: :title, higher_hierarchy: [[section.class.to_s, section.id]]}.to_json}
    assert_response :success
    assert_equal :de, assigns(:second_locale)
    assert_equal org, assigns(:level_obj)
    assert_equal LocalizableContent::USER_PROFILE, assigns[:category]
    assert_equal section.id, assigns(:base_id)
  end

  def test_should_update_with_empty_subject_campaign_mails
    prog = programs(:albers) #not standalone
    prog.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    campaign = prog.abstract_campaigns.first
    email = campaign.email_templates.first
    put :update, xhr: true, params: { locale: :de, id: email.id, value: "", abstract_program_id: prog.id, category: LocalizableContent::CAMPAIGN, object: {"id"=> email.id, "attribute"=>"subject", "higher_hierarchy"=>[["CampaignManagement::UserCampaign", campaign.id], ["Mailer::Template", email.id]]}.to_json}
    assert_response :success
    assert_equal :de, assigns(:second_locale)
    assert_nil email.reload.translations.find_by(locale: :de)[:subject]   
    assert_equal email.reload.translations.find_by(locale: :en)[:subject], email.subject
  end

  def test_update_of_other_attribute_should_raise_error
    org = programs(:org_primary) #not standalone
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    showed_obj = org.pages.last
    assert_raise RuntimeError do
      put :update, xhr: true, params: { id: showed_obj.id, value: org.programs.first.id, abstract_program_id: org.id, category: LocalizableContent::OVERVIEW_PAGES, object: {id: showed_obj.id, attribute: :program_id, higher_hierarchy: [[showed_obj.class.to_s, showed_obj.id]]}.to_json}
    end
  end

  def test_edit_content_page
    org = programs(:org_primary) #not standalone
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    showed_obj = org.pages.last
    get :edit_content, params: { id: showed_obj.id, locale: :de, abstract_program_id: org.id, category: LocalizableContent::OVERVIEW_PAGES, object: {id: showed_obj.id, attribute: :content, higher_hierarchy: [[showed_obj.class.to_s, showed_obj.id]]}.to_json}
    assert_response :success
    assert_equal :de, assigns(:second_locale)
    assert_equal org, assigns(:level_obj)
    assert_equal LocalizableContent::OVERVIEW_PAGES, assigns[:category]
    assert_equal showed_obj.id, assigns(:base_id)
    showed_obj_trans_content = {:category => LocalizableContent::OVERVIEW_PAGES, :id => showed_obj.id, :klass => showed_obj.class.to_s, :attribute =>  "content", :higher_hierarchy => [[showed_obj.class.to_s, showed_obj.id]], :en => showed_obj.content, :de=> showed_obj.globalize.send(:fetch_attribute, :de, :content), :heading => showed_obj.title, :ckeditor_type => LocalizableContent.ckeditor_type[Page][:content]}
    showed_obj_trans_content.keys.each do |key|
      assert_dynamic_expected_nil_or_equal showed_obj_trans_content[key], assigns(:object_details)[key]
    end
  end

  def test_edit_content_campaign
    prog = programs(:albers) #not standalone
    prog.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    campaign = prog.abstract_campaigns.first
    email = campaign.email_templates.first
    get :edit_content, params: { id: email.id, locale: :de ,abstract_program_id: prog.id, category: LocalizableContent::CAMPAIGN, object: {:id =>  email.id, :attribute => "source", :higher_hierarchy => [["CampaignManagement::UserCampaign", campaign.id], ["Mailer::Template", email.id]]}.to_json}
    assert_response :success
    assert_equal :de, assigns(:second_locale)
    assert_equal prog, assigns(:level_obj)
    assert_equal LocalizableContent::CAMPAIGN, assigns[:category]
    assert_equal email.id, assigns(:base_id)
    all_tags =  campaign.campaign_email_tags
    strinsert_for_campaign = fetch_placeholders(all_tags, prog)
    showed_obj_trans_content = {:category =>LocalizableContent::CAMPAIGN, :id =>email.id, :klass => email.class.to_s, :attribute => "source", :higher_hierarchy => [[campaign.class.to_s, campaign.id],[email.class.to_s, email.id]], :en => email.source, :de => email.globalize.send(:fetch_attribute, :de, :source), :heading => email.subject, :ckeditor_type => :dropdown, strinsert: strinsert_for_campaign, label: 'feature.campaigns.label.Insert_variable'.translate}
    showed_obj_trans_content.keys.each do |key|
      assert_dynamic_expected_nil_or_equal showed_obj_trans_content[key], assigns(:object_details)[key]
    end

    assert_not_equal LocalizableContent.ckeditor_type[Mailer::Template][:source], showed_obj_trans_content["ckeditor_type"]
  end

  def test_edit_content_mentoring_model_facilitaion_message
    prog = programs(:albers) #not standalone
    prog.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_user_is :f_admin
    mm = prog.mentoring_models.first
    fmt = facilitation_template = create_mentoring_model_facilitation_template(mentoring_model: mm, roles: prog.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]), message: "Please take a survey: ")

    get :edit_content, params: { id: fmt.id, abstract_program_id: prog.id, category: LocalizableContent::MENTORING_MODEL, object: {"id"=> fmt.id, "attribute"=>"message", "higher_hierarchy"=>[[mm.class.to_s, mm.id], [fmt.class.to_s, fmt.id]]}.to_json}
    assert_response :success
    assert_equal :de, assigns(:second_locale)
    assert_equal prog, assigns(:level_obj)
    assert_equal LocalizableContent::MENTORING_MODEL, assigns[:category]
    assert_equal fmt.id, assigns(:base_id)

    showed_obj_trans_content = {:category => LocalizableContent::MENTORING_MODEL, :id => fmt.id, :klass => fmt.class.to_s, :attribute => "message", :higher_hierarchy => [[mm.class.to_s, mm.id],[fmt.class.to_s, fmt.id]], :en => fmt.message, :de => fmt.globalize.send(:fetch_attribute, :de, :message), :heading  => fmt.subject, :ckeditor_type => :dropdown, strinsert: "[{\"value\":\"{{user_firstname}}\",\"name\":\"<b>User Firstname</b> <br />{{user_firstname}}\",\"label\":\"First name of recipient\"},{\"value\":\"{{user_lastname}}\",\"name\":\"<b>User Lastname</b> <br />{{user_lastname}}\",\"label\":\"Last name of recipient\"},{\"value\":\"{{user_name}}\",\"name\":\"<b>User Name</b> <br />{{user_name}}\",\"label\":\"Full name of recipient\"},{\"value\":\"{{user_email}}\",\"name\":\"<b>User Email</b> <br />{{user_email}}\",\"label\":\"Email of recipient\"},{\"value\":\"{{user_role}}\",\"name\":\"<b>User Role</b> <br />{{user_role}}\",\"label\":\"Role of recipient\"},{\"value\":\"{{program_name}}\",\"name\":\"<b>Program Name</b> <br />{{program_name}}\",\"label\":\"Name of the program\"},{\"value\":\"{{group_name}}\",\"name\":\"<b>Mentoring Connection Name</b> <br />{{group_name}}\",\"label\":\"Name of the mentoring connection\"},{\"value\":\"{{mentoring_area_button}}\",\"name\":\"<b>Mentoring Connection area button</b> <br />{{mentoring_area_button}}\",\"label\":\"Mentoring Connection button\"}]", label: "Insert Variables"}

    showed_obj_trans_content.keys.each do |key|
      assert_dynamic_expected_nil_or_equal showed_obj_trans_content[key], assigns(:object_details)[key]
    end
  end

  def test_edit_content_draft_announcement
    prog = programs(:albers) #not standalone
    prog.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_user_is :f_admin
    announ = Announcement.create!({:program => programs(:albers), :admin => users(:f_admin), :status => Announcement::Status::DRAFTED})

    get :edit_content, params: { id: announ.id, abstract_program_id: prog.id, category: LocalizableContent::ANNOUNCEMENT, object: {"id"=> announ.id, "attribute"=>"body", "higher_hierarchy"=>[[announ.class.to_s, announ.id]]}.to_json}
    assert_response :success
    assert_equal :de, assigns(:second_locale)
    assert_equal prog, assigns(:level_obj)
    assert_equal LocalizableContent::ANNOUNCEMENT, assigns(:category)
    assert_equal announ.id, assigns(:base_id)
    showed_obj_trans_content = {:category => LocalizableContent::ANNOUNCEMENT, :id => announ.id, :klass => announ.class.to_s, :attribute => "body", :higher_hierarchy => [[announ.class.to_s, announ.id]], :en => announ.body, :de => announ.globalize.send(:fetch_attribute, :de, :body), :heading => "(No title)", :ckeditor_type => :default}
    assert response.body.match /English version/
    showed_obj_trans_content.keys.each do |key|
      assert_dynamic_expected_nil_or_equal showed_obj_trans_content[key], assigns(:object_details)[key]
    end
  end

  def test_edit_content_published_announcement_should_not_send_mail
    prog = programs(:albers) #not standalone
    prog.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_user_is :f_admin
    announ = create_announcement(email_notification: UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE, recipient_role_names: RoleConstants::MENTOR_NAME)
    Announcement.expects(:delay).never
    Push::Base.expects(:delay).never

    get :edit_content, params: { id: announ.id, abstract_program_id: prog.id, category: LocalizableContent::ANNOUNCEMENT, object: {"id"=> announ.id, "attribute"=>"body", "higher_hierarchy"=>[[announ.class.to_s, announ.id]]}.to_json}
    assert_response :success
    assert_equal :de, assigns(:second_locale)
    assert_equal prog, assigns(:level_obj)
    assert_equal LocalizableContent::ANNOUNCEMENT, assigns(:category)
    assert_equal announ.id, assigns(:base_id)
    showed_obj_trans_content = {:category => LocalizableContent::ANNOUNCEMENT, :id => announ.id, :klass => announ.class.to_s, :attribute => "body", :higher_hierarchy => [[announ.class.to_s, announ.id]], :en => announ.body, :de => announ.globalize.send(:fetch_attribute, :de, :body), :heading => "Hello", :ckeditor_type => :default}
    assert response.body.match /English version/
    showed_obj_trans_content.keys.each do |key|
      assert_dynamic_expected_nil_or_equal showed_obj_trans_content[key], assigns(:object_details)[key]
    end
  end

  def test_add_language_flash
    org = programs(:org_primary) #not standalone
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    org.languages.destroy_all
    get :index
    assert_equal "There are no languges added in the system yet, Kindly add to proceed.", flash[:notice]
    assert_redirected_to organization_languages_path
  end

  def test_standalone_org
    org = programs(:org_foster)
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    org.update_attributes!(privacy_policy: "Eng privacy_policy", agreement: "Eng agreement", browser_warning: "Eng browser_warning")
    current_member_is :foster_admin
    create_organization_language( {:organization => org, :enabled => true, :language => languages(:hindi)})
    get :index
    showed_obj = org.programs.first.abstract_campaigns.first
    assert_equal :de, assigns(:second_locale)
    assert_equal org, assigns(:level_obj)
    assert_equal [org.id], assigns(:progs).collect(&:id)
    assert_equal LocalizableContent::CAMPAIGN, assigns[:category]
    assert_equal showed_obj.id, assigns(:base_id)

    category_with_scores = {
      LocalizableContent::CAMPAIGN => org.programs.first.abstract_campaigns.collect{|p| [0, hier_count(p, :email_templates, LocalizableContent::CAMPAIGN)]}.transpose.map{|a| a.sum},
      LocalizableContent::INSTRUCTION => org.programs.first.abstract_instructions.collect { |p| [1, LocalizableContent.attributes_for_model(category: LocalizableContent::INSTRUCTION, tab: nil)[p.class].count]}.transpose.map{|a| a.sum},
      LocalizableContent::OVERVIEW_PAGES=> (org.pages + org.programs.first.pages).collect{|p| [0, LocalizableContent.attributes_for_model(category: LocalizableContent::OVERVIEW_PAGES, tab: nil)[p.class].count]}.transpose.map{|a| a.sum},
      LocalizableContent::PROGRAM_SETTINGS => [
        [0, LocalizableContent.attributes_for_model(category: LocalizableContent::PROGRAM_SETTINGS, tab: ProgramsController::SettingsTabs::GENERAL)[AbstractProgram].count + LocalizableContent.attributes_for_model(category: LocalizableContent::PROGRAM_SETTINGS, tab: ProgramsController::SettingsTabs::GENERAL)[Organization].count],
        [0, org.get_terms_for_view.count*LocalizableContent.attributes_for_model(category: LocalizableContent::PROGRAM_SETTINGS, tab: ProgramsController::SettingsTabs::TERMINOLOGY)[CustomizedTerm].count],
        [2, 2],
        [1, 1]
        ].transpose.map{|a| a.sum},
      LocalizableContent::RESOURCES => (org.resources + org.programs.first.resources).collect{|p| [0, LocalizableContent.attributes_for_model(category: LocalizableContent::RESOURCES, tab: nil)[p.class].count]}.transpose.map{|a| a.sum},
      LocalizableContent::SURVEY => org.programs.first.visible_surveys.collect{|p| [0, hier_count(p, nil, LocalizableContent::SURVEY)]}.transpose.map{|a| a.sum},
      LocalizableContent::SURVEY_QUESTION => org.programs.first.visible_surveys.collect(&:survey_questions).flatten.collect{|sq| [0, hier_count(sq, nil, LocalizableContent::SURVEY_QUESTION) + sq.default_question_choices.map{|qc| hier_count(qc, nil, LocalizableContent::SURVEY_QUESTION)}.sum]}.transpose.map{|a| a.sum},
      LocalizableContent::USER_PROFILE => org.sections.where("default_field IS NULL OR default_field = 0").collect{|p| [0, hier_count(p, nil, LocalizableContent::USER_PROFILE)]}.transpose.map{|a| a.sum},
      LocalizableContent::PROFILE_QUESTION => org.sections.where("default_field IS NULL OR default_field = 0").collect(&:profile_questions).flatten.collect{|pq| [0, hier_count(pq, nil, LocalizableContent::PROFILE_QUESTION) + pq.default_question_choices.map{|qc| hier_count(qc, nil, LocalizableContent::PROFILE_QUESTION)}.sum]}.transpose.map{|a| a.sum},
      LocalizableContent::PROGRAM_ASSET => [0, 0]
    }

    assigns(:category_with_scores).each do |category, score|
      assert_equal category_with_scores[category], score
    end

    showed_obj_trans_content = [[{"category"=>LocalizableContent::CAMPAIGN, "id"=>showed_obj.id, "klass"=>showed_obj.class.to_s, "attribute"=>:title, "higher_hierarchy"=>[[showed_obj.class.to_s, showed_obj.id]], "en"=> showed_obj.title, :de=> showed_obj.globalize.send(:fetch_attribute, :de, :title)}]]

    assert_equal_hash showed_obj_trans_content.first.first, assigns(:translatable_content).first.first
  end

  def test_update_content
    prog = programs(:albers) #not standalone
    prog.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    campaign = prog.abstract_campaigns.first
    email = campaign.email_templates.first
    post :update_content, params: { locale: :de, id: email.id, abstract_program_id: prog.id, category: LocalizableContent::CAMPAIGN, object: {:id =>  email.id, :attribute => "source", :higher_hierarchy => [["CampaignManagement::UserCampaign", campaign.id], ["Mailer::Template", email.id]]}.to_json, object_content: "harry hermoine ron neville"}
    assert_redirected_to translations_path(locale: :de, category: LocalizableContent::CAMPAIGN, abstract_program_id: prog.id, id: campaign.id, examined_object: ["Mailer::Template", email.id, "source"], rich_content_save: true)
    assert_nil flash[:error]
    assert_equal flash[:notice], "Your changes have been saved"
    assert_equal email.reload.translations.find_by(locale: :de)[:source], "harry hermoine ron neville"
  end

  def test_update_content_raise_error
    prog = programs(:albers) #not standalone
    prog.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    campaign = prog.abstract_campaigns.first
    email = campaign.email_templates.first
    assert_raise RuntimeError do
      post :update_content, params: { locale: :de, id: email.id, abstract_program_id: prog.id, category: LocalizableContent::CAMPAIGN, object: {"id"=> email.id, "attribute"=>"subject", "higher_hierarchy"=>[["CampaignManagement::UserCampaign", campaign.id], ["Mailer::Template", email.id]]}.to_json, object_content: "harry hermoine ron neville"}
    end
  end

  def test_update_content_should_accept_empty_content_for_campaign_mails
    prog = programs(:albers) #not standalone
    prog.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    campaign = prog.abstract_campaigns.first
    email = campaign.email_templates.first
    post :update_content, params: { locale: :de, id: email.id, abstract_program_id: prog.id, category: LocalizableContent::CAMPAIGN, object: {:id =>  email.id, :attribute => "source", :higher_hierarchy => [["CampaignManagement::UserCampaign", campaign.id], ["Mailer::Template", email.id]]}.to_json, object_content: ""}
    assert_redirected_to translations_path(locale: :de, category: LocalizableContent::CAMPAIGN, abstract_program_id: prog.id, id: campaign.id, examined_object: ["Mailer::Template", email.id, "source"], rich_content_save: true)
    assert_equal "Your changes have been saved", flash[:notice]
    assert_nil email.reload.translations.find_by(locale: :de).source
  end

  def test_standalone_survey_links_ckeditor
    current_user_is :foster_admin
    org = programs(:org_foster)
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    create_organization_language(:organization => org, :enabled => true, :language => languages(:hindi))
    org.programs.first.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    mm = org.programs.first.mentoring_models.first
    fm = create_mentoring_model_facilitation_template(mentoring_model_id: mm.id)

    get :edit_content, params: { id: fm.id, locale: :de, abstract_program_id: org.id, category: LocalizableContent::MENTORING_MODEL, object: {id: fm.id, attribute: :message, higher_hierarchy: [["MentoringModel", mm.id], ["MentoringModel::FacilitationTemplate", fm.id]]}.to_json}
    assert_response :success

    assert_equal :de, assigns(:second_locale)
    assert_equal org, assigns(:level_obj)
    assert_equal LocalizableContent::MENTORING_MODEL, assigns[:category]
    assert_equal fm.id, assigns(:base_id)
    survey_links = []
    org.programs.first.surveys.of_engagement_type.each do |survey|
      survey_links << {name: survey.name, value: "{{engagement_survey_link_#{survey.id}}}"}
    end

    showed_obj_trans_content = {"category"=>LocalizableContent::MENTORING_MODEL, "id"=>fm.id, "klass"=>fm.class.to_s, "attribute"=> "message", "higher_hierarchy"=>[[mm.class.to_s, mm.id],[fm.class.to_s, fm.id]], "en"=> fm.message, :de=> fm.message, "heading" => fm.subject, "ckeditor_type" => :facilitation_message, strinsert: survey_links.to_json, label: "feature.mentoring_model.button.new_engagement_survey".translate}
  end

  def test_edit_content_campaign_for_standalone
    current_user_is :foster_admin
    org = programs(:org_foster)
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    create_organization_language(:organization => org, :enabled => true, :language => languages(:hindi))
    prog = org.programs.first
    campaign = prog.abstract_campaigns.first
    email = campaign.email_templates.first
    get :edit_content, params: { id: email.id, locale: :de, abstract_program_id: prog.id, category: LocalizableContent::CAMPAIGN, object: {:id =>  email.id, :attribute => "source", :higher_hierarchy => [["CampaignManagement::UserCampaign", campaign.id], ["Mailer::Template", email.id]]}.to_json}
    assert_response :success
    assert_equal :de, assigns(:second_locale)
    assert_equal org, assigns(:level_obj)
    assert_equal LocalizableContent::CAMPAIGN, assigns[:category]
    assert_equal email.id, assigns(:base_id)
    all_tags =  campaign.campaign_email_tags
    strinsert_for_campaign = fetch_placeholders(all_tags, prog)
    showed_obj_trans_content = {:category => LocalizableContent::CAMPAIGN, :id => email.id, :klass => email.class.to_s, :attribute => "source", :higher_hierarchy => [[campaign.class.to_s, campaign.id],[email.class.to_s, email.id]], :en => email.source, :de => email.globalize.send(:fetch_attribute, :de, :source), :heading => email.subject, :ckeditor_type => :dropdown, strinsert: strinsert_for_campaign, label: 'feature.campaigns.label.Insert_variable'.translate}

    showed_obj_trans_content.keys.each do |key|
      assert_dynamic_expected_nil_or_equal showed_obj_trans_content[key], assigns(:object_details)[key]
    end

    assert_not_equal LocalizableContent.ckeditor_type[Mailer::Template][:source], showed_obj_trans_content["ckeditor_type"]
  end

  def test_set_scores_for_programs
    prog = programs(:albers) #not standalone
    org = prog.organization
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    announ = Announcement.create!({:program => programs(:albers), :admin => users(:f_admin), :status => Announcement::Status::DRAFTED})

    LocalizableContent.stubs(:program_level).returns([LocalizableContent::RESOURCES])
    LocalizableContent.stubs(:org_level).returns([LocalizableContent::OVERVIEW_PAGES, LocalizableContent::RESOURCES])
    LocalizableContent.stubs(:all).returns([LocalizableContent::OVERVIEW_PAGES, LocalizableContent::RESOURCES])

    org.resources.destroy_all
    org.pages.destroy_all
    prog.resources.destroy_all

    r1 = org.resources.create!({:title => "title 1", :content => "content 1"})
    r2 = org.resources.create!({:title => "title 2", :content => "content 2"})
    r3 = prog.resources.create!({:title => "title 1", :content => "content 1"})
    r4 = prog.resources.create!({:title => "title 2", :content => "content 2"})
    p1 = org.pages.create!(:title => "title 1", :content => "some content")
    p2 = org.pages.create!(:title => "title 2", :content => "some content")

    get :index
    programs_score = assigns(:programs_score)
    assert_equal [0, 4], programs_score[prog.id]
    assert_equal [0, 8], programs_score[org.id]
  end

  def test_show_category_content_membership_request_instructions
    program = programs(:albers)
    instruction = MembershipRequest::Instruction.new(:program => programs(:albers))
    Globalize.with_locale(:en) do
      instruction.content = "english content"
      instruction.save!
    end
    Globalize.with_locale(:de) do
      instruction.content = "french content"
      instruction.save!
    end
    current_user_is :f_admin
    program.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)

    get :show_category_content, xhr: true, params: { abstract_program_id: program.id, category: LocalizableContent::INSTRUCTION, id: instruction.id, :format => :js}
    LocalizableContent.attributes_for_model(category: LocalizableContent::INSTRUCTION, tab: nil)[instruction.class].each do |attr|
      assert_match /#{instruction.send(attr)}/, response.body
    end
  end

  def test_show_category_content_membership_request_instructions_non_default_locale
    program = programs(:albers)
    instruction = MembershipRequest::Instruction.new(:program => programs(:albers))
    Globalize.with_locale("en") do
      instruction.content = "english content"
      instruction.save!
    end
    Globalize.with_locale(:de) do
      instruction.content = "french content"
      instruction.save!
    end
    current_user_is :f_admin
    program.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)

    get :show_category_content, xhr: true, params: { abstract_program_id: program.id, category: LocalizableContent::INSTRUCTION, id: instruction.id, :format => :js, :locale => :de}
    LocalizableContent.attributes_for_model(category: LocalizableContent::INSTRUCTION, tab: nil)[instruction.class].each do |attr|
      Globalize.with_locale(:de) do
        assert_match /#{instruction.send(attr)}/, response.body
      end
    end
  end

  def test_show_category_content_mentor_request_instructions
    program = programs(:albers)
    instruction = MentorRequest::Instruction.new(:program => programs(:albers))
    Globalize.with_locale(:en) do
      instruction.content = "english content"
      instruction.save!
    end
    Globalize.with_locale(:de) do
      instruction.content = "french content"
      instruction.save!
    end
    current_user_is :f_admin
    program.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)

    get :show_category_content, xhr: true, params: { abstract_program_id: program.id, category: LocalizableContent::INSTRUCTION, id: instruction.id, :format => :js}
    LocalizableContent.attributes_for_model(category: LocalizableContent::INSTRUCTION, tab: nil)[instruction.class].each do |attr|
      assert_match /#{instruction.send(attr)}/, response.body
    end
  end

  def test_show_category_content_mentor_request_instructions_non_default_locale
    program = programs(:albers)
    instruction = MentorRequest::Instruction.new(:program => programs(:albers))
    Globalize.with_locale("en") do
      instruction.content = "english content"
      instruction.save!
    end
    Globalize.with_locale(:de) do
      instruction.content = "french content"
      instruction.save!
    end
    current_user_is :f_admin
    program.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)

    get :show_category_content, xhr: true, params: { abstract_program_id: program.id, category: LocalizableContent::INSTRUCTION, id: instruction.id, :format => :js, :locale => :de}
    LocalizableContent.attributes_for_model(category: LocalizableContent::INSTRUCTION, tab: nil)[instruction.class].each do |attr|
      Globalize.with_locale(:de) do
        assert_match /#{instruction.send(attr)}/, response.body
      end
    end
  end

  def test_show_category_content_program_events
    program = programs(:albers)
    event = program.program_events.first
    current_user_is :f_admin
    program.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    get :show_category_content, xhr: true, params: { abstract_program_id: program.id, category: LocalizableContent::PROGRAM_EVENTS, id: event.id, :format => :js}
    LocalizableContent.attributes_for_model(category: LocalizableContent::PROGRAM_EVENTS, tab: nil)[event.class].each do |attr|
      assert_match /#{event.send(attr)}/, response.body
    end
  end

  def test_show_category_content_program_events_non_default_locale
    event = program_events(:birthday_party)
    Globalize.with_locale(:de) do
      event.update_attributes!(:title => "french title", :description => "french desc")
    end
    program = programs(:albers)
    current_user_is :f_admin
    program.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    get :show_category_content, xhr: true, params: { abstract_program_id: program.id, category: LocalizableContent::PROGRAM_EVENTS, id: event.id, :format => :js, :locale => :de}
    LocalizableContent.attributes_for_model(category: LocalizableContent::PROGRAM_EVENTS, tab: nil)[event.class].each do |attr|
      assert_match /#{event.send(attr)}/, response.body
    end
  end

  def test_update_content_program_events
    prog = programs(:albers)
    prog.organization.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    event = program_events(:birthday_party)

    assert_no_difference('Delayed::Job.count') do
      put :update, xhr: true, params: { locale: :de, value: "french title", id: event.id, abstract_program_id: prog.id, category: LocalizableContent::PROGRAM_EVENTS, object: {id: event.id, attribute: :title, higher_hierarchy: [[event.class.to_s, event.id]]}.to_json}
    end
    Globalize.with_locale(:de) do
      assert_equal "french title", program_events(:birthday_party).title
    end
    assert_response :success
  end

  def test_show_category_content_images_one_locale
    org = programs(:org_primary)
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    ProgramAsset.find_or_create_by(program_id: org.id)
    org.program_asset.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    org.program_asset.save!
    get :show_category_content, xhr: true, params: { locale: :de, abstract_program_id: org.id, category: LocalizableContent::PROGRAM_ASSET, id: "logo"}
    assert_equal 1, response.body.scan(/<img/).count
    assert_equal 1, response.body.scan(/test_pic.png/).count
  end

  def test_show_category_content_images_both_locales
    org = programs(:org_primary)
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    pa = ProgramAsset.find_or_create_by(program_id: org.id)
    pa.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    pa.save!
    GlobalizationUtils.run_in_locale(:de) do
      pa.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
      pa.save!
    end
    get :show_category_content, xhr: true, params: { locale: :de, abstract_program_id: org.id, category: LocalizableContent::PROGRAM_ASSET, id: "logo"}
    assert_equal 2, response.body.scan(/<img/).count
    assert_equal 2, response.body.scan(/test_pic.png/).count
  end

  def test_update_images_successful
    org = programs(:org_primary)
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    ProgramAsset.find_or_create_by(program_id: org.id)
    org.program_asset.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    org.program_asset.save!
    TranslationsController.any_instance.expects(:expire_fragment).times(18)
    #2(stylesheets ) + 6(programs)*3(locales)
    post :update_images, xhr: true, params: { locale: :de, abstract_program_id: org.id, category: LocalizableContent::PROGRAM_ASSET, id: "logo", :logo => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')}
    assert_equal [programs(:org_primary).id] + programs(:org_primary).programs.ordered.pluck(:id), assigns(:progs).collect(&:id)
    assert_match /Localization.updateScores.*?program_asset.*?\[1,1\]/, response.body.squish
  end

  def test_cache_expiry_standalone_program
    program = programs(:foster)
    org = program.organization
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :foster_admin
    create_organization_language(:organization => org, :enabled => true, :language => languages(:hindi))
    ProgramAsset.find_or_create_by(program_id: org.id) #program asset belongs to org in standalone case
    org.program_asset.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    org.program_asset.save!
    # 2 locales * 2 programs(prog+org) + 2 (stylesheets)
    TranslationsController.any_instance.expects(:expire_fragment).times(4)
    post :update_images, xhr: true, params: { locale: :de, abstract_program_id: program.id, category: LocalizableContent::PROGRAM_ASSET, id: "logo", :logo => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')}
  end

  def test_update_images_edit_successful
    org = programs(:org_primary)
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    ProgramAsset.find_or_create_by(program_id: org.id)
    org.program_asset.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    org.program_asset.save!
    GlobalizationUtils.run_in_locale(:de) do
      org.program_asset.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    end
    post :update_images, xhr: true, params: { locale: :de, abstract_program_id: org.id, category: LocalizableContent::PROGRAM_ASSET, id: "logo", :logo => fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png')}
    assert_equal [programs(:org_primary).id] + programs(:org_primary).programs.ordered.pluck(:id), assigns(:progs).collect(&:id)
    assert_match /Localization.updateScores.*?program_asset.*?\[1,1\]/, response.body.squish
  end

  def test_update_images_failure
    org = programs(:org_primary)
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    ProgramAsset.find_or_create_by(program_id: org.id)
    org.program_asset.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    org.program_asset.save!
    post :update_images, xhr: true, params: { locale: :de, abstract_program_id: org.id, category: LocalizableContent::PROGRAM_ASSET, id: "logo", :logo => fixture_file_upload(File.join('files', 'big.pdf'), 'image/pdf')}
    assert_match /Logo content type is not one of/, response.body.squish
    assert_match /Logo file size must be less than/, response.body.squish
  end

  def test_percent_images
    org = programs(:org_primary)
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    ProgramAsset.find_or_create_by(program_id: org.id)
    org.program_asset.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    org.program_asset.save!
    get :index
    assert_match /cjs_percent_completed_program_asset.*0/, response.body.squish
  end

  def test_expand_category
    org = programs(:org_primary)
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_member_is :f_admin
    get :expand_category, xhr: true, params: { :locale => :de, :category => "user_profile", :abstract_program_id => org.id}
    category_details = assigns(:category_detail)
    org.sections.each do |section|
      assert category_details.select{|cd| cd[:id] == section.id}.present?
    end
    assert_equal org.sections.size, category_details.size
  end

  private
  def hier_count(obj, relation, category, tab=nil)
    attributes = LocalizableContent.attributes_for_model(category: category, tab: tab)[obj.class]
    count = can_be_edited(obj) ? attributes.select{|attribute| obj[attribute].present?}.count : 0
    depen_objs = obj.send(relation) if relation.present?
    if depen_objs.present?
      attributes = LocalizableContent.attributes_for_model(category: category, tab: tab)[depen_objs.first.class]
      depen_objs.each{|obj| count += (can_be_edited(obj) ? attributes.collect{|attribute| (obj[attribute].present? ? 1 : 0 )} : 0).sum}
    end
    return count
  end

  def can_be_edited(obj)
    object_condition = LocalizableContent.get_editable_condition[obj.class]
    val = true
    object_condition.each{|cond| val &&= !obj.send(cond)} if object_condition
    return val
  end
end