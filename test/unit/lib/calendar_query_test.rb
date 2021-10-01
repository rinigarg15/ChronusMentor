require_relative './../../test_helper.rb'

class CalendarQueryTest < ActionView::TestCase

  def setup
    super
    @start_time = DateTime.current.beginning_of_day
    @end_time = @start_time.tomorrow
  end

  def test_busy_slots_for_members
    Timecop.freeze
    member = members(:f_mentor)
    stub_busy_slots_response

    response = CalendarQuery.get_busy_slots_for_members(@start_time, @end_time, members: [member])
    assert_equal ({error_occured: false, busy_slots: []}), response[member.id]

    member.o_auth_credentials.new
    response = CalendarQuery.get_busy_slots_for_members(@start_time, @end_time, members: [member])
    assert_equal ({error_occured: nil, busy_slots: get_free_calendar_slots_for_member(Date.current, :start_time, :end_time), error_code: nil, error_message: nil}), response[member.id]

    # with error code, response and message
    stub_busy_slots_response(error_occured: true, error_code: 401, error_message: "error message")
    response = CalendarQuery.get_busy_slots_for_members(@start_time, @end_time, members: [member])
    assert_equal ({error_occured: true, error_code: 401, error_message: "error message"}), response[member.id].slice(:error_occured, :error_code, :error_message)
  end

  def test_get_merged_busy_slots_for_member
    Timecop.freeze
    mentor = members(:f_mentor)
    student = members(:f_student)
    stub_busy_slots_response(error_occured: false)

    response = CalendarQuery.get_merged_busy_slots_for_member(@start_time, @end_time, members: [mentor])
    assert_equal ({error_occured: false, busy_slots: []}), response

    mentor.o_auth_credentials.new
    response = CalendarQuery.get_merged_busy_slots_for_member(@start_time, @end_time, members: [mentor])
    assert_equal ({error_occured: false, busy_slots: get_free_calendar_slots_for_member(Date.current, :start_time, :end_time)}), response
    
    student.o_auth_credentials.new
    response = CalendarQuery.get_merged_busy_slots_for_member(@start_time, @end_time, members: [mentor, student])
    assert_equal ({error_occured: false, busy_slots: (get_free_calendar_slots_for_member(Date.current, :start_time, :end_time) * 2)}), response
  end

  def test_get_o_auth_credentials
    member = members(:f_mentor)

    member_o_auth_creds = create_o_auth_credential({ref_obj: member})
    org_o_auth_creds = create_o_auth_credential({ref_obj: member.organization})

    o_auth_credentials_result = CalendarQuery.send(:get_o_auth_credentials, member, {organization_wide_calendar: true})
    assert_equal [org_o_auth_creds], o_auth_credentials_result[:o_auth_credentials].to_a
    assert_equal member.email, o_auth_credentials_result[:calendar_key]

    o_auth_credentials_result = CalendarQuery.send(:get_o_auth_credentials, member, {organization_wide_calendar: false})
    assert_equal [member_o_auth_creds], o_auth_credentials_result[:o_auth_credentials].to_a
    assert_equal "primary", o_auth_credentials_result[:calendar_key]
  end

  private

  def stub_busy_slots_response(options = {})
    return_hash = {busy_slots: get_free_calendar_slots_for_member(Date.current, :start_time, :end_time)}.merge(options)
    OAuthCredential.any_instance.stubs(:get_free_busy_slots).returns(return_hash)
  end

end
