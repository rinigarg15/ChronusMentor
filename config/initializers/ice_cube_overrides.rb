unless Rails.env.test?
  module IceCube
    class Schedule
      def to_s
        raise "Unexpected Invocation: meeting.schedule.to_s! Use MeetingScheduleStringifier.stringify instead!"
      end
    end
  end
end