require_relative './../test_helper.rb'

class ProgramEventsControllerTest < ActionController::TestCase
  def setup
    super
    programs(:albers).enable_feature(FeatureName::PROGRAM_EVENTS)
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    programs(:org_primary).enable_feature(FeatureName::CALENDAR_SYNC, false)
    programs(:org_anna_univ).enable_feature(FeatureName::CALENDAR, true)
    programs(:org_anna_univ).enable_feature(FeatureName::CALENDAR_SYNC, false)
    chronus_s3_utils_stub
  end

  def test_should_log_in
    get :index
    assert_redirected_to new_session_path
  end

  def test_should_get_index
    current_user_is :f_admin

    event_1 = program_events(:birthday_party)
    event_2 = program_events(:ror_meetup)
    #event_3 belongs to other program, should not come in index
    event_3 = program_events(:entrepreneur_meetup)
    # The user, who is a member of the program should get the page
    #By default, the upcoming tab will be indexed
    get :index
    assert_response :success
    assert_equal_unordered [event_1], assigns(:program_events) #event_1 is the only published event of program
    #index drafted tab
    get :index, params: { :tab => ProgramEventConstants::Tabs::DRAFTED}
    assert_response :success
    assert_equal_unordered [event_2], assigns(:program_events)
  end

  def test_index_for_new_invites_for_admin
    current_user_is :f_admin

    event = program_events(:birthday_party)
    event.program_event_users.where(user_id: [users(:f_mentor_student).id, users(:robert).id]).delete_all
    event.event_invites.where(user_id: [users(:f_mentor_student).id, users(:robert).id]).delete_all

    get :index
    assert_response :success
    assert_equal_unordered [event], assigns(:program_events)
    assert_select "div#admin_view_change_event_#{event.id}" do
      assert_select "div.media-body", /The guest list for #{event.title} has changed since you last sent invitations. Would you like to update the list?/
      assert_select "span.new-invite-button-text", "Yes, update guest list"
    end
  end

  def test_index_for_new_invites_for_admin_drafted_tab
    current_user_is :f_admin

    event = program_events(:ror_meetup)
    event.program_event_users.where(user_id: [users(:f_mentor_student).id, users(:robert).id]).delete_all
    event.event_invites.where(user_id: [users(:f_mentor_student).id, users(:robert).id]).delete_all
    event.program_event_users.reload
    old_count = event.program_event_users.size

    ProgramEvent.any_instance.stubs(:get_user_ids_to_set).returns(event.program_event_users.pluck(:user_id) - [users(:f_mentor).id] + [users(:f_mentor_student).id, users(:robert).id])
    assert_no_emails do
      get :index, params: { tab: ProgramEventConstants::Tabs::DRAFTED}
    end
    assert_response :success
    assert_equal_unordered [event], assigns(:program_events)
    assert_select "div#admin_view_change_event_#{event.id}", false, "Not shown for drafted events"
    event.program_event_users.reload
    assert_equal old_count + 1, event.program_event_users.size
  end

  def test_index_for_new_invites_for_end_user
    current_user_is :f_student

    event = program_events(:birthday_party)
    event.program_event_users.where(user_id: [users(:f_mentor_student).id, users(:robert).id]).delete_all
    event.event_invites.where(user_id: [users(:f_mentor_student).id, users(:robert).id]).delete_all

    get :index
    assert_response :success
    assert_equal_unordered [event], assigns(:program_events)
    assert_select "div#admin_view_change_event_#{event.id}", false, "This should be restricted to admins"
  end

  def test_index_restricts_the_event_according_to_the_user
    event_1 = program_events(:birthday_party)
    event_1.role_names = RoleConstants::STUDENT_NAME
    event_2 = program_events(:ror_meetup)
    event_2.role_names = RoleConstants::MENTOR_NAME
    current_user_is :f_student
    get :index
    assert_response :success
    assert_equal_unordered [event_1], assigns(:program_events)
  end

  def test_should_get_index_only_published_events_for_non_admins
    current_user_is :f_mentor
    assert_permission_denied do
      get :index, params: { :tab => ProgramEventConstants::Tabs::DRAFTED}
    end
  end

  def test_new_permission_denied
    current_user_is :f_mentor
    assert_permission_denied do
      get :new
    end
  end

  def test_create_permission_denied
    current_user_is :f_mentor
    assert_permission_denied do
      post :create
    end
  end

  def test_new
    current_user_is :ram
    get :new
    assert_response :success
    assert_match NewProgramEventNotification.mailer_attributes[:uid], response.body
    assert assigns(:program_event).new_record?
    assert_not_nil assigns(:admin_views)
  end

  def test_edit
    current_user_is :ram
    get :edit, params: { id: program_events(:birthday_party).id}
    assert_response :success
    assert_match ProgramEventUpdateNotification.mailer_attributes[:uid], response.body
  end

  def test_create
    current_user_is :ram
    programs(:albers).mailer_template_enable_or_disable(NewProgramEventNotification, true)
    admin_view = programs(:albers).admin_views.first
    assert_equal 2, programs(:albers).program_events.size
    post :create, params: { :program_event => {:title => 'Hack Day', :location => 'Chronus Office', :date => "August 25, 2015", :start_time => '09:30 am', :admin_view_id => admin_view.id, :status => "0", :time_zone => "Asia/Kolkata"}}
    assert_equal 3, programs(:albers).program_events.size
    event = programs(:albers).program_events.reload.find_by(title: 'Hack Day')
    assert_equal "04:00 am August 25, 2015", event.start_time.strftime('%I:%M %P %B %d, %Y')
    assert_equal 'Chronus Office', event.location
    assert_equal ProgramEvent::Status::DRAFT, event.status
    assert_equal admin_view, event.admin_view
    assert_redirected_to program_event_path(event)
    assert_false programs(:albers).email_template_disabled_for_activity?(NewProgramEventNotification)
  end

  def test_create_published_mailer_check
    current_user_is :ram
    programs(:albers).mailer_template_enable_or_disable(NewProgramEventNotification, true)
    admin_view = programs(:albers).admin_views.first
    post :create, params: { :program_event => {:title => 'Hack Day', :location => 'Chronus Office', :date => "August 25, 2015", :start_time => '09:30 am', :admin_view_id => admin_view.id, :status => "#{ProgramEvent::Status::PUBLISHED}", :time_zone => "Asia/Kolkata"}}
    assert programs(:albers).email_template_disabled_for_activity?(NewProgramEventNotification)
  end

  def test_create_with_email_notification_set_for_drafted
    current_user_is :ram
    programs(:albers).mailer_template_enable_or_disable(NewProgramEventNotification, false)
    admin_view = programs(:albers).admin_views.first
    post :create, params: { :program_event => {:title => 'Hack Day', :location => 'Chronus Office', :date => "August 25, 2015", :start_time => '09:30 am', :admin_view_id => admin_view.id, :status => "#{ProgramEvent::Status::DRAFT}", :time_zone => "Asia/Kolkata", email_notification: 'true'}}
    assert programs(:albers).email_template_disabled_for_activity?(NewProgramEventNotification)
  end

  def test_create_with_email_notification_set_for_published
    current_user_is :ram
    programs(:albers).mailer_template_enable_or_disable(NewProgramEventNotification, false)
    admin_view = programs(:albers).admin_views.first
    post :create, params: { :program_event => {:title => 'Hack Day', :location => 'Chronus Office', :date => "August 25, 2015", :start_time => '09:30 am', :admin_view_id => admin_view.id, :status => "#{ProgramEvent::Status::PUBLISHED}", :time_zone => "Asia/Kolkata", email_notification: 'true'}}
    assert_false programs(:albers).email_template_disabled_for_activity?(NewProgramEventNotification)
  end

  def test_create_with_vulnerable_content_with_version_v1
    current_user_is :ram
    admin_view = programs(:albers).admin_views.first
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")

    assert_no_difference "VulnerableContentLog.count" do
      post :create, params: { :program_event => {:title => 'Hack Day', :location => 'Chronus Office', :date => "August 25, 2015", :start_time => '09:30 am', :admin_view_id => admin_view.id, :status => "0", :time_zone => "Asia/Kolkata", :description => "This is a event <script>alert(10);</script>"}}
    end
  end

  def test_create_with_vulnerable_content_with_version_v2
    current_user_is :ram
    admin_view = programs(:albers).admin_views.first
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")

    assert_difference "VulnerableContentLog.count" do
      post :create, params: { :program_event => {:title => 'Hack Day', :location => 'Chronus Office', :date => "August 25, 2015", :start_time => '09:30 am', :admin_view_id => admin_view.id, :status => "0", :time_zone => "Asia/Kolkata", :description => "This is a event <script>alert(10);</script>"}}
    end
  end

  def test_update_permission_denied
    current_user_is :f_mentor
    assert_permission_denied do
      post :update, params: { :id => program_events(:birthday_party).id}
    end
  end

  def test_update
    current_user_is :ram
    programs(:albers).mailer_template_enable_or_disable(ProgramEventUpdateNotification, true)
    assert_equal 2, programs(:albers).program_events.size
    admin_view = programs(:albers).admin_views.last
    post :update, params: { :id => program_events(:birthday_party).id, :program_event => {:title => 'Hack Day', :location => 'Hyderabad Office', :date => "August 20, 2015", :start_time => '10:30 am', :admin_view_id => admin_view.id, :status => "0", :time_zone => "Asia/Kuwait"}}
    assert_equal 2, programs(:albers).program_events.size
    event = programs(:albers).program_events.reload.find_by(title: 'Hack Day')
    assert_equal "07:30 am August 20, 2015", event.start_time.strftime('%I:%M %P %B %d, %Y')
    assert_equal 'Hyderabad Office', event.location
    assert_equal ProgramEvent::Status::DRAFT, event.status
    assert_equal admin_view, event.admin_view
    assert_equal 'Asia/Kuwait', event.time_zone
    assert_redirected_to program_event_path(event)
    assert_false programs(:albers).email_template_disabled_for_activity?(ProgramEventUpdateNotification)
  end

  def test_calendar_rsvp_program_event
    token = '3ohe4aeu7q0n6zjm1b0lbmvhro1v-s0zr6t9oieqhqm0vmnfm2'
    timestamp = '1351248513'
    signature = '303611ee8b73ea66858ee6c248c7fbf40377e72c6702453e5486a03285e35fde'
    credentials = { token: token, timestamp: timestamp, signature: signature }
    event = programs(:albers).program_events.first
    assert_equal 0, event.event_invites.count
    response = "BEGIN:VCALENDAR\r\nPRODID;X-RICAL-TZSOURCE=TZINFO:-//com.denhaven2/NONSGML ri_cal gem//EN\r\nCALSCALE:GREGORIAN\r\nVERSION:2.0\r\nMETHOD:REQUEST\r\nBEGIN:VEVENT\r\nCREATED:#{DateTime.localize(event.created_at.utc, format: :ics_full_time)}\r\nSTATUS:CONFIRMED\r\nDTSTART:#{DateTime.localize(event.start_time.utc, format: :ics_full_time)}\r\nTRANSP:OPAQUE\r\nDTSTAMP:#{DateTime.localize(event.created_at.utc, format: :ics_full_time)}\r\nLAST-MODIFIED:#{DateTime.localize(event.updated_at.utc, format: :ics_full_time)}\r\nATTENDEE;CN=student example;CUTYPE=INDIVIDUAL;PARTSTAT=ACCEPTED;ROLE=REQ-PARTICIPANT:mailto:rahim@example.com\r\nUID:program_event_#{DateTime.localize(event.created_at.utc, format: :ics_full_time)}@chronus.com\r\nDESCRIPTION:Message description:\nmail gun response\n\n\r\nSUMMARY:Test event mg\r\nORGANIZER;CN=Apollo Services:mailto:event-calendar-assistant-dev+#{ProgramEvent.send(:encryptor).encrypt(event.id)}@testmg.realizegoal.com\r\nLOCATION:CHENNAI\r\nEND:VEVENT\r\nEND:VCALENDAR"

    ProgramEvent.any_instance.stubs(:can_be_synced?).returns(true)
    post :calendar_rsvp_program_event, params: credentials.merge("body-calendar" => response, "To" => "Apollo Services <event-calendar-assistant-dev+#{ProgramEvent.send(:encryptor).encrypt(event.id)}@testmg.realizegoal.com>")
    ProgramEvent.calendar_rsvp_program_event("Apollo Services <event-calendar-assistant-dev+#{ProgramEvent.send(:encryptor).encrypt(event.id)}@testmg.realizegoal.com>", response)

    assert_equal 1, event.event_invites.count
    assert_equal EventInvite::Status::YES, event.event_invites.first.status

    post :calendar_rsvp_program_event, params: { "body-calendar" => response, "To" => "Apollo Services <EVENT-calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(event.id)}@testmg.realizegoal.com>"}
    assert_response 403
    assert_equal "Invaid signature", @response.body


    post :calendar_rsvp_program_event, params: credentials.merge("body-calendar" => response, "To" => "Apollo Services <random+#{Meeting.send(:encryptor).encrypt(event.id)}@testmg.realizegoal.com>")
    assert_response 200
    assert_equal "Mail Received But Rejected", @response.body

  end

  def test_update_published_mailer_check
    current_user_is :ram
    programs(:albers).mailer_template_enable_or_disable(ProgramEventUpdateNotification, true)
    admin_view = programs(:albers).admin_views.last
    post :update, params: { :id => program_events(:birthday_party).id, :program_event => {:title => 'Hack Day', :location => 'Hyderabad Office', :date => "August 20, 2015", :start_time => '10:30 am', :admin_view_id => admin_view.id, :status => "#{ProgramEvent::Status::PUBLISHED}", :time_zone => "Asia/Kuwait"}}
    assert programs(:albers).email_template_disabled_for_activity?(ProgramEventUpdateNotification)
  end

  def test_update_with_email_notification_set_for_drafted
    current_user_is :ram
    programs(:albers).mailer_template_enable_or_disable(ProgramEventUpdateNotification, false)
    admin_view = programs(:albers).admin_views.last
    post :update, params: { :id => program_events(:birthday_party).id, :program_event => {:title => 'Hack Day', :location => 'Hyderabad Office', :date => "August 20, 2015", :start_time => '10:30 am', :admin_view_id => admin_view.id, :status => "#{ProgramEvent::Status::DRAFT}", :time_zone => "Asia/Kuwait", email_notification: 'true'}}
    assert programs(:albers).email_template_disabled_for_activity?(ProgramEventUpdateNotification)
  end

  def test_update_with_email_notification_set_for_published
    current_user_is :ram
    programs(:albers).mailer_template_enable_or_disable(NewProgramEventNotification, false)
    admin_view = programs(:albers).admin_views.last
    post :update, params: { :id => program_events(:birthday_party).id, :program_event => {:title => 'Hack Day', :location => 'Hyderabad Office', :date => "August 20, 2015", :start_time => '10:30 am', :admin_view_id => admin_view.id, :status => "#{ProgramEvent::Status::PUBLISHED}", :time_zone => "Asia/Kuwait", email_notification: 'true'}}
    assert_false programs(:albers).email_template_disabled_for_activity?(ProgramEventUpdateNotification)
  end

  def test_update_with_vulnerable_content_with_version_v1
    current_user_is :ram
    admin_view = programs(:albers).admin_views.last
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")

    assert_no_difference "VulnerableContentLog.count" do
      post :update, params: { :id => program_events(:birthday_party).id, :program_event => {:title => 'Hack Day', :location => 'Hyderabad Office', :date => "August 20, 2015", :start_time => '10:30 am', :admin_view_id => admin_view.id, :status => "0", :time_zone => "Asia/Kuwait", :description => "This is a event <script>alert(10);</script>"}}
    end
  end

  def test_update_with_vulnerable_content_with_version_v2
    current_user_is :ram
    admin_view = programs(:albers).admin_views.last
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")

    assert_difference "VulnerableContentLog.count" do
      post :update, params: { :id => program_events(:birthday_party).id, :program_event => {:title => 'Hack Day', :location => 'Hyderabad Office', :date => "August 20, 2015", :start_time => '10:30 am', :admin_view_id => admin_view.id, :status => "0", :time_zone => "Asia/Kuwait", :description => "This is a event <script>alert(10);</script>"}}
    end
  end

  def test_destroy_permission_denied
    current_user_is :f_mentor
    assert_permission_denied do
      post :destroy, params: { :id => program_events(:ror_meetup).id}
    end
  end

  def test_destroy
    current_user_is :nwen_admin
    program_event = program_events(:entrepreneur_meetup)
    assert_difference 'ProgramEvent.count', -1 do
      assert_emails(ProgramEvent.notification_list(program_event.user_ids).active_or_pending.size) do
        post :destroy, params: { :id => program_event.id}
      end
    end
  end

  def test_show_permission_denied
    current_user_is :f_mentor
    event = program_events(:birthday_party)
    program = programs(:albers)
    mentee_view = program.admin_views.where(:default_view => AbstractView::DefaultType::MENTEES).first
    event.admin_view = mentee_view
    event.save!
    assert_permission_denied do
      get :show, params: { :id => event.id}
    end
  end

  def test_show_permission_denied_for_drafts
    current_user_is :f_mentor
    event = program_events(:birthday_party)
    event.status = ProgramEvent::Status::DRAFT
    event.save!
    assert_equal true, event.draft?
    assert_permission_denied do
      get :show, params: { :id => event.id}
    end
  end

  def test_show
    current_user_is :f_mentor
    event = program_events(:birthday_party)
    event.program_event_users.where(user_id: [users(:f_mentor_student).id, users(:robert).id]).destroy_all
    event.event_invites.where(user_id: [users(:f_mentor_student).id, users(:robert).id]).destroy_all
    attending_size = event.event_invites.attending.size
    attending_user_to_display = event.users_for_listing(users(:f_mentor)).where(:id => event.event_invites.attending.collect(&:user_id)).limit(ProgramEvent::SIDE_PANE_USER_LIMIT).collect(&:user_id)
    not_attending_size = event.event_invites.not_attending.size
    not_attending_user_to_display = event.users_for_listing(users(:f_mentor)).where(:id => event.event_invites.not_attending.collect(&:user_id)).limit(ProgramEvent::SIDE_PANE_USER_LIMIT).collect(&:user_id)
    maybe_attending_size = event.event_invites.maybe_attending.size
    maybe_attending_user_to_display = event.users_for_listing(users(:f_mentor)).where(:id => event.event_invites.maybe_attending.collect(&:user_id)).limit(ProgramEvent::SIDE_PANE_USER_LIMIT).collect(&:user_id)

    responded_users = (event.event_invites.attending + event.event_invites.not_attending + event.event_invites.maybe_attending).collect(&:user)
    not_responded_users = event.users - responded_users
    not_responded_size = not_responded_users.size
    not_responded_user_to_display = event.users_for_listing(users(:f_mentor)).where("users.id NOT IN (?)", responded_users.present? ? responded_users.map(&:id) : [0]).limit(ProgramEvent::SIDE_PANE_USER_LIMIT).collect(&:id)

    reponses_hash = { :attending => {size: attending_size, users_to_diplay: attending_user_to_display},
                      :not_attending => {size: not_attending_size, users_to_diplay: not_attending_user_to_display},
                      :may_be_attending => {size: maybe_attending_size, users_to_diplay: maybe_attending_user_to_display},
                      :not_responded => {size: not_responded_size, users_to_diplay: not_responded_user_to_display}}
    get :show, params: { :id => event.id}
    assert_response :success
    assert_select "div#admin_view_change_event_#{event.id}", false, "This should be restricted to admins"
    assert_equal event, assigns(:program_event)
    reponses_hash.each do |key,value|
      assert_equal value[:size], assigns(:responses)[key][:size]
      assert_equal_unordered value[:users_to_diplay], assigns(:responses)[key][:users_to_diplay].collect(&:id)
    end
  end

  def test_show_for_admins
    current_user_is :f_admin

    event = program_events(:birthday_party)
    event.program_event_users.where(user_id: [users(:f_mentor_student).id, users(:robert).id]).delete_all
    event.event_invites.where(user_id: [users(:f_mentor_student).id, users(:robert).id]).delete_all

    get :show, params: { :id => event.id}
    assert_match ProgramEventDeleteNotification.mailer_attributes[:uid], response.body
    assert_response :success
    assert_equal event, assigns(:program_event)
    assert_select "div#admin_view_change_event_#{event.id}" do
      assert_select "div.media-body", /The guest list for #{event.title} has changed since you last sent invitations. Would you like to update the list?/
      assert_select "span.new-invite-button-text", "Yes, update guest list"
    end
  end

  def test_show_drafted_for_admins
    current_user_is :f_admin

    event = program_events(:ror_meetup)
    assert_equal ProgramEvent::Status::DRAFT, event.status
    event.program_event_users.where(user_id: [users(:f_mentor_student).id, users(:robert).id]).delete_all
    event.event_invites.where(user_id: [users(:f_mentor_student).id, users(:robert).id]).delete_all
    event.program_event_users.reload
    old_count = event.program_event_users.size

    assert_no_emails do
      get :show, params: { id: event.id}
    end
    assert_response :success
    assert_equal event, assigns(:program_event)

    assert_select "div#admin_view_change_event_#{event.id}", false, "Not shown for drafted events"
    event.program_event_users.reload
    assert_equal old_count + 2, event.program_event_users.size
  end

  def test_show_with_tabs
    current_user_is :f_mentor
    event = program_events(:birthday_party)
    get :show, params: { :id => event.id, :tab => ProgramEventConstants::ResponseTabs::ATTENDING}
    assert_response :success
    assert_equal event, assigns(:program_event)
    assert_equal event.event_invites.attending.collect(&:user), assigns(:users_for_listing)

    get :show, params: { :id => event.id, :tab => ProgramEventConstants::ResponseTabs::NOT_ATTENDING}
    assert_response :success
    assert_equal event.event_invites.not_attending.collect(&:user), assigns(:users_for_listing)

    get :show, params: { :id => event.id, :tab => ProgramEventConstants::ResponseTabs::MAYBE_ATTENDING}
    assert_response :success
    assert_equal event.event_invites.maybe_attending.collect(&:user), assigns(:users_for_listing)
  end

  def test_show_csv_export_for_student
    current_user_is :f_student
    event = program_events(:birthday_party)
    event.role_names = [RoleConstants::STUDENT_NAME]
    event.save!
    event_invite_yes = event.event_invites.create!(:user => users(:f_student), :status => EventInvite::Status::YES)
    event_invite_no = event.event_invites.create!(:user => users(:student_7), :status => EventInvite::Status::NO)
    event_invite_maybe = event.event_invites.create!(:user => users(:student_6), :status => EventInvite::Status::MAYBE)
    get :show, params: { :id => event.id, :format => :csv}
    assert_response :success
    assert_equal event, assigns(:program_event)
    assert_response :success
    assert_equal "text/csv; charset=iso-8859-1; header=present", @response.headers["Content-Type"]
    csv_response = @response.body
    assert_match /First name,Last name,Email,Role,Attending?/, csv_response
    assert_match /Freakin,Admin,ram@example.com,Administrator,Not Responded/, csv_response
    assert_match /student,example,rahim@example.com,Student,Yes/, csv_response
    assert_match /student_g,example,student_6@example.com,Student,Maybe/, csv_response
    assert_match /student_h,example,student_7@example.com,Student,No/, csv_response
    assert_match /Event_birthday_party_#{DateTime.localize(event.start_time.in_time_zone(members(:f_mentor).get_valid_time_zone), format: :csv_timestamp)}/, @response.header["Content-Disposition"]
  end

  def test_show_csv_export_for_mentor_event
    current_user_is :f_mentor
    event = program_events(:birthday_party)
    event.role_names = [RoleConstants::MENTOR_NAME]
    event.save!
    event_invite_yes = event.event_invites.create!(:user => users(:f_mentor), :status => EventInvite::Status::YES)
    event_invite_no = event.event_invites.create!(:user => users(:mentor_7), :status => EventInvite::Status::NO)
    event_invite_maybe = event.event_invites.create!(:user => users(:mentor_6), :status => EventInvite::Status::MAYBE)
    get :show, params: { :id => event.id, :format => :csv}
    assert_response :success
    assert_equal event, assigns(:program_event)
    assert_response :success
    assert_equal "text/csv; charset=iso-8859-1; header=present", @response.headers["Content-Type"]
    csv_response = @response.body
    assert_match /First name,Last name,Email,Role,Attending?/, csv_response
    assert_match /Freakin,Admin,ram@example.com,Administrator,Not Responded/, csv_response
    assert_match /Good unique,name,robert@example.com,Mentor,Yes/, csv_response
    assert_match /mentor_g,chronus,mentor_6@example.com,Mentor,Maybe/, csv_response
    assert_match /mentor_h,chronus,mentor_7@example.com,Mentor,No/, csv_response
    assert_match /Event_birthday_party_#{DateTime.localize(event.start_time.in_time_zone(members(:f_mentor).get_valid_time_zone), format: :csv_timestamp)}/, @response.header["Content-Disposition"]
  end

  def test_show_csv_export_for_all_roles
    current_user_is :f_mentor
    event = program_events(:birthday_party)
    event_invite_yes = event.event_invites.create!(:user => users(:f_student), :status => EventInvite::Status::YES)
    event_invite_no = event.event_invites.create!(:user => users(:mentor_7), :status => EventInvite::Status::NO)
    event_invite_maybe = event.event_invites.create!(:user => users(:mentor_6), :status => EventInvite::Status::MAYBE)
    get :show, params: { :id => event.id, :format => :csv}
    assert_response :success
    assert_equal event, assigns(:program_event)
    assert_response :success
    assert_equal "text/csv; charset=iso-8859-1; header=present", @response.headers["Content-Type"]
    csv_response = @response.body
    assert_match /First name,Last name,Email,Role,Attending?/, csv_response
    assert_match /Freakin,Admin,ram@example.com,Administrator,Not Responded/, csv_response
    assert_match /student,example,rahim@example.com,Student,Yes/, csv_response
    assert_match /mentor_g,chronus,mentor_6@example.com,Mentor,Maybe/, csv_response
    assert_match /mentor_h,chronus,mentor_7@example.com,Mentor,No/, csv_response
    assert_match /Event_birthday_party_#{DateTime.localize(event.start_time.in_time_zone(members(:f_mentor).get_valid_time_zone), format: :csv_timestamp)}/, @response.header["Content-Disposition"]
  end

  def test_show_search
    current_user_is :f_mentor
    event = program_events(:birthday_party)
    event.event_invites.create!(:user => users(:f_mentor), :status => EventInvite::Status::YES)
    attending_user = event.event_invites.first.user

    get :show, xhr: true, params: { :format => :js, :id => event.id, :tab => ProgramEventConstants::ResponseTabs::ATTENDING, :search_content => attending_user.name}
    assert_response :success
    assert_equal event, assigns(:program_event)
    assert_equal [attending_user], assigns(:users_for_listing)
  end

  def test_show_sorting_order_for_invited_users
    current_user_is :f_mentor
    event = program_events(:birthday_party)
    event.event_invites.create!(:user => users(:f_mentor), :status => EventInvite::Status::YES)
    event.event_invites.create!(:user => users(:f_student), :status => EventInvite::Status::NO)
    connected_users = event.program_event_users.where(:user_id => (users(:f_mentor).students + users(:f_mentor).mentors)).map(&:user)

    get :show, params: { :id => event.id, :tab => ProgramEventConstants::ResponseTabs::INVITED}
    assert_response :success
    assert_equal event, assigns(:program_event)
    assert_equal (connected_users), assigns(:users_for_listing)[0..(connected_users.size-1)]
    assert assigns(:users_for_listing).include?(users(:f_student))
    assert assigns(:users_for_listing).include?(users(:f_mentor))
  end

  def test_update_invite_permission_denied
    current_user_is :f_mentor
    event = program_events(:birthday_party)
    program = programs(:albers)
    mentee_view = program.admin_views.where(:default_view => AbstractView::DefaultType::MENTEES).first
    event.admin_view = mentee_view
    event.save!

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ATTEND_PROGRAM_EVENT, {context_object: event.title}).never
    assert_permission_denied do
      post :update_invite, params: { :id => event.id, :status => EventInvite::Status::YES}
    end
  end

  def test_update_invite
    event = program_events(:birthday_party)
    current_user_is :f_mentor
    assert_empty event.event_invites.for_user(users(:f_mentor))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ATTEND_PROGRAM_EVENT, context_object: event.title).once
    post :update_invite, params: { id: event.id, status: EventInvite::Status::YES}
    invite = event.event_invites.for_user(users(:f_mentor)).reload
    assert_equal invite.first, assigns(:invite)
    assert_equal 1, invite.size
    assert_false invite.first.reminder
    assert_equal EventInvite::Status::YES, invite.first.status

    post :update_invite, params: { id: event.id, status: EventInvite::Status::MAYBE, event_invite: { reminder: "true" }}
    invite = event.event_invites.for_user(users(:f_mentor)).reload
    assert_equal 1, invite.size
    assert invite.first.reminder
    assert_equal EventInvite::Status::MAYBE, invite.first.status
  end

  def test_update_invite_via_email_yes
    event = program_events(:birthday_party)
    current_user_is :f_mentor
    assert_empty event.event_invites.for_user(users(:f_mentor))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ATTEND_PROGRAM_EVENT, context_object: event.title).once
    post :update_invite, params: { id: event.id, status: EventInvite::Status::YES, src: "email"}
    assert_redirected_to program_event_path(event)
    assert_equal "Your RSVP has been updated successfully. Click here to set reminder.", ActionController::Base.helpers.strip_tags(flash[:notice])
    invite = event.event_invites.for_user(users(:f_mentor)).reload
    assert_equal invite.first, assigns(:invite)
    assert_equal 1, invite.size
    assert_false invite.first.reminder
    assert_equal EventInvite::Status::YES, invite.first.status
  end

  def test_update_invite_via_email_maybe
    event = program_events(:birthday_party)
    current_user_is :f_mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ATTEND_PROGRAM_EVENT, context_object: event.title).never
    post :update_invite, params: { id: event.id, status: EventInvite::Status::MAYBE, event_invite: { reminder: "true" }, src: "email"}
    invite = event.event_invites.for_user(users(:f_mentor)).reload
    assert_equal 1, invite.size
    assert invite.first.reminder
    assert_equal EventInvite::Status::MAYBE, invite.first.status
  end

  def test_update_invite_without_status
    event = program_events(:birthday_party)
    current_user_is :f_mentor
    assert_empty event.event_invites.for_user(users(:f_mentor))
    post :update_invite, params: { id: event.id, src: "email"}
    assert_redirected_to program_event_path(event)
    assert_nil flash[:notice]
    assert_empty event.event_invites.for_user(users(:f_mentor))
  end

  def test_update_invite_for_non_existent_event
    event = program_events(:birthday_party)
    current_user_is :f_mentor
    post :update_invite, params: { id: 0}
    assert_redirected_to program_events_path
    assert_equal "The event you are trying to access doesn't exist.", flash[:error]
  end

  def test_more_activities_permission_denied
    current_user_is :f_mentor
    event = program_events(:birthday_party)
    program = programs(:albers)
    mentee_view = program.admin_views.where(:default_view => AbstractView::DefaultType::MENTEES).first
    event.admin_view = mentee_view
    event.save!
    assert_permission_denied do
      get :more_activities, xhr: true, params: { :id => event.id, :offset_id => 5}
    end
  end

  def test_more_activities
    current_user_is :f_mentor

    mock_1 = mock()
    mock_2 = mock()
    mock_3 = mock()

    Group.any_instance.expects(:activities).at_least(0).returns(mock_1)
    mock_1.expects(:for_display).at_least(0).returns(mock_2)
    mock_2.expects(:latest_first).at_least(0).returns(mock_3)
    mock_3.expects(:fetch_with_offset).with(20, 5, {}).at_least(0).returns([])

    get :more_activities, xhr: true, params: { :id => program_events(:birthday_party).id, :offset_id => 5}
    assert_response :success
    assert_equal 5, assigns(:offset_id)
    assert_equal 25, assigns(:new_offset_id)
  end

  def test_update_reminder
    current_user_is :ram
    event = program_events(:birthday_party)
    event.event_invites.create!(:user => users(:ram), :status => EventInvite::Status::YES)
    invite = event.event_invites.for_user(users(:ram)).first
    assert_equal false, invite.reminder
    post :update_reminder, params: { :id => event.id, :event_invite => {:reminder => "true"}}
    assert_equal true, invite.reload.reminder
    assert_redirected_to program_event_path(event)

    post :update_reminder, params: { :id => event.id}
    assert_equal false, invite.reload.reminder
    assert_redirected_to program_event_path(event)
  end

  def test_publish_permission_denied
    current_user_is :f_mentor
    event = program_events(:birthday_party)
    assert_permission_denied do
      post :publish, params: { :id => event.id, :email_notification => "true"}
    end
  end

  def test_publish
    current_user_is :nwen_admin
    event = program_events(:entrepreneur_meetup)
    program = programs(:nwen)
    assert_emails(ProgramEvent.notification_list(event.user_ids).active_or_pending.size) do
      post :publish, params: { :id => event.id, :program_event => { :email_notification => "true"}}
    end
    assert_equal ProgramEvent::Status::PUBLISHED, event.status
    assert_redirected_to program_event_path(event)
    assert_false programs(:albers).email_template_disabled_for_activity?(NewProgramEventNotification)
  end

  def test_publish_no_emails
    current_user_is :ram
    event = program_events(:birthday_party)
    assert_no_emails do
      post :publish, params: { :id => event.id}
    end
    assert_equal ProgramEvent::Status::PUBLISHED, event.status
    assert_redirected_to program_event_path(event)
    assert programs(:albers).email_template_disabled_for_activity?(NewProgramEventNotification)
  end

  def test_send__test_emails_permission_denied
    current_user_is :f_mentor
    event = program_events(:birthday_party)
    assert_permission_denied do
      post :send_test_emails, params: { :id => event.id}
    end
  end

  def test_send_test_emails_from_show
    current_user_is :ram
    event = program_events(:birthday_party)
    assert_emails(2) do
      post :send_test_emails, xhr: true, params: { :id => event.id, :test_program_event => {:notification_list_for_test_email => "test12@test.com, test23@test.com"}, :src => "show"}
    end
    assert_response :success
    email = ActionMailer::Base.deliveries.last
    assert_equal "Update: Birthday Party", email.subject
  end

  def test_send_test_emails_from_form
    current_user_is :ram
    event = program_events(:birthday_party)
    assert_emails(2) do
      post :send_test_emails, xhr: true, params: { :test_program_event => {:date => "October 26, 2012", :start_time => "7:00 am", :notification_list_for_test_email => "test12@test.com, test23@test.com", :time_zone => "Asia/Kolkata"}}
    end
    assert_response :success
    email = ActionMailer::Base.deliveries.last
    assert_equal "Invitation: (No title) on October 26, 2012 07:00 am IST", email.subject
  end

  def test_add_new_invitees_permission_denied
    current_user_is :f_mentor
    assert_permission_denied do
      post :add_new_invitees, params: { id: program_events(:birthday_party).id}
    end
  end

  def test_add_new_invitees_permission_denied_archived_event
    current_user_is :ram
    program_event = program_events(:birthday_party)
    ProgramEvent.any_instance.stubs(:archived?).returns(true)
    assert_permission_denied do
      post :add_new_invitees, params: { id: program_event.id}
    end
  end

  def test_add_new_invitees_user_added
    current_user_is :ram
    program_event = program_events(:birthday_party)
    program_event.program_event_users.where(user_id: users(:f_student).id).delete_all
    old_version = program_event.version_number
    display_time = "#{DateTime.localize(program_event.start_time.in_time_zone(program_event.time_zone), format: 'short_date_short_time'.to_sym)} IST"
    assert_emails(1) do
      post :add_new_invitees, params: { id: program_event.id, from: "show"}
    end
    assert_redirected_to program_event_path(program_event)
    assert_equal "Guest list updated for Birthday Party", flash[:notice]
    assert_equal old_version + 1, program_event.reload.version_number
    email = ActionMailer::Base.deliveries.last
    assert_equal [users(:f_student).email], email.to
    assert_equal "Invitation: Birthday Party on #{display_time}", email.subject
    mail_content = get_html_part_from(email)
    assert_match /Yes, I will attend/, mail_content
    assert_match /No, I will not attend/, mail_content
    assert_match /Maybe, I might attend/, mail_content
    assert_match /You've been invited/, mail_content
  end

  def test_add_new_invitees_user_added_and_removed_together
    current_user_is :ram
    program_event = program_events(:birthday_party)
    program_event.program_event_users.where(user_id: users(:f_student).id).delete_all
    program_event.program_event_users.create(user_id: users(:f_user).id)
    assert_emails(2) do
      post :add_new_invitees, params: { id: program_event.id}
    end
    assert_redirected_to program_events_path
    assert_equal "Guest list updated for Birthday Party", flash[:notice]
  end

  def test_add_new_invitees_user_added_multiple
    current_user_is :ram
    program_event = program_events(:birthday_party)
    program_event.program_event_users.where(user_id: [users(:f_student).id, users(:f_mentor).id]).delete_all
    assert_emails(2) do
      post :add_new_invitees, params: { id: program_event.id, from: "show"}
    end
    assert_redirected_to program_event_path(program_event)
    assert_equal "Guest list updated for Birthday Party", flash[:notice]
  end

  def test_add_new_invitee_removed_and_then_added_back
    current_user_is :ram
    user = users(:f_mentor_student)
    program_event = program_events(:birthday_party)
    user.program = programs(:pbe)
    user.save!
    user.reload
    assert_emails(1) do
      post :add_new_invitees, params: { id: program_event.id}
    end
    assert_redirected_to program_events_path
    assert_equal "Guest list updated for Birthday Party", flash[:notice]

    user.program = programs(:albers)
    user.save!
    reindex_documents(updated: user)
    assert_emails(1) do
      post :add_new_invitees, params: { id: program_event.id}
    end
    assert_redirected_to program_events_path
    assert_equal "Guest list updated for Birthday Party", flash[:notice]
  end

  def test_create_with_xss_content
    current_user_is :ram
    admin_view = programs(:albers).admin_views.first
    assert_equal 2, programs(:albers).program_events.size
    post :create, params: { :program_event => {:title => '<script>alert("Hack Day")</script>', :location => '<script>alert("Chronus Office")</script>', :date => "August 25, 2015", :start_time => '09:30 am', :admin_view_id => admin_view.id, :status => "0", :time_zone => "Asia/Kolkata"}}
    assert_equal 3, programs(:albers).program_events.size
    event = programs(:albers).program_events.reload.find_by(title: '<script>alert("Hack Day")</script>')
    assert_equal "04:00 am August 25, 2015", event.start_time.strftime('%I:%M %P %B %d, %Y')
    assert_equal '<script>alert("Chronus Office")</script>', event.location
    assert_equal ProgramEvent::Status::DRAFT, event.status
    assert_equal admin_view, event.admin_view
    assert_redirected_to program_event_path(event)
  end

  def test_show_with_xss_content
    current_user_is :ram
    event = programs(:albers).program_events.first
    event.update_attributes(:title => '<script>alert("Hack Day")</script>')
    get :show, params: { :id => event.id}
    assert_response :success
    assert_equal event, assigns(:program_event)
    assert_select "div#page_heading", true, '<script>alert("Hack Day")</script>'
  end
end
