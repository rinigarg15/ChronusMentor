require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/group_checkins_helper"

class GroupCheckinsHelperTest < ActionView::TestCase
  def test_display_checkin_duration
    clock_div = content_tag(:i, "", :class => "fa fa-clock-o no-margins fa-fw m-r-xs")

    assert_equal display_checkin_duration(0), "" 
    assert_equal display_checkin_duration(20), clock_div+"20 minutes"
    assert_equal display_checkin_duration(60), clock_div+"1 hour"
    assert_equal display_checkin_duration(105), clock_div+"1 hour, 45 minutes"
    assert_equal display_checkin_duration(60000045), clock_div+"1000000 hours, 45 minutes"
    #hide clock
    assert_equal display_checkin_duration(0, hide_clock: true), "0 hours"
    assert_equal display_checkin_duration(20, hide_clock: true), "20 minutes"
    assert_equal display_checkin_duration(60, hide_clock: true), "1 hour"
    assert_equal display_checkin_duration(105, hide_clock: true), "1 hour, 45 minutes"
    assert_equal display_checkin_duration(60000045, hide_clock: true), "1000000 hours, 45 minutes"
    #hour format
    assert_equal display_checkin_duration(0, hide_clock: true, hour_format: true), ["0", "hours"]
    assert_equal display_checkin_duration(20, hide_clock: true, hour_format: true), ["00:20", "hours"]
    assert_equal display_checkin_duration(60, hide_clock: true, hour_format: true), ["01:00", "hours"]
    assert_equal display_checkin_duration(105, hide_clock: true, hour_format: true), ["01:45", "hours"]
    #without hide clock
    assert_equal display_checkin_duration(0, hour_format: true), ""
    assert_equal display_checkin_duration(20, hour_format: true), clock_div+"00:20 hours"
    assert_equal display_checkin_duration(60, hour_format: true), clock_div+"01:00 hours"
    assert_equal display_checkin_duration(105, hour_format: true), clock_div+"01:45 hours"

  end


  def test_checkin_listing_fields
    expected_obj = {
      id: { type: :string },
      mentor: {type: :string },
      group: {type: :string},
      date: { type: :date }, 
      duration: { type: :string },
      type: {type: :string},
      comment: { type: :string },
      title: {type: :string}
    }
    fields = check_in_listing_fields
    assert_equal fields.count, 8, "more than required no of fields present"
    assert_equal expected_obj, fields
  end

  def test_get_column_names
    column_names = get_column_names
    assert_equal 7, column_names.count, "Different number of column names being returned"
    assert_equal "Mentor", column_names[:mentorName]
    assert_equal "Mentoring Connection", column_names[:mentoringConnection]
    assert_equal "Date", column_names[:date]
    assert_equal "Time", column_names[:duration]
    assert_equal "Type", column_names[:checkin_type]
    assert_equal "Comment", column_names[:comment]
    assert_equal "Title", column_names[:titleName]
  end

  def test_construct_optionals
    program = Program.find_by(name: "Albers Mentor Program")
    self.expects(:type_radioboxes).returns(["Type"])
    self.expects(:get_column_names).returns(["a","b","c"])
    self.expects(:check_in_listing_fields).returns(["Fields"])
    checkin_details = render partial: "group_checkins/duration_details", locals: {meeting_text: "Meetings"}
    expected_options = {
      fields: ["Fields"],
      dataSource: "/group_checkins.json",
      # dataSource: check_ins_path(format: :json),
      grid_id: "cjs_check_ins_listing_kendogrid",
      selectable: false,
      serverPaging: true,
      serverFiltering: true,
      serverSorting: true,
      sortable: true,
      pageable: {
        messages: {
          empty: "There are no check-ins to report on"
        }
      },
      filterable:{
        extra: false,
        operators: {
          string: {
            startswith: "contains",
          }
        }
      },
      checkbox_fields: [:type],
      checkbox_values: {
        :type => ["Type"],
      },
      simple_search_fields: [:mentor, :group, :comment, :title],
      date_fields: [:date],
      column_names: ["a","b","c"],
      checkin_details:{
        details_text: "details",
        checkinHoursDetails: checkin_details
      }
    }
    assert_equal expected_options, construct_optionals(program,checkin_details)
  end

  def test_initialize_check_in_listing_kendo_script
    options = {:key => "value"}
    self.expects(:construct_optionals).returns(options)
    checkin_details = render partial: "group_checkins/duration_details", locals: {meeting_text: "Meetings"}
    expected_output = javascript_tag "CheckinsKendo.initializeKendo(#{options.to_json})"
    assert_equal expected_output, initialize_check_in_listing_kendo_script(Program.find(13), checkin_details)
  end

  def test_get_mentor_name_from_group_checkin
    checkin = GroupCheckin.first
    assert_equal "Good unique name", get_mentor_name_from_group_checkin(checkin)
  end

  def test_get_group_name_from_group_checkin
    checkin = GroupCheckin.first
    assert_equal "name & madankumarrajan", get_group_name_from_group_checkin(checkin)
  end

  def test_get_group_checkin_type
    checkin = GroupCheckin.first
    assert_equal "Meeting", get_group_checkin_type(checkin)
  end

  def test_get_group_checkin_date
    time = Time.now
    assert_equal time.strftime("%m/%d/%Y"), get_group_checkin_date(time)
  end

private

  def _Mentor
    "Mentor"
  end

  def _Mentoring_Connection
    "Mentoring Connection"
  end

  def _Meeting
    "Meeting"
  end

end