require_relative './../../../test_helper.rb'

class ExportImportCommonUtilsTest < ActiveSupport::TestCase

  def test_zip_all_files_in_dir
    path = File.join(self.class.fixture_path, "files", "solution_pack_123")
    SolutionPack::ExportImportCommonUtils.zip_all_files_in_dir(path)
    assert File.exists?("#{path}.zip")
    FileUtils.rm "#{path}.zip", :force=>true
  end

  def test_unzip_file
    path = File.join(self.class.fixture_path, "files", "solution_pack.zip")
    unzipped_dir = SolutionPack::ExportImportCommonUtils.unzip_file(path)

    correct_directory = File.join(self.class.fixture_path, "files", "solution_pack_123")
    correct_file_list = Dir["#{correct_directory}/**/*"]
    correct_file_list.each{|file| file.sub!( "solution_pack_123", "solution_pack" )}
    assert_equal_unordered correct_file_list, Dir["#{unzipped_dir}/**/*"]
    FileUtils.rm_rf unzipped_dir
  end

end