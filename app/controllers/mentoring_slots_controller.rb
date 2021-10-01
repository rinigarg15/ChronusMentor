class MentoringSlotsController < ApplicationController
  include MentoringSlotsHelper

  skip_action_callbacks_for_autocomplete :index
  before_action :check_feature_access, :only => [:index]
  before_action :fetch_profile_member
  before_action :fetch_mentoring_slot, :only => [:show, :edit, :update, :destroy]

  allow :exec => :check_availability_permission
  allow :exec => :check_user_can_manage_mentoring_slot, :except => [:index]

  def index
    start_time = Time.at(params[:start].to_i)
    end_time = Time.at(params[:end].to_i)
    current_user_meetings_id = wob_member.meetings.of_program(@current_program).between_time(start_time, end_time).slot_availability_meetings.pluck(:id)
    recurrent_meetings = get_meetings_for_mentoring_slot_index(start_time, end_time)
    busy_slots = current_program.calendar_sync_v2_enabled? ? Member.get_busy_slots_for_members(start_time, end_time, members: [@profile_member], viewing_member: wob_member, program: current_program) : []
    if @profile_member == wob_member
      @mentoring_slots = @profile_member.get_mentoring_slots(start_time, end_time, true, nil, false, true, false, false, check_for_expired_availability: true)
      @meetings = @profile_member.get_meeting_slots(recurrent_meetings, current_user_meetings_id, wob_member)
      add_urls(@mentoring_slots)
      render json: (@mentoring_slots + @meetings + busy_slots).to_json
    else
      @meetings = @profile_member.get_meeting_slots(recurrent_meetings, current_user_meetings_id, wob_member)
      student = current_user.is_student? ? current_user : nil
      @availability = @profile_member.get_availability_slots(start_time, end_time, current_program, true, nil, false, student)
      add_urls(@availability.flatten)
      render json: (@availability + @meetings + busy_slots).to_json
    end
  end
  
  def new
    @mentoring_slot = @profile_member.mentoring_slots.new(mentoring_slot_permitted_params(:new))
    start_time_of_day = (Time.now + 1.day).round_to_next
    @mentoring_slot.start_time ||= start_time_of_day
    @allowed_individual_slot_duration = @current_program.get_calendar_slot_time
    @mentoring_slot.end_time = @mentoring_slot.start_time + @allowed_individual_slot_duration.minutes if (!@mentoring_slot.end_time.present? || ((@mentoring_slot.end_time - @mentoring_slot.start_time).to_i < @allowed_individual_slot_duration.minutes.to_i))
    @mentoring_slot_locations = @profile_member.get_locations
    @from_settings_page = params[:from_settings_page].to_s.to_boolean
    mentoring_slot_start_time_params_present = (params[:mentoring_slot].present? && params[:mentoring_slot][:start_time].present?)
    meeting_start_time = mentoring_slot_start_time_params_present ? params[:mentoring_slot][:start_time] : start_time_of_day
    @new_meeting = wob_member.meetings.build({:start_time => meeting_start_time})
    @can_current_user_create_meeting = current_user.can_create_meeting?(@current_program)
    @can_mark_availability_slot = (Time.now.to_i <= meeting_start_time.to_datetime.to_i) || !mentoring_slot_start_time_params_present
    @unlimited_slot = @current_program.calendar_setting.slot_time_in_minutes.zero?
    @new_meeting.end_time = (@unlimited_slot && (params[:mentoring_slot].present? && params[:mentoring_slot][:end_time].present?))? params[:mentoring_slot][:end_time] : @new_meeting.start_time + @allowed_individual_slot_duration.minutes
    render :partial => "mentoring_slots/new_form.html", :layout => false
  end
  
  def create
    mentoring_slot_params = mentoring_slot_permitted_params(:create)
    mentoring_slot_params[:date] = get_en_datetime_str(mentoring_slot_params[:date]) if mentoring_slot_params[:date].present?
    mentoring_slot_params[:repeats_end_date_view] = get_en_datetime_str(mentoring_slot_params[:repeats_end_date_view]) if mentoring_slot_params[:repeats_end_date_view].present?
    mentoring_slot_params[:start_time], mentoring_slot_params[:end_time] = MentoringSlot.fetch_start_and_end_time(mentoring_slot_params.delete(:date),
                                                                            mentoring_slot_params.delete(:start_time_of_day), mentoring_slot_params.delete(:end_time_of_day))
    mentoring_slot_params[:repeats_on_week] = process_repeats_on_week(mentoring_slot_params.delete(:repeats_on_week), mentoring_slot_params[:start_time]) if mentoring_slot_params[:repeats_on_week]
    @mentoring_slot = @profile_member.mentoring_slots.build(mentoring_slot_params)
    @from_settings_page = params["mentoring_slot"]["from_settings_page"].try(:to_boolean)
    if @mentoring_slot.save
      @profile_member.update_attributes(will_set_availability_slots: true)
    end
    start_time = Time.now.utc
    @mentoring_slots = MentoringSlot.sort_slots!(@profile_member.get_mentoring_slots(start_time, start_time.next_month.end_of_month, false, nil, false, false, false, false, {mentor_settings_page: true}))
  end

  def show
    render :partial => "/mentoring_slots/show.html", :layout => false
  end

  def edit
#   strptime will not take care of DST
    @mentoring_slot.start_time = Time.zone.parse(params[:mentoring_slot][:start_time])
    @mentoring_slot.end_time = Time.zone.parse(params[:mentoring_slot][:end_time])
    @mentoring_slot_locations = @profile_member.get_locations
    @allowed_individual_slot_duration = @current_program.get_calendar_slot_time
    @can_mark_availability_slot = true
  end

  def update
    mentoring_slot_params = mentoring_slot_permitted_params(:update)
    mentoring_slot_params[:date] = get_en_datetime_str(mentoring_slot_params[:date]) if mentoring_slot_params[:date].present?
    mentoring_slot_params[:repeats_end_date_view] = get_en_datetime_str(mentoring_slot_params[:repeats_end_date_view]) if mentoring_slot_params[:repeats_end_date_view].present?
    mentoring_slot_params[:start_time], mentoring_slot_params[:end_time] = MentoringSlot.fetch_start_and_end_time(mentoring_slot_params.delete(:date),
    mentoring_slot_params.delete(:start_time_of_day), mentoring_slot_params.delete(:end_time_of_day))
    mentoring_slot_params[:repeats_on_week] = process_repeats_on_week(mentoring_slot_params.delete(:repeats_on_week), mentoring_slot_params[:start_time]) if mentoring_slot_params[:repeats_on_week]
    @mentoring_slot.update_attributes(mentoring_slot_params)
  end

  def destroy
    @from_settings_page = params[:from_settings_page].to_s.to_boolean
    @mentoring_slot.destroy
    start_time = Time.now.utc
    @mentoring_slots = MentoringSlot.sort_slots!(@profile_member.get_mentoring_slots(start_time, start_time.next_month.end_of_month, false, nil, false, false, false, false, {mentor_settings_page: true})) if @from_settings_page
  end
  
  private

  def mentoring_slot_permitted_params(action)
    return {} if params[:mentoring_slot].blank?
    params.require(:mentoring_slot).permit(MentoringSlot::MASS_UPDATE_ATTRIBUTES[action]).merge(repeats_on_week: params[:mentoring_slot][:repeats_on_week])
  end

  def fetch_profile_member
    @profile_member = @current_organization.members.find(params[:member_id])
  end

  def fetch_mentoring_slot
    @mentoring_slot = @profile_member.mentoring_slots.find(params[:id])
  end
  
  def check_user_can_manage_mentoring_slot
    wob_member == @profile_member
  end

  def check_availability_permission
    return true if params["from_settings_page"].try(:to_boolean) || (params["mentoring_slot"].present? && params["mentoring_slot"]["from_settings_page"].try(:to_boolean))
    @profile_member.ask_to_set_availability?
  end

  def get_meetings_for_mentoring_slot_index(start_time, end_time)
    meetings = @profile_member.meetings.of_program(@current_program).slot_availability_meetings
    meetings = @current_program.mentoring_connection_meeting_enabled? ? meetings : meetings.non_group_meetings
    return Meeting.recurrent_meetings(meetings, {get_occurrences_between_time: true, start_time: start_time, end_time: end_time, get_merged_list: true})
  end

  def process_repeats_on_week(repeats_on_week, start_time)
    return unless repeats_on_week.present?
    repeats_on_week = repeats_on_week.map(&:to_i)
    days_diff = (start_time.utc.to_date - start_time.to_date).to_i
    MentoringSlot.rotate_repeats_on_week(repeats_on_week, days_diff).join(",")
  end

end
