require_relative './../test_helper.rb'

class SolutionPackTest < ActiveSupport::TestCase
  def test_initialize_base_path
    Timecop.freeze do
      sp = SolutionPack.new(:program => programs(:albers))
      sp.initialize_base_path
      assert "#{Rails.root}/tmp/solution_pack/SolutionPack_#{Time.now.to_i}", sp.base_directory_path
      assert "#{Rails.root}/tmp/solution_pack", sp.parent_directory_path
    end
  end

  def test_export
    Timecop.freeze do
      SolutionPack.any_instance.expects(:rand).with(10000).at_least(0).returns(2323)
      dummy_attachment_path = File.join(self.class.fixture_path, "files", "solution_pack.zip")
      sp = SolutionPack.new(:program => programs(:albers), :created_by => "c by", :description => "desc")
      sp.initialize_base_path

      SolutionPack::ExportImportCommonUtils.expects(:zip_all_files_in_dir).with(sp.base_path).returns(dummy_attachment_path)
      options = {}
      program_exporter = ProgramExporter.new(sp.program, sp, options)
      ProgramExporter.expects(:new).with(sp.program, sp, options).once.returns(program_exporter)
      program_exporter.expects(:export).with().once
      FileUtils.expects(:rm).with(dummy_attachment_path).returns()

      sp.export(options)
      assert_false File.exists?(sp.base_directory_path)
    end
  end

  def test_export_without_save
    Timecop.freeze do
      SolutionPack.any_instance.expects(:rand).with(10000).at_least(0).returns(2323)
      dummy_attachment_path = File.join(self.class.fixture_path, "files", "solution_pack.zip")
      sp = SolutionPack.new(:program => programs(:albers), :created_by => "c by", :description => "desc", :is_sales_demo => true)
      sp.initialize_base_path

      SolutionPack::ExportImportCommonUtils.expects(:zip_all_files_in_dir).with(sp.base_path).returns(dummy_attachment_path)
      options = {target_location: Rails.root + "/tmp/dummy"}
      program_exporter = ProgramExporter.new(sp.program, sp, options)
      ProgramExporter.expects(:new).with(sp.program, sp, options).once.returns(program_exporter)
      program_exporter.expects(:export).with().once
      FileUtils.expects(:mv).with(dummy_attachment_path, Rails.root + "/tmp/dummy")

      sp.export(options)
      assert_false File.exists?(sp.base_directory_path)
    end
  end

  def test_import
    SolutionPack.any_instance.expects(:rand).with(10000).at_least(0).returns(2323)
    FileUtils::cp(File.join(self.class.fixture_path, "files", "solution_pack.zip"), "./tmp/")
    zip_file_path = Rails.root.to_s+"/tmp/solution_pack.zip"
    expected_base_directory_path = Rails.root.to_s+"/tmp/solution_pack_2323/"
    ProgramImporter.any_instance.expects(:import).returns()
    FileUtils.expects(:rm).with(zip_file_path)
    FileUtils.expects(:rm_rf).with(expected_base_directory_path)

    sp = SolutionPack.new(:program => programs(:albers))
    sp.import(zip_file_path)
    assert_equal expected_base_directory_path, sp.base_directory_path
    assert_equal "iitm.localhost.com", sp.ckeditor_old_base_url
    assert_equal_unordered Ckeditor::Asset.column_names, sp.ck_editor_column_names
  end

  def test_import_sales_demo
    SolutionPack.any_instance.expects(:rand).with(10000).at_least(0).returns(2323)
    FileUtils::cp(File.join(self.class.fixture_path, "files", "solution_pack.zip"), "./tmp/")
    zip_file_path = Rails.root.to_s+"/tmp/solution_pack.zip"
    expected_base_directory_path = Rails.root.to_s+"/tmp/solution_pack_2323/"
    ProgramImporter.any_instance.expects(:import).returns()
    FileUtils.expects(:rm).with(zip_file_path)
    FileUtils.expects(:rm_rf).with(expected_base_directory_path)

    sp = SolutionPack.new(:program => programs(:albers))
    SolutionPack.any_instance.expects(:id_mappings).at_least_once.returns({"User" => { 123 => 125}})
    sp.import(zip_file_path, dump_location: Rails.root.to_s + "/tmp/id_mappings.yml")
    assert_equal expected_base_directory_path, sp.base_directory_path
    assert_equal "iitm.localhost.com", sp.ckeditor_old_base_url
    File.exist?(Rails.root.to_s + "/tmp/id_mappings.yml")
    assert_equal sp.id_mappings, YAML.load_file(Rails.root.to_s + "/tmp/id_mappings.yml")
  end

  def test_base_path
    Timecop.freeze do
      sp = SolutionPack.new(:program => programs(:albers))
      sp.initialize_base_path
      assert "#{Rails.root}/tmp/SolutionPack_#{Time.now.to_i}/", sp.base_path
    end
  end

  def test_base_path_with_file_path
    Timecop.freeze do
      SolutionPack.any_instance.expects(:rand).with(10000).at_least(0).returns(2323)
      sp = SolutionPack.new(:program => programs(:albers))
      sp.initialize_base_path("./tmp/sp_1234.zip")
      assert "#{Rails.root}/tmp/sp_1234_2323/", sp.base_path
    end
  end

  def test_ckeditor_base_path
    Timecop.freeze do
      sp = SolutionPack.new(:program => programs(:albers))
      sp.initialize_base_path
      assert "#{Rails.root}/tmp/SolutionPack_#{Time.now.to_i}/ckeditor/", sp.ckeditor_base_path
    end
  end

  def test_validate_presence_of_description_and_program_and_created_by
    assert_no_difference 'SolutionPack.count' do
      assert_raise_error_on_field(ActiveRecord::RecordInvalid, :description) do
        assert_raise_error_on_field(ActiveRecord::RecordInvalid, :program_id, nil, cascade: true) do
          assert_raise_error_on_field(ActiveRecord::RecordInvalid, :created_by, nil, cascade: true) do
            SolutionPack.create!
          end
        end
      end
    end
  end

  def test_read_metadata
    hash = {"a" => "c", "b" => "d"}
    file_path = "./tmp/metadata.json"
    File.open(file_path,"wb") do |f|
      f.write(hash.to_json)
    end

    sp = SolutionPack.new(:program => programs(:albers))
    SolutionPack.any_instance.expects(:metadata_file_path).with().at_least(0).returns(file_path)

    sp.read_metadata
    assert_equal hash["a"], sp.metadata_hash["a"]
    assert_equal hash["b"], sp.metadata_hash["b"]
    File.delete(file_path) if File.exist?(file_path)
  end

  def test_write_metadata
    hash = {"a" => "c", "b" => "d"}
    file_path = "./tmp/metadata.json"

    sp = SolutionPack.new(:program => programs(:albers))
    SolutionPack.any_instance.expects(:metadata_file_path).with().at_least(0).returns(file_path)
    sp.metadata_hash = hash
    sp.write_metadata
    assert File.exist?(file_path)

    file = File.read(file_path)
    new_hash = JSON.parse(file)

    assert_equal hash["a"], new_hash["a"]
    assert_equal hash["b"], new_hash["b"]

    File.delete(file_path) if File.exist?(file_path)
  end

end
