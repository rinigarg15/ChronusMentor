# -*- encoding: utf-8 -*-
require_relative './../../../../test_helper'

class PaychexPreprocessorTest < ActiveSupport::TestCase

  def test_pre_process
    csv_options = ChronusSftpFeed::Constant::CSV_OPTIONS.merge(chunk_size: nil, file_encoding: UTF8_BOM_ENCODING)
    options = { organization_name: "paychex-tmp", is_encrypted: false }

    file = ChronusSftpFeed::Preprocessor::PaychexPreprocessor.pre_process("test/fixtures/files/feed_migrator/paychex/paychex_data_2016071143201.csv", options)
    csv_records = SmarterCSV.process(file, csv_options)
    assert_equal 2, csv_records.count
    assert_equal_unordered ["First Name", "Last Name", "User Email", "Location", "Car-goals", "qn1", "qn2", "qn3", "qn4", "qn5", "qn6", "qn7", "qn8", "qn9"], csv_records.first.keys
    assert_equal "HR", csv_records[0]["First Name"]
    assert_equal "Test", csv_records[0]["Last Name"]
    assert_equal "Location Test", csv_records[1]["Location"]
    assert_equal "Agency Operations, PEO Operations, Shared Services, SurePayroll", csv_records[0]["qn9"]
  end
end