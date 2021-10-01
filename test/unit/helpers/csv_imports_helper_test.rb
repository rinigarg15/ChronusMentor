require_relative "./../../test_helper.rb"

class CsvImportsHelperTest < ActionView::TestCase
  def test_csv_imports_active_profile_link
    self.stubs(:csv_imports_validation_link).with(1, 2, CsvImportsController::DataPopup::Type::ACTIVE, false).once.returns("something")
    assert_equal "something", csv_imports_active_profile_link(1, 2, false)
  end

  def test_csv_imports_pending_profile_link
    self.stubs(:csv_imports_validation_link).with(1, 2, CsvImportsController::DataPopup::Type::PENDING, false).once.returns("something")
    assert_equal "something", csv_imports_pending_profile_link(1, 2, false)
  end

  def test_csv_imports_users_to_invite_link
    self.stubs(:csv_imports_validation_link).with(1, 2, CsvImportsController::DataPopup::Type::INVITE, false).once.returns("something")
    assert_equal "something", csv_imports_users_to_invite_link(1, 2, false)
  end

  def test_csv_imports_users_to_update_link
    self.stubs(:csv_imports_validation_link).with(1, 2, CsvImportsController::DataPopup::Type::UPDATE, false).once.returns("something")
    assert_equal "something", csv_imports_users_to_update_link(1, 2, false)
  end

  def test_csv_imports_suspended_members_link
    self.stubs(:csv_imports_validation_link).with(1, 2, CsvImportsController::DataPopup::Type::SUSPENDED, false).once.returns("something")
    assert_equal "something", csv_imports_suspended_members_link(1, 2, false)
  end

  def test_csv_imports_error_link
    self.stubs(:csv_imports_validation_link).with(1, 2, CsvImportsController::DataPopup::Type::ERROR, false, "csv_import.content.validation_information.errors_link_text".translate(count: 2)).once.returns("something")
    assert_equal "something", csv_imports_error_link(1, 2, false)
  end

  def test_csv_imports_validation_link
    assert_equal 0, csv_imports_validation_link(777, 0, "something", false)
    assert_select_helper_function "a[class=\"remote-popup-link\"][data-largemodal=\"true\"][data-url=\"/csv_imports/777/validation_data_popup.html?type=something\"][href=\"javascript:void(0);\"][id=\"imports_validation_data_something\"]", csv_imports_validation_link(777, 40, "something", false), {text: "40"}
    assert_select_helper_function "a[class=\"remote-popup-link\"][data-largemodal=\"true\"][data-url=\"/csv_imports/777/validation_data_popup.html?type=something\"][href=\"javascript:void(0);\"][id=\"imports_validation_data_something\"]", csv_imports_validation_link(777, 40, "something", false, "link_to_this"), {text: "link_to_this"}
  end

  def test_add_bulk_users_wizard
    assert_equal add_bulk_users_wizard, {1=>{:label=>"Import Data"}, 2=>{:label=>"Map Data"}, 3=>{:label=>"Create Users"}}
  end

  def test_create_users_wizard
    program = programs(:albers)

    user_csv_import = program.user_csv_imports.new
    user_csv_import.member = members(:f_admin)
    user_csv_import.attachment = fixture_file_upload("/files/csv_import.csv", "text/csv")
    user_csv_import.save!

    user_csv_import.update_attribute(:local_csv_file_path, UserCsvImport.save_user_csv_to_be_imported(fixture_file_upload("/files/csv_import.csv", "text/csv").read, "csv_import.csv", user_csv_import.id))

    assert_equal create_users_wizard(user_csv_import, false), {1=>{:label=>"Import Data", :url=>"/csv_imports/#{user_csv_import.id}/edit"}, 2=>{:label=>"Map Data", :url=>"/csv_imports/#{user_csv_import.id}/map_csv_columns"}, 3=>{:label=>"Create Users"}}
  end

  def test_map_user_columns_wizard
    program = programs(:albers)

    user_csv_import = program.user_csv_imports.new
    user_csv_import.member = members(:f_admin)
    user_csv_import.attachment = fixture_file_upload("/files/csv_import.csv", "text/csv")
    user_csv_import.save!

    user_csv_import.update_attribute(:local_csv_file_path, UserCsvImport.save_user_csv_to_be_imported(fixture_file_upload("/files/csv_import.csv", "text/csv").read, "csv_import.csv", user_csv_import.id))

    assert_equal map_user_columns_wizard(user_csv_import, false), {1=>{:label=>"Import Data", :url=>"/csv_imports/#{user_csv_import.id}/edit"}, 2=>{:label=>"Map Data"}, 3=>{:label=>"Create Users"}}
  end

  def test_render_dropdown_for_csv_headers
    csv_headers = ["First name", "last name", "email", "p1", "p2"]

    saved_mapping = {"First name" => "first_name", "last name" => "last_name", "email" => "email", "p1" => "profile_question_1", "p2" => "profile_question_2"}

    assert_select_helper_function_block "select[class=\"form-control cjs_csv_header_dropdown cjs_user_csv_dropdown cjs_mandatory_csv_column\"][id=\"_csv_dropdown_3\"][name=\"[csv_dropdown][3]\"]", render_dropdown_for_csv_headers(3, csv_headers, saved_mapping, "first_name") do
      assert_select "option[value=\"select_a_column\"]", text: "Select an imported field"
      assert_select "option[selected=\"selected\"][value=\"0\"]", text: "First name"
      assert_select "option[value=\"1\"]", text: "last name"
      assert_select "option[value=\"2\"]", text:"email"
      assert_select "option[value=\"3\"]", text: "p1"
      assert_select "option[value=\"4\"]", text:"p2"
    end
    saved_mapping = {}

    assert_select_helper_function_block "select[class=\"form-control cjs_csv_header_dropdown cjs_user_csv_dropdown cjs_optional_csv_column\"][id=\"_csv_dropdown_3\"][name=\"[csv_dropdown][3]\"]", render_dropdown_for_csv_headers(3, csv_headers, saved_mapping, nil) do
      assert_select "option[value=\"select_a_column\"]", text: "Select an imported field"
      assert_select "option[value=\"0\"]", text: "First name"
      assert_select "option[value=\"1\"]", text: "last name"
      assert_select "option[value=\"2\"]", text:"email"
      assert_select "option[value=\"3\"]", text: "p1"
      assert_select "option[value=\"4\"]", text:"p2"
    end
  end

  def test_render_dropdown_for_column_options
    csv_headers = ["First name", "last name", "email", "p1", "p2", "p3", "p4"]
    profile_column_keys = ["profile_question_1", "profile_question_3", "profile_question_4"]

    saved_mapping = {"p1" => "profile_question_1", "First name" => "first_name", "last name" => "last_name", "email" => "email", "p2" => "profile_question_2"}

    assert_select_helper_function_block "select[class=\"cjs_profile_header_dropdown cjs_user_csv_dropdown form-control\"][id=\"_profile_dropdown_3\"][name=\"[profile_dropdown][3]\"]", render_dropdown_for_column_options(3, csv_headers, profile_column_keys, saved_mapping) do
      assert_select "option[selected=\"selected\"][value=\"profile_question_1\"]", text: "Name"
      assert_select "option[value=\"profile_question_3\"]", text: "Location"
      assert_select "option[value=\"profile_question_4\"]", text: "Phone"
    end

    saved_mapping = {"p1" => "profile_question_2", "First name" => "first_name", "last name" => "last_name", "email" => "email", "p2" => "profile_question_1"}

    assert_select_helper_function_block "select[class=\"cjs_profile_header_dropdown cjs_user_csv_dropdown form-control\"][id=\"_profile_dropdown_3\"][name=\"[profile_dropdown][3]\"]", render_dropdown_for_column_options(3, csv_headers, profile_column_keys, saved_mapping) do
      assert_select "option[value=\"profile_question_1\"]", text: "Name"
      assert_select "option[value=\"profile_question_3\"]", text: "Location"
      assert_select "option[value=\"profile_question_4\"]", text: "Phone"
    end

    saved_mapping = {}

    assert_select_helper_function_block "select[class=\"cjs_profile_header_dropdown cjs_user_csv_dropdown form-control\"][id=\"_profile_dropdown_3\"][name=\"[profile_dropdown][3]\"]", render_dropdown_for_column_options(3, csv_headers, profile_column_keys, saved_mapping) do
      assert_select "option[value=\"profile_question_1\"]", text: "Name"
      assert_select "option[value=\"profile_question_3\"]", text:"Location"
      assert_select "option[value=\"profile_question_4\"]", text: "Phone"
    end
  end
end
