module WeekCalculator
  def week_of_year(mondays = false)
    # Use %U for weeks starting on Sunday
    # Use %W for weeks starting on Monday
    strftime(mondays ? "%W" : "%U").to_i + 1
  end

  def week_of_month(mondays = false)
    week_of_year(mondays) - beginning_of_month.week_of_year(mondays) + 1
  end

  # gives array of days in month
  # Date.new(2012,1,1).days_array
  #   => [ 1, 2, 3, 4, 5, 6, 7, 8, 9,
  #        10, 11, 12, 13, 14, 15, 16,
  #        17, 18, 19, 20, 21, 22, 23,
  #        24, 25, 26, 27, 28, 29, 30,
  #        31]
  # @return [Array]
  def days_array
    day = self.beginning_of_month.to_date.wday
    array = []
    array[day] = 1
    (2..self.end_of_month.mday).each {|i| array << i }
    array
  end

  # returns week split of the month for the given date
  # example-
  # Date.new(2012,1,1).week_split
  #   => [[1, 2, 3, 4, 5, 6, 7],
  #       [8, 9, 10, 11, 12, 13, 14],
  #       [15, 16, 17, 18, 19, 20, 21],
  #       [22, 23, 24, 25, 26, 27, 28],
  #       [29, 30, 31]
  # @return [Array]
  def week_split
    days_array.each_slice(7).to_a
  end

  # it returns date of the previous week day.
  # Date.new(2012,11,15).previous_week
  #   => #<Date: 2012-11-08 ((2456240j,0s,0n),+0s,2299161j)>
  # Time.new(2012,11,30).previous_week
  #   => 2012-11-29 23:59:53 +0530
  # @return [Date || Time]
  def previous_week
    if self.class == Date
      self - 7
    elsif self.class == Time
      self - (60 * 60 * 24 * 7)
    end
  end
end

class Date
  include WeekCalculator
end

class Time
  include WeekCalculator
  def round_to_next(options={})
    time = self.to_a
    interval = options[:interval] || 30
    window = ((time[1] % 60) / (interval.to_f)).ceil
    time[1] = (window * interval) % 60
    timezone = options[:timezone] || "local"
    Time.send("#{timezone}", *time) + (window == (60/interval) ? 3600 : 0)
  end
end