module CalendarSettingPermissions

  #check if slot availability is enabled at program level
  def is_allowed_to_set_slot_availability?
    is_calendar_enabled? && get_calendar_setting.allow_mentor_to_configure_availability_slots?
  end

  #check if general availability is enabled at program level
  def is_allowed_to_set_general_availability?
    is_calendar_enabled? && get_calendar_setting.allow_mentor_to_describe_meeting_preference?
  end

  def is_allowed_to_set_all_availability?
    is_allowed_to_set_slot_availability? && is_allowed_to_set_general_availability?
  end

  def is_allowed_to_set_only_slot_availability?
    is_allowed_to_set_slot_availability? && !is_allowed_to_set_general_availability?
  end

  #check if slot availability is enabled at role level - user with mentor role can set this
  def can_set_slot_availability?
    is_allowed_to_set_slot_availability? && self.can_set_availability?
  end

   #check if general availability is enabled at role level - user with mentor role can set this
  def can_set_general_availability?
    is_allowed_to_set_general_availability? && self.can_set_availability?
  end

  def can_set_meeting_availability?
    can_set_slot_availability? || can_set_general_availability?
  end

  #check if the user has chosen slot availability in settings page
  def is_opted_for_slot_availability?
    can_set_slot_availability? && self.member.will_set_availability_slots
  end

  #check if the user has chosen general availability in settings page
  def is_opted_for_general_availability?
    can_set_general_availability? && !self.member.will_set_availability_slots
  end

  #check if the user can set availability preference text - user with mentee role can set this
  def can_set_mentee_general_availability_preference?
    is_calendar_enabled? && self.can_set_meeting_preference? && (!self.can_set_availability? || is_opted_for_slot_availability? || is_allowed_to_set_only_slot_availability?  )
  end

  private
  
  #below settings are at program level

  def is_calendar_enabled?
    self.program.calendar_enabled?
  end

  def get_calendar_setting
    self.program.calendar_setting
  end

end
