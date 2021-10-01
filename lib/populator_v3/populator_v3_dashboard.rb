# encoding: UTF-8
class PopulatorV3Dashboard
  attr_accessor :status, :sub_status, :progress_total, :progress, :sub_progress,
    :sub_progress_total, :heading

  STATUS_MSG_LEN = 50

  def initialize(options = {})
    @screen = options[:screen]
    status = options[:status] || "*"
    sub_status = options[:sub_status] || "*"
    @progress_total = options[:progress_total] || 1
    @progress = options[:progress] || 0
    @sub_progress_total = options[:sub_progress_total] || 1
    @sub_progress = options[:sub_progress] || 0
    @heading = options[:heading] || "Populator V3"
    @status_history = []
    @sub_status_history = []
    @_status_timestamp = Time.now
    @_dot_counter = 0
    @_dot_graphics = [
      "    ",
      "=   ",
      "==  ",
      "=== ",
      " ===",
      "  ==",
      "   ="
    ]
    @_dot_graphics_slides = 7
  end

  def flush
    $stdout.flush
  end

  def increment_progress(i)
    @progress += i
  end

  def status=(new_status)
    if @status != new_status
      time_taken = Time.now - @_status_timestamp
      @status_history << {from: @status, to: new_status, time_taken: time_taken}
      @status = new_status
      @_status_timestamp = Time.now
      increment_progress(1)
      @_dot_counter += 1
    end
    @status
  end

  def status_progress_bar
    len = 120
    fill = @progress * len / @progress_total
    scr_puts("\r|#{"█"*(fill)}#{"·"*([len-fill, 0].max)}|")
  end

  def print_history
    scr_puts("\n\nTime taken in each state:")
    @status_history.last(50).each do |status|
      scr_puts "#{"%-#{STATUS_MSG_LEN}s"%status[:from]} => #{DataPopulator.formatted_populator_time_display(status[:time_taken])}"
    end
  end

  def refresh(options = {})
    if @screen
      options.each do |k, v|
        send(:"#{k}=", v) if respond_to?(:"#{k}=")
      end
      system("clear")
      scr_puts("#{' ' * 40}***** #{@heading} ***** \n\n")
      scr_puts("STATUS (#{dot}) : '#{status}'")
      status_progress_bar
      print_history
      flush
    end
  end

  def dot
    @_dot_graphics[@_dot_counter % @_dot_graphics_slides]
  end

  def scr_puts(*args)
    puts(*args)
  end
end