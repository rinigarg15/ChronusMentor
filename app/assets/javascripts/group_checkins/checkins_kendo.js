var CheckinsKendo = {

  columnAttributes: { "class" : "checkin-row" },

  initializeKendo: function(options) {
    jQuery(document).ready(function(){
      CheckinsKendo.initializeCSV(options);
      CheckinsKendo.initializeDateForm(options);
      CheckinsKendo.initializeGrid(options);
    });
  },

  initializeGrid: function(options) {
    var gridDiv = jQuery("#" + options.grid_id);
    var grid = gridDiv.kendoGrid({
      dataSource: {
        type: "json",
        transport: { read: options.dataSource },
        schema: {
          model: { fields: options.fields },
          parse: function(response) {
            gridDiv.data('totalHours', response.totalHours);
            gridDiv.data('meetingHours', response.meetingHours);
            gridDiv.data('taskHours', response.taskHours);
            data = response.data;
            data.total = response.total;
            return data;
          },
          total: function (response) { return data.total }
        },
        pageSize: 25,
        serverPaging: options.serverPaging,
        serverFiltering: options.serverFiltering,
        serverSorting: options.serverSorting,
        sort: {field: "date", dir: "desc"}
      },
      sortable: options.sortable,
      pageable: options.pageable,
      scrollable: true,
      filterable: options.filterable,
      filterMenuInit: function (e) {
        checkbox_fields = this.input_options.checkbox_fields;
        simple_search_fields = this.input_options.simple_search_fields;
        date_fields = this.input_options.date_fields;
        if((checkbox_fields != undefined) &&  (checkbox_fields.indexOf(e.field) != -1)) {
          KendoRadioHelper.onFilterMenuInit(e);
        }
        else if((simple_search_fields != undefined) &&  (simple_search_fields.indexOf(e.field) != -1)) {
          KendoFilterHelper.onSimpleSearchFilterInit(e);
        }
        else if((date_fields != undefined) &&  (date_fields.indexOf(e.field) != -1)) {
          KendoFilterHelper.onDateFilterInit(e);
        }
      },
      columns: [
        {
          title: options.column_names.mentorName,
          field: "mentor",
          width: "200px",
          encoded: false,
          template: function(options) {
            return options.memberPic + "<a href="+ options.mentorLink + ">" + kendo.htmlEncode(options.mentor) + "</a>";
          },
          attributes: CheckinsKendo.columnAttributes
        },
        {
          title: options.column_names.mentoringConnection,
          field: "group",
          width: "280px",
          encoded: false,
          template: function(options) {
            return "<a href="+ options.groupsLink + ">" + kendo.htmlEncode(options.group) + "</a>";
          },
          attributes: CheckinsKendo.columnAttributes
        },
        {
          title: options.column_names.date,
          field: "date",
          width: "90px",
          encoded: false,
          filterable: false,
          format: "{0:MM/dd/yyyy}",
          attributes: CheckinsKendo.columnAttributes
        },
        {
          title: options.column_names.duration,
          field: "duration",
          width: "220px",
          encoded: false,
          filterable: false,
          sortable: false,
          attributes: CheckinsKendo.columnAttributes,
          headerAttributes: {"class": "checkin-time-heading"}
        },
        {
          title: options.column_names.checkin_type,
          field: "type",
          width: "100px",
          encoded: false,
          attributes: CheckinsKendo.columnAttributes
        },
        {
          title: options.column_names.titleName,
          field: "title",
          width: "300px",
          encoded: false,
          attributes: CheckinsKendo.columnAttributes
        },
        {
          title: options.column_names.comment,
          field: "comment",
          width: "360px",
          encoded: false,
          attributes: CheckinsKendo.columnAttributes
        }
      ],
      height: options.height,
      dataBound: function () {
        CheckinsKendo.onDataBound(options);
      }
    });

    // Store the input options in the kendo instance
    var kendo_instance = gridDiv.data('kendoGrid');
    if(kendo_instance){
      kendo_instance.input_options = options;
    }
  },

  getCSV: function(options){
    var gridDiv = jQuery("#" + options.grid_id);
    var grid = gridDiv.data('kendoGrid');
    info = {};
    if(grid){
      if(grid.dataSource.filter() && grid.dataSource.filter().filters){
        info.filter = {filters: grid.dataSource.filter().filters}
      }

      if(grid.dataSource.sort()){
        info.sort = grid.dataSource.sort();
      }
    }
    var targetURL = window.location.href
    if(targetURL.indexOf("?") != -1)
      targetURL = targetURL.substring(0, targetURL.indexOf("?"))

      var targetURL = targetURL + ".csv";
      if(!jQuery.isEmptyObject(info)) targetURL += "?" + jQuery.param(info);
      window.open(targetURL);
  },

  initializeCSV: function(options){
    jQuery(".check_in_csv").click(function(e)
      {
        CheckinsKendo.getCSV(options);
      });
  },

  mentorTemplate: function(options){
    return options.memberPic + "<a href="+ options.mentorLink + ">" + kendo.htmlEncode(options.mentor) + "</a>";
  },

  onDataBound: function (options) {
    var gridDiv = jQuery("#" + options.grid_id);
    var grid = gridDiv.data('kendoGrid');
    if(grid.dataSource.view().length == 0 && options.grid_id != "cjs_check_ins_listing_kendogrid") {
      jQuery(grid.table).parent().html('<div class="empty-grid">' + options.messages.emptyMessage + '</div>');
    }
    var checkinData = {
      totalHours: gridDiv.data('totalHours'),
      meetingHours: gridDiv.data('meetingHours'),
      taskHours: gridDiv.data('taskHours')
    }

    handleDoubleScroll("#cjs_check_in_result table", ".cjs_table_enclosure", ".k-grid-content", "#cjs_check_ins_listing_kendogrid", { contentElement: "table" });
    CheckinsKendo.initializeTimeHover(options, checkinData);
    initialize.initializeTooltip();
  },

  initializeTimeHover: function(options, checkinData){
    jQuery('.cjs-checkin-total-hours').remove();
    jQuery('.cjs-checkin-details-tooltip').remove();

    var th = jQuery(".checkin-time-heading");
    var detailsDiv = document.createElement("a");
    detailsDiv.setAttribute("class", "cjs-checkin-details-tooltip cjs-tool-tip has-before has-next-2");
    detailsDiv.innerHTML = "(" + options.checkin_details.details_text + ")";
    var toolTipText = options.checkin_details.checkinHoursDetails;

    toolTipText = toolTipText.replace("CJS_DUMMY_TEXT_MEETING_HOURS", checkinData.meetingHours);
    toolTipText = toolTipText.replace("CJS_DUMMY_TEXT_TASK_HOURS", checkinData.taskHours);
    toolTipText = toolTipText.replace("CJS_DUMMY_TEXT_TOTAL_HOURS", checkinData.totalHours);

    detailsDiv.setAttribute("title", toolTipText);
    var totalHours = document.createElement("span");
    totalHours.setAttribute("class", "cjs-checkin-total-hours");
    totalHours.innerHTML = checkinData.totalHours;
    th.append(detailsDiv);
    th.append(totalHours);
  },

  initializeDateForm: function(){
    CheckinsKendo.initializeSubmit();
  },

  getUserCheckins: function(user_id){
    var gridDiv = jQuery("#cjs_check_ins_listing_kendogrid");
    var grid = gridDiv.data('kendoGrid');
    var userFilter = {
      field: "user",
      value: user_id
    }

    var filters = [userFilter]
    grid.dataSource.filter({
      logic: "and",
      filters: filters
    });
  },

  initializeSubmit: function(options){
    jQuery("#cjs_date_range_submit").click(function(e){
      e.preventDefault();
      var gridDiv = jQuery("#" + "cjs_check_ins_listing_kendogrid");
      var grid = gridDiv.data('kendoGrid');
      dataSource = grid.dataSource;

      filters = [];
      if(grid.dataSource.filter() && grid.dataSource.filter().filters){
        filters = grid.dataSource.filter().filters
      }

      dates = CheckinsKendo.getDateSelections();
      dateFilter = {
        field: "date",
        start_date: dates["start_date"],
        end_date: dates["end_date"],
        value: "between"
      }

      for(var i = filters.length - 1; i >= 0; i--){
        if(filters[i].field == "date"){
          filters.splice(i,1);
        }
      }
      filters.push(dateFilter);
      grid.dataSource.filter({
        logic: "and",
        filters: filters
      });
      jQuery('.cui-date-range-filter .panel-title').html(dates["start_date"] + " - " + dates["end_date"]);
    });

  },

  getDateSelections: function(){
    var values = {};
    values["start_date"] = jQuery('.cjs_daterange_picker_start').val();
    values["end_date"] = jQuery('.cjs_daterange_picker_end').val();
    return values;
  }
};