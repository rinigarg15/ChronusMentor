require_relative './../../test_helper.rb'

class DataImportsHelperTest < ActionView::TestCase

  def test_data_import_status_display_text
    di = create_data_import
    di.status = DataImport::Status::SUCCESS
    assert_equal '<strong class="text-navy">Success</strong>', data_import_status_display_text(di)
    di.status = DataImport::Status::FAIL
    assert_equal '<strong class="text-danger">Failed</strong>', data_import_status_display_text(di)
    di.status = DataImport::Status::SKIPPED
    assert_equal '<strong class="text-muted">Skipped</strong>', data_import_status_display_text(di)
  end

  def test_additional_information_text
    di = create_data_import
    di.status = DataImport::Status::SUCCESS
    di.created_count = 5
    di.updated_count = 6
    di.suspended_count = 7
    assert_equal "Member records (created: 5, updated: 6, suspended: 7)", additional_information_text(di)
    di.status = DataImport::Status::FAIL
    di.failure_message = "Error"
    assert_equal di.failure_message, additional_information_text(di)
    di.status = DataImport::Status::SKIPPED
    assert_equal "Skipped due to availability of new version file", additional_information_text(di)
  end

  def test_source_file_created_at
    file_name = "20130205043201_rc_test.csv"
    assert_equal source_file_created_at(file_name), "February 05, 2013 at 04:32 AM"
  end
end
