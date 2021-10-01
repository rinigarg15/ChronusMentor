require_relative './../test_helper.rb'

class VulnerableContentLogTest < ActiveSupport::TestCase
  def test_vulnerable_content_log_creation_without_args_must_fail
    e = assert_raise(ActiveRecord::RecordInvalid) do
      VulnerableContentLog.create!
    end

    assert_match(/Original content can't be blank/, e.message)
    assert_match(/Ref obj type can't be blank,/, e.message)
    assert_match(/Ref obj column can't be blank/, e.message)
    assert_match(/Member can't be blank,/, e.message)
  end
end