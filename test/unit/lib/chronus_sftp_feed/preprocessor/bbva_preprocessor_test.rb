# -*- encoding: utf-8 -*-
require_relative './../../../../test_helper'

class BbvaPreprocessorTest < ActiveSupport::TestCase

  def test_pre_process
    options = { organization_name: programs(:org_primary).subdomain, is_encrypted: false }

    file = ChronusSftpFeed::Preprocessor::BbvaPreprocessor.pre_process("test/fixtures/files/feed_migrator/bbva/20130205043201_bbva_create_invalid.csv", options)
    csv_records = CSV.read(file)
    assert_empty csv_records.collect { |row| row[2] } & ChronusSftpFeed::Preprocessor::BbvaPreprocessor::IGNORE_MAILS
    assert_equal "", csv_records[4][4]
    assert_equal "sc64315", csv_records[4][5]
  end
end