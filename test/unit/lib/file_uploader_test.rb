require_relative './../../test_helper.rb'

class FileUploaderTest < ActiveSupport::TestCase
  def setup
    super
    FileUtils::mkdir_p(expected_dir) unless Dir.exist?(expected_dir)
    FileUtils.rm_rf(expected_path) if File.exists?(expected_path)
  end

  def teardown
    super
    FileUtils::rm_rf(expected_dir) if Dir.exist?(expected_dir)
  end

  def member
    members(:f_student)
  end

  def question
    profile_questions(:profile_questions_1)
  end

  def expected_dir
    FileUploader.stubs(:uniq_code).returns(uniq_code)
    File.join("data/question_files/#{question.id}/#{member.id}/#{uniq_code}")
  end

  def uniq_code
    Digest::MD5.hexdigest('1')
  end

  def expected_path
    File.join(expected_dir, 'test_file.css')
  end

  def test_save_with_normal_file
    stream = fixture_file_upload(File.join('files', 'test_file.css'), 'text/css')
    ChronusS3Utils::S3Helper.expects(:store_in_s3)

    uploader = FileUploader.new(question.id, member.id, stream, max_file_size: AttachmentSize::END_USER_ATTACHMENT_SIZE, base_path: ProfileAnswer::TEMP_BASE_PATH)
    assert uploader.save
    assert uploader.valid?
    assert_equal [], uploader.errors

    assert_equal expected_path, uploader.path_to_file
  end

  def test_save_with_invlaid_extension_failure
    stream = fixture_file_upload(File.join('files', 'test_php.php'), 'application/octet-stream')

    uploader = FileUploader.new(question.id, member.id, stream, max_file_size: AttachmentSize::END_USER_ATTACHMENT_SIZE, base_path: ProfileAnswer::TEMP_BASE_PATH)
    assert_false uploader.save
    assert_false uploader.valid?
    assert_equal ["Attachment content type is restricted"], uploader.errors
  end

  def test_save_with_invalid_stream
    stream = File.join(Rails.root, 'files', 'test_file.css')

    uploader = FileUploader.new(question.id, member.id, stream, max_file_size: AttachmentSize::END_USER_ATTACHMENT_SIZE, base_path: ProfileAnswer::TEMP_BASE_PATH)
    assert_false uploader.save
    assert_false uploader.valid?
    assert_equal ['Input stream is invalid'], uploader.errors
    assert_false File.exists?(expected_path)
  end

  def test_save_with_infected_file
    stream = fixture_file_upload(File.join('files', 'test_file.css'), 'text/css')

    ClamScanner.stubs(:scan_file).returns(false)

    uploader = FileUploader.new(question.id, member.id, stream, max_file_size: AttachmentSize::END_USER_ATTACHMENT_SIZE, base_path: ProfileAnswer::TEMP_BASE_PATH)
    assert_false uploader.save
    assert_false uploader.valid?
    assert_equal ['File is infected'], uploader.errors
    assert_false File.exists?(expected_path)
  end

  def test_get_file_path_with_uploaded_file
    stream = fixture_file_upload(File.join('files', 'test_file.css'), 'text/css')
    ChronusS3Utils::S3Helper.expects(:store_in_s3)

    uploader = FileUploader.new(question.id, member.id, stream, max_file_size: AttachmentSize::END_USER_ATTACHMENT_SIZE, base_path: ProfileAnswer::TEMP_BASE_PATH)
    assert uploader.save

    path = File.join(ProfileAnswer::TEMP_BASE_PATH, question.id.to_s, member.id.to_s, uniq_code, 'test_file.css')
    ChronusS3Utils::S3Helper.expects(:get_bucket).returns("bucket")
    String.any_instance.expects(:objects).returns({ path => "bucket" })
    FileUploader.get_file_path(question.id, member.id, ProfileAnswer::TEMP_BASE_PATH, { code: uniq_code, file_name: 'test_file.css' })
  end
end