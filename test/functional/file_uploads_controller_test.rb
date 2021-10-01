require_relative './../test_helper.rb'

class FileUploadsControllerTest < ActionController::TestCase
    tests FileUploadsController

  def test_create_file_upload
    error = "error"
    code = "code"
    current_user_is :f_admin
    FileUploader.expects(:new).with(ProgramAsset::Type::LOGO.to_s, programs(:org_primary).id.to_s, "test file", { base_path: "#{DROPZONE::TEMP_BASE_PATH}/#{ProgramAsset::TEMP_BASE_PATH}", max_file_size: ProgramAsset::MAX_SIZE[ProgramAsset::Type::LOGO] }).returns(FileUploader).twice
    FileUploader.expects(:new).with(ProgramAsset::Type::LOGO.to_s, programs(:org_primary).id.to_s, "test file", { base_path: DROPZONE::TEMP_BASE_PATH }).returns(FileUploader)

    FileUploader.expects(:save).returns(false)
    FileUploader.expects(:errors).returns("error")
    post :create, params: { type_id: ProgramAsset::Type::LOGO, owner_id: programs(:org_primary).id, file: "test file", uploaded_class: ProgramAsset.name, program_asset_type: ProgramAsset::Type::LOGO }
    assert_response 403
    assert_equal error.to_json, response.body

    FileUploader.expects(:save).returns(true).twice
    FileUploader.expects(:uniq_code).returns("code").twice
    post :create, params: { type_id: ProgramAsset::Type::LOGO, owner_id: programs(:org_primary).id, file: "test file", uploaded_class: ProgramAsset.name, program_asset_type: ProgramAsset::Type::LOGO }
    assert_response :success
    assert_equal code.to_json, response.body

    post :create, params: { type_id: ProgramAsset::Type::LOGO, owner_id: programs(:org_primary).id, file: "test file" }
    assert_response :success
    assert_equal code.to_json, response.body
  end
end