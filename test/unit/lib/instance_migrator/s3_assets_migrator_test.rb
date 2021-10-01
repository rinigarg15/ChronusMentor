require_relative './../../../test_helper'
class S3AssetsMigratorTest < ActiveSupport::TestCase
  def test_migrate_s3_assets_invalid_cases
    options = {access_key: "test", secret_key: "test", source_region: "us-east-1", target_region: "us-east-1", target_bucket_name: "dummy_target_bucket"}
    s3_migrator = InstanceMigrator::S3AssetsMigrator.new("source_environment", "source_seed", "invalid_file", options)
    assert_raise "S3 Assets csv file is not present" do
      s3_migrator.migrate_assets
    end
    # without target_bucket_name
    options.delete(:target_bucket_name)
    s3_migrator = InstanceMigrator::S3AssetsMigrator.new("source_environment", "source_seed", dummy_file_name, options)
    assert_raise "Target bucket name should be present" do
      s3_migrator.migrate_assets
    end
    # without access keys
    assert_raise RuntimeError, "Access_key, Secret_key, Source region and Target Region should be present" do
      s3_migrator = InstanceMigrator::S3AssetsMigrator.new("source_environment", "source_seed", "invalid_file")
      s3_migrator.migrate_assets
    end
  end

  def test_migrate_assets
    create_s3_assets_csv
    article_content = article_contents(:economy)
    ArticleContent.where(id: article_content.id).update_all(source_audit_key: "source_environment_source_seed_10")
    organization = programs(:org_primary)
    Organization.where(id: organization.id).update_all(source_audit_key: "source_environment_source_seed_11")
    options = {access_key: "test", secret_key: "test", source_region: "us-east-1", target_region: "us-east-1", target_bucket_name: "dummy_target_bucket", source_common_bucket: "dummy_source_common_bucket", target_common_bucket: "dummy_target_common_bucket", source_org_id: "11"}
    s3_migrator = InstanceMigrator::S3AssetsMigrator.new("source_environment", "source_seed", dummy_file_name, options)
    Organization.any_instance.stubs(:has_saml_auth?).returns(true)
    AWS::S3::S3Object.any_instance.stubs(:copy_to)
    s3_objects = [AWS::S3.new.buckets["dummy_source_common_bucket"].objects["saml-sso-files/11/20160128085356_IDP_Metadata.xml"]]
    AWS::S3::ObjectCollection.any_instance.stubs(:with_prefix).returns(
      s3_objects)
    s3_migrator.migrate_assets
    csv = CSV.read(processed_dummy_file)
    assert_equal [["dummy_bucket", "dummy_target_bucket", "article_contents/attachments/10/original.jpg", "article_contents/attachments/#{article_content.id}/original.jpg", "successfully copied"], ["dummy_source_common_bucket", "dummy_target_common_bucket", "saml-sso-files/11/20160128085356_IDP_Metadata.xml", "saml-sso-files/#{organization.id}/20160128085356_IDP_Metadata.xml", "successfully copied"]], csv
  end

  def test_check_new_folder_added_to_common_bucket
    file_content = File.read("#{Rails.root}/test/fixtures/files/instance_migrator/common_bucket_code_references.txt")
    actual_content = `grep -R "APP_CONFIG\\[:chronus_mentor_common_bucket\\]" #{Rails.root}/app #{Rails.root}/lib #{Rails.root}/vendor | sort | sed 's/#{Rails.root.to_s.gsub('/', '\/')}/ /'`
    # If any new folder is added to the chronus_mentor_common_bucket which have MODEL_ID as a sub-folder please handle it in InstanceMigrator::S3AssetsMigrator#migrate_assets. To pass the test run the following command in rails console. `grep -R "APP_CONFIG\\[:chronus_mentor_common_bucket\\]" #{Rails.root}/app #{Rails.root}/lib #{Rails.root}/vendor | sort | sed 's/#{Rails.root.to_s.gsub('/', '\/')}/ /' > #{Rails.root}/test/fixtures/files/instance_migrator/common_bucket_code_references.txt`
    assert_equal Digest::SHA1.hexdigest(actual_content), Digest::SHA1.hexdigest(file_content)
  end

  private
  def create_s3_assets_csv
    CSV.open(dummy_file_name, "w", {encoding: "utf-8"}) do |csv|
      csv << ["dummy_bucket","article_contents/attachments/10/original.jpg","ArticleContent","10", "attachment"]
    end
  end

  def dummy_file_name
    "tmp/s3_assets.csv"
  end

  def processed_dummy_file
    File.join(File.dirname(dummy_file_name), "#{File.basename(dummy_file_name, File.extname(dummy_file_name))}_processed#{File.extname(dummy_file_name)}")
  end

  def teardown
    super
    FileUtils.rm_f(dummy_file_name)
    FileUtils.rm_f(processed_dummy_file)
  end

end