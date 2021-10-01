require_relative './../../test_helper.rb'

class ProgramAssetUtilsTest < ActiveSupport::TestCase
  include ProgramAssetUtils

  def test_get_banner_logo_attributes
    program = programs(:albers)
    program_attrs = { "logo" => { file_name: "banner.jpg", code: "123" }, "banner" => { file_name: "" } }
    program_asset = ProgramAsset.create!(program_id: program.id)
    expects(:update_banner_logo).with(program, program_asset, ProgramAsset::Type::LOGO, { file_name: "banner.jpg", code: "123" })
    expects(:destroy_banner_logo).with(program_asset, ProgramAsset::Type::BANNER)
    get_banner_logo_attributes(program, program_attrs)
  end

  def test_update_banner_logo
    File.expects(:open).with("banner_pic.jpg", "rb").returns("banner.pic")
    File.expects(:open).with("logo_pic.jpg", "rb").returns("logo.pic")
    program = programs(:albers)
    FileUploader.expects(:get_file_path).with(ProgramAsset::Type::LOGO, program.id, "#{DROPZONE::TEMP_BASE_PATH}/#{ProgramAsset::TEMP_BASE_PATH}", { 'code' => "123", 'file_name' => "logo.jpg" }).returns("logo_pic.jpg")
    FileUploader.expects(:get_file_path).with(ProgramAsset::Type::BANNER, program.id, "#{DROPZONE::TEMP_BASE_PATH}/#{ProgramAsset::TEMP_BASE_PATH}", { 'code' => "123", 'file_name' => "banner.jpg" }).returns("banner_pic.jpg")

    program_asset = ProgramAsset.create!(program_id: program.id)
    program_asset.expects("banner=").with("banner.pic")
    program_asset.expects("logo=").with("logo.pic")
    send(:update_banner_logo, program, program_asset, ProgramAsset::Type::BANNER, ActionController::Parameters.new({ file_name: "banner.jpg", code: "123" }))
    send(:update_banner_logo, program, program_asset, ProgramAsset::Type::LOGO, ActionController::Parameters.new({ file_name: "logo.jpg", code: "123" }))
  end

  def test_destroy_banner_logo
    program = programs(:albers)
    program_asset = ProgramAsset.create!(program_id: program.id)
    program_asset.expects(:logo)
    program_asset.expects(:banner)
    send(:destroy_banner_logo, program_asset, ProgramAsset::Type::BANNER)
    send(:destroy_banner_logo, program_asset, ProgramAsset::Type::LOGO)
  end
end
