# == Schema Information
#
# Table name: mentoring_slots
#
#  id                    :integer          not null, primary key
#  start_time            :datetime
#  end_time              :datetime
#  location              :text(65535)
#  repeats               :integer
#  member_id             :integer          not null
#  created_at            :datetime
#  updated_at            :datetime
#  repeats_end_date      :date
#  repeats_on_week       :string(255)
#  repeats_by_month_date :boolean          default(TRUE)
#  ics_sequence          :integer          default(0)
#

class MentoringSlot < ActiveRecord::Base

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:date, :start_time, :end_time, :location, :repeats_by_month_date, :repeats_on_week, :repeats_end_date_view, :repeats_every_option, :start_time_of_day, :end_time_of_day],
    :new => [:date, :start_time, :end_time, :location, :repeats_by_month_date, :repeats_on_week, :repeats_end_date_view, :repeats_every_option, :start_time_of_day, :end_time_of_day],
    :update => [:date, :start_time, :end_time, :location, :repeats_on_week, :repeats_end_date_view, :repeats_every_option, :repeats_by_month_date, :start_time_of_day, :end_time_of_day]
  }

  module Repeats
    NONE = 0
    DAILY = 1
    WEEKLY = 2
    MONTHLY = 3

    def self.all
      [NONE, DAILY, WEEKLY, MONTHLY]
    end

    DAYS_MAP = {
      NONE => 0,
      DAILY => 1,
      WEEKLY => 7,
      MONTHLY => 30
    }

    def self.days_map(repeats)
      DAYS_MAP[repeats]
    end
  end

  module OPTIONS_FOR_AVAILABILITY
    NONE = 0
    DAILY = 1
    WEEKLY = 2
    MONTHLY = 3
  end

  DATEPICKER_DATE_FORMAT = "MM dd, yy"

  DATE_TO_DATE_TIME_FORMAT = "%Y-%m-%d"

  belongs_to :member, inverse_of: :mentoring_slots

  validates_presence_of :start_time, :end_time, :repeats, :member
  validates_inclusion_of :repeats_by_month_date, :in => [true, false], :if => Proc.new{|m| m.repeats_monthly?}
  validates_presence_of :repeats_on_week, :if => Proc.new{|m| m.repeats_weekly?}
  
  validate :check_start_time_should_be_lesser
  validate :check_repeats_end_date
  validate :check_start_time_is_after_current_time, :on => :create

  scope :recurring, -> { where('repeats != ?', Repeats::NONE)}
  scope :non_recurring, -> { where(repeats: Repeats::NONE)}
  scope :between_time, Proc.new{|st,en| where("start_time > ? AND end_time <= ?", st.to_s(:db), en.to_s(:db))}
  scope :recurring_between_time, Proc.new{|en| where("start_time < ? ", en.to_s(:db))}

  attr_accessor :start_time_of_day, :end_time_of_day, :computed_start_time

  def self.fetch_start_and_end_time(date, start_time_of_day, end_time_of_day, start_time_next_day = false, end_time_next_day = false)
    s_time = DateTime.strptime(date + " " + start_time_of_day, MentoringSlot.calendar_datetime_format).to_time.utc
    e_time = DateTime.strptime(date + " " + end_time_of_day, MentoringSlot.calendar_datetime_format).to_time.utc

    # DateTime doesn't take care of DST, while Time does
    start_time = Time.zone.parse(DateTime.localize(s_time, format: :full_date_full_time))
    end_time = Time.zone.parse(DateTime.localize(e_time, format: :full_date_full_time))

    if start_time_next_day
      start_time +=1.day
    end

    if end_time_next_day
      end_time +=1.day
    end

    if end_time.seconds_since_midnight == 0
      end_time += 1.day
    end

    return [start_time, end_time]
  end

  def self.sort_slots!(available_slots)
    available_slots.sort!{|slot1, slot2| slot1[:start].to_time <=> slot2[:start].to_time}
  end

  def self.remove_slots_smaller_than_calendar_slot_time(slots, program)
    allowed_individual_slot_minutes = program.get_calendar_slot_time
    slots.select{|slot| !slot_duration_less_than_allowed_duration(slot, allowed_individual_slot_minutes)}
  end

  def self.calendar_datetime_format
    "#{'time.formats.full_display_no_time'.translate} #{'time.formats.short_time_small'.translate}"
  end

  def self.generate_hash(scope, options = {})
    period_select = "IF(end_time <= '#{options[:one_month_ago].to_s(:db)}','last2', IF(start_time > '#{options[:current_time].to_s(:db)}', 'next', 'last')) as period"
    sum_select = "SUM(TIMESTAMPDIFF(SECOND,start_time,end_time)/3600.0) as duration"
    scope.between_time(options[:two_months_ago], options[:one_month_from_now]).select(
      [period_select, sum_select].join(',')).group('period').inject({}) { |res,elem| res[elem.period] = elem.duration; res }
  end

  def self.generate_recurring_slots_hash(scope, options = {})
    slots_hash = Hash.new(0)
    intervals_hash = {"last2" => {:start_time => options[:two_months_ago], :end_time => options[:one_month_ago]},
                      "last" => {:start_time => options[:one_month_ago], :end_time => options[:current_time]},
                      "next" => {:start_time => options[:current_time], :end_time => options[:one_month_from_now]}
                     }
    ActiveRecord::Base.connection.select_all(scope).each do |slot|
      rep_in_days = MentoringSlot::Repeats.days_map(slot["repeats"])
      slot_duration = (slot["end_time"] - slot["start_time"])/1.hour
      repeats_end_date = Date.strptime(slot["repeats_end_date"].to_s + " " + Time.zone.now.formatted_offset, 'time.formats.full_date_timezone'.translate).to_time unless slot["repeats_end_date"].nil?
      intervals_hash.each_pair do |key, interval|
        next if (interval[:end_time] <= slot["start_time"]) || (repeats_end_date.present? && repeats_end_date < interval[:start_time])
        computed_end_time = (repeats_end_date && interval[:end_time] > repeats_end_date) ? repeats_end_date : interval[:end_time]
        days_after = ((interval[:start_time] - slot["start_time"])/1.day).ceil
        days_count = ((computed_end_time - interval[:start_time]) / 1.day).round
        if days_after > 0
          days_offset_for_first_slot = (days_after % rep_in_days) == 0 ? 0 : rep_in_days - (days_after % rep_in_days)
        else
          days_offset_for_first_slot = -days_after
        end
        repetitions_count = ((days_count - days_offset_for_first_slot + 0.0)/rep_in_days).ceil
        slots_hash[key] += repetitions_count * slot_duration        
      end
    end
    slots_hash
  end

  def self.generate_slot_hashes(program, member = nil, time_intervals_hash)
    member_restriction = {:member_id => [member.try(:id)].compact}
    member_restriction[:member_id] += program.mentor_users.joins(:member).where("users.mentoring_mode in (?)", User::MentoringMode.one_time_sanctioned).pluck("members.id") unless member.present?

    non_recurring_slots_hash = MentoringSlot.generate_hash(program.mentoring_slots.non_recurring.where(member_restriction), time_intervals_hash)
    slots_scope = program.mentoring_slots.recurring.recurring_between_time(time_intervals_hash[:one_month_from_now]).where(member_restriction).where('repeats_end_date IS NULL OR repeats_end_date > ?', 3.months.ago).select('start_time, end_time, repeats, repeats_end_date')
    recurring_slots_hash = MentoringSlot.generate_recurring_slots_hash(slots_scope, time_intervals_hash)

    [non_recurring_slots_hash, recurring_slots_hash]
  end

  def self.generate_meeting_hash(scope, time_intervals_hash)
    meetings = Meeting.recurrent_meetings(scope, {get_occurrences_between_time: true, start_time: time_intervals_hash[:two_months_ago], end_time: time_intervals_hash[:one_month_from_now], get_merged_list: true})
    grouped = meetings.group_by do |m|
      start_time = m[:current_occurrence_time]
      end_time = start_time + m[:meeting].schedule.duration
      if end_time <= time_intervals_hash[:one_month_ago].to_s(:db)
        'last2'
      elsif start_time > time_intervals_hash[:current_time].to_s(:db)
        'next'
      else
        'last'
      end
    end

    duration_hash = Hash.new(0)
    grouped.each do |k,v|
      duration_hash[k] = v.sum {|m| m[:meeting].schedule.duration / 3600.0 }
    end
    duration_hash
  end

  def self.session_hours_intervals
    current_time = Time.zone.now
    two_months_ago = current_time - 2.months
    one_month_ago = current_time - 1.month
    one_month_from_now = current_time + 1.month
    {:current_time => current_time, :two_months_ago => two_months_ago, :one_month_ago => one_month_ago, :one_month_from_now => one_month_from_now}
  end

  def self.rotate_repeats_on_week(repeats_on_week, days_diff)
    return unless repeats_on_week.present?
    days_diff == 0 ? repeats_on_week : repeats_on_week.map{|day| (day+days_diff)%7}
  end

  def recurrent?
    !(self.repeats.to_i == 0)
  end

  def repeats_every_option=(option)
    self.repeats = option.to_i
  end

  def repeats_every_option
    return self.repeats
  end

  # Handles weekly availability slots timezone for both mentor & mentee
  def repeats_on_week
    return unless self.start_time.present?
    value = super.to_s.split(",").map(&:to_i)
    days_diff = (self.start_time.to_date - self.start_time.utc.to_date).to_i
    MentoringSlot.rotate_repeats_on_week(value, days_diff).join(",") if value.present?
  end

  def date
    DateTime.localize(self.start_time, format: :full_display_no_time)
  end

  def repeats_end_date
    Date.strptime(super.to_s + " " + Time.zone.now.formatted_offset, 'time.formats.full_date_timezone'.translate).to_time unless super.nil?
  end

  def start_time_of_the_day
    DateTime.localize(self.start_time, format: :short_time_small)
  end

  def end_time_of_the_day
    DateTime.localize(self.end_time, format: :short_time_small)
  end
  
  def repeats_end_date_view
    DateTime.localize(self.repeats_end_date - 1.day, format: :full_display_no_time) if !self.repeats_end_date.blank?
  end

  def repeats_end_date_view=(date)
    if !date.blank?
      self.repeats_end_date = date.to_date + 1.day
    end
  end

  def member_name
    self.member.name
  end

  def repeats_daily?
    self.repeats == OPTIONS_FOR_AVAILABILITY::DAILY
  end

  def repeats_weekly?
    self.repeats == OPTIONS_FOR_AVAILABILITY::WEEKLY
  end
  
  def repeats_monthly?
    self.repeats == OPTIONS_FOR_AVAILABILITY::MONTHLY
  end

  def get_json_objects(title, loc, clickable, score, mentoring_calendar, slot_self_view, event = nil, load_member = false, recurring_options = {})
    check_available_slots = recurring_options.delete(:check_for_expired_availability)
    start_time_from_beginning = self.start_time - self.start_time.beginning_of_day
    end_time_from_beginning = self.end_time - self.start_time.beginning_of_day
    obj = get_default_hash(title, self, loc, score)
    obj.merge!(:recurring_options => recurring_options) if recurring_options.present?
    obj[:member] = self.member if load_member
    if event
      st_time = event.to_time + start_time_from_beginning
      event_end_time = event.to_time + end_time_from_beginning
      obj.merge!({:start => DateTime.localize(st_time, format: :full_date_full_time_utc),
      :end => DateTime.localize(event_end_time, format: :full_date_full_time_utc),
      :clickable => get_clickable(event, slot_self_view, clickable, st_time)})
      handle_expired_availabile_slots(obj, event_end_time, check_available_slots)
    else
      obj.merge!({:start => DateTime.localize(self.start_time, format: :full_date_full_time_utc), :end => DateTime.localize(self.end_time, format: :full_date_full_time_utc),
      :clickable => get_clickable(event, slot_self_view, clickable)})
      handle_expired_availabile_slots(obj, end_time, check_available_slots)
    end

    obj[:new_meeting_params].merge!({:mentoring_calendar => mentoring_calendar}) if mentoring_calendar
    return obj
  end

  def duration_in_hours
    (self.end_time - self.start_time)/1.hour
  end

  private

  def handle_expired_availabile_slots(slot_options, end_time, check_available_slots)
    if check_available_slots
      slot_options.merge!(className: "expired_availability_slots", clickable: true) if (end_time < Time.current)
    end
    slot_options
  end

  def get_default_hash(title, obj, loc, score)
    {
      title: title,
      allDay: false,
      repeats: obj.repeats,
      dbId: obj.id,
      eventMemberId: obj.member.id,
      location: loc,
      new_meeting_params: {location: loc, mentor_id: obj.member.id}.merge(score.nil? ? {} : {score: score}),
      editable: false
    }
  end

  def self.slot_duration_less_than_allowed_duration(slot, allowed_duration)
    start_time = slot[:start].to_time
    end_time = slot[:end].to_time
    slot_duration = (end_time - start_time).to_i
    return slot_duration < allowed_duration.minutes.to_i
  end

  def get_clickable(event, slot_self_view, clickable, st_time = nil)
    if slot_self_view
      return clickable
    else
      if event
        return (clickable ? (Time.zone.parse(DateTime.localize(st_time, format: :full_date_full_time)) > Time.now) : false)
      else
        return (clickable ? (self.start_time > Time.now) : false)
      end
    end
  end

  def check_start_time_should_be_lesser
    return if self.start_time.nil? || self.end_time.nil?
    if self.start_time >= self.end_time
      self.errors.add(:start_time, "activerecord.custom_errors.mentoring_slot.invalid_time".translate)
    end
  end

  def check_repeats_end_date
    return if self.start_time.nil? || self.repeats_end_date.nil?
    if self.repeats_end_date < self.start_time
      self.errors.add(:repeats_end_date, "activerecord.custom_errors.mentoring_slot.invalid_repeat_date".translate)
    end
  end

  def check_start_time_is_after_current_time
    self.errors.add(:start_time, "activerecord.custom_errors.mentoring_slot.invalid_start_time".translate) if self.start_time && (Time.now > self.start_time)
  end
  
end
