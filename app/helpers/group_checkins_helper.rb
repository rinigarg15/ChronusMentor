module GroupCheckinsHelper
  def check_in_listing_fields
    {
      id: { type: :string },
      mentor: {type: :string },
      group: {type: :string},
      date: { type: :date }, 
      duration: { type: :string },
      type: {type: :string},
      comment: { type: :string },
      title: {type: :string }
    }
  end

  def get_column_names
    {
      mentorName: _Mentor,
      mentoringConnection: _Mentoring_Connection,
      date: "feature.contract_management.headings.date".translate,
      duration: "feature.contract_management.headings.duration".translate,
      checkin_type: "feature.contract_management.headings.type".translate,
      comment: "feature.contract_management.headings.comment".translate,
      titleName: "feature.contract_management.headings.title".translate
    }
  end

  def type_radioboxes
    [
      {
        displayed_as: _Meeting,
        posted_as: "Meeting"
      }, #first array element
      {
        displayed_as: "feature.contract_management.kendo.filters.checkboxes.statuses.task".translate,
        posted_as: "Task"
      } #second array element
    ]

  end
   
  def construct_optionals(program, checkin_hours_details)
    {
      fields: check_in_listing_fields,
      dataSource: url_for(:controller=>'group_checkins', :action=>'index', :format=>:json),
      # dataSource: check_ins_path(format: :json),
      grid_id: "cjs_check_ins_listing_kendogrid",
      selectable: false,
      serverPaging: true,
      serverFiltering: true,
      serverSorting: true,
      sortable: true,
      pageable: {
        messages: {
          empty: "feature.contract_management.content.no_checkin".translate
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
        :type => type_radioboxes,
      },
      simple_search_fields: [:mentor, :group, :comment, :title],
      date_fields: [:date],
      column_names: get_column_names,
      checkin_details:{
        details_text: "feature.group_checkin.label.details".translate,
        checkinHoursDetails: checkin_hours_details
      }
      
    }
  end
  
  def initialize_check_in_listing_kendo_script(program, checkin_hours_details)
    options = construct_optionals(program, checkin_hours_details)
    javascript_tag "CheckinsKendo.initializeKendo(#{options.to_json})"
  end

  def get_mentor_name_from_group_checkin(check_in)
    check_in.user.name
  end

  def get_group_name_from_group_checkin(check_in)
    check_in.group.name
  end

  def get_group_checkin_type(check_in)
    return "feature.contract_management.task".translate if check_in.checkin_ref_obj_type == MentoringModel::Task.name 
    return _Meeting
  end

  def get_group_checkin_date(date)
    date.strftime("%m/%d/%Y")
  end

  def get_checkin_member_pic(check_in)
     member_picture_v3(check_in.user.member, {:no_name => true, :row_fluid => true, :size => :small, :new_size => "small"}, image_options = {:class => "img-circle"})
  end

  def get_checkin_report_date_range_options(selected_option)
    options_array = []
    GroupCheckinsController::DateRangeOptions.presets.each do |option|
      options_array << ["chronus_date_range_picker_strings.preset_ranges.#{option}".translate, option]
    end
    options_array << ["chronus_date_range_picker_strings.custom".translate, ReportsController::DateRangeOptions::CUSTOM]
    options_for_select(options_array, selected_option)
  end

  def display_checkin_duration(duration, options = {})
    if duration == 0
      response = options[:hide_clock].present? ? ("feature.group_checkin.hours".translate(count: 0)) : ""
      return (options[:hour_format] && !response.blank?) ? response.split(" ") : response
    end
    
    hours = duration / 60
    minutes = duration % 60
    
    clock_div = options[:hide_clock].present? ? "" : get_icon_content("fa fa-clock-o no-margins")
    divider = options[:divider].present? ? vertical_separator : ""

    if options[:hour_format]
      duration_text = "feature.group_checkin.hours".translate(count: format("%02d:%02d", hours, minutes))
      if clock_div.blank? && divider.blank?
        return duration_text.split(" ")
      else
        return clock_div + duration_text + divider
      end
    end

    if hours == 0
      duration_text = "display_string.minutes".translate(minutes: minutes) 
    else
      hours_string = "feature.group_checkin.hours".translate(count: hours)
      minutes_string = minutes == 0 ? "" : ", " + "display_string.minutes".translate(minutes: minutes)
      duration_text = hours_string + minutes_string
    end
    clock_div + duration_text + divider 
  end
end