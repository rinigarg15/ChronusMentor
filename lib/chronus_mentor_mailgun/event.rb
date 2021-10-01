module ChronusMentorMailgun
  
  class Event
    OPENED      = 'opened'
    CLICKED     = 'clicked'
    DELIVERED   = 'delivered'
    DROPPED     = 'dropped'
    BOUNCED     = 'bounced'
    SPAMMED     = 'complained'
    FAILED      = 'failed'

    def self.get_events_string
      events_array = []
      Event.constants.each do |c|
        events_array << Event.const_get(c)
      end
      events_array.join(' OR ')
    end

  end

  
end
