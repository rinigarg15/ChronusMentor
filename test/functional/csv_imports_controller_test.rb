require_relative "./../test_helper.rb"

class CsvImportsControllerTest < ActionController::TestCase

  def setup
    super
    programs(:albers).enable_feature(FeatureName::USER_CSV_IMPORT, true)
    programs(:org_primary).enable_feature(FeatureName::USER_CSV_IMPORT, true)
  end

  def test_any_action_cannot_be_accessed_without_logging_in_org_level
    user_csv_import = create_org_user_csv_import

    current_organization_is :org_primary
    [:validation_information, :validation_data_popup, :import_data, :completed, :records].each do |action|
      get action, params: { id: user_csv_import.id }
      assert_redirected_to new_session_path
    end
  end

  def test_any_action_cannot_be_accessed_without_logging_in_prog_level
    program = programs(:albers)
    user_csv_import = create_user_csv_import(program)

    current_program_is program
    [:validation_information, :validation_data_popup, :import_data, :completed, :records].each do |action|
      get action, params: { id: user_csv_import.id }
      assert_redirected_to new_session_path
    end
  end

  def test_any_action_cannot_be_accessed_for_non_admin_in_org_level
    user_csv_import = create_org_user_csv_import

    current_member_is :f_mentor
    [:validation_information, :validation_data_popup, :import_data, :completed, :records].each do |action|
      assert_permission_denied do
        get action, params: { id: user_csv_import.id }
      end
    end
  end

  def test_any_action_cannot_be_accessed_for_non_admin_in_prog_level
    user_csv_import = create_user_csv_import(programs(:albers))

    current_user_is :f_mentor
    [:validation_information, :validation_data_popup, :import_data, :completed, :records].each do |action|
      assert_permission_denied do
        get action, params: { id: user_csv_import.id }
      end
    end
  end

  def test_new_permission_denied
    current_user_is :f_mentor

    assert_permission_denied do
      get :new
    end
  end

  def test_edit_permission_denied
    user_csv_import = create_user_csv_import(programs(:albers))

    current_user_is :f_mentor
    assert_permission_denied do
      get :edit, params: { id: user_csv_import.id }
    end
  end

  def test_new_at_program_level
    current_program_is :albers
    current_user_is :f_admin

    get :new

    assert_response :success

    assert_equal assigns(:program_roles), programs(:albers).roles
  end

  def test_new_at_org_level
    current_organization_is :org_primary

    current_member_is :f_admin

    get :new

    assert_response :success

    assert_nil assigns(:program_roles)
  end

  def test_new_for_standalone_org
    current_organization_is :org_primary

    current_member_is :f_admin

    Organization.any_instance.stubs(:standalone?).returns(true)

    get :new

    assert_response :success

    assert_false assigns(:program_level_import)
    assert assigns(:standalone_org_level_access)
    assert_nil assigns(:program_roles)
  end

  def test_edit_at_program_level
    current_program_is :albers
    current_user_is :f_admin

    user_csv_import = programs(:albers).user_csv_imports.new
    user_csv_import.member = members(:f_admin)
    user_csv_import.attachment = fixture_file_upload("/files/csv_import.csv", "text/csv")
    user_csv_import.save!

    user_csv_import.update_or_save_role([RoleConstants::MENTOR_NAME])

    get :edit, params: { :id => user_csv_import.id}

    assert_response :success

    assert_equal assigns(:user_csv_import), user_csv_import
    assert_equal assigns(:program_roles), programs(:albers).roles
    assert_equal assigns(:selected_roles), [RoleConstants::MENTOR_NAME]
  end

  def test_edit_at_org_level
    current_organization_is :org_primary

    current_member_is :f_admin

    user_csv_import = programs(:org_primary).user_csv_imports.new
    user_csv_import.member = members(:f_admin)
    user_csv_import.attachment = fixture_file_upload("/files/csv_import.csv", "text/csv")
    user_csv_import.save!

    user_csv_import.stubs(:selected_roles).returns("roles")

    get :edit, params: { :id => user_csv_import.id}

    assert_response :success

    assert_equal assigns(:user_csv_import), user_csv_import
    assert_nil assigns(:program_roles)
    assert_nil assigns(:selected_roles)
  end

  def test_edit_for_standalone_org
    current_organization_is :org_primary

    current_member_is :f_admin

    Organization.any_instance.stubs(:standalone?).returns(true)

    user_csv_import = programs(:org_primary).user_csv_imports.new
    user_csv_import.member = members(:f_admin)
    user_csv_import.attachment = fixture_file_upload("/files/csv_import.csv", "text/csv")
    user_csv_import.save!

    user_csv_import.stubs(:selected_roles).returns("roles")

    get :edit, params: { :id => user_csv_import.id}

    assert_response :success

    assert_false assigns(:program_level_import)
    assert_equal assigns(:user_csv_import), user_csv_import
    assert_nil assigns(:program_roles)
    assert_nil assigns(:selected_roles)
  end

  def test_map_csv_columns_permission_denied
    user_csv_import = create_user_csv_import(programs(:albers))

    current_user_is :f_mentor
    assert_permission_denied do
      get :map_csv_columns, params: { id: user_csv_import.id }
    end
  end

  def test_map_csv_columns_at_prog_level
    current_program_is :albers
    current_user_is :f_admin

    user_csv_import = create_user_csv_import(programs(:albers))

    user_csv_import.update_or_save_role([RoleConstants::MENTOR_NAME])

    csv_dropdown_choices = {"0"=>"0", "1"=>"1", "2"=>"2", "3"=>"3", "4"=>"4", "5"=>"5", "6"=>"7", "7"=>"8"}

    profile_dropdown_choices = {"3"=>"profile_question_9", "4"=>"profile_question_33", "5"=>"profile_question_10", "6"=>"profile_question_206", "7"=>UserCsvImport::CsvMapColumns::DONT_MAP}

    user_csv_import.save_mapping_params(csv_dropdown_choices, profile_dropdown_choices)

    user_csv_import.save_processed_csv_import_params

    user_csv_import.reload

    get :map_csv_columns, params: { :id => user_csv_import.id}

    assert_response :success

    assert_equal assigns(:user_csv_import), user_csv_import
    assert_equal assigns(:selected_roles), [RoleConstants::MENTOR_NAME]
    assert_equal assigns(:csv_column_headers), user_csv_import.csv_headers_for_dropdown
    assert_equal assigns(:mandatory_column_keys), user_csv_import.map_mandatory_column_keys(true, [RoleConstants::MENTOR_NAME])
    assert_equal assigns(:profile_column_keys), user_csv_import.map_non_mandatory_columns_keys([RoleConstants::MENTOR_NAME])
    assert_equal assigns(:example_column_values), user_csv_import.example_column_values
    assert_false assigns(:saved_mapping).present?
    assert assigns(:showing_saved_mapping)
  end

  def test_map_csv_columns_at_org_level
    current_organization_is :org_primary

    current_member_is :f_admin

    user_csv_import = create_org_user_csv_import

    csv_dropdown_choices = {"0"=>"0", "1"=>"1", "2"=>"2", "3"=>"3", "4"=>"4", "5"=>"5", "6"=>"7", "7"=>"8"}

    profile_dropdown_choices = {"3"=>"profile_question_9", "4"=>"profile_question_33", "5"=>"profile_question_10", "6"=>"profile_question_206", "7"=>UserCsvImport::CsvMapColumns::DONT_MAP}

    user_csv_import.save_mapping_params(csv_dropdown_choices, profile_dropdown_choices)

    user_csv_import.reload

    get :map_csv_columns, params: { :id => user_csv_import.id}

    assert_response :success

    assert_equal assigns(:user_csv_import), user_csv_import
    assert_nil assigns(:selected_roles)
    assert_equal assigns(:csv_column_headers), user_csv_import.csv_headers_for_dropdown
    assert_equal assigns(:mandatory_column_keys), user_csv_import.map_mandatory_column_keys(false, assigns(:selected_roles))
    assert_equal assigns(:profile_column_keys), user_csv_import.map_non_mandatory_columns_keys(assigns(:selected_roles))
    assert_equal assigns(:example_column_values), user_csv_import.example_column_values
  end

  def test_map_csv_columns_for_standalone_org
    current_organization_is :org_primary

    current_member_is :f_admin

    Organization.any_instance.stubs(:standalone?).returns(true)

    user_csv_import = create_org_user_csv_import

    get :map_csv_columns, params: { :id => user_csv_import.id}

    assert_response :success

    assert_equal assigns(:user_csv_import), user_csv_import
    assert_nil assigns(:selected_roles)
    assert_equal assigns(:csv_column_headers), user_csv_import.csv_headers_for_dropdown
    assert_equal assigns(:mandatory_column_keys), user_csv_import.map_mandatory_column_keys(false, assigns(:selected_roles))
    assert_equal assigns(:profile_column_keys), user_csv_import.map_non_mandatory_columns_keys(assigns(:selected_roles))
    assert_equal assigns(:example_column_values), user_csv_import.example_column_values
    assert_false assigns(:saved_mapping).present?
    assert_false assigns(:showing_saved_mapping)
  end

  def test_map_csv_columns_at_org_level_with_session_mapping
    current_organization_is :org_primary
    current_member_is :f_admin

    user_csv_import = create_org_user_csv_import

    previous_import_info_hash = {:processed_csv_import_params => {"First name" => "first_name", "Last name" => "last_name", "email" => "email"}}

    programs(:org_primary).stubs(:previous_user_csv_import_info_hash).returns(previous_import_info_hash) 

    get :map_csv_columns, params: { :id => user_csv_import.id}

    assert_response :success

    assert_false assigns(:program_level_import)
    assert_equal assigns(:user_csv_import), user_csv_import
    assert_nil assigns(:selected_roles)
    assert_equal assigns(:csv_column_headers), user_csv_import.csv_headers_for_dropdown
    assert_equal assigns(:mandatory_column_keys), user_csv_import.map_mandatory_column_keys(false, assigns(:selected_roles))
    assert_equal assigns(:profile_column_keys), user_csv_import.map_non_mandatory_columns_keys(assigns(:selected_roles))
    assert_equal assigns(:example_column_values), user_csv_import.example_column_values
    assert_false assigns(:saved_mapping).present?
    assert_false assigns(:showing_saved_mapping)
  end

  def test_create_permission_denied
    current_user_is :f_mentor

    assert_permission_denied do
      post :create
    end
  end

  def test_update_permission_denied
    user_csv_import = create_user_csv_import(programs(:albers))

    current_user_is :f_mentor
    assert_permission_denied do
      put :update, params: { id: user_csv_import.id }
    end
  end

  def test_create_at_prog_level
    current_program_is :albers
    current_user_is :f_admin

    assert_difference "UserCsvImport.count", +1 do
      post :create, params: { :user_csv => fixture_file_upload("/files/csv_import.csv", "text/csv"), :role_option => UserCsvImport::RoleOption::MapRoles, :role => [RoleConstants::MENTOR_NAME]}
    end

    assert_equal assigns(:user_csv_import).attachment_file_name, "csv_import.csv"
    assert_equal assigns(:user_csv_import).program, programs(:albers)
    assert_nil assigns(:selected_roles)

    assert_redirected_to map_csv_columns_csv_import_path(:id => assigns(:user_csv_import).id)
  end

  def test_create_at_org_level
    current_organization_is :org_primary

    current_member_is :f_admin

    assert_difference "UserCsvImport.count", +1 do
      post :create, params: { :user_csv => fixture_file_upload("/files/csv_import.csv", "text/csv")}
    end

    assert_equal assigns(:user_csv_import).attachment_file_name, "csv_import.csv"
    assert_equal assigns(:user_csv_import).program, programs(:org_primary)
    assert_nil assigns(:selected_roles)

    assert_redirected_to map_csv_columns_csv_import_path(:id => assigns(:user_csv_import).id)
  end

  def test_create_for_standalone_org
    current_organization_is :org_primary

    current_member_is :f_admin

    Organization.any_instance.stubs(:standalone?).returns(true)

    assert_difference "UserCsvImport.count", +1 do
      post :create, params: { :user_csv => fixture_file_upload("/files/csv_import.csv", "text/csv")}
    end

    assert_equal assigns(:user_csv_import).attachment_file_name, "csv_import.csv"
    assert_equal assigns(:user_csv_import).program, programs(:org_primary)
    assert_nil assigns(:selected_roles)

    assert_false assigns(:program_level_import)

    assert_redirected_to map_csv_columns_csv_import_path(:id => assigns(:user_csv_import).id, :organization_level => true)
  end

  def test_update_at_prog_level
    current_program_is :albers
    current_user_is :f_admin

    user_csv_import = create_user_csv_import(programs(:albers))

    user_csv_import.save_mapping_params({"0"=>"1"}, {"3"=>"profile_question_9"})

    user_csv_import.update_or_save_role([RoleConstants::MENTOR_NAME])

    assert_equal user_csv_import.selected_roles, [RoleConstants::MENTOR_NAME]

    put :update, params: { :role_option => UserCsvImport::RoleOption::SelectRoles, :role => [RoleConstants::STUDENT_NAME], :id => user_csv_import.id}

    user_csv_import.reload

    assert_equal user_csv_import.selected_roles, [RoleConstants::STUDENT_NAME]

    assert_equal assigns(:user_csv_import).attachment_file_name, "csv_import.csv"
    assert_equal assigns(:selected_roles), [RoleConstants::STUDENT_NAME]
    assert_equal assigns(:user_csv_import).program, programs(:albers)

    assert assigns(:program_level_import)
    assert_false assigns(:standalone_org_level_access)

    assert_redirected_to map_csv_columns_csv_import_path(assigns(:user_csv_import).id)
  end

  def test_create_redirection_with_csv_error
    current_organization_is :org_primary

    current_member_is :f_admin

    post :create, params: { :user_csv => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'), :role_option => UserCsvImport::RoleOption::MapRoles}

    assert_equal "Please upload a valid CSV file. If you are using an Excel file, follow these <a href='https://support.office.com/en-us/article/Import-or-export-text-txt-or-csv-files-5250ac4c-663c-47ce-937b-339e391393ba#bmexport' target='_blank'>instructions</a> to convert the file into a CSV file.", flash[:error]

    assert_redirected_to new_csv_import_path
  end

  def test_create_redirection_with_limit_exceeded_error
    current_user_is :f_admin
    @controller.stubs(:get_number_of_user_records).returns(CsvImportsController::MAX_NUMBER_OF_USER_RECORDS + 2)

    post :create, params: { :user_csv => fixture_file_upload("/files/csv_import.csv", "text/csv"), :role_option => UserCsvImport::RoleOption::MapRoles}
    assert_equal "Please upload a csv file with maximum of 1000 rows.", flash[:error]
    assert_redirected_to new_csv_import_path
  end

  def test_create_limit_exceeded_for_super_user
    current_user_is :f_admin
    @controller.stubs(:get_number_of_user_records).returns(CsvImportsController::MAX_NUMBER_OF_USER_RECORDS + 2)

    login_as_super_user
    post :create, params: { :user_csv => fixture_file_upload("/files/csv_import.csv", "text/csv"), :role_option => UserCsvImport::RoleOption::MapRoles}
    assert_nil flash[:error]
  end


  def test_create_redirection_with_invalid_encoding_error
    current_user_is :f_admin

    UserCsvImport.stubs(:handle_file_encoding).returns(false)

    post :create, params: { :user_csv => fixture_file_upload("/files/csv_import.csv", "text/csv"), :role_option => UserCsvImport::RoleOption::MapRoles}

    assert_redirected_to new_csv_import_path
    assert_equal "We are sorry we are not able to process the file. Please make sure the file is UTF 8 encoded.", flash[:error]
  end

  def test_create_redirection_with_no_csv
    current_organization_is :org_primary

    current_member_is :f_admin

    assert_no_difference "UserCsvImport.count" do
      post :create, params: { :role_option => UserCsvImport::RoleOption::MapRoles}
    end

    assert_redirected_to new_csv_import_path
  end

  def test_create_redirection_with_role_not_selected
    current_program_is :albers
    current_user_is :f_admin

    assert_no_difference "UserCsvImport.count" do
      post :create, params: { :user_csv => fixture_file_upload("/files/csv_import.csv", "text/csv"), :role_option => UserCsvImport::RoleOption::SelectRoles}
    end

    assert_redirected_to new_csv_import_path
  end

  def test_update_redirection_with_role_not_selected
    current_program_is :albers
    current_user_is :f_admin

    user_csv_import = create_user_csv_import(programs(:albers))

    assert_no_difference "UserCsvImport.count" do
      put :update, params: { :user_csv => fixture_file_upload("/files/csv_import.csv", "text/csv"), :role_option => UserCsvImport::RoleOption::SelectRoles, :id => user_csv_import.id}
    end

    assert_redirected_to edit_csv_import_path(user_csv_import)
  end

  def test_destroy_permission_denied
    user_csv_import = create_user_csv_import(programs(:albers))

    current_user_is :f_mentor
    assert_permission_denied do
      delete :destroy, params: { id: user_csv_import.id }
    end
  end

  def test_destroy
    current_program_is :albers
    current_user_is :f_admin

    user_csv_import = programs(:albers).user_csv_imports.new
    user_csv_import.member = members(:f_admin)
    user_csv_import.attachment = fixture_file_upload("/files/csv_import.csv", "text/csv")
    user_csv_import.save!

    user_csv_import.update_attribute(:local_csv_file_path, UserCsvImport.save_user_csv_to_be_imported(fixture_file_upload("/files/csv_import.csv", "text/csv").read, "csv_import.csv", user_csv_import.id))

    assert_difference "UserCsvImport.count", -1 do
      delete :destroy, params: { :id => user_csv_import.id}
    end

    assert_redirected_to new_csv_import_path
  end

  def test_create_mapping_permission_denied
    user_csv_import = create_user_csv_import(programs(:albers))

    current_user_is :f_mentor
    assert_permission_denied do
      post :create_mapping, params: { id: user_csv_import.id }
    end
  end

  def test_create_mapping_at_prog_level
    current_program_is :albers
    current_user_is :f_admin

    user_csv_import = create_user_csv_import(programs(:albers))

    assert_nil user_csv_import.info

    user_csv_import.update_or_save_role([RoleConstants::MENTOR_NAME])

    post :create_mapping, params: { :id => user_csv_import.id, :csv_dropdown =>{"0"=>"0", "1"=>"1", "2"=>"2", "3"=>"3", "4"=>"4", "5" => "5"}, :profile_dropdown => {"3"=>"profile_dropdown_column_2", "2"=>"profile_dropdown_column_3", "1"=>"profile_dropdown_column_4", "0"=>"profile_dropdown_column_11", "4"=>"profile_dropdown_column_11"}}

    user_csv_import.reload

    assert_equal assigns(:selected_roles), [RoleConstants::MENTOR_NAME]
    assert_equal assigns(:user_csv_import), user_csv_import
    assert_not_nil assigns(:user_csv_import).info
  end

  def test_create_mapping_at_org_level
    current_organization_is :org_primary

    current_member_is :f_admin

    user_csv_import = create_org_user_csv_import

    assert_nil user_csv_import.info

    post :create_mapping, params: { :id => user_csv_import.id, :csv_dropdown =>{"0"=>"0", "1"=>"1", "2"=>"2", "3"=>"3", "4"=>"4", "5"=>"5", "6"=>"7", "7"=>"8"}, :profile_dropdown => {"3"=>"profile_dropdown_column_2", "4"=>"profile_dropdown_column_3", "5"=>"profile_dropdown_column_4", "6"=>"profile_dropdown_column_11", "7"=>"profile_dropdown_column_11"}}

    assert_nil assigns(:selected_roles)
    assert_equal assigns(:user_csv_import), user_csv_import
    assert_not_nil assigns(:user_csv_import).info
  end

  def test_create_mapping_for_standalone_org
    current_organization_is :org_primary

    current_member_is :f_admin

    Organization.any_instance.stubs(:standalone?).returns(true)

    user_csv_import = create_org_user_csv_import

    assert_nil user_csv_import.info

    post :create_mapping, params: { :id => user_csv_import.id, :csv_dropdown =>{"0"=>"0", "1"=>"1", "2"=>"2", "3"=>"3", "4"=>"4", "5"=>"5", "6"=>"7", "7"=>"8"}, :profile_dropdown => {"3"=>"profile_dropdown_column_2", "4"=>"profile_dropdown_column_3", "5"=>"profile_dropdown_column_4", "6"=>"profile_dropdown_column_11", "7"=>"profile_dropdown_column_11"}}

    assert_nil assigns(:selected_roles)
    assert_equal assigns(:user_csv_import), user_csv_import
    assert_not_nil assigns(:user_csv_import).info
  end

  def test_permission_denied_with_feature_disabled
    programs(:albers).enable_feature(FeatureName::USER_CSV_IMPORT, false)

    current_user_is :f_admin

    assert_permission_denied do
      get :new
    end
  end

  def test_validation_information_success
    current_program_is :albers
    current_user_is :f_admin

    user_csv_import = create_user_csv_import(programs(:albers))
    result = {total_added: 0, updated_users: 0, suspended_members: 0, errors_count: 0, invited_users: 0, active_profiles: 0, pending_profiles: 0, imported_users: 0}
    CsvImporter::DataProcessor.any_instance.stubs(:process).returns(result)

    get :validation_information, params: { id: user_csv_import.id}

    assert_select("a", text: "display_string.Cancel".translate)
    assert_no_select("a", text: "display_string.Complete".translate)
  end

  def test_validation_information_success_with_data
    current_program_is :albers
    current_user_is :f_admin

    user_csv_import = create_user_csv_import(programs(:albers))
    user_csv_import_id = user_csv_import.id

    result = {total_added: 10, updated_users: 1, suspended_members: 2, errors_count: 4, invited_users: 5, active_profiles: 3, pending_profiles: 7, imported_users: 16}
    CsvImporter::DataProcessor.any_instance.stubs(:process).returns(result)

    get :validation_information, params: { id: user_csv_import.id}
    assert_select("a", text: "display_string.Cancel".translate)
    assert_select("a", text: "display_string.Complete".translate)
    body = response.body
    assert_match /10 new users .*3.* in Active state and .*7.* in Unpublished state/, body
    assert_match /5.* users who are part of the Primary Organization and not a part of this program will be invited/, body
    assert_match /Profile information for .*1.* user who is already part of this program will be updated/, body
    assert_match /2.* users will not be imported as they are suspended from Primary Organization/, body
    assert_match /There are .*errors in 4 rows.* They will be ignored and not imported./, body
  end

  def test_validation_information_success_org_level
    current_organization_is :org_primary

    current_member_is :f_admin

    user_csv_import = create_org_user_csv_import
    user_csv_import_id = user_csv_import.id
    result = {total_added: 0, updated_users: 0, suspended_members: 0, errors_count: 0, imported_users: 0}
    CsvImporter::DataProcessor.any_instance.stubs(:process).returns(result)

    get :validation_information, params: { id: user_csv_import.id}
    assert_select("a", text: "display_string.Cancel".translate)
    assert_no_select("a", text: "display_string.Complete".translate)
  end

  def test_validation_information_success_org_level_with_data
    current_organization_is :org_primary

    current_member_is :f_admin
    user_csv_import = create_org_user_csv_import
    user_csv_import_id = user_csv_import.id

    result = {total_added: 10, updated_users: 1, suspended_members: 2, errors_count: 4, imported_users: 11}
    CsvImporter::DataProcessor.any_instance.stubs(:process).returns(result)

    get :validation_information, params: { id: user_csv_import.id}
    assert_select("a", text: "display_string.Cancel".translate)
    assert_select("a", text: "display_string.Complete".translate)
    body = response.body
    assert_match /10.* new members will be imported to Primary Organization/, body
    assert_no_match(/5.* users who are part of the Primary Organization and not a part of this program will be invited/, body)
    assert_match /Profile information for .*1.* member who is already part of Primary Organization will be updated/, body
    assert_match /2.* users will not be imported as they are suspended from Primary Organization/, body
    assert_match /There are .*errors in 4 rows.* They will be ignored and not imported./, body
  end

  def test_validation_information_success_for_standalone_org_with_data
    current_organization_is :org_primary

    current_member_is :f_admin

    Organization.any_instance.stubs(:standalone?).returns(true)

    user_csv_import = create_org_user_csv_import
    user_csv_import_id = user_csv_import.id

    result = {total_added: 10, updated_users: 1, suspended_members: 2, errors_count: 4, imported_users: 11}
    CsvImporter::DataProcessor.any_instance.stubs(:process).returns(result)

    get :validation_information, params: { id: user_csv_import.id}
    assert_select("a", text: "display_string.Cancel".translate)
    assert_select("a", text: "display_string.Complete".translate)
    body = response.body
    assert_match /10.* new members will be imported to Primary Organization/, body
    assert_no_match(/5.* users who are part of the Primary Organization and not a part of this program will be invited/, body)
    assert_match /Profile information for .*1.* member who is already part of Primary Organization will be updated/, body
    assert_match /2.* users will not be imported as they are suspended from Primary Organization/, body
    assert_match /There are .*errors in 4 rows.*. They will be ignored and not imported./, body
  end

  def test_validation_data_popup_js
    current_program_is :albers
    current_user_is :f_admin

    user_csv_import = create_user_csv_import(programs(:albers))
    user_csv_import_id = user_csv_import.id
    processed_rows = get_processed_rows
    CsvImporter::Cache.stubs(:read).returns(processed_rows).times(3)
    CsvImporter::ProcessedRow.stubs(:select_rows_where).with(processed_rows, :can_show_errors?).returns(processed_rows).times(2)
    CsvImporter::ProcessedRow.stubs(:select_rows_where).with(processed_rows, :active_profile?).returns(processed_rows).times(1)

    get :validation_data_popup, xhr: true, params: { id: user_csv_import.id, format: :js }
    assert_equal 1, assigns(:page)
    assert_equal CsvImportsController::DataPopup::Type::ERROR, assigns(:type)
    assert_equal processed_rows, assigns(:all_data)
    assert_equal processed_rows.first(10), assigns(:data)
    assert_no_match /Records/, response.body
    assert_no_match /Download/, response.body

    get :validation_data_popup, xhr: true, params: { id: user_csv_import.id, page: "2", format: :js }
    assert_equal "2", assigns(:page)
    assert_equal CsvImportsController::DataPopup::Type::ERROR, assigns(:type)
    assert_equal processed_rows, assigns(:all_data)
    assert_equal processed_rows.last(1), assigns(:data)

    get :validation_data_popup, xhr: true, params: { id: user_csv_import.id, type: "active", format: :js }
    assert_equal 1, assigns(:page)
    assert_equal CsvImportsController::DataPopup::Type::ACTIVE, assigns(:type)
    assert_equal processed_rows, assigns(:all_data)
    assert_equal processed_rows.first(10), assigns(:data)
  end

  def test_import_data_success
    current_program_is :albers
    current_user_is :f_admin

    user_csv_import = create_user_csv_import(programs(:albers))
    user_csv_import_id = user_csv_import.id
    assert_false user_csv_import.reload.imported?
    ps = get_ps
    processed_rows = get_processed_rows

    CsvImporter::Cache.stubs(:read).returns(processed_rows).times(1)
    CsvImporter::ProcessedRow.stubs(:select_rows_where).with(processed_rows, :to_be_imported?).returns(processed_rows).times(1)
    CsvImporter::ProcessedRow.stubs(:select_rows_where).with(processed_rows, :is_user_to_be_added?).returns([]).times(1)
    CsvImporter::ProcessedRow.stubs(:select_rows_where).with(processed_rows, :is_user_to_be_updated?).returns([]).times(1)
    CsvImporter::ProcessedRow.stubs(:select_rows_where).with(processed_rows, :is_user_to_be_invited?).returns([]).times(1)
    UserCsvImport.any_instance.stubs(:profile_questions).returns([]).once
    CsvImporter::ImportUsers.any_instance.stubs(:progress).returns(ps)
    get :import_data, xhr: true, params: { id: user_csv_import.id}
    assert_equal ps, assigns(:progress)
    assert user_csv_import.reload.imported?
    assert_response :success
  end

  def test_completed_success
    current_program_is :albers
    current_user_is :f_admin

    user_csv_import = create_user_csv_import(programs(:albers))
    user_csv_import_id = user_csv_import.id
    processed_rows = get_processed_rows

    CsvImporter::Cache.stubs(:read_failures).returns(processed_rows)
    get :completed, xhr: true, params: { id: user_csv_import.id}
    assert_redirected_to manage_program_path
    assert_match "Due to an unexpected error, only part of the file could be imported.", flash[:warning]

    CsvImporter::Cache.stubs(:read_failures).returns([])
    get :completed, xhr: true, params: { id: user_csv_import.id}
    assert_redirected_to manage_program_path
    assert_equal "The import has been successfully completed.", flash[:notice]
  end

  def test_completed_success_at_org_level
    current_organization_is :org_primary
    current_member_is :f_admin

    user_csv_import = create_user_csv_import(programs(:org_primary))
    user_csv_import_id = user_csv_import.id
    processed_rows = get_processed_rows

    CsvImporter::Cache.stubs(:read_failures).returns(processed_rows)
    get :completed, xhr: true, params: { id: user_csv_import_id}
    assert_redirected_to manage_organization_path
    assert_match "Due to an unexpected error, only part of the file could be imported.", flash[:warning]

    CsvImporter::Cache.stubs(:read_failures).returns([])
    get :completed, xhr: true, params: { id: user_csv_import_id}
    assert_redirected_to manage_organization_path
    assert_equal "The import has been successfully completed.", flash[:notice]

    assert_equal assigns(:current_import_level), programs(:org_primary)
    assert_false assigns(:standalone_dormant_import)
  end

  def test_completed_success_at_org_level_for_standalone_org
    current_organization_is :org_primary

    current_member_is :f_admin

    Organization.any_instance.stubs(:standalone?).returns(true)

    user_csv_import = create_user_csv_import(programs(:org_primary))
    user_csv_import_id = user_csv_import.id
    processed_rows = get_processed_rows

    CsvImporter::Cache.stubs(:read_failures).returns(processed_rows)
    get :completed, xhr: true, params: { id: user_csv_import_id}
    assert_redirected_to manage_program_path
    assert_match "Due to an unexpected error, only part of the file could be imported.", flash[:warning]

    CsvImporter::Cache.stubs(:read_failures).returns([])
    get :completed, xhr: true, params: { id: user_csv_import_id}
    assert_redirected_to manage_program_path
    assert_equal "The import has been successfully completed.", flash[:notice]

    assert_equal assigns(:current_import_level), programs(:org_primary)
    assert assigns(:standalone_dormant_import)
  end

  def test_records_success
    current_program_is :albers
    current_user_is :f_admin

    user_csv_import = create_user_csv_import(programs(:albers))
    user_csv_import_id = user_csv_import.id
    processed_rows = get_processed_rows

    CsvImporter::Cache.stubs(:read_failures).returns(processed_rows).once
    get :records, params: { id: user_csv_import.id, format: :csv, failed: true}

    CsvImporter::Cache.stubs(:read).returns(processed_rows).times(1)
    CsvImporter::ProcessedRow.stubs(:select_rows_where).with(processed_rows, :active_profile?).returns(processed_rows).times(1)
    get :records, params: { id: user_csv_import.id, format: :csv, type: "active"}

    assert_equal assigns(:current_import_level), programs(:albers)
    assert_false assigns(:standalone_dormant_import)

    processed_rows.first.instance_variable_set(:@errors, {:email => ["is invalid."], :role => ["not a valid role."]})
    user_csv_import.stubs(:field_to_csv_column_mapping).returns({"email" => "Email", "role" => "Roles"})
    assert_equal "Email is invalid. Roles not a valid role.", CsvImporter::GenerateCsv.get_row_errors(processed_rows.first, user_csv_import)
  end

  private

  def create_user_csv_import(org_or_prog)
    user_csv_import = org_or_prog.user_csv_imports.new
    user_csv_import.member = members(:f_admin)
    user_csv_import.attachment = fixture_file_upload("/files/csv_import.csv", "text/csv")
    user_csv_import.local_csv_file_path = Rails.root.to_s + "/test/fixtures/files/csv_import.csv"
    user_csv_import.save!
    return user_csv_import
  end

  def create_org_user_csv_import
    user_csv_import = programs(:org_primary).user_csv_imports.new
    user_csv_import.member = members(:f_admin)
    user_csv_import.attachment = fixture_file_upload("/files/csv_import.csv", "text/csv")
    user_csv_import.local_csv_file_path = Rails.root.to_s + "/test/fixtures/files/csv_import.csv"
    user_csv_import.save!
    return user_csv_import
  end

  def get_processed_rows
    prs = []
    11.times do |i|
      prs << CsvImporter::ProcessedRow.new({first_name: "F#{i}", last_name: "L#{i}", email: "e#{i}", roles: "r#{i}"}, {"First Name" => "F#{i}", "Last Name" => "L#{i}", "Email" => "E#{i}", "Roles" => "R#{i}", "Location" => "L#{i}", "language" => "l#{i}"})
    end
    prs
  end

  def get_ps
    ProgressStatus.create!(ref_obj_id: users(:f_admin).id, ref_obj_type: User.name, for: ProgressStatus::For::CsvImports::VALIDATION, maximum: 100)
  end
end