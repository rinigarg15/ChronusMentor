require_relative './../../test_helper.rb'

class AdminWeeklyStatusHelperTest < ActionView::TestCase
  include Emails::AdminWeeklyStatusHelper

  def setup
    super
    @_Mentoring_string = "Test Mentoring"
    @_Mentoring_Connections_string = "Test Mentoring Connection"
    @_Meeting_string = "Test Meeting"
    @_articles_string = "Test articles"
    @_mentoring_connections_string = "Test mentoring connection"
    @_employees_string = "Test employees"
    @_mentors_string = "Test teachers"
    @_mentees_string = "Test students"
    @_admins_string = "Test admins"
  end

  def test_items_to_display
    portal = programs(:primary_portal)
    data_hash = {}
    data_hash[:last_week_mem_requests] = 1000
    data_hash[:show_mr_data] = false
    data_hash[:mr_data_values_changed] = true

    data_hash[:new_survey_responses] = 0

    result = items_to_display(portal, data_hash)
    assert_equal [], result

    data_hash[:last_week_mem_requests] = 1000
    data_hash[:show_mr_data] = false
    data_hash[:mr_data_values_changed] = true

    result = items_to_display(portal, data_hash)
    assert_equal [], result

    data_hash[:last_week_mem_requests] = 1000
    data_hash[:show_mr_data] = false
    data_hash[:mr_data_values_changed] = false

    result = items_to_display(portal, data_hash)
    assert_equal [], result

    data_hash[:last_week_mem_requests] = 1000
    data_hash[:show_mr_data] = true
    data_hash[:mr_data_values_changed] = true

    result = items_to_display(portal, data_hash)
    assert_has_item_with_text "Pending Membership Requests", 1000, result
    assert_has_no_item_with_text "New Survey Responses", result
    data_hash[:last_week_mentor_reqs] = 2000
    data_hash[:last_week_active_mentor_reqs] = 3000
    data_hash[:show_mentor_reqs] = true
    
    result = items_to_display(portal, data_hash)
    assert_has_item_with_text "Test Mentoring Requests Received", 2000, result
    assert_has_item_with_text "Test Mentoring Requests Pending", 3000, result
    
    data_hash[:show_mentor_reqs] = false
    result = items_to_display(portal, data_hash)
    assert_has_no_item_with_text "Test Mentoring Requests Received", result
    assert_has_no_item_with_text "Test Mentoring Requests Pending", result

    data_hash[:last_week_groups] = 4000
    data_hash[:show_groups] = true

    result = items_to_display(portal, data_hash)
    assert_has_item_with_text "Test Mentoring Connection Established", 4000, result

    data_hash[:show_groups] = false
    assert_has_no_item_with_text "Test Mentoring Connection Established", items_to_display(portal, data_hash)

    data_hash[:last_week_meeting_reqs] = 5000
    data_hash[:show_meeting_reqs] = true

    assert_has_item_with_text "Test Meeting Requests Received", 5000, items_to_display(portal, data_hash)
    data_hash[:show_meeting_reqs] = false
    assert_has_no_item_with_text "Test Meeting Requests Received", items_to_display(portal, data_hash)
    
    data_hash[:last_week_active_meeting_reqs] = 6000
    data_hash[:show_active_meeting_reqs] = true

    assert_has_item_with_text "Test Meeting Requests Pending", 6000, items_to_display(portal, data_hash)
    data_hash[:show_active_meeting_reqs] = false
    assert_has_no_item_with_text "Test Meeting Requests Pending", items_to_display(portal, data_hash)
    

    data_hash[:last_week_articles] = 7000
    data_hash[:show_articles_data] = true

    assert_has_item_with_text "New Test articles", 7000, items_to_display(portal, data_hash)
    data_hash[:show_articles_data] = false
    assert_has_no_item_with_text "New Test articles", items_to_display(portal, data_hash)

    data_hash[:proposed_groups] = 8000

    assert_has_item_with_text "Test Mentoring Connection waiting to be approved", 8000, items_to_display(portal, data_hash)
    data_hash[:proposed_groups] = nil
    assert_has_no_item_with_text "Test Mentoring Connection waiting to be approved", items_to_display(portal, data_hash)

    data_hash[:pending_project_requests] = 9000
    data_hash[:pending_project_requests_data_values_changed] = true
    assert_has_item_with_text "Users waiting to join Test mentoring connection", 9000, items_to_display(portal, data_hash)
    data_hash[:pending_project_requests_data_values_changed] = false
    assert_has_no_item_with_text "Users waiting to join Test mentoring connection", items_to_display(portal, data_hash)
    
    data_hash[:last_week_employees] = 10000
    data_hash[:show_employees] = true
    assert_has_item_with_text "New Test employees", 10000, items_to_display(portal, data_hash)
    data_hash[:show_employees] = false
    assert_has_no_item_with_text "New Test employees", items_to_display(portal, data_hash)
    
    program = programs(:albers)

    data_hash[:last_week_mentors] = 11000
    data_hash[:show_mentors] = true
    assert_has_item_with_text "New Test teachers", 11000, items_to_display(program, data_hash)
    data_hash[:show_mentors] = false
    assert_has_no_item_with_text "New Test teachers", items_to_display(program, data_hash)

    data_hash[:last_week_students] = 12000
    data_hash[:show_students] = true
    assert_has_item_with_text "New Test students", 12000, items_to_display(program, data_hash)
    data_hash[:show_students] = false
    assert_has_no_item_with_text "New Test students", items_to_display(program, data_hash)

    data_hash[:last_week_admins] = 12000
    data_hash[:show_admins] = true
    assert_has_no_item_with_text "New Test admins", items_to_display(program, data_hash)
    data_hash[:show_admins] = false
    assert_has_no_item_with_text "New Test admins", items_to_display(program, data_hash)

    data_hash[:last_week_students] = 12000
    data_hash[:show_students] = true
    assert_has_item_with_text "New Test students", 12000, items_to_display(program, data_hash)
    data_hash[:show_students] = false
    assert_has_no_item_with_text "New Test students", items_to_display(program, data_hash)

    data_hash[:new_survey_responses] = 13000
    assert_has_item_with_text "New Survey Responses", 13000, items_to_display(program, data_hash)
  end

  private
    def assert_has_item_with_text(text, count = nil, result)
      assert (element = result.find{|item| item[:text] == text}).present?
      assert_equal element[:count], count if count.present?
    end

    def assert_has_no_item_with_text(text, result)
      assert_false (element = result.find{|item| item[:text] == text}).present?
    end
end


  
