require_relative './../../../test_helper'

class CsvImporter::ProcessedRowTest < ActiveSupport::TestCase

  def test_select_rows_where
    rows = [users(:f_mentor), members(:f_admin)]
    users(:f_mentor).stubs(:something).returns(true)
    members(:f_admin).stubs(:something).returns(false)
    assert_equal [users(:f_mentor)], CsvImporter::ProcessedRow.select_rows_where(rows, :something)
  end

  def test_has_errors
    processed_row = CsvImporter::ProcessedRow.new("something", "somethingelse")
    assert_false processed_row.has_errors?
    processed_row.errors = "something else"
    assert processed_row.has_errors?
    processed_row.errors = {}
    assert_false processed_row.has_errors?
    processed_row.errors = []
    assert_false processed_row.has_errors?
  end

  def test_can_show_errors
    processed_row = CsvImporter::ProcessedRow.new("something", "somethingelse")
    assert_false processed_row.has_errors?
    processed_row.errors = "something else"
    processed_row.is_suspended_member = false
    assert processed_row.can_show_errors?
    processed_row.is_suspended_member = true
    assert_false processed_row.can_show_errors?
    processed_row.errors = {}
    assert_false processed_row.can_show_errors?
    processed_row.errors = []
    assert_false processed_row.has_errors?
  end

  def test_active_profile
    processed_row = CsvImporter::ProcessedRow.new("something", "somethingelse")
    assert_false processed_row.active_profile?
    processed_row.state = User::Status::ACTIVE
    assert processed_row.active_profile?
    processed_row.stubs(:user_to_be_invited).returns(true)
    assert_false processed_row.active_profile?
    processed_row.stubs(:user_to_be_invited).returns(false)
    processed_row.stubs(:user_to_be_updated).returns(true)
    assert_false processed_row.active_profile?
    processed_row.stubs(:user_to_be_updated).returns(false)
    processed_row.stubs(:has_errors?).returns(true)
    assert_false processed_row.active_profile?
    processed_row.stubs(:has_errors?).returns(false)
    processed_row.stubs(:is_suspended_member).returns(true)
    assert_false processed_row.active_profile?
  end

  def test_pending_profile
    processed_row = CsvImporter::ProcessedRow.new("something", "somethingelse")
    assert_false processed_row.pending_profile?
    processed_row.state = User::Status::PENDING
    assert processed_row.pending_profile?
    processed_row.stubs(:user_to_be_invited).returns(true)
    assert_false processed_row.pending_profile?
    processed_row.stubs(:user_to_be_invited).returns(false)
    processed_row.stubs(:user_to_be_updated).returns(true)
    assert_false processed_row.pending_profile?
    processed_row.stubs(:user_to_be_updated).returns(false)
    processed_row.stubs(:has_errors?).returns(true)
    assert_false processed_row.pending_profile?
    processed_row.stubs(:has_errors?).returns(false)
    processed_row.stubs(:is_suspended_member).returns(true)
    assert_false processed_row.pending_profile?
  end

  def test_is_suspended_member
    processed_row = CsvImporter::ProcessedRow.new("something", "somethingelse")
    assert_false processed_row.is_suspended_member?
    processed_row.is_suspended_member = true
    assert processed_row.is_suspended_member?
  end

  def test_is_user_to_be_invited
    processed_row = CsvImporter::ProcessedRow.new("something", "somethingelse")
    assert_false processed_row.is_user_to_be_invited?
    processed_row.user_to_be_invited = true
    assert processed_row.is_user_to_be_invited?
    processed_row.stubs(:has_errors?).returns(true)
    assert_false processed_row.is_user_to_be_invited?
    processed_row.stubs(:has_errors?).returns(false)
    processed_row.stubs(:is_suspended_member).returns(true)
    assert_false processed_row.is_user_to_be_invited?
  end

  def test_is_user_to_be_updated
    processed_row = CsvImporter::ProcessedRow.new("something", "somethingelse")
    assert_false processed_row.is_user_to_be_updated?
    processed_row.user_to_be_updated = true
    assert processed_row.is_user_to_be_updated?
    processed_row.stubs(:has_errors?).returns(true)
    assert_false processed_row.is_user_to_be_updated?
    processed_row.stubs(:has_errors?).returns(false)
    processed_row.stubs(:is_suspended_member).returns(true)
    assert_false processed_row.is_user_to_be_updated?
  end

  def test_set_program_level_information
    processed_row = CsvImporter::ProcessedRow.new("something", "somethingelse")
    assert_nil processed_row.state
    assert_nil processed_row.user_to_be_invited
    processed_row.set_program_level_information("one", "two")
    assert_equal "one", processed_row.state
    assert_equal "two", processed_row.user_to_be_invited
  end

  def test_has_custom_login_identifier
    processed_row = CsvImporter::ProcessedRow.new({}, {})
    assert_false processed_row.has_custom_login_identifier?

    processed_row.data = { UserCsvImport::CsvMapColumns::UUID.to_sym => "uid" }
    assert processed_row.has_custom_login_identifier?
  end
end