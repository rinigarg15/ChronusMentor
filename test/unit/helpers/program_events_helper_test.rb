require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/program_events_helper"

class ProgramEventsHelperTest < ActionView::TestCase
  include AdminViewsHelper

  def test_fetch_user_info
	assert_equal "", fetch_user_info(users(:f_mentor), programs(:org_primary).profile_questions, "experience")
    assert_equal "", fetch_user_info(users(:f_mentor), programs(:org_primary).profile_questions, "education")
    assert_equal "", fetch_user_info(users(:f_mentor), programs(:org_primary).profile_questions, "location")
    assert_equal "Member since #{users(:f_mentor).created_at.strftime("%B %Y")}", fetch_user_info(users(:f_mentor), programs(:org_primary).profile_questions, "join_date")
	end

  def test_get_image_class
    assert_equal "hide", get_image_class(users(:f_mentor), program_events(:birthday_party), EventInvite::Status::YES)
    assert_equal "hide", get_image_class(users(:f_mentor), program_events(:birthday_party), EventInvite::Status::NO)
    assert_equal "hide", get_image_class(users(:f_mentor), program_events(:birthday_party), EventInvite::Status::MAYBE)
  end

  def test_users_invited_label
    @current_user = users(:f_admin)
    program_event = program_events(:birthday_party)
    program_event.admin_view_fetched_at = '2014/06/25'.to_date
    stub_request_parameters
    assert_equal %Q{<div class=\"inline\">44 users ( <a class=\"cjs_see_more_event_details\" href=\"javascript:void(0)\">view details <i class=\"fa fa-chevron-down fa-fw m-r-xs\"></i></a><a class=\"cjs_see_less_event_details hide\" href=\"javascript:void(0)\">hide details <i class=\"fa fa-chevron-up fa-fw m-r-xs\"></i></a>)</div><div class=\"cjs_invited_details help-block m-b-0 hide\">Users that belong to the view '<a href=\"/admin_views/#{program_event.admin_view_id}\">All Users</a>' as of Jun 25, 2014</div>}, users_invited_label(program_event)
  end

  def test_users_invited_label_for_student
    @current_user = users(:f_student)
    program_event = program_events(:birthday_party)
    program_event.admin_view_fetched_at = '2014/06/25'.to_date
    assert_equal '<div class="inline">44 users</div>', users_invited_label(program_event)
  end

  def test_users_invited_label_for_mentor
    @current_user = users(:f_mentor)
    program_event = program_events(:birthday_party)
    program_event.admin_view_fetched_at = '2014/06/25'.to_date
    assert_equal '<div class="inline">44 users</div>', users_invited_label(program_event)
  end

  def test_users_invited_label_without_admin_view_fetched_at
    @current_user = users(:f_admin)
    program_event = program_events(:birthday_party)
    program_event.admin_view_fetched_at = nil
    stub_request_parameters
    assert_equal %Q{<div class=\"inline\">44 users ( <a class=\"cjs_see_more_event_details\" href=\"javascript:void(0)\">view details <i class=\"fa fa-chevron-down fa-fw m-r-xs\"></i></a><a class=\"cjs_see_less_event_details hide\" href=\"javascript:void(0)\">hide details <i class=\"fa fa-chevron-up fa-fw m-r-xs\"></i></a>)</div><div class=\"cjs_invited_details help-block m-b-0 hide\">Users that belong to the view '<a href=\"/admin_views/#{program_event.admin_view_id}\">All Users</a>'</div>}, users_invited_label(program_event)
  end

  def test_users_invited_label_without_admin_view
    @current_user = users(:f_admin)
    program_event = program_events(:birthday_party)
    program_event.admin_view_id = nil
    assert_equal '<div class="inline">44 users</div>', users_invited_label(program_event)
  end

  def test_get_event_status_text
    assert_equal "drafted", get_event_status_text(ProgramEventConstants::Tabs::DRAFTED)
    assert_equal "past", get_event_status_text(ProgramEventConstants::Tabs::PAST)
    assert_equal "upcoming", get_event_status_text()
  end

  def test_get_invite_reponse_text
    assert_equal "You attended this program event", get_invite_reponse_text(EventInvite::Status::YES)
    assert_equal "You did not attend this program event", get_invite_reponse_text(EventInvite::Status::NO)
    assert_equal "You may have attended this program event", get_invite_reponse_text(EventInvite::Status::MAYBE)
  end

  def test_invite_response_label
    event = program_events(:birthday_party)
    assert_equal "Attending", invite_response_label(event, EventInvite::Status::YES, 2)
    assert_equal "Not Attending", invite_response_label(event, EventInvite::Status::NO, 2)
    assert_equal "May be Attending", invite_response_label(event, EventInvite::Status::MAYBE, 2)

    event.start_time = "2012-06-06 07:30:00"
    event.save!
    assert_equal "Attended", invite_response_label(event, EventInvite::Status::YES, 2)
    assert_equal "Not Attended", invite_response_label(event, EventInvite::Status::NO, 2)
    assert_equal "May have Attended", invite_response_label(event, EventInvite::Status::MAYBE, 2)
  end

  def test_get_reponse_label_tab_pane
    event = program_events(:birthday_party)
    assert_equal "Attending", get_reponse_label_tab_pane(event, ProgramEventConstants::ResponseTabs::ATTENDING)
    assert_equal "Not Attending", get_reponse_label_tab_pane(event, ProgramEventConstants::ResponseTabs::NOT_ATTENDING)
    assert_equal "May be Attending", get_reponse_label_tab_pane(event, ProgramEventConstants::ResponseTabs::MAYBE_ATTENDING)
    assert_equal "Not Responded", get_reponse_label_tab_pane(event, ProgramEventConstants::ResponseTabs::NOT_RESPONDED)
    assert_equal "Invited", get_reponse_label_tab_pane(event, ProgramEventConstants::ResponseTabs::INVITED)

    event.start_time = "2012-06-06 07:30:00"
    event.save!
    assert_equal "Attended", get_reponse_label_tab_pane(event, ProgramEventConstants::ResponseTabs::ATTENDING)
    assert_equal "Not Attended", get_reponse_label_tab_pane(event, ProgramEventConstants::ResponseTabs::NOT_ATTENDING)
    assert_equal "May have Attended", get_reponse_label_tab_pane(event, ProgramEventConstants::ResponseTabs::MAYBE_ATTENDING)
    assert_equal "Invited", get_reponse_label_tab_pane(event, ProgramEventConstants::ResponseTabs::INVITED)
  end

  def test_event_time_for_display
    event = program_events(:birthday_party)
    member = members(:ram)
    event.update_column(:start_time, "2015-12-06 07:30:00".to_datetime)
    #if members time zone is absent, time is displayed in UTC
    assert_equal "07:30 am UTC (01:00 pm IST)", event_time_for_display(event, member)
    #if event and member time zones are same
    member.stubs(:time_zone).returns("Asia/Kolkata")
    assert_equal "01:00 pm IST", event_time_for_display(event, member)
    #if event and member time zones are different, but dates are same
    event.stubs(:time_zone).returns("Asia/Tokyo")
    assert_equal "01:00 pm IST (04:30 pm JST)", event_time_for_display(event, member)
    #if event and member time zones are different, but dates are different
    event.stubs(:start_time).returns("2015-12-06 15:30".to_datetime)
    assert_equal "09:00 pm IST (Dec 07, 2015 12:30 am JST)", event_time_for_display(event, member)
    #if event time zone is not present, time is displayed in member time zone
    event.stubs(:time_zone).returns("")
    assert_equal "09:00 pm IST", event_time_for_display(event, member)
    event.stubs(:end_time).returns("2015-12-07 18:30".to_datetime)
    assert_equal "09:00 pm to 12:00 am IST", event_time_for_display(event, member)
    event.stubs(:time_zone).returns("Asia/Tokyo")
    assert_equal "09:00 pm to 12:00 am IST (Dec 07, 2015 12:30 am to 03:30 am JST)", event_time_for_display(event, member)
    #if event time is in dst, time is displayed in dst, irrespective of member's current time.
    Timecop.freeze(DateTime.parse("October 27, 2016 14:30:00").in_time_zone("America/Los_Angeles")) do
      Time.zone = "America/Los_Angeles"
      member.stubs(:time_zone).returns("America/Los_Angeles")
      event.stubs(:time_zone).returns("America/Los_Angeles")
      assert Time.current.dst?
      assert_false event.start_time.in_time_zone("America/Los_Angeles").dst?
      assert_equal "PDT", Time.current.strftime("%Z")
      assert_equal "07:30 am to 10:30 am PST", event_time_for_display(event, member)
    end
  end

  def test_get_reponse_label_for_invited_list
    event = program_events(:birthday_party)
    invited_users = event.program_event_users.map(&:user)
    event.event_invites.create!(:user => invited_users[1], :status => EventInvite::Status::NO)
    event.event_invites.create!(:user => invited_users[2], :status => EventInvite::Status::MAYBE)
    event.event_invites.create!(:user => invited_users[3], :status => EventInvite::Status::YES)
    assert_equal "<span class=\"label navy-bg text-white\"><i class=\"fa fa-check fa-fw m-r-xs\"></i>Attending</span>", get_reponse_label_for_invited_list(event, invited_users[3])
    assert_equal "<span class=\"label label-default\"><i class=\"fa fa-exclamation fa-fw m-r-xs\"></i>May be Attending</span>", get_reponse_label_for_invited_list(event, invited_users[2])
    assert_equal "<span class=\"label red-bg text-white\"><i class=\"fa fa-times fa-fw m-r-xs\"></i>Not Attending</span>", get_reponse_label_for_invited_list(event, invited_users[1])
    assert_equal "<span class=\"small text-muted\">Not Responded</span>", get_reponse_label_for_invited_list(event, invited_users[4])

    event.update_column(:start_time, "2012-06-06 07:30:00")
    assert_equal "<span class=\"label navy-bg text-white\"><i class=\"fa fa-check fa-fw m-r-xs\"></i>Attended</span>", get_reponse_label_for_invited_list(event, invited_users[3])
    assert_equal "<span class=\"label label-default\"><i class=\"fa fa-exclamation fa-fw m-r-xs\"></i>May have Attended</span>", get_reponse_label_for_invited_list(event, invited_users[2])    
    assert_equal "<span class=\"label red-bg text-white\"><i class=\"fa fa-times fa-fw m-r-xs\"></i>Not Attended</span>", get_reponse_label_for_invited_list(event, invited_users[1])
    assert_equal "<span class=\"small text-muted\">Not Responded</span>", get_reponse_label_for_invited_list(event, invited_users[4])
  end

  def test_get_admin_views_options
    program = programs(:albers)
    @current_user = users(:f_admin)
    program_event = program_events(:birthday_party)
    admin_view_id = program_event.admin_view_id

    first_option = {"id"=>admin_view_id, "icon"=>"fa fa-star", "title"=>"All Users"}
    assert_equal JSON.parse(get_admin_views_options(program.admin_views, program_event)).first, first_option
    program_event.admin_view.destroy
    deleted_view = {"id"=>admin_view_id, "title"=>"All Users (deleted)"}
    assert_equal JSON.parse(get_admin_views_options(program.reload.admin_views, program_event.reload)).first, deleted_view
  end

  def test_event_datetime_for_display_in_email
    event = program_events(:birthday_party)
    member = members(:ram)
    event.update_column(:start_time, "2015-12-06 07:30:00".to_datetime)
    #if member's time zone is present and program_event's time zone is present, datetime is displayed in member's time_zone
    member.time_zone = "Asia/Kolkata"
    event.time_zone = "Asia/Tokyo"
    assert_equal "December 06, 2015 01:00 pm IST", event_datetime_for_display_in_email(event, member)

    #if member's time zone is present and program_event's time zone is not present, datetime is displayed in member's time_zone
    member.time_zone = "Asia/Kolkata"
    event.time_zone = nil
    assert_equal "December 06, 2015 01:00 pm IST", event_datetime_for_display_in_email(event, member)

    #if member's time zone is not present and program_event's time zone is present, datetime is displayed in event's time_zone
    member.time_zone = nil
    event.time_zone = "Asia/Tokyo"
    assert_equal "December 06, 2015 04:30 pm JST", event_datetime_for_display_in_email(event, member)

    #if member's time zone is not present and program_event's time zone is not present, datetime is displayed in UTC
    member.time_zone = nil
    event.time_zone = nil
    assert_equal "December 06, 2015 07:30 am UTC", event_datetime_for_display_in_email(event, member)

    #if member's time zone is empty string and program_event's time zone is present, datetime is displayed in event's time_zone
    event.update_column(:start_time, "2016-01-05 22:30:00".to_datetime)
    member.time_zone = ""
    event.time_zone = "Asia/Tokyo"
    assert_equal "January 06, 2016 07:30 am JST", event_datetime_for_display_in_email(event, member)
  end

  def test_get_confirm_message_for_event_guest_list_update
    program_event = program_events(:birthday_party)
    program = program_event.program
    assert program_event.email_notification?
    program_event.stubs(:get_current_admin_view_changes).returns([0, 0])
    assert_equal "", get_confirm_message_for_event_guest_list_update(program_event)

    event_invite_mail_uid = NewProgramEventNotification.mailer_attributes[:uid]
    event_delete_mail_uid = ProgramEventDeleteNotification.mailer_attributes[:uid]

    program_event.stubs(:get_current_admin_view_changes).returns([1, 1])
    assert_equal "Updating guest list would add 1 user who got added and remove 1 user who got removed from the view 'All Users' since guest list was updated last time. Also, <a href=\"/mailer_templates/#{event_invite_mail_uid}/edit\">event invite notification</a> will be sent to the user who got added and <a href=\"/mailer_templates/#{event_delete_mail_uid}/edit\">event delete notification</a> will be sent to the user who got removed.", get_confirm_message_for_event_guest_list_update(program_event)
    program_event.stubs(:get_current_admin_view_changes).returns([1, 2])
    program_event.stubs(:email_notification?).returns(false)
    assert_equal "Updating guest list would add 1 user who got added and remove 2 users who got removed from the view 'All Users' since guest list was updated last time. Also, <a href=\"/mailer_templates/#{event_delete_mail_uid}/edit\">event delete notification</a> will be sent to the users who got removed.", get_confirm_message_for_event_guest_list_update(program_event)
    program_event.stubs(:get_current_admin_view_changes).returns([2, 1])
    program.stubs(:email_template_disabled_for_activity?).returns(true)
    assert_equal "Updating guest list would add 2 users who got added and remove 1 user who got removed from the view 'All Users' since guest list was updated last time.", get_confirm_message_for_event_guest_list_update(program_event)

    program.stubs(:email_template_disabled_for_activity?).returns(false)
    program_event.stubs(:get_current_admin_view_changes).returns([1, 0])
    assert_equal "Updating guest list would add 1 user who got added to the view 'All Users' since guest list was updated last time.", get_confirm_message_for_event_guest_list_update(program_event)
    program_event.stubs(:email_notification?).returns(true)
    program_event.stubs(:get_current_admin_view_changes).returns([2, 0])
    assert_equal "Updating guest list would add 2 users who got added to the view 'All Users' since guest list was updated last time. Also, <a href=\"/mailer_templates/#{event_invite_mail_uid}/edit\">event invite notification</a> will be sent to the users who got added.", get_confirm_message_for_event_guest_list_update(program_event)

    program_event.stubs(:get_current_admin_view_changes).returns([0, 1])
    assert_equal "Updating guest list would remove 1 user who got removed from the view 'All Users' since guest list was updated last time. Also, <a href=\"/mailer_templates/#{event_delete_mail_uid}/edit\">event delete notification</a> will be sent to the user who got removed.", get_confirm_message_for_event_guest_list_update(program_event)
    program_event.stubs(:get_current_admin_view_changes).returns([0, 3])
    program_event.stubs(:email_notification?).returns(false)
    assert_equal "Updating guest list would remove 3 users who got removed from the view 'All Users' since guest list was updated last time. Also, <a href=\"/mailer_templates/#{event_delete_mail_uid}/edit\">event delete notification</a> will be sent to the users who got removed.", get_confirm_message_for_event_guest_list_update(program_event)
    program.stubs(:email_template_disabled_for_activity?).with(NewProgramEventNotification).returns(true)
    assert_equal "Updating guest list would remove 3 users who got removed from the view 'All Users' since guest list was updated last time. Also, <a href=\"/mailer_templates/#{event_delete_mail_uid}/edit\">event delete notification</a> will be sent to the users who got removed.", get_confirm_message_for_event_guest_list_update(program_event)
    program.stubs(:email_template_disabled_for_activity?).with(ProgramEventDeleteNotification).returns(true)
    assert_equal "Updating guest list would remove 3 users who got removed from the view 'All Users' since guest list was updated last time.", get_confirm_message_for_event_guest_list_update(program_event)
  end

  def test_get_program_event_link
    program_event = program_events(:birthday_party)
    set_response_text(get_program_event_link(program_event))
    assert_select "a", text: "Birthday Party", href: program_event_path(program_event)
  end

  def test_get_program_events_timezone_selector_locals_hash
    wob_member = members(:f_admin)
    self.stubs(:wob_member).returns(wob_member)
    program_event = program_events(:birthday_party)
    locals_hash = {
      object: program_event,
      tz_identifier_element_name: "program_event[time_zone]",
      additional_container_label_class: "col-sm-3",
      container_input_class: "col-sm-9",
      default_selected_time_zone: wob_member.get_valid_time_zone
    }
    assert_equal locals_hash, get_program_events_timezone_selector_locals_hash(program_event, true)
    locals_hash.merge!({
      tz_area_class: "cjs_selector_time_zone_area",
      tz_identifier_class: "cjs_selector_time_zone_identifier",
      track_change: true
    })
    assert_equal locals_hash, get_program_events_timezone_selector_locals_hash(program_event, false)
  end

  private

  def _Mentors
    "Mentors"
  end

  def _Mentees
    "Mentees"
  end
end
