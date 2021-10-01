require_relative './../test_helper.rb'

class DataImportTest < ActiveSupport::TestCase
  def test_recent_first
    Timecop.freeze(Time.now) do
      d1 = create_data_import
      d2 = create_data_import
      d2.update_attribute(:created_at, Date.today + 30)
      d2.reload
      d3 = create_data_import
      d3.update_attribute(:created_at, Date.today - 30)
      d3.reload
      assert_equal [d2, d1, d3], DataImport.recent_first.all
    end
  end

  def test_success
    d1 = create_data_import
    assert_equal DataImport::Status::SUCCESS, d1.status
    assert d1.success?
    d1.status = DataImport::Status::FAIL
    assert_false d1.success?
  end

  def test_validate_presence_source_file_file_name
    org = programs(:org_primary)
    status = DataImport::Status::SUCCESS
    di = DataImport.create({organization_id: org.id, status: status})
    assert_equal false, di.valid?
    assert_equal(["can't be blank"], di.errors.messages[:source_file_file_name])
  end
end
