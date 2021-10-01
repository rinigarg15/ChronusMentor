function closeQtip() {
  jQuery('.cjs-qtip').each( function() {
    var qtipObject = jQuery(this);
    qtipObject.find(".select2-offscreen").each(function(){
      jQuery(this).select2("destroy");
    });
    qtipObject.qtip("destroy");
  });
  jQuery("#remoteModal").modal('hide');
}

function hideQtip() {
  jQuery('.cjs-qtip').each( function() {
    jQuery(this).qtip("hide");
  });
}

function closeDatepicker(){
  jQuery('#mentoring_slot_datepicker').each(function() {
    jQuery(this).datepicker('hide')
    });
  jQuery('#mentoring_slot_datepicker').each(function() {
    jQuery(this).datepicker('destroy')
    });
}

function jsonDateParser(dateStr){
  var pattern = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})[Z+].*/;
  var match = pattern.exec(dateStr);
  if (!match) {
    throw new Error(calendarTranslations.dateStrParseError+dateStr);
  }
  // we're safe to use the fields, return the dates in utc
  //utcDate = new Date.UTC(match[1], match[2]-1, match[3], match[4], match[5], match[6]);
  return new Date(match[1], match[2]-1, match[3], match[4], match[5], match[6]);
}

function validateDateForAllSlotsAndSubmit(flash_id){
  var is_valid = true;
  jQuery('.mentoring_slot').each( function() {
    var startDateEle = jQuery(this).find('.cjs_start_date');
    var endDateEle = jQuery(this).find('.cjs_end_date');
    if (MentoringSlotForm.validateDateForGivenElements(flash_id, startDateEle, endDateEle)){
      ChronusValidator.ErrorManager.HideFieldError(startDateEle);
    }
    else{
      ChronusValidator.ErrorManager.ShowFieldError(startDateEle);
      is_valid = false;
    }
  });
  return is_valid;
}


function validateTimesAndSubmit(timesArray, flash_id, slot_diff, timeErrorMsg){
  var st = jQuery("#mentoring_slot_start_time_of_day").val() || jQuery("#meeting_start_time_of_day").val();
  var en = jQuery("#mentoring_slot_end_time_of_day").val() || jQuery("#meeting_end_time_of_day").val();
  var isValidTime = false;
  if ((en == calendarTranslations.midNightAM) || (jQuery.inArray(en, timesArray) - jQuery.inArray(st, timesArray) >= slot_diff)){
    isValidTime = true;
  }
  else{
    ChronusValidator.ErrorManager.ShowResponseFlash(flash_id, timeErrorMsg);
    return false;
  }
  var repeats = jQuery("#mentoring_slot_repeats_every_option").val();
  var dayArray = jQuery("#repeats_on_week_day");
  var dayCheckedIfWeekly = validateDayPresentIfWeekly(repeats, dayArray, flash_id);
  return (isValidTime && dayCheckedIfWeekly);
}

function validateTimesForAllSlotsAndSubmit(timesArray, slot_diff, errorMsg, flash_id, defaultStart, defaultEnd){
  var is_valid = true;
  var dayCheckedIfWeekly = true;
  jQuery('.mentoring_slot').each( function() {
    var repeatsOption = jQuery(this).find('#repeats_every_option select').val();
    var dayArray = jQuery(this).find('#repeats_on_week_day');
    var validateWeekly = validateDayPresentIfWeekly(repeatsOption, dayArray, flash_id);
    dayCheckedIfWeekly = dayCheckedIfWeekly && validateWeekly;
    var st_ele = jQuery(this).find('.start_time_of_day');
    var en_ele = jQuery(this).find('.end_time_of_day');
    var st = st_ele.val() || defaultStart;
    var en = en_ele.val() || defaultEnd;
    if ((en == defaultStart) || (jQuery.inArray(en, timesArray) - jQuery.inArray(st, timesArray) >= slot_diff)){
      ChronusValidator.ErrorManager.HideFieldError(st_ele);
      ChronusValidator.ErrorManager.HideFieldError(en_ele);
      is_valid = is_valid && true;
    }
    else{
      ChronusValidator.ErrorManager.ShowFieldError(st_ele);
      ChronusValidator.ErrorManager.ShowFieldError(en_ele);
      ChronusValidator.ErrorManager.ShowResponseFlash(flash_id, errorMsg);
      is_valid = false;
    }
  });
  return (is_valid && dayCheckedIfWeekly);
}

function validateDayPresentIfWeekly(mentoring_slot_freq, dayArray, flash_id){
  var isValid = true;
  if (mentoring_slot_freq == "2"){
    isValid = false;
    var dayArrayOpts = dayArray.find('input:checked');
    if (dayArrayOpts.length>0){
      isValid = true;
    }
    if(isValid){
      ChronusValidator.ErrorManager.HideFieldError(dayArray);
    }
    else{
      ChronusValidator.ErrorManager.ShowFieldError(dayArray);
      ChronusValidator.ErrorManager.ShowResponseFlash(flash_id, calendarTranslations.noDateForRepeatingSlot);
    }
  }
  return isValid;
}

function eventBeforeCurrentTime(startTime){
  if ((new Date()) > Date.parse(startTime)){
    return true;
  }
  return false;
}

function parseTimeForAjax(startTime, endTime, forMeeting){
  var formattedStartTime = startTime.format();
  var formattedEndTime = endTime.format();

  if(forMeeting === undefined)
    forMeeting = false;
  if(forMeeting)
    return ("start_time=" + formattedStartTime + "&end_time=" + formattedEndTime);
  return ("mentoring_slot[start_time]=" + formattedStartTime + "&mentoring_slot[end_time]=" + formattedEndTime);
}

function parseTimeForEventsFetch(startTime, endTime, offset){
  var formattedStartTime = startTime.add(-offset, "second").unix();
  var formattedEndTime = endTime.add(-offset, "second").unix();

  return ("start=" + formattedStartTime + "&end=" + formattedEndTime);
}

function handleExpiredAvailabilitySlots(className){
  if(className == "expired_availability_slots"){
    alert(jsCommonTranslations.chooseFutureAvailability);
    return true;
  }
  return false;
}

function setupCalendar(profileUser, memberId, canCreateMeeting){
  jQuery(document).ready(function(){
    Placeholder.init(jQuery("#search_filter_form").find("input[type='text']"));
    Placeholder.cleanBeforeSubmit(jQuery("#search_filter_form"));

    var mentorCalendarOptions = {
      events: function(start, end, timezone, callback){
        jQuery.ajax({
          url: jQuery("#calendar").attr("eventsUrl"),
          data: parseTimeForEventsFetch(start, end, jQuery("#calendar").attr("timeZoneOffset")),
          success: function(events){
            callback(events);
          }
        });
      }
    };
    if(profileUser){
      mentorCalendarOptions.selectable = true,
      mentorCalendarOptions.eventClick = function(event){
        if(event.clickable == false)
          return;
        if(event.className == "meetings"){
          jQueryShowQtip("#inner_content", 600, event.show_meeting_url, "", {modal: true, largeModal: true});
          return;
        }
        if(event.className == "requested_meetings"){
          handleRequestedMeetingsClick(event.onclick_message);
          return;
        }
        if(handleExpiredAvailabilitySlots(event.className))
          return;
        jQueryShowQtip("#inner_content", 600, event.show_member_mentoring_slot_url, parseTimeForAjax(event.start, event.end));
      },
      mentorCalendarOptions.select = function(start, end){
        if(canCreateMeeting || !eventBeforeCurrentTime(start.format())){
          jQueryShowQtip("#inner_content", 600, jQuery('#calendar').attr("new_member_mentoring_slot_url"), parseTimeForAjax(start, end), {successCallback: function(){CalendarAvailabilityInfo.initialize({setDefaultSpan: true})}});
        }
      }
    }else{
      mentorCalendarOptions.eventClick = function(event){
        if(event.clickable == false)
          return;
        if(handleExpiredAvailabilitySlots(event.className))
          return;
        jQueryShowQtip("#inner_content", 600, event.new_meeting_url, jQuery.param(event.new_meeting_params) + "&" + parseTimeForAjax(event.start, event.end, true));
      }
    }

    var menteeCalendarOptions = {
      events: function(start, end, timezone, callback){
        jQuery.ajax({
          url: jQuery("#mentoring_calendar").attr("eventsUrl"),
          data: parseTimeForEventsFetch(start, end, jQuery("#mentoring_calendar").attr("timeZoneOffset")) + "&" + jQuery("#search_filter_form").serialize(),
          success: function(data){
            var events = data.events;
            var filtersContent = data.filters_content;
            callback(events);
            jQuery("#your_filters").replaceWith(filtersContent);
          }
        });
      },
      eventClick: function(event){
        if(event.clickable == false) {
          return;
        }
        if(event.className == "meetings"){
          jQueryShowQtip("#inner_content", 600, event.show_meeting_url, "", {modal: true, largeModal: true});
          chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.GA_MEETING_ACTIVITY_CATEGORY, chrGoogleAnalytics.action.GA_MENTORING_CALENDAR_OPENED_MEETING_SLOT, chrGoogleAnalytics.eventLabel.GA_FLASH_MENTORING_CALENDAR_EVENTS_LABEL, chrGoogleAnalytics.eventLabelId.GA_FLASH_MENTORING_CALENDAR_EVENTS_LABEL_ID);
          return;
        }
        if(event.className == "non_self_meetings"){
            alert(event.onclick_message);
            chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.GA_MEETING_ACTIVITY_CATEGORY, chrGoogleAnalytics.action.GA_MENTORING_CALENDAR_CLICKED_BUSY_MEETING_SLOT, chrGoogleAnalytics.eventLabel.GA_FLASH_MENTORING_CALENDAR_EVENTS_LABEL, chrGoogleAnalytics.eventLabelId.GA_FLASH_MENTORING_CALENDAR_EVENTS_LABEL_ID);
        }
        if(event.className == "requested_meetings"){
          handleRequestedMeetingsClick(event.onclick_message);
        }
        if(handleExpiredAvailabilitySlots(event.className))
          return;
        if(typeof(event.new_meeting_url) !== "undefined") {
          jQueryShowQtip("#inner_content", 600, event.new_meeting_url, jQuery.param(event.new_meeting_params) + "&" + parseTimeForAjax(event.start, event.end, true));
          chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.GA_MEETING_ACTIVITY_CATEGORY, chrGoogleAnalytics.action.GA_MENTORING_CALENDAR_OPENED_AVAILABILITY_SLOT, chrGoogleAnalytics.eventLabel.GA_FLASH_MENTORING_CALENDAR_EVENTS_LABEL, chrGoogleAnalytics.eventLabelId.GA_FLASH_MENTORING_CALENDAR_EVENTS_LABEL_ID);
        }
      },
      dayClick: function(date, jsEvent, view) {
        alert(meetingTranslations.clickOnEmptySlotMessage);
        chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.GA_MEETING_ACTIVITY_CATEGORY, chrGoogleAnalytics.action.GA_MENTORING_CALENDAR_CLICKED_EMPTY_SLOTS, chrGoogleAnalytics.eventLabel.GA_FLASH_MENTORING_CALENDAR_EVENTS_LABEL, chrGoogleAnalytics.eventLabelId.GA_FLASH_MENTORING_CALENDAR_EVENTS_LABEL_ID);
      }
    };

    jQueryShowFullCalendar("#calendar", mentorCalendarOptions);
    jQueryShowFullCalendar("#mentoring_calendar", menteeCalendarOptions);
  });
}


function handleRequestedMeetingsClick(message){
  alert(message);
  chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.GA_MEETING_ACTIVITY_CATEGORY, chrGoogleAnalytics.action.GA_MENTORING_CALENDAR_CLICKED_REQUESTED_MEETING_SLOT, chrGoogleAnalytics.eventLabel.GA_FLASH_MENTORING_CALENDAR_EVENTS_LABEL, chrGoogleAnalytics.eventLabelId.GA_FLASH_MENTORING_CALENDAR_EVENTS_LABEL_ID);
}