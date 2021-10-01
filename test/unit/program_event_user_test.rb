require_relative './../test_helper.rb'

class ProgramEventUserTest < ActiveSupport::TestCase
  def test_belongs_to
    event = program_events(:birthday_party)    
    assert_equal 44, event.program_event_users.size
  end

end