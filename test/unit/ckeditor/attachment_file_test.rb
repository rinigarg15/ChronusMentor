require_relative './../../test_helper.rb'

class Ckeditor::AttachmentFileTest < ActiveSupport::TestCase
  def test_tiff_file_upload
    asset = Ckeditor.attachment_file_model.new(program_id: programs(:org_primary).id)
    asset.data = fixture_file_upload(File.join('files', 'test_pic.tiff'), 'image/tiff')
    assert_raise(ActiveRecord::RecordInvalid) do
        asset.save!
    end
  end
end
