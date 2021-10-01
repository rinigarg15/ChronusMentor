module CalendarIcsGenerator

  class << self

    def generate_ics_calendar(event, options = {})
      ics_event = get_ics_event(event, options)
      calendar = generate_ics_calendar_events(ics_event)
      calendar.export
    end

    def generate_ics_calendar_for_deletion(options = {})
      ics_event = get_ics_event_for_deletion(options)
      calendar = generate_ics_calendar_events_for_deletion(ics_event)
      calendar.export
    end

    private

    def get_ics_event_for_deletion(options = {})
      encrypted_program_event_id = ProgramEvent::encryptor.encrypt(options[:program_event_id])
      organizer = {name: APP_CONFIG[:scheduling_assistant_display_name], email: "#{APP_CONFIG[:reply_to_program_event_calendar_notification]}+#{encrypted_program_event_id}@#{MAILGUN_DOMAIN}"}
      event_options = {
        :start_time => DateTime.localize(options[:start_time].utc, format: :ics_full_time),
        :uid => "program_event_#{DateTime.localize(options[:created_at].utc, format: :ics_full_time)}@chronus.com",
        :topic => options[:title][I18n.default_locale],
        :organizer => organizer
      }
      return [event_options]
    end

    def generate_ics_calendar_events_for_deletion(ics_events_array)
      cal = RiCal.Calendar do |calobj|
        calobj.icalendar_method = "CANCEL"
        ics_events_array.each do |ics_event|
          calobj.event do |event|
            event.dtstart = DateTime.parse(DateTime.localize(ics_event[:start_time].to_time.utc, format: :ics_full_time))
            event.uid = ics_event[:uid]
            event.status = "CANCELLED"
            event.summary = ics_event[:topic]
            options = {'CUTYPE' => 'INDIVIDUAL','ROLE' => 'REQ-PARTICIPANT'}
            event.organizer_property = RiCal::PropertyValue::CalAddress.new(nil, :value => "mailto:"+ics_event[:organizer][:email], :params => options)
          end
        end
      end
      return cal
    end

    def get_ics_event(events, options = {})
      events_data = [events].flatten
      events_data.map do |event|
        start_time, end_time = ProgramEvent.get_event_start_and_end_time(event)
        {
          event_id: event.id,
          start_time: start_time,
          end_time: end_time,
          guest_details: ics_guests_details(event, options[:user]),
          topic: event.title,
          description: event.get_description_for_calendar_event,
          location: event.location,
          uid: event.get_calendar_event_uid,
          organizer: ProgramEvent.ics_organizer(event)
        }
      end
    end

    def generate_ics_calendar_events(ics_events_array, options = {})
      cal = RiCal.Calendar do |calobj|
        calobj.icalendar_method = "REQUEST"
        ics_events_array.each do |ics_event|
          event = ProgramEvent.unscoped.find_by(id: ics_event[:event_id])
          calobj.event do |event|
            event = date_and_time_initialization(event, ics_event.slice(:start_time, :end_time))
            event.attendee_property = attendee_property(ics_event[:guest_details])
            event.organizer_property = event_organizer_property(ics_event[:organizer])
            event = event_details(event, ics_event.slice(:description, :location, :topic, :uid))
            event.transp = "OPAQUE"
          end
        end
      end
      return cal
    end

    def event_organizer_property(organizer)
      options = {'CN' => organizer[:name]}
      RiCal::PropertyValue::CalAddress.new(nil, :value => "mailto:"+organizer[:email], :params => options)
    end

    def event_details(event, options = {})
      event.uid = options[:uid]
      event.description = options[:description].present? ? options[:description] : "feature.meetings.content.meeting_scheduled_in_program_v1".translate(:program => Program.name, :Meeting => ProgramEvent.name)
      event.location = options[:location] if options[:location].present?
      event.status = "CONFIRMED"
      event.summary = options[:topic]
      return event
    end

    def date_and_time_initialization(event, options = {})
      event.dtstart = DateTime.parse(DateTime.localize(options[:start_time].to_time.utc, format: :ics_full_time))
      event.dtend = DateTime.parse(DateTime.localize(options[:end_time].to_time.utc, format: :ics_full_time)) if options[:end_time].present?
      event.dtstamp = event.created = event.last_modified = DateTime.parse(DateTime.localize(Time.now.utc, format: :ics_full_time))
      return event
    end

    def attendee_property(guest_details)
      options = {'CUTYPE' => 'INDIVIDUAL','ROLE' => 'REQ-PARTICIPANT'}
      guest_details.map do |guest|
        RiCal::PropertyValue::CalAddress.new(nil, :value => "mailto:"+guest[:email], :params => options.merge('CN' => guest[:name], 'PARTSTAT' => guest[:part_stat] || Meeting::CalendarEventPartStatValues::NEEDS_ACTION))
      end
    end

    def ics_guests_details(event, user)
      [{ email: user.email, name: user.name,
        part_stat: EventInvite::CALENDAR_EVENT_TO_PROGRAM_EVENT_RSVP_MAP_ICS.invert[event.event_invites.for_user(user).first.try(:status)] || ProgramEvent::CalendarEventPartStatValues::NEEDS_ACTION
      }]
    end

  end
end

