require_relative './../../../test_helper.rb'

class EventTest < ActiveSupport::TestCase
  def test_get_events_string_should_return_or_concatenated_string_of_events
    assert_equal_unordered ["opened", "clicked", "delivered", "dropped", "bounced", "complained", "failed"], ChronusMentorMailgun::Event.get_events_string.split(' OR ')
  end
end