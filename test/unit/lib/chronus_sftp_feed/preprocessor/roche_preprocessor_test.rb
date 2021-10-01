# -*- encoding: utf-8 -*-
require_relative './../../../../test_helper'

class RochePreprocessorTest < ActiveSupport::TestCase

  def test_pre_process
    options = { organization_name: programs(:org_primary).subdomain, is_encrypted: false }
    file = "test/fixtures/files/feed_migrator/roche/20130205043201_roche_create_invalid.csv"
    original_file = CSV.read(file)

    file = ChronusSftpFeed::Preprocessor::RochePreprocessor.pre_process(file, options)
    csv_records = CSV.read(file)
    assert_equal 1, original_file.collect { |row| row.count }.to_set.first - csv_records.collect { |row| row.count }.to_set.first
  end
end