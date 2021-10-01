class MentoringSlotObserver < ActiveRecord::Observer

  def before_save(mentoring_slot)
    mentoring_slot.repeats_end_date = nil if mentoring_slot.repeats == MentoringSlot::Repeats::NONE
    return nil
  end

end