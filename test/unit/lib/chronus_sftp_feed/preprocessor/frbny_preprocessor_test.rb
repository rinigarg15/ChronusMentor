# -*- encoding: utf-8 -*-
require_relative './../../../../test_helper'

class FrbnyPreprocessorTest < ActiveSupport::TestCase

  def test_pre_process
    options = { organization_name: programs(:org_primary).subdomain, is_encrypted: false }
    file = "test/fixtures/files/feed_migrator/frbny/20130205043201_frbny_create_invalid.csv"
    original_file = CSV.read(file)

    file = ChronusSftpFeed::Preprocessor::FrbnyPreprocessor.pre_process(file, options)
    csv_records = CSV.read(file)
    index_of_data_merge_hash = csv_records[0].index(ChronusSftpFeed::Preprocessor::FrbnyPreprocessor::DATA_MERGE_HASH.first[0])
    index1 = original_file[0].index(ChronusSftpFeed::Preprocessor::FrbnyPreprocessor::DATA_MERGE_HASH.first[1][0])
    index2 = original_file[0].index(ChronusSftpFeed::Preprocessor::FrbnyPreprocessor::DATA_MERGE_HASH.first[1][1])
    index3 = original_file[0].index(ChronusSftpFeed::Preprocessor::FrbnyPreprocessor::DATA_MERGE_HASH.first[1][2])
    index4 = original_file[0].index(ChronusSftpFeed::Preprocessor::FrbnyPreprocessor::DATA_MERGE_HASH.first[1][3])
    assert_equal original_file[1][index1] + ',' + original_file[1][index2] + ',' + original_file[1][index3] + ',' + original_file[1][index4], csv_records[1][index_of_data_merge_hash]
    assert_equal ",,,", csv_records[5][index_of_data_merge_hash]
  end
end