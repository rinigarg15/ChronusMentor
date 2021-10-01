module ApplicationControllerExtensions::ActionEvents::PendingRequestCount
  private

  def get_pending_requests_count_for_quick_links
    return unless @current_program.present? && current_user.present?
    @cumulative_requests_notification_count = 0
    @past_requests_count = 0
    @notification_quick_links = []

    set_counts_for_program_events
    set_counts_for_mentor_or_student
    set_counts_for_ongoing_mentoring_matching_mentee_admin
    set_counts_for_pbe

    @mobile_requests_tab_badge_count = @cumulative_requests_notification_count
    @cumulative_requests_notification_count = 1 if @past_requests_count.zero? && current_user.is_student? && current_user.groups.active.blank?
  end

  def set_counts_for_program_events
    return unless @current_program.program_events_enabled?
    @unanswered_program_events = current_user.get_unanswered_program_events
    @unanswered_program_events_count = @unanswered_program_events.size
    @cumulative_requests_notification_count += @unanswered_program_events_count
    @notification_quick_links << MobileTab::QuickLink::ProgramEvent
  end

  def set_counts_for_mentor_or_student
    return unless current_user.is_mentor_or_student?
    
    set_counts_for_ongoing_mentoring_matching_mentee_alone
    set_counts_for_calendar_enabled
    set_counts_for_meetings_listing
    set_counts_for_mentor_offer_acceptance_required
  end

  def set_counts_for_ongoing_mentoring_matching_mentee_alone
    return unless @current_program.ongoing_mentoring_enabled? && @current_program.matching_by_mentee_alone?
    @new_mentor_requests_count = 0
    set_counts_for_ongoing_mentoring_matching_mentee_alone_mentor
    if current_user.is_student?
      @past_requests_count += current_user.sent_mentor_requests.count
      @mentor_requests_url_options ||= { filter: AbstractRequest::Filter::BY_ME }
    end
    @cumulative_requests_notification_count += @new_mentor_requests_count
    @notification_quick_links << MobileTab::QuickLink::MentorRequest
  end

  def set_counts_for_ongoing_mentoring_matching_mentee_alone_mentor
    return unless current_user.is_mentor?
    past_requests = current_user.received_mentor_requests
    @past_requests_count += past_requests.count
    @new_mentor_requests_count = past_requests.active.count
    @mentor_requests_url_options = { filter: AbstractRequest::Filter::TO_ME }
  end

  def set_counts_for_calendar_enabled
    return unless @current_program.calendar_enabled?
    @new_meeting_requests_count = 0
    if current_user.is_mentor?
      past_requests = current_user.received_meeting_requests
      @past_requests_count += past_requests.count
      @new_meeting_requests_count = past_requests.active.count
    end
    if current_user.is_student?
      @past_requests_count += current_user.sent_meeting_requests.count
    end
    @cumulative_requests_notification_count += @new_meeting_requests_count
    @notification_quick_links << MobileTab::QuickLink::MeetingRequest
  end

  def set_counts_for_meetings_listing
    return unless current_user.can_be_shown_meetings_listing?
    @upcoming_meetings_count = wob_member.get_upcoming_not_responded_meetings_count(@current_program)
    @cumulative_requests_notification_count += @upcoming_meetings_count
    @notification_quick_links << MobileTab::QuickLink::Meeting
  end

  def set_counts_for_mentor_offer_acceptance_required
    return unless @current_program.mentor_offer_enabled? && @current_program.mentor_offer_needs_acceptance?
    @new_mentor_offers_count = 0
    past_requests = set_counts_for_mentor_offer_student
    past_requests = set_counts_for_mentor_offer_mentor(past_requests)
    @new_mentor_offers = past_requests.pending
    @cumulative_requests_notification_count += @new_mentor_offers_count
    @notification_quick_links << MobileTab::QuickLink::MentorOffer
  end

  def set_counts_for_mentor_offer_student
    return unless current_user.is_student?
    past_requests = current_user.received_mentor_offers
    @past_requests_count += past_requests.count
    @new_mentor_offers_count = past_requests.pending.count
    past_requests
  end

  def set_counts_for_mentor_offer_mentor(past_requests)
    return past_requests unless current_user.is_mentor?
    @past_requests_count += current_user.sent_mentor_offers.count
    return past_requests if past_requests.present?
    current_user.sent_mentor_offers
  end

  def set_counts_for_ongoing_mentoring_matching_mentee_admin
    return unless @current_program.ongoing_mentoring_enabled? && @current_program.matching_by_mentee_and_admin?
    @new_mentor_requests_count = 0
    if current_user.is_student?
      past_requests = current_user.sent_mentor_requests
      @past_requests_count += past_requests.count
      @mentor_requests_url_options = { filter: AbstractRequest::Filter::BY_ME }
      @notification_quick_links << MobileTab::QuickLink::MentorRequest
    elsif current_user.can_manage_mentor_requests?
      @new_mentor_requests_count = @current_program.mentor_requests.active.count
      @mentor_requests_url_options = { filter: AbstractRequest::Filter::ALL }
    end
  end

  def set_counts_for_pbe
    return unless current_program.project_based?
    project_requests =
      if current_user.is_admin?
        current_program.project_requests.active
      elsif current_user.has_owned_groups?
        current_user.owned_groups.collect { |group| group.active_project_requests }.flatten
      end
    return if project_requests.blank?
    @new_project_requests_count = project_requests.size
    @past_requests_count += @new_project_requests_count
    @cumulative_requests_notification_count += @new_project_requests_count
  end
  
end