class ChangeCalendarSettings< ActiveRecord::Migration[4.2]
  def up
    change_table :calendar_settings do |t|
      t.boolean :allow_mentor_to_configure_availability_slots
      t.boolean :allow_mentor_to_describe_meeting_preference
    end
    CalendarSetting.find_each do |cs|
      cs.allow_mentor_to_configure_availability_slots = true
      if cs.allow_mentor_to_not_set_availability
        cs.allow_mentor_to_describe_meeting_preference = true
      end
      cs.save!(validate: false)
    end
    remove_column :calendar_settings, :allow_mentor_to_not_set_availability
  end

  def down
    add_column :calendar_settings, :allow_mentor_to_not_set_availability, :boolean

    CalendarSetting.find_each do |cs|
      if cs.allow_mentor_to_set_all_availability?
        cs.allow_mentor_to_not_set_availability = true
      else
        cs.allow_mentor_to_not_set_availability = false
      end
      cs.save!(validate: false)
    end
    remove_column :calendar_settings, :allow_mentor_to_configure_availability_slots
    remove_column :calendar_settings, :allow_mentor_to_describe_meeting_preference
  end
end
