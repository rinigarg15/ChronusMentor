# -*- encoding: utf-8 -*-
require_relative './../../../../test_helper'

class CokePreprocessorTest < ActiveSupport::TestCase

  def test_pre_process
    options = { organization_name: "cocacolamentoring", is_encrypted: false }

    file = ChronusSftpFeed::Preprocessor::CokePreprocessor.pre_process("test/fixtures/files/feed_migrator/coke/2017_coke_create_sample.csv", options)
    csv_records = CSV.read(file)
    int_data_column_index = csv_records[0].index(ChronusSftpFeed::Preprocessor::CokePreprocessor::INT_DATA_COLUMN)
    assert_equal "1", csv_records[1][int_data_column_index]
    assert_nil csv_records[2][int_data_column_index]
  end
end