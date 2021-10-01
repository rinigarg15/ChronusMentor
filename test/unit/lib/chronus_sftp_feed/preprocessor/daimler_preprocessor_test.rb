# -*- encoding: utf-8 -*-
require_relative './../../../../test_helper'

class DaimlerPreprocessorTest < ActiveSupport::TestCase

  def test_pre_process
    options = { organization_name: programs(:org_primary).subdomain, is_encrypted: false }
    file = "test/fixtures/files/feed_migrator/daimler/20130205043201_daimler_create_invalid.csv"
    original_csv = SmarterCSV.process(file, ChronusSftpFeed::Constant::CSV_OPTIONS.merge(chunk_size: nil, col_sep: "\;"))

    file = ChronusSftpFeed::Preprocessor::DaimlerPreprocessor.pre_process(file, options)
    csv_records = CSV.read(file)
    assert_equal ChronusSftpFeed::Preprocessor::DaimlerPreprocessor::LOCATION_MAP[original_csv[0]["dcxLocationID"]], csv_records[1][4]
    assert_equal ChronusSftpFeed::Preprocessor::DaimlerPreprocessor::JOB_GRADE[original_csv[0]["dcxManagementLevel"]], csv_records[1][13]
    assert_equal original_csv[2]["dcxLocationID"], csv_records[3][4]
    assert_equal original_csv[2]["dcxManagementLevel"], csv_records[3][13]
  end
end