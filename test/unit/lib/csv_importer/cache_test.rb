require_relative './../../../test_helper'

class CsvImporter::CacheTest < ActiveSupport::TestCase

  def setup
    super
    @user_csv_import = UserCsvImport.new
    @user_csv_import.stubs(:id).returns(777)
    @data = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]
    @primary_key_proc = CsvImporter::Constants::CACHE_KEY
    @batch_key_proc = CsvImporter::Constants::INDEXED_CACHE_KEY
  end

  def test_write
    CsvImporter::Cache.stubs(:write_data).with("a", "b", CsvImporter::Constants::CACHE_KEY, CsvImporter::Constants::INDEXED_CACHE_KEY).once
    CsvImporter::Cache.write("a", "b")
  end

  def test_read
    CsvImporter::Cache.stubs(:read_data).with("a", CsvImporter::Constants::CACHE_KEY, CsvImporter::Constants::INDEXED_CACHE_KEY).once.returns("something")
    assert_equal "something", CsvImporter::Cache.read("a")
  end

  def test_delete
    CsvImporter::Cache.stubs(:delete_data).with("a", CsvImporter::Constants::CACHE_KEY, CsvImporter::Constants::INDEXED_CACHE_KEY).once
    CsvImporter::Cache.delete("a")
  end

  def test_write_failures
    CsvImporter::Cache.stubs(:write_data).with("a", "b", CsvImporter::Constants::FAILED_RECORDS_CACHE_KEY, CsvImporter::Constants::INDEXED_FAILED_RECORDS_CACHE_KEY).once
    CsvImporter::Cache.write_failures("a", "b")
  end

  def test_read_failures
    CsvImporter::Cache.stubs(:read_data).with("a", CsvImporter::Constants::FAILED_RECORDS_CACHE_KEY, CsvImporter::Constants::INDEXED_FAILED_RECORDS_CACHE_KEY).once.returns("something")
    assert_equal "something", CsvImporter::Cache.read_failures("a")
  end

  def test_delete_failures
    CsvImporter::Cache.stubs(:delete_data).with("a", CsvImporter::Constants::FAILED_RECORDS_CACHE_KEY, CsvImporter::Constants::INDEXED_FAILED_RECORDS_CACHE_KEY).once
    CsvImporter::Cache.delete_failures("a")
  end

  def test_write_data
    CsvImporter::Cache.send(:write_data, @user_csv_import, @data, @primary_key_proc, @batch_key_proc)
    assert_equal 2, Rails.cache.read(@primary_key_proc.call(@user_csv_import.id))
    assert_equal [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24], Rails.cache.read(@batch_key_proc.call(@user_csv_import.id, 0))
    assert_equal [25, 26], Rails.cache.read(@batch_key_proc.call(@user_csv_import.id, 1))
  end

  def test_read_data
    assert_nil CsvImporter::Cache.send(:read_data, @user_csv_import, @primary_key_proc, @batch_key_proc)
    CsvImporter::Cache.send(:write_data, @user_csv_import, @data, @primary_key_proc, @batch_key_proc)
    assert_equal @data, CsvImporter::Cache.send(:read_data, @user_csv_import, @primary_key_proc, @batch_key_proc)
  end

  def test_delete_data
    CsvImporter::Cache.send(:write_data, @user_csv_import, @data, @primary_key_proc, @batch_key_proc)
    assert_equal @data, CsvImporter::Cache.send(:read_data, @user_csv_import, @primary_key_proc, @batch_key_proc)
    CsvImporter::Cache.send(:delete_data, @user_csv_import, @primary_key_proc, @batch_key_proc)
    assert_nil CsvImporter::Cache.send(:read_data, @user_csv_import, @primary_key_proc, @batch_key_proc)
  end
end