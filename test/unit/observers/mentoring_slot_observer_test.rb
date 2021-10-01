require_relative './../../test_helper.rb'

class MentoringSlotObserverTest < ActiveSupport::TestCase

  def test_before_save
    mentoring_slots(:f_mentor).update_attributes(:start_time => "2011-03-01 17:00:00", :end_time => "2011-03-01 19:00:00")
    assert mentoring_slots(:f_mentor).update_attributes(:repeats_end_date => "2011-03-06")
    assert_nil mentoring_slots(:f_mentor).repeats_end_date
    assert mentoring_slots(:f_mentor).reload.update_attributes(:repeats_end_date => "2011-03-06", :repeats => MentoringSlot::Repeats::WEEKLY, :repeats_on_week => "0")
    assert_time_string_equal mentoring_slots(:f_mentor).repeats_end_date, "2011-03-06 00:00:00".to_date
  end
  
end