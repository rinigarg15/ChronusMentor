// This file contains js from the calendar related changes done in the users listing page scoped under Meetings
// Also, contains js from the Home page quick connect box, this is scoped under the QuickConnect scope

var Meetings = {

  requestMeetingPopupContent: "#cjs_meeting_mini_popup_slots",
  quickMeetingForm: "#cjs_quick_meeting_form", 
  miniAvailabilityLink: "#cjs_mini_availability_link",
  backLink: "#cjs_availability_back_link", 
  miniRequestButton: "a.cjs_mini_popup_button",
  quickConnectRequestButton: ".cjs_home_quick_connect_button",
  quickConnectHide: ".cjs_quick_connect_box #cjs_hide_quick_connect_box",
  membersQuickMeetingLink: "#cjs_schedule_meeting_link",
  getValidTimeSlotsRegistered: false,
  calendarSyncV2TimeDetails: {},
  handleRsvpPopupInitializationStatus: false,


  trackMeetingPopupEvents: function(edit_meeting_url){
    Meetings.settingMeetingStatus();
    Meetings.trackMeetingActivityMeetingRescheduled(edit_meeting_url);
    Meetings.trackMeetingActivityMeetingPopupCancelled();
  }, 

  getMeetingListingLabelAndId: function(element){
    var eventLabel = chrGoogleAnalytics.eventLabel.GA_MEETING_ACTIVITY_LABEL_MEETINGS_LISTING;
    var eventLabelId = chrGoogleAnalytics.eventLabelId.GA_MEETING_ACTIVITY_LABEL_MEETINGS_LISTING_ID;
    if(element.hasClass("cjs_meeting_area")){
      eventLabel = chrGoogleAnalytics.eventLabel.GA_MEETING_ACTIVITY_LABEL_MEETING_AREA;
      eventLabelId = chrGoogleAnalytics.eventLabelId.GA_MEETING_ACTIVITY_LABEL_MEETING_AREA_ID;
    }
    if(element.hasClass("cjs_source_mail")){
      eventLabel = chrGoogleAnalytics.eventLabel.GA_MEETING_ACTIVITY_LABEL_EMAIL;
      eventLabelId = chrGoogleAnalytics.eventLabelId.GA_MEETING_ACTIVITY_LABEL_EMAIL_ID;
    }
    if(element.hasClass("cjs_source_home_page")){
      eventLabel = chrGoogleAnalytics.eventLabel.GA_MEETING_ACTIVITY_LABEL_HOME_PAGE;
      eventLabelId = chrGoogleAnalytics.eventLabelId.GA_MEETING_ACTIVITY_LABEL_HOME_PAGE_ID;
    }
    return [eventLabel, eventLabelId];
  },

  gaTrackRsvpResponse: function(isUpdatingRsvp, rsvpYes, eventLabel, eventLabelId){
    var action = chrGoogleAnalytics.action.GA_MEETING_ACTIVITY_RSVP_NO;

    if(rsvpYes){
      action = chrGoogleAnalytics.action.GA_MEETING_ACTIVITY_RSVP_YES;
    }

    if(isUpdatingRsvp){
      action = chrGoogleAnalytics.action.GA_MEETING_ACTIVITY_RSVP_UPDATED;
    }

    chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.GA_MEETING_ACTIVITY_CATEGORY, action, eventLabel, eventLabelId);    
  },

  gaTrackMeetingEdit: function(homepageView, fromMeetingArea, setMeetingLocation){
    var eventLabel = chrGoogleAnalytics.eventLabel.GA_MEETING_ACTIVITY_LABEL_MEETINGS_LISTING;
    var eventLabelId = chrGoogleAnalytics.eventLabelId.GA_MEETING_ACTIVITY_LABEL_MEETINGS_LISTING_ID;
    var action = setMeetingLocation ? chrGoogleAnalytics.action.GA_MEETING_ACTIVITY_SET_LOCATION: chrGoogleAnalytics.action.GA_MEETING_ACTIVITY_EDIT_DETAILS;
    if(homepageView){
      eventLabel = chrGoogleAnalytics.eventLabel.GA_MEETING_ACTIVITY_LABEL_HOME_PAGE;
      eventLabelId = chrGoogleAnalytics.eventLabelId.GA_MEETING_ACTIVITY_LABEL_HOME_PAGE_ID;
    }
    else if (fromMeetingArea){
      eventLabel = chrGoogleAnalytics.eventLabel.GA_MEETING_ACTIVITY_LABEL_MEETING_AREA;
      eventLabelId = chrGoogleAnalytics.eventLabelId.GA_MEETING_ACTIVITY_LABEL_MEETING_AREA_ID;
    }
    chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.GA_MEETING_ACTIVITY_CATEGORY, action, eventLabel, eventLabelId);

  },

  getEventActionForListing: function(element){
    if (element.hasClass("cjs_meeting_edit_details")){
      return chrGoogleAnalytics.action.GA_MEETING_ACTIVITY_INITIALIZE_EDIT_DETAILS;
    }

    else if (element.hasClass("cjs_meeting_view_feedback_survey")){
      return chrGoogleAnalytics.action.GA_MEETING_ACTIVITY_VIEW_FEEDBACK;
    }

    else if (element.hasClass("cjs_meeting_provide_feedback_survey")){
      return chrGoogleAnalytics.action.GA_MEETING_ACTIVITY_PROVIDE_FEEDBACK;
    }

    else if (element.hasClass("cjs_meeting_completed")){
      return chrGoogleAnalytics.action.GA_MEETING_ACTIVITY_MEETING_COMPLETED;
    }

    else if (element.hasClass("cjs_meeting_cancelled")){
      return chrGoogleAnalytics.action.GA_MEETING_ACTIVITY_MEETING_CANCELLED;
    }
  },

  trackMeetingListingEvents: function(){
    jQuery(".cjs_meeting_area_listing_event").on('click', function(){
      eventsArray = Meetings.getMeetingListingLabelAndId(jQuery(this));
      var eventLabel = eventsArray[0];
      var eventLabelId = eventsArray[1];
      var eventAction = Meetings.getEventActionForListing(jQuery(this));
      chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.GA_MEETING_ACTIVITY_CATEGORY, eventAction, eventLabel, eventLabelId);
    });
  },

  settingMeetingStatus: function(){
    jQuery(document).on("click", '.cjs_meeting_status', function(){
      eventsArray = Meetings.getMeetingListingLabelAndId(jQuery(this));
      var eventLabel = eventsArray[0];
      var eventLabelId = eventsArray[1];
      var eventAction = Meetings.getEventActionForListing(jQuery(this));
      chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.GA_MEETING_ACTIVITY_CATEGORY, eventAction, eventLabel, eventLabelId);
      element = jQuery(this);
      jQuery.ajax({
        url: element.data("url"),
        data: {meeting_state: element.data("meeting-state"), current_occurrence_time: element.data("current-occurrence-time"), src: element.data("src")},
        beforeSend: function(){
          jQuery("#loading_results").show();
        }
      });
    });
  },

  setNewMeetingFormEISrc: function(){
    jQuery(document).on("click", '.cjs_set_ei_src', function(){
      var src = jQuery(this).data("ei-src");
      jQuery("#ei_src").val(src);
    });
  },

  trackMeetingActivityMeetingRescheduled: function(edit_meeting_url){
    jQuery(".cjs_meeting_rescheduled").on('click', function(){
      eventsArray = Meetings.getMeetingListingLabelAndId(jQuery(this));
      var eventLabel = eventsArray[0];
      var eventLabelId = eventsArray[1];
      chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.GA_MEETING_ACTIVITY_CATEGORY, chrGoogleAnalytics.action.GA_MEETING_ACTIVITY_MEETING_INITIALIZE_UPDATED_TIME, eventLabel, eventLabelId);
      jQueryShowQtip('#inner_content', 850, edit_meeting_url,'',{modal: true,  successCallback: function(){CalendarAvailabilityInfo.initialize()}});
    });
  },

  trackMeetingUpdatedTime: function(editOnlyTime){
    if(editOnlyTime){
      chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.GA_MEETING_ACTIVITY_CATEGORY, chrGoogleAnalytics.action.GA_MEETING_ACTIVITY_MEETING_UPDATED_TIME, chrGoogleAnalytics.eventLabel.GA_MEETING_ACTIVITY_LABEL_MEETING_AREA, chrGoogleAnalytics.eventLabelId.GA_MEETING_ACTIVITY_LABEL_MEETING_AREA_ID);
    }
    else{
      chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.GA_MEETING_ACTIVITY_CATEGORY, chrGoogleAnalytics.action.GA_MEETING_ACTIVITY_EDIT_DETAILS, chrGoogleAnalytics.eventLabel.GA_MEETING_ACTIVITY_LABEL_MEETING_AREA, chrGoogleAnalytics.eventLabelId.GA_MEETING_ACTIVITY_LABEL_MEETING_AREA_ID);
    }
  },

  trackMeetingActivityMeetingPopupCancelled: function(){
    jQuery(".cjs_dismiss_meeting_popup").on('click', function(event){
      event.preventDefault();
      eventsArray = Meetings.getMeetingListingLabelAndId(jQuery(this));
      var eventLabel = eventsArray[0];
      var eventLabelId = eventsArray[1];
      chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.GA_MEETING_ACTIVITY_CATEGORY, chrGoogleAnalytics.action.GA_MEETING_ACTIVITY_MEETING_POPUP_DISMISSED, eventLabel, eventLabelId);
      closeQtip();
    });
  },

  trackMeetingActivityAddNote: function(add_note_url){
    jQuery(".add_private_meeting_note").on('click', function(){
      eventLabel = chrGoogleAnalytics.eventLabel.GA_MEETING_ACTIVITY_LABEL_MEETING_AREA;
      eventLabelId = chrGoogleAnalytics.eventLabelId.GA_MEETING_ACTIVITY_LABEL_MEETING_AREA_ID;
      chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.GA_MEETING_ACTIVITY_CATEGORY, chrGoogleAnalytics.action.GA_MEETING_ACTIVITY_ADD_NOTE_INITIATED, eventLabel, eventLabelId);
      jQueryShowQtip('#inner_content', 650, add_note_url,'',{modal: true});
    });
  },

  trackMeetingActivityAddNotePopupCancelled: function(){
    jQuery(".cjs_dismiss_meeting_note_popup").on('click', function(){
      event.preventDefault();
      eventLabel = chrGoogleAnalytics.eventLabel.GA_MEETING_ACTIVITY_LABEL_MEETING_AREA;
      eventLabelId = chrGoogleAnalytics.eventLabelId.GA_MEETING_ACTIVITY_LABEL_MEETING_AREA_ID;
      chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.GA_MEETING_ACTIVITY_CATEGORY, chrGoogleAnalytics.action.GA_MEETING_ACTIVITY_ADD_NOTE_POPUP_DISMISSED, eventLabel, eventLabelId);
      closeQtip();
    });
  },

  AnalyticsParams: {
    requestMeetingPopup: "request_meeting_button"
  },

  gaTrackMeetingMessages: function(){
    chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.GA_MEETING_ACTIVITY_CATEGORY, chrGoogleAnalytics.action.GA_MEETING_AREA_SENT_MESSAGE, chrGoogleAnalytics.eventLabel.GA_MEETING_ACTIVITY_LABEL_MEETING_AREA, chrGoogleAnalytics.eventLabelId.GA_MEETING_ACTIVITY_LABEL_MEETING_AREA_ID);
  },

  gaTrackSkypeCall: function(){
    jQuery(".cjs_meeting_area_skype_call").on("click", function(){
      chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.GA_MEETING_ACTIVITY_CATEGORY, chrGoogleAnalytics.action.GA_MEETING_AREA_SKYPE_CALL, chrGoogleAnalytics.eventLabel.GA_MEETING_ACTIVITY_LABEL_MEETING_AREA, chrGoogleAnalytics.eventLabelId.GA_MEETING_ACTIVITY_LABEL_MEETING_AREA_ID);
    });
  },

  trackInstructionsPageVisit: function(){
    jQuery(".cjs_show_instructions_page").on('click', function(){
      eventLabel = chrGoogleAnalytics.eventLabel.GA_CAL_SYNC_OUTLOOK_ICAL;
      eventLabelId = chrGoogleAnalytics.eventLabelId.GA_CAL_SYNC_OUTLOOK_ICAL_ID;
      if(jQuery(this).attr("id") == "cjs_google_instruction_link"){
        eventLabel = chrGoogleAnalytics.eventLabel.GA_CAL_SYNC_GOOGLE;
        eventLabelId = chrGoogleAnalytics.eventLabelId.GA_CAL_SYNC_GOOGLE_ID;
      }
      chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.GA_CAL_SYNC_CATEGORY, chrGoogleAnalytics.action.GA_CAL_SYNC_MORE_DETAILS, eventLabel, eventLabelId);
    });
  },

  trackCalendarSyncPopupView: function(){
    jQuery(".cjs_show_calendar_sync_popup").on('click', function(){
      chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.GA_CAL_SYNC_CATEGORY, chrGoogleAnalytics.action.GA_CAL_SYNC_OPEN_POPUP, "", "");
    });
  },

  embedContent: function(content){
    jQuery(Meetings.requestMeetingPopupContent).addClass("hide");
    jQuery(Meetings.quickMeetingForm).removeClass("hide");
    Meetings.resetLink(false);
    jQuery(Meetings.quickMeetingForm).html(content);
    jQuery("#inner_content").qtip('option', { 'position.my' : 'center' });
  },

  resetLink: function(shouldReset){
    if(shouldReset){
      jQuery(Meetings.backLink).addClass("hide");
      jQuery(Meetings.miniAvailabilityLink).removeClass("hide")
    }
    else{
      jQuery(Meetings.backLink).removeClass("hide");
      jQuery(Meetings.miniAvailabilityLink).addClass("hide")  
    }
  },

  renderMiniPopup: function(url){
    jQueryShowQtip('#inner_content', 675, url,'',{modal: true, successCallback: function(){CalendarAvailabilityInfo.initialize()}});
  },

  inspectRequestMeetingUrl: function(){
    if(jQueryReadUrlParam('request_meeting_email').length > 0 && jQuery(Meetings.membersQuickMeetingLink).length > 0){
      jQuery(Meetings.membersQuickMeetingLink).click();
    } 
  },

  showAcceptPopup: function(meetingRequestSelector){
    jQuery(meetingRequestSelector).modal('show');
  },

  handleRsvpPopup: function(){
    if(!Meetings.handleRsvpPopupInitializationStatus){
      jQuery(document).on("click", '.Rsvp_accepted_decline', function(){
        var meetingSelector = jQuery(this).data("meetingselector");
        var element = jQuery('.cjs_rsvp_accepted[data-meetingselector='+meetingSelector+']');
        Meetings.handleRsvpNo(element);
      });
      jQuery(document).on("click", '.Rsvp_accepted_reschedule', function(){   
        var meetingSelector = jQuery(this).data("meetingselector");
        var element = jQuery('.cjs_rsvp_confirm[data-meetingselector='+meetingSelector+']');
        jQuery("#modal_"+meetingSelector).modal('hide');
        Meetings.handleReschedule(element, meetingSelector);
      });
      Meetings.handleRsvpPopupInitializationStatus = true;
    }
  },

  handleRsvpNo: function(element){
    var url = element.data("url");
    Meetings.updateRsvpResponse(url);
  },

  handleReschedule: function(element, meetingSelector){
    var editTimeUrl = element.data("edittimeurl");
    MeetingForm.showEditMeetingQtip(meetingSelector, editTimeUrl, false);
  },

  updateRsvpResponse: function(url){
    jQuery.ajax({
      url: url
    });
  },

  handleRsvpChange: function(){
    jQuery(document).on("click", '.cjs_rsvp_confirm', function(event){
      event.preventDefault();
      var meetingSelector = jQuery(this).data("meetingselector");
      var url = jQuery(this).data("url");
      if(jQuery(this).hasClass("cjs_rsvp_accepted")){
        if(jQuery(".meeting_modal").length > 0){
          jQuery('.meeting_modal_close_link').click();
        }
        jQuery("#modal_"+meetingSelector).modal('show');
      }
      else{
        Meetings.updateRsvpResponse(url);
      }
    });
  },

  resetModalDateContainer: function(selector){
    jQuery(selector).on('hidden.bs.modal', function () {
      jQuery(this).find('.cjs-meeting-date-input').val("");
      MeetingForm.hideShortlistTimesHelpText("#" + jQuery(this).attr('id'));
    });
  },

  settingMeetingReportTab: function(){
    jQuery(document).on("click", '.cjs_meeting_calendar_report', function(){
      element = jQuery(this).find("a");
      jQuery.ajax({
        url: element.data("url"),
        data: {tab: element.data("tab"), filters: commonReportFilters.getFiltersData()},
        beforeSend: function(){
          jQuery("#loading_results").show();
        },
        complete: function(){
          commonReportFilters.updateExportUrls();
        }
      });
    });
  },

  getMeetingReportFilterData: function(){
    var data = {tab: jQuery('.cjs_meeting_calendar_report.active').find('a').data('tab'), filters: commonReportFilters.getFiltersData()};
    return data;
  },

  getMentoringSessionsFilterData: function(){
    var data = {tab: jQuery('#filter_tab').val(), filters: commonReportFilters.getFiltersData()};
    return data;
  },

  initializeCarouselGaTrack: function(){
    jQuery(".meetings-slick").on('beforeChange', function (event, slick, currentSlide, nextSlide) {
      chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.MEETING_ACTIVITY, chrGoogleAnalytics.action.GA_MEETING_ACTIVITY_VIEWED_MEETING + nextSlide, chrGoogleAnalytics.eventLabel.GA_MENTORING_AREA_ACTIVITY_LABEL_HOME_PAGE, chrGoogleAnalytics.eventLabelId.GA_MENTORING_AREA_ACTIVITY_HOME_PAGE_LABEL_ID);
    });
  },


  QuickConnect: {
    mentorPreferenceBoxInitializationStatus: false,

    initializeMentorPreferenceBoxElements: function(){
      if(!Meetings.QuickConnect.mentorPreferenceBoxInitializationStatus){
        Meetings.QuickConnect.inspectQuickConnect();
        Meetings.QuickConnect.hideQuickConnect();
        Meetings.QuickConnect.initializeQuickConnectButtons();
        MentorRequests.showRequestConnectionPopup();
        initialize.initializeTooltip();
        initialize.initializeMatchDetailsPopup();
        Meetings.QuickConnect.mentorPreferenceBoxInitializationStatus = true;
      }
    },

    initializeQuickConnectButtons: function(){
      Meetings.QuickConnect.initializeIgnorePreferenceButton();
    },

    initializeIgnorePreferenceButton: function(){
      jQuery(document).on("click", ".cjs_create_ignore_preference", function(event){
        event.preventDefault();
        var url = jQuery(this).data("url");
        jQuery.ajax({
          url: url,
          type: 'POST'
        });
      });
    },

    inspectQuickConnect: function(){
      jQuery(document).on("click", Meetings.quickConnectRequestButton, function(event){
        event.preventDefault();
        var url = jQuery(this).data("url");
        Meetings.renderMiniPopup(url);
      });
    }, 

    initializeQuickConnectElements: function(url){
      Meetings.QuickConnect.hideQuickConnect();
      jQuery.ajax({
        url: url
      });  
    },

    embedQuickConnect: function(selector, carouselSelector, content){
      if(!content.blank()){
        var divEnclosure = jQuery(selector);
        divEnclosure.html(content);
        divEnclosure.closest(".cjs_quick_connect_box").removeClass("hide");
      }
      homePageRecommendation.addCarousel(carouselSelector);
      Meetings.QuickConnect.adjustQuickConnectMatchInfo();
    },

    showNoRecommendationsExperience: function(selector){
      var divEnclosure = jQuery(selector);
      var noRecommendationsHtml = divEnclosure.find(".cjs_no_recommendations_available").html();
      divEnclosure.find(".tile-placeholder").html(noRecommendationsHtml);
      divEnclosure.fadeOut(5000);
    },

    adjustQuickConnectMatchInfo: function(){
      jQuery(".cjs_match_details").each(function(){
        var parentElementWidth = jQuery(".cjs_tags_container").width();
        var childElementWidth = 75;
        var labelsOverflow = false;
        jQuery(this).find(".status_icon").each(function(){
          if(labelsOverflow){
            jQuery(this).remove();
          }else{
            jQuery(this).addClass("truncate-with-ellipsis");
            var curWidth = jQuery(this).outerWidth(true);
            var prevSiblingsWidth = childElementWidth;
            childElementWidth += (curWidth);
            if(childElementWidth > parentElementWidth){
              var availableWidth = parentElementWidth - prevSiblingsWidth - 1;
              labelsOverflow = true;
              if(jQuery(this).siblings(".truncate-with-ellipsis").length > 1){
                jQuery(this).remove();
              }
              else if((availableWidth / curWidth) > 0.50){
                jQuery(this).outerWidth(availableWidth, true);
              }else{
                jQuery(this).remove();
              }
            }
          }
        });
      });
      jQuery(".cjs_quick_connect_user_details").each(function(){
        var recommendationContainer = jQuery(this).closest(".cjs_mentor_recommendation");
        var recommendationContainerWidth = recommendationContainer.width();
        var userDetailsWidth = jQuery(this).css('max-width', (recommendationContainerWidth - 100) + 'px');
      });
      // 100 px is the width of profile picture(65 px) + padding on left and right(30 px) + 5px buffer
      jQuery(".cjs_quick_connect_user_name").each(function(){
        var recommendationContainer = jQuery(this).closest(".cjs_mentor_recommendation");
        var recommendationContainerWidth = recommendationContainer.width();
        var preferenceLinksWidth = recommendationContainer.find(".cjs_quick_connect_preference_links").outerWidth(true);
        var userDetailsWidth = jQuery(this).css('max-width', (recommendationContainerWidth -(preferenceLinksWidth + 100)) + 'px');
      });
    },

    hideQuickConnect: function(){
      jQuery(document).on("click", Meetings.quickConnectHide, function(event){
        jQueryBlind(jQuery(this).closest(".cjs_quick_connect_box"));
      });
    },

    hideOrShowYouMayAlsoBox: function(){
      if(jQuery(".cjs_mentor_recommendation:visible").length > 0){
        jQuery("#cjs_recommendations_you_may_also").show();
      }
      else{
        jQuery("#cjs_recommendations_you_may_also").hide();
      }
    }
  },

  DisableAvailabilitySlot: {
    responseOnclickHandler: function(){
      jQuery("#will_set_availability_setting .controls input[type=radio]").on('click', function(){
        var setAvailabilityObj = jQuery('.cjs_will_set_availability');
        var responseValue = setAvailabilityObj.find('input:checked').val();
        if (responseValue == "true"){
          setAvailabilityObj.find('.cjs_flash_message_availability_not_set').hide();
          setAvailabilityObj.find('.cjs_availability_slots').show();
          jQuery('.mentee_scheduling_preference').show();
        } 
        else 
        {
          setAvailabilityObj.find('.cjs_flash_message_availability_not_set').show();
          setAvailabilityObj.find('.cjs_availability_slots').hide();
          jQuery('.mentee_scheduling_preference').hide();
        }
      });
    }
  },

  showSlimScrollAvailabilitySlot: function(class_name) {
    jQuery(class_name).slimScroll({
      height: '',
      railVisible: true,
      alwaysVisible: true
    });
  },

  hidePopup: function(path, confirmation) {
    closeQtip();
    chronusConfirm(confirmation, function() {
      jQuery('#loading_results').show();
      jQuery.ajax({
        url: path,
        type: 'DELETE'
      });
    });
  },

  hideEditPopup: function(confirmation, edit_option_current, setMeetingTime) {
    if ((setMeetingTime == "true" || RequiredFields.checkNonMultiInputCase(jQuery('#edit_meeting_topic'))) && RequiredFields.checkNonMultiInputCase(jQuery('#edit_meeting #new_meeting_form_date'))) {      
      if(jQuery("#edit_meeting #meeting_current_occurrence_date").val() == jQuery("#edit_meeting #new_meeting_form_date").val()){
        jQuery("#meeting_edit_form_container").hide();
        jQuery("#meeting_edit_options").show();
      }
      else{
        jQuery("#edit_option").val(edit_option_current);
        jQuery("#edit_meeting_form").submit();
        jQuery('#loading_results').show();
        closeQtip();
      }
    }
  },
  
  validateEditTopicAndDate: function(edit_date, setMeetingTime){
    jQuery("#edit_meeting_form").on("submit", function(){
      return ((setMeetingTime || RequiredFields.checkNonMultiInputCase(jQuery('#edit_meeting_topic'))) && RequiredFields.checkNonMultiInputCase(jQuery('#edit_meeting #' + edit_date)))
    });
  },

  submitEditPopup: function(edit_option) {
    jQuery("#edit_option").val(edit_option);
    jQuery("#edit_meeting_form").submit();
    jQuery('#loading_results').show();
    closeQtip();
  },

  showPastMeetings: function() {
    jQuery(".cjs_archived_meetings_tab a").tab("show");
  },

  showUpcomingMeetings: function() {
    jQuery(".cjs_upcoming_meetings_tab a").tab("show");
  },

  updateAllInvitees: function(checkbox_selector, isSelected){
    jQuery(checkbox_selector).prop('checked', isSelected);
  }
};

var MentoringSlot = {
  initializeAddSlotPopup: function(selector, url){
    jQuery(document).on('click', selector, function(){
      Meetings.renderMiniPopup(url);
    });
  },

  handleAvailabilityTextChange: function(className, duplicateClassName){
    jQuery(className).on('keyup keypress blur', function() {
      jQuery(duplicateClassName).val(jQuery(className).val());
    });
  }
};

var MeetingRequest = {

  GA_REQUEST_MEETING_WORKFLOW: "Request Meeting Workflow",
  GA_GENERAL_AVAILABILITY_MEETING_LABEL: "General Availability",
  GA_GENERAL_AVAILABILITY_MEETING_LABEL_ID: 1,
  GA_CALENDAR_AVAILABILITY_MEETING_LABEL: "Calendar Availability",
  GA_CALENDAR_AVAILABILITY_MEETING_LABEL_ID: 2,
  GA_INITIATED_MEETING: "Initiated meeting",
  GA_FILLED_TOPIC_AND_DESCRIPTION: "Filled topic and agenda",
  GA_SELECT_SLOT_FROM_LIST: "chose slot from list",
  GA_VIEWED_CALAENDAR_LINK: "viewed next 30 days",
  GA_VIEWED_PREVIOUS_STEP: "viewed previous step",
  GA_EDITED_PROPOSED_SLOT: "edited proposed slot",
  GA_PROPOSED_SLOT: "proposed slot",
  GA_REMOVE_PROPOSED_SLOT: "removed proposed slot",
  GA_ADD_NEW_SLOT: "added new slot",
  GA_COMPLETED_REQUEST: "completed request",
  GA_REQUEST_ERRORED_OUT: "request errored out",
  GA_DISMISSED_POPUP: "dismissed popup",
  GA_ENTER_DETAILS_TAB: " - Enter Details",
  GA_SELECT_MEETING_TIMES_TAB: " - Select Meeting Times",
  GA_PROPOSE_TIMES_TAB: " - Propose Meeting Times",
  GA_ACCEPTED_REQUEST_WITH_SLOT: "Accepted from timeslot",
  GA_ACCEPTED_REQUEST_AND_PROPOSED_SLOT: "Accepted and proposed timeslot",
  GA_ACCEPTED_REQUEST_AND_SENT_MESSAGE: "Accepted and sent message",
  GA_REJECTED_REQUEST: "Rejected request",
  GA_DISMISSED_PROPOSE_SLOT_POPUP: "Dismissed propose slot popup",
  GA_WITHDRAWN_MEETING_REQUEST: "Withdrawn request",
  GA_CLOSED_MEETING_REQUEST: "Closed Request",
  GA_MEETING_REQUEST_ACTIVITY_LABEL_QUICK_LINKS_ID: 1,
  GA_MEETING_REQUEST_ACTIVITY_LABEL_QUICK_LINKS: "quick_links",
  GA_MEETING_REQUEST_ACTIVITY_LABEL_HEADER_NAVIGATION_ID: 2,
  GA_MEETING_REQUEST_ACTIVITY_LABEL_HEADER_NAVIGATION: "header_nav",
  GA_MEETING_REQUEST_ACTIVITY_LABEL_EMAIL_ID: 3,
  GA_MEETING_REQUEST_ACTIVITY_LABEL_EMAIL: "email",
  GA_MEETING_REQUEST_ACTIVITY_LABEL_USER_PROFILE_ID: 4,
  GA_MEETING_REQUEST_ACTIVITY_LABEL_USER_PROFILE: "user_profile_page",
  GA_MEETING_REQUEST_ACTIVITY_LABEL_USER_LISTING_ID: 5,
  GA_MEETING_REQUEST_ACTIVITY_LABEL_USER_LISTING: "user_listing_page",





  PROPOSED_SLOTS_COUNT: 1,
  SAVED_PROPOSED_SLOT_DETAILS_HASH: {},

  gaInitializeTrackingEvents: function(){
    MeetingRequest.gaTrackViewCalendarLink();
    MeetingRequest.trackClickOnMeetingDetailsTab();
    MeetingRequest.gaTrackPopupClose();
  },

  gaTrackEvent: function(action){
    var eventLabel = MeetingRequest.gaGetEventLabel();
    chrGoogleAnalytics.addEvent(MeetingRequest.GA_REQUEST_MEETING_WORKFLOW, action, eventLabel, MeetingRequest.gaGetEventLabelId(eventLabel));
  },

  gaGetEventLabelId: function(eventLabel){
    var eventLabelId = MeetingRequest.GA_CALENDAR_AVAILABILITY_MEETING_LABEL_ID;
    
    if(eventLabel == MeetingRequest.GA_GENERAL_AVAILABILITY_MEETING_LABEL){
      eventLabelId = MeetingRequest.GA_GENERAL_AVAILABILITY_MEETING_LABEL_ID;
    }
    
    return eventLabelId;
  },

  gaGetEventLabel: function(){
    var eventLabel = MeetingRequest.GA_CALENDAR_AVAILABILITY_MEETING_LABEL;
    
    if(jQuery(".cjs_meeting_times_tab").find("span.hidden-xs.hidden-sm").hasClass("cjs_ga_meeting")){
      eventLabel = MeetingRequest.GA_GENERAL_AVAILABILITY_MEETING_LABEL;
    }

    return eventLabel;
  },

  gaGetRequestSourceId: function(source){
    var sourceId = MeetingRequest.GA_MEETING_REQUEST_ACTIVITY_LABEL_QUICK_LINKS_ID;
    
    if(source == MeetingRequest.GA_MEETING_REQUEST_ACTIVITY_LABEL_HEADER_NAVIGATION){
      sourceId =  MeetingRequest.GA_MEETING_REQUEST_ACTIVITY_LABEL_HEADER_NAVIGATION_ID;
    }
    else if(source == MeetingRequest.GA_MEETING_REQUEST_ACTIVITY_LABEL_EMAIL){
      sourceId =  MeetingRequest.GA_MEETING_REQUEST_ACTIVITY_LABEL_EMAIL_ID;
    }
    else if(source == MeetingRequest.GA_MEETING_REQUEST_ACTIVITY_LABEL_USER_PROFILE){
      sourceId =  MeetingRequest.GA_MEETING_REQUEST_ACTIVITY_LABEL_USER_PROFILE_ID;
    }
    else if(source == MeetingRequest.GA_MEETING_REQUEST_ACTIVITY_LABEL_USER_LISTING){
      sourceId =  MeetingRequest.GA_MEETING_REQUEST_ACTIVITY_LABEL_USER_LISTING_ID;
    }
    return sourceId;
  },

  gaTrackNewRequestInitiation: function(){
    MeetingRequest.gaTrackEvent(MeetingRequest.GA_INITIATED_MEETING);
  },

  gaTrackCompletionOfFirstStep: function(){
    MeetingRequest.gaTrackEvent(MeetingRequest.GA_FILLED_TOPIC_AND_DESCRIPTION);
  },

  gaTrackSlotSelection: function(){
    MeetingRequest.gaTrackEvent(MeetingRequest.GA_SELECT_SLOT_FROM_LIST);
  },

  gaTrackViewCalendarLink: function(){
    jQuery(".cjs_view_calendar_link").on("click", function(){
      chrGoogleAnalytics.addEvent(MeetingRequest.GA_REQUEST_MEETING_WORKFLOW, MeetingRequest.GA_VIEWED_CALAENDAR_LINK, MeetingRequest.GA_CALENDAR_AVAILABILITY_MEETING_LABEL, MeetingRequest.GA_CALENDAR_AVAILABILITY_MEETING_LABEL_ID);
    });
  },

  gaTrackViewedPreviousStep: function(){
    MeetingRequest.gaTrackEvent(MeetingRequest.GA_VIEWED_PREVIOUS_STEP);
  },

  gaTrackEditProposedSlot: function(){
    chrGoogleAnalytics.addEvent(MeetingRequest.GA_REQUEST_MEETING_WORKFLOW, MeetingRequest.GA_EDITED_PROPOSED_SLOT, MeetingRequest.GA_GENERAL_AVAILABILITY_MEETING_LABEL, MeetingRequest.GA_GENERAL_AVAILABILITY_MEETING_LABEL_ID);
  },

  gaTrackProposeNewSlot: function(){
    chrGoogleAnalytics.addEvent(MeetingRequest.GA_REQUEST_MEETING_WORKFLOW, MeetingRequest.GA_PROPOSED_SLOT, MeetingRequest.GA_GENERAL_AVAILABILITY_MEETING_LABEL, MeetingRequest.GA_GENERAL_AVAILABILITY_MEETING_LABEL_ID);
  },

  gaTrackSlotDeletion: function(){
    chrGoogleAnalytics.addEvent(MeetingRequest.GA_REQUEST_MEETING_WORKFLOW, MeetingRequest.GA_REMOVE_PROPOSED_SLOT, MeetingRequest.GA_GENERAL_AVAILABILITY_MEETING_LABEL, MeetingRequest.GA_GENERAL_AVAILABILITY_MEETING_LABEL_ID);
  },

  gaTrackNewSlotAddition: function(){
    chrGoogleAnalytics.addEvent(MeetingRequest.GA_REQUEST_MEETING_WORKFLOW, MeetingRequest.GA_ADD_NEW_SLOT, MeetingRequest.GA_GENERAL_AVAILABILITY_MEETING_LABEL, MeetingRequest.GA_GENERAL_AVAILABILITY_MEETING_LABEL_ID);
  },

  gaTrackCompletedRequest: function(isGAMeeting){
    var eventLabel = MeetingRequest.GA_CALENDAR_AVAILABILITY_MEETING_LABEL;

    if(isGAMeeting){
      eventLabel = MeetingRequest.GA_GENERAL_AVAILABILITY_MEETING_LABEL;
    }

    chrGoogleAnalytics.addEvent(MeetingRequest.GA_REQUEST_MEETING_WORKFLOW, MeetingRequest.GA_COMPLETED_REQUEST, eventLabel, MeetingRequest.gaGetEventLabelId(eventLabel));
  },

  gaTrackRequestErroredOut: function(isGAMeeting){
    var eventLabel = MeetingRequest.GA_CALENDAR_AVAILABILITY_MEETING_LABEL;

    if(isGAMeeting){
      eventLabel = MeetingRequest.GA_GENERAL_AVAILABILITY_MEETING_LABEL;
    }

    chrGoogleAnalytics.addEvent(MeetingRequest.GA_REQUEST_MEETING_WORKFLOW, MeetingRequest.GA_REQUEST_ERRORED_OUT, eventLabel, MeetingRequest.gaGetEventLabelId(eventLabel));
  },

  getDismissPopupActionNameWithTab: function(selector){
    var activeTabTextElement = selector.closest("div.modal-content").find("div.tabs-container li.active span.hidden-xs.hidden-sm");
    var action = MeetingRequest.GA_DISMISSED_POPUP;
    var currentTab = MeetingRequest.GA_ENTER_DETAILS_TAB;

    if(activeTabTextElement.hasClass("cjs_calendar_meeting")){
      currentTab = MeetingRequest.GA_SELECT_MEETING_TIMES_TAB;
    }
    else if(activeTabTextElement.hasClass("cjs_ga_meeting")){
      currentTab = MeetingRequest.GA_PROPOSE_TIMES_TAB; 
    }

    return action + currentTab;
  },

  gaTrackPopupClose: function(){
    jQuery(".cjs_dismiss_request_meeting_popup").on("click", function(event){
      event.preventDefault();
      MeetingRequest.gaTrackEvent(MeetingRequest.getDismissPopupActionNameWithTab(jQuery(this)));
      closeQtip();
    });
  },

  trackClickOnMeetingDetailsTab: function(){
    jQuery(".cjs_visit_details_tab").on("click", function(){
      if(!jQuery(this).closest("li").hasClass("active")){
        MeetingRequest.gaTrackViewedPreviousStep();
      }
    });
  },

  resetProposedSlotIndexAndHash: function(){
    MeetingRequest.SAVED_PROPOSED_SLOT_DETAILS_HASH = {};
    MeetingRequest.PROPOSED_SLOTS_COUNT = 1;
    Meetings.calendarSyncV2TimeDetails = {};
  },

  saveMeetingDetails: function(){
    jQuery(".cjs_show_timing_tab").on("click", function(){
      MeetingRequest.validateMeetingDetails(false);
    });
  },

  changeMeetingSlot: function(){
    jQuery(".cjs_change_meeting_slot").on("click", function(){
      MeetingRequest.gaTrackViewedPreviousStep();
      MeetingRequest.handleBackButtonClick();
    });
  },

  backToSelectTimes: function(slotsPresent){
    jQuery(".cjs_back_to_select_times").on("click", function(){
      MeetingRequest.gaTrackViewedPreviousStep();
      if(slotsPresent){
        MeetingRequest.handleBackButtonClick();
      }
      else{
        jQuery("a[href='#cjs_select_meeting_details_tab_content']").click();
      }
    });
  },

  handleBackButtonClick: function(){
    jQuery(".cjs_mentor_available_slots_listing").show();
    jQuery(".cjs_selected_meeting_slot_info").hide();
    jQuery(".cjs_propose_slot_button_container").show();
    jQuery(".cjs_propose_meeting_slot_content").hide();
  },

  selectProposeSlot: function(){
    jQuery(".cjs_propose_slot_button").on("click", function(){
      jQuery(".cjs_mentor_available_slots_listing").hide();
      jQuery(".cjs_selected_meeting_slot_info").hide();
      jQuery(".cjs_propose_slot_button_container").hide();
      jQuery(".cjs_propose_meeting_slot_content").show();
    });
  },

  disableWithForLink: function(buttonSelector, disableText){
    jQuery(buttonSelector).attr("disabled", true);
    jQuery(buttonSelector).html(disableText);
  },

  enableWithForLink: function(buttonSelector, buttonText){
    jQuery(buttonSelector).attr("disabled", false);
    jQuery(buttonSelector).html(buttonText);
  },

  validateMeetingDetails: function(fromTabClick){
    var meetingTitle = jQuery("#new_meeting_title").val().trim();
    var meetingDescription = jQuery("#new_meeting_description").val().trim();

    ValidateRequiredFields.hideFieldError(jQuery("#new_meeting_title"));
    ValidateRequiredFields.hideFieldError(jQuery("#new_meeting_description"));

    if(meetingTitle.length > 0 && meetingDescription.length > 0){
      if(!fromTabClick){
        jQuery("a[href='#select_meeting_time_tab_content']").click();
      }
      else{
        MeetingRequest.gaTrackCompletionOfFirstStep();
      }
    }
    else{
      if(meetingTitle.length == 0){
        ValidateRequiredFields.showFieldError(jQuery("#new_meeting_title"));
      }
      if(meetingDescription.length == 0){
        ValidateRequiredFields.showFieldError(jQuery("#new_meeting_description"));
      }
    }
  },

  handleMeetingDetailsChange: function(){
    jQuery(".cjs_mandatory_meeting_detail").on("change", function(){
      var meetingTitle = jQuery("#new_meeting_title").val().trim();
      var meetingDescription = jQuery("#new_meeting_description").val().trim();
      if(meetingTitle.length > 0 && meetingDescription.length > 0){
        jQuery("a[href='#select_meeting_time_tab_content']").attr("data-toggle", "tab");
      }
      else{
        jQuery("a[href='#select_meeting_time_tab_content']").removeAttr("data-toggle");
      }
    });
  },

  handleSelectTimeTabClick: function(){
    jQuery("a[href='#select_meeting_time_tab_content']").on("click", function(){
      MeetingRequest.validateMeetingDetails(true);
    });
  },

  handleSlotSelection: function(){
    jQuery(".cjs_choose_mentoring_slot").on("click", function(){
      MeetingRequest.gaTrackSlotSelection();
      var url = jQuery(this).data("url");

      jQuery.ajax({
        url: url,
        complete: function(){
          jQuery(".cjs_mentor_available_slots_listing").hide();
          jQuery(".cjs_selected_meeting_slot_info").show();
        }
      });
    });
  },

  toggleSlotForm: function(){
    jQuery("div.cjs_propose_meeting_slot_content").on("click", ".cjs_edit_slot", function(){
      MeetingRequest.closeSlotForm(jQuery(this).closest(".proposed_slots_container"));
    });
  },

  makeAdaChanges: function(clone, slotIndex){
    clone.find(".cjs_meeting_slot_date_label").attr("for", "cjs_meeting_slot_" + slotIndex + "_date");
    clone.find(".cjs_slot_start_time_label").attr("for", "cjs_slot_" + slotIndex + "_start_time");
    clone.find(".cjs_slot_end_time_label").attr("for", "cjs_slot_" + slotIndex + "_end_time");
    clone.find(".cjs_meeting_slot_location_label").attr("for", "cjs_meeting_slot_" + slotIndex + "_location");
  },

  initializeProposeMeetingSlotsJs: function(slotsPresent, allTime, slotDiff, unlimitedSlots, disableText, buttonText){
    MeetingRequest.resetProposedSlotIndexAndHash();
    MeetingRequest.backToSelectTimes(slotsPresent);
    MeetingRequest.handleStartTimeChange(allTime, slotDiff, unlimitedSlots);
    MeetingRequest.toggleSlotForm();
    MeetingRequest.removeProposedSlot();
    MeetingRequest.initializeInitialProposedSlots();
    MeetingRequest.addProposedSlot();
    MeetingRequest.saveProposedSlotForm();
    MeetingRequest.getValidTimeSlots();
    MeetingRequest.cancelProposedSlotForm();
    MeetingRequest.requestMeetingWithProposedSlots(disableText, buttonText);
  },

  proposedSlotsCloner: function(){
    var clone = jQuery(".cjs_proposed_slots_dummy").clone();
    var slotIndex = MeetingRequest.PROPOSED_SLOTS_COUNT;
    clone.removeClass("cjs_proposed_slots_dummy");
    clone.attr("id", "cjs_proposed_slot_" + slotIndex + "_container");
    clone.removeClass("hide");
    clone.find(".cjs_slot_start_time").attr("id", "cjs_slot_" + slotIndex + "_start_time");
    clone.find(".cjs_slot_end_time").attr("id", "cjs_slot_" + slotIndex + "_end_time");
    clone.find(".cjs_meeting_slot_date").attr("id", "cjs_meeting_slot_" + slotIndex + "_date");
    clone.find(".cjs_meeting_slot_location").attr("id", "cjs_meeting_slot_" + slotIndex + "_location");
    clone.find(".cjs_meeting_slot_date").removeClass("cjs-date-picker-added");
    clone.find(".cjs_proposed_slot_index").val(slotIndex);
    clone.find(".cjs-meeting-strip-date-box-handler").remove();
    MeetingRequest.makeAdaChanges(clone, slotIndex);
    MeetingRequest.PROPOSED_SLOTS_COUNT += 1;
    var prependElement = jQuery(".cjs_proposed_slot_prepend_element");
    prependElement.before(clone);
    jQuery("#cjs_slot_" + slotIndex + "_start_time").trigger("change");
    initialize.setDatePicker();
  },

  handleStartTimeChange: function(allTime, slotDiff, unlimitedSlots){
    jQuery("div.cjs_propose_meeting_slot_content").on("change", ".cjs_slot_start_time", function(){
      var proposedSlotContainer = jQuery(this).closest(".proposed_slots_container");
      var slotIndex = proposedSlotContainer.find(".cjs_proposed_slot_index").val();
      var startTimeElement = "#cjs_slot_" + slotIndex + "_start_time";
      var endTimeElement = "#cjs_slot_" + slotIndex + "_end_time";

      if(proposedSlotContainer.hasClass("cjs_calendar_sync_v2_proposed_slot_container")){
        return;
      }
      else{
        if(unlimitedSlots){
          calendarSlot.changeEndTime(allTime, '0', startTimeElement, endTimeElement);
        }
        else{
          var meetingDateContainer = "#" + proposedSlotContainer.attr("id") + " .meeting_date_container ";
          MeetingForm.toggle_end_date(allTime, slotDiff, meetingDateContainer, startTimeElement, endTimeElement);
        }
      }
    });
  },

  handleStartTimeChangeForV2: function(options){
    jQuery("div.cjs_propose_meeting_slot_content, div.meeting_slot_time_form").off("change", ".cjs_slot_start_time, .cjs-meeting-start-time-input").on("change", ".cjs_slot_start_time, .cjs-meeting-start-time-input", function(){
      options = getDefaultVal(options, {});
      var calendarSyncV2Selector = ".cjs_calendar_sync_v2";
      var startTimeElement, endTimeElement, meetingDateContainer;
      if(options.findStartAndEndTimeElements){
        startTimeElement = jQuery(this).closest(calendarSyncV2Selector).find(options.startTimeElement);
        endTimeElement = jQuery(this).closest(calendarSyncV2Selector).find(options.endTimeElement);
        meetingDateContainer = jQuery(this).closest(calendarSyncV2Selector).find(options.meetingDateContainerClass);
      }
      var proposedSlotContainer = jQuery(this).closest(".proposed_slots_container");
      var slotIndex = getDefaultVal(proposedSlotContainer.find(".cjs_proposed_slot_index").val(), 0);
      var startTimes = getDefaultVal(Meetings.calendarSyncV2TimeDetails["startTimes_" + slotIndex], "");
      var endTimes = getDefaultVal(Meetings.calendarSyncV2TimeDetails["endTimes_" + slotIndex], "");
      var indices = getDefaultVal(Meetings.calendarSyncV2TimeDetails["indices_" + slotIndex], "");
      var unlimitedSlots = Meetings.calendarSyncV2TimeDetails["unlimitedSlots"];
      startTimeElement = getDefaultVal(startTimeElement, "#cjs_slot_" + slotIndex + "_start_time");
      endTimeElement = getDefaultVal(endTimeElement, "#cjs_slot_" + slotIndex + "_end_time");
      if(unlimitedSlots){
        MeetingRequest.changeEndTimeForV2(startTimes, endTimes, indices, startTimeElement, endTimeElement);
      }
      else{
        meetingDateContainer = getDefaultVal(meetingDateContainer, "#" + proposedSlotContainer.attr("id") + " .meeting_date_container ");
        MeetingRequest.toggleEndDateForV2(startTimes, endTimes, meetingDateContainer, startTimeElement, endTimeElement);
      }
    });
  },

  toggleEndDateForV2: function(startTimes, endTimes, meetingDateContainer, startTimeElement, endTimeElement){
    var element = jQuery(meetingDateContainer).find('.to_text');
    var startTimesArray = startTimes.split(',');
    var endTimesArray = endTimes.split(',');
    var startTimeValue = jQuery(startTimeElement).val();
    var index = jQuery.inArray(startTimeValue, startTimesArray);
    var endTimeValue = endTimesArray[index];
    jQuery(endTimeElement).val(endTimeValue);
    element.text(endTimeValue);
  },

  changeEndTimeForV2: function(startTimes, endTimes, indices, startTimeElement, endTimeElement){
    var startTimesArray = startTimes.split(',');
    var endTimesArray = endTimes.split(',');
    var indicesArray = indices.split(',');
    jQuery(endTimeElement).empty(); //Clear options if there are any already existing ones.
    var startIndex = jQuery.inArray(jQuery(startTimeElement).val(), startTimesArray);
    var endIndex = indicesArray[startIndex];
    for(i = startIndex; i <= endIndex; i++) {
      jQuery(endTimeElement).append('<option value="' + endTimesArray[i] + '">' + endTimesArray[i] +"</option>");
    }
  },

  setCalendarSyncV2TimeDetails: function(startTimes, endTimes, indices, unlimitedSlots, slotIndex){
    Meetings.calendarSyncV2TimeDetails["startTimes_" + slotIndex] = startTimes;
    Meetings.calendarSyncV2TimeDetails["endTimes_" + slotIndex] = endTimes;
    Meetings.calendarSyncV2TimeDetails["indices_" + slotIndex] = indices;
    Meetings.calendarSyncV2TimeDetails["unlimitedSlots"] = unlimitedSlots;
  },

  initializeInitialProposedSlots: function(){
    MeetingRequest.proposedSlotsCloner();
    MeetingRequest.proposedSlotsCloner();
  },

  addProposedSlot: function(){
    jQuery(".cjs_propose_another_slot_btn").on("click", function(){
      MeetingRequest.gaTrackNewSlotAddition();
      MeetingRequest.proposedSlotsCloner();
    });
  },

  removeProposedSlot: function(){
    jQuery("div.cjs_propose_meeting_slot_content").on("click", ".cjs_remove_slot", function(){
      var proposedSlotContainer = jQuery(this).closest(".proposed_slots_container");
      var slotIndex = proposedSlotContainer.find(".cjs_proposed_slot_index").val();
      MeetingRequest.gaTrackSlotDeletion();
      delete MeetingRequest.SAVED_PROPOSED_SLOT_DETAILS_HASH[slotIndex];
      proposedSlotContainer.remove();
    });
  },

  closeSlotForm: function(proposedSlotContainer){
    proposedSlotContainer.find(".cjs_meeting_slot_form").slideToggle(function(){
      if(proposedSlotContainer.find(".cjs-meeting-strip-date-box-handler").length == 0) CalendarAvailabilityInfo.initialize({selector: proposedSlotContainer, clearCache: false});
    });
  },

  resetSlotForm: function(resetWithDetailsHash, proposedSlotContainer){
    proposedSlotContainer.find(".cjs_meeting_slot_date").val(resetWithDetailsHash["date"]);
    proposedSlotContainer.find(".cjs_meeting_slot_location").val(resetWithDetailsHash["location"]);
    proposedSlotContainer.find(".cjs_slot_start_time option[value='" + resetWithDetailsHash["startTime"] + "']").attr("selected", "selected");
    proposedSlotContainer.find(".cjs_slot_start_time").trigger("change");
    proposedSlotContainer.find(".cjs_slot_end_time option[value='" + resetWithDetailsHash["endTime"] + "']").attr("selected", "selected");
  },

  cancelProposedSlotForm: function(){
    jQuery("div.cjs_propose_meeting_slot_content").on("click", ".cjs_cancel_slot_form", function(){
      var proposedSlotContainer = jQuery(this).closest(".proposed_slots_container");
      var slotIndex = proposedSlotContainer.find(".cjs_proposed_slot_index").val();
      MeetingForm.hideShortlistTimesHelpText("#" + jQuery(proposedSlotContainer).attr('id'));
      MeetingRequest.resetSlotForm(MeetingRequest.SAVED_PROPOSED_SLOT_DETAILS_HASH[slotIndex] || {}, proposedSlotContainer);
      MeetingRequest.closeSlotForm(proposedSlotContainer);
    });
  },

  requestMeetingWithProposedSlots: function(disableText, buttonText){
    jQuery(".cjs_request_meeting_with_proposed_slots").on("click", function(){
      var url = jQuery(this).data("url");
      var slotValidationUrl = jQuery(this).data("slotvalidationurl");
      var menteeAvailabilityText = jQuery(".cjs_mentee_availability_message").val();
      var meetingData = {meeting: {proposedSlots: MeetingRequest.SAVED_PROPOSED_SLOT_DETAILS_HASH, topic: jQuery("#new_meeting_title").val(), description: jQuery("#new_meeting_description").val(), menteeAvailabilityText: menteeAvailabilityText, attendee_ids: jQuery(".cjs_meeting_attendee_ids").val()}, non_time_meeting: true, quick_meeting: true, src: jQuery(".cjs_meeting_request_source").val()};

      var proposedSlotsLength = Object.keys(MeetingRequest.SAVED_PROPOSED_SLOT_DETAILS_HASH).length;

      if(proposedSlotsLength == 0 && menteeAvailabilityText.length == 0){
        ChronusValidator.ErrorManager.ShowResponseFlash("meeting_create_flash", meetingTranslations.slotsOrAvailabilityTextRequired);
      }
      else{
        jQuery.ajax({
          url: slotValidationUrl,
          data: {"slotDetails": MeetingRequest.SAVED_PROPOSED_SLOT_DETAILS_HASH},
          beforeSend: function(){
            MeetingRequest.disableWithForLink(".cjs_request_meeting_with_proposed_slots", disableText);
          },
          success: function(data){
            var valid = data.valid;
            var errorFlash = data.error_flash;
            if(valid){
              jQuery.ajax({
                url: url,
                data: meetingData,
                type: 'POST',
                success: function(){
                  MeetingRequest.enableWithForLink(".cjs_request_meeting_with_proposed_slots", buttonText);
                }
              });
            }
            else{
              MeetingRequest.enableWithForLink(".cjs_request_meeting_with_proposed_slots", buttonText);
              MeetingRequest.gaTrackRequestErroredOut(true);
              ChronusValidator.ErrorManager.ShowResponseFlash("meeting_create_flash", errorFlash);
            }
          }
        });
      }
    });
  },

  saveProposedSlotForm: function(){
    jQuery("div.cjs_propose_meeting_slot_content").on("click", ".cjs_save_slot", function(){
      var proposedSlotContainer = jQuery(this).closest(".proposed_slots_container");
      var slotIndex = proposedSlotContainer.find(".cjs_proposed_slot_index").val();
      var slotDetails = {date: proposedSlotContainer.find(".cjs_meeting_slot_date").val(), location: proposedSlotContainer.find(".cjs_meeting_slot_location").val(), startTime: proposedSlotContainer.find(".cjs_slot_start_time").val(), endTime: proposedSlotContainer.find(".cjs_slot_end_time").val()};

      if(typeof(MeetingRequest.SAVED_PROPOSED_SLOT_DETAILS_HASH[slotIndex]) == "undefined"){
        MeetingRequest.gaTrackProposeNewSlot();
      }
      else{
        MeetingRequest.gaTrackEditProposedSlot();
      }

      if (RequiredFields.checkNonMultiInputCase(proposedSlotContainer.find(".cjs_meeting_slot_date"))){
        jQuery.ajax({
          url: jQuery(this).data("url"),
          data: {"slotDetails": {"1": slotDetails}},
          success: function(data){
            var valid = data.valid;
            var errorFlash = data.error_flash;
            var savedSlotDetail = data.slot_detail;
            if(valid){
              MeetingRequest.SAVED_PROPOSED_SLOT_DETAILS_HASH[slotIndex] = slotDetails;
              proposedSlotContainer.find(".cjs_proposed_slot_detail").html(savedSlotDetail);
              proposedSlotContainer.find(".cjs_proposed_slot_detail").show();
              proposedSlotContainer.find(".cjs_slot_placeholder").hide();
              MeetingRequest.closeSlotForm(proposedSlotContainer);
            }
            else{
              ChronusValidator.ErrorManager.ShowResponseFlash("meeting_create_flash", errorFlash);
            }
          }
        });
      }
    });
  },

  getValidTimeSlotsForSingle: function(jQueryElement){
    if(!CalendarSyncV2.calendarSyncV2Enabled) return;
    var closestForm = jQueryElement.closest("form");
    var closestModal = jQueryElement.closest(".modal");
    /*
      The following are used to get attendees of a meeting (flash & 1-1 ongoing)
        - use groupId from new meetings created inside group
        - use meetingId when editing already created meetings
        - use attendeeId when mentor is creating a flash meeting from calendar
    */
    var groupId = closestForm.find("#meeting_group_id").val();
    var slotIndex = jQueryElement.closest(".proposed_slots_container").find(".cjs_proposed_slot_index").val();
    var meetingId = closestForm.data('meeting-id');
    var attendeeId = closestForm.find("input[name='meeting[attendee_ids][]']:hidden").val()
    var isEditForm = (jQueryElement.closest(".cjs_edit_meeting_form").length == 1);
    var currentOccurrenceTime = closestForm.find(".cjs_current_occurrence_time").val();
    jQuery.ajax({
      url: jQueryElement.data("url"),
      type: 'POST',
      data: {pickedDate: jQueryElement.val(), slotIndex: slotIndex, groupId: groupId, meetingId: meetingId, attendeeId: attendeeId, isEditForm: isEditForm, currentOccurrenceTime: currentOccurrenceTime},
      beforeSend: function(){
        closestModal.hide();
        jQuery("#loading_results").show();
      },
      success: function(){
        jQuery("#loading_results").hide();
        closestModal.show();
      }
    });
  },

  getValidTimeSlotsFunctionForStrip: function(jQueryElement){
    if(!CalendarSyncV2.calendarSyncV2Enabled) return;
    if(!jQueryElement.data('dummy-click') && !jQueryElement.hasClass("cjs-clickable")) return;
    var meetingStripContainer = jQueryElement.closest(".cjs-meeting-strip-container");
    if(!jQueryElement.data('dummy-click')) {
      meetingStripContainer.find(".cjs-meeting-strip-date-box-handler").removeClass("list-group-item selected").css({border: ''});
      var inputField;
      if(meetingStripContainer.data("input-field-container-class").length) inputField = meetingStripContainer.closest("." + meetingStripContainer.data("input-field-container-class")).find("." + meetingStripContainer.data("target-input-class"));
      else inputField = meetingStripContainer.closest("form").find("." + meetingStripContainer.data("target-input-class"));
      inputField.val(MeetingRequest.getDateStr(new Date(jQueryElement.data('date-key'))));
      if(inputField.hasClass('cjs-date-picker-added')) inputField.data("kendoDatePicker").value(MeetingRequest.getDateStr(new Date(jQueryElement.data('date-key'))));
      jQueryElement.addClass("list-group-item selected").css({border: "1px solid #1c84c6"});
    }
    var key = jQueryElement.data("date-key");
    var data = CalendarAvailabilityInfo.getValueFromDataCache(key);
    MeetingRequest.setCalendarSyncV2TimeDetails(data.startTimes, data.endTimes, data.indices, data.unlimitedSlots, data.slotIndex);
    if(CalendarAvailabilityInfo.proposeSlots) {
      var proposedSlotContainer = jQueryElement.closest(".proposed_slots_container");
      var slotIndex = proposedSlotContainer.find(".cjs_proposed_slot_index").val();
      MeetingRequest.setCalendarSyncV2TimeDetails(data.startTimes, data.endTimes, data.indices, data.unlimitedSlots, slotIndex);
      proposedSlotContainer.addClass("cjs_calendar_sync_v2_proposed_slot_container");
      proposedSlotContainer.find(".cjs_propose_slot_time_form").html(data.content);
      proposedSlotContainer.find(".cjs_slot_start_time").attr("id", "cjs_slot_" + slotIndex + "_start_time");
      proposedSlotContainer.find(".cjs_slot_end_time").attr("id", "cjs_slot_" + slotIndex + "_end_time");
      MeetingRequest.makeAdaChanges(proposedSlotContainer.find(".cjs_calendar_sync_v2"), slotIndex);
      MeetingRequest.handleStartTimeChangeForV2();
      proposedSlotContainer.find(".cjs_slot_start_time").trigger('change');
      if(!data.slotsAvailable) proposedSlotContainer.find(".cjs_calendar_sync_v2_date").val("");
    } else {
      var selectorPrefix = ".";
      jQuery(".meeting_slot_time_form").html(data.content);
      MeetingRequest.handleStartTimeChangeForV2({startTimeElement: selectorPrefix + data.partialOptions.start_time_attributes.class, endTimeElement: selectorPrefix + data.partialOptions.end_time_attributes.class, meetingDateContainerClass: selectorPrefix + data.partialOptions.meeting_date_container_class, findStartAndEndTimeElements: true});
      if(!CalendarAvailabilityInfo.triggerNoChange) {
        jQuery(selectorPrefix + data.partialOptions.start_time_attributes.class).trigger('change');
      }
      if(!data.slotsAvailable) {
        jQuery(".cjs_calendar_sync_v2_date").val("");
      }
    }
    jQueryElement.data('dummy-click', false);
  },

  getAdjustedDateFromDateMillisecond: function(dateInMillisecond) {
    return new Date(dateInMillisecond - (getDefaultVal(TimeZoneUtils.getSystemTimeZoneOffset(), 0) * 1000) + (getDefaultVal(currentUserTimeZone, 0) * 60000));
  },

  getAdjustedDate: function(date) {
    return MeetingRequest.getAdjustedDateFromDateMillisecond(date.getTime());
  },

  updateMeetingStrip: function(buttonContext, startDate, endDate, options) {
    options = getDefaultVal(options, {});
    var meetingStripContainer = buttonContext.closest(".cjs-meeting-strip-container");
    meetingStripContainer.find(".cjs-meeting-strip-date-box-handler").remove();
    var dateBox = jQuery("<div>", {class: "b-l b-t b-b text-center cjs-meeting-strip-date-box-handler pull-left pointer cjs-clickable cui-meeting-strip-box"});
    if(startDate > endDate) { var tmp = endDate; endDate = startDate; startDate = tmp; }
    
    var date;
    for(date = new Date(endDate); date >= startDate; date.setDate(date.getDate() - 1)) {
      var thisDateBox = dateBox.clone();
      var dateKey = date.getTime();
      var convertedDate = MeetingRequest.getAdjustedDateFromDateMillisecond(dateKey);
      thisDateBox.append(jQuery("<div>", {text: fullCalendarParamHash['dayNamesShort'][convertedDate.getDay()], class: "small"}));
      thisDateBox.append(jQuery("<div>", {html: jQuery("<strong>", {class: "cjs-day-name", text: (fullCalendarParamHash['monthNamesShort'][convertedDate.getMonth()] + " " + convertedDate.getDate())}), class: "p-t-1"}));
      var cachedData = CalendarAvailabilityInfo.getValueFromDataCache(dateKey);
      var countSlotsText = '' + cachedData['slotsCount'] + ' ';
      if(cachedData['slotsCount'] == 1) countSlotsText += CalendarAvailabilityTranslations.slotOne;
      else countSlotsText += CalendarAvailabilityTranslations.slotOther;
      thisDateBox.append(jQuery("<div>", {text: countSlotsText, class: "small p-t-1"}));
      thisDateBox.toggleClass("pointer cjs-clickable text-info", (cachedData['slotsCount'] > 0));
      thisDateBox.find(".cjs-day-name").toggleClass("todo-completed", (cachedData['slotsCount'] == 0));
      thisDateBox.toggleClass("text-muted", (cachedData['slotsCount'] == 0));
      thisDateBox.data('date-key', dateKey);
      thisDateBox.insertAfter(meetingStripContainer.find(".cjs-get-prev-n-days-container"));
    }
    
    var nextButton = meetingStripContainer.find(".cjs-get-next-n-days-slots-info");
    var nextDate = new Date((new Date(endDate)).setDate((new Date(endDate)).getDate() + 1))
    nextButton.data('date-pointer', nextDate);
    MeetingRequest.updateButtonClickability(nextButton);
    
    var prevButton = meetingStripContainer.find(".cjs-get-prev-n-days-slots-info");
    var prevDate = new Date((new Date(startDate)).setDate((new Date(startDate)).getDate() - 1))
    prevButton.data('date-pointer', prevDate);
    MeetingRequest.updateButtonClickability(prevButton);

    var dateBoxToSelect;
    if(options.selectDateKey) {
      jQuery.each(meetingStripContainer.find(".cjs-meeting-strip-date-box-handler.cjs-clickable"), function(index, element) {
        if(jQuery(element).data('date-key') == options.selectDateKey) dateBoxToSelect = jQuery(element);
      });
    } else {
      dateBoxToSelect = meetingStripContainer.find(".cjs-meeting-strip-date-box-handler.cjs-clickable").eq(0);
    }
    if(dateBoxToSelect && dateBoxToSelect.length) dateBoxToSelect.click();
    // TODO_CSV3 : check and remove later after PM feedback
    // else if(buttonContext.hasClass("cjs-get-next-n-days-slots-info") && prevButton.hasClass(".cjs-clickable")) prevButton.click();
    // else if(buttonContext.hasClass("cjs-get-prev-n-days-slots-info") && nextButton.hasClass(".cjs-clickable")) nextButton.click();
    else meetingStripContainer.find(".cjs-meeting-strip-date-box-handler").eq(0).data('dummy-click', true).click();
  },

  updateButtonClickability: function(navButton) {
    var nextButton = navButton.hasClass("cjs-get-next-n-days-slots-info");
    var makeUnclickable = false;
    if(nextButton) {
      makeUnclickable = (navButton.data('no-future') && navButton.data('date-pointer') > MeetingRequest.getTodayBeginningOfDayInUserTimeZone());
      makeUnclickable = makeUnclickable || (!(getDefaultVal(navButton.data('max-date').toString(), "").blank()) && (navButton.data('date-pointer') > navButton.data('max-date')));
    } else makeUnclickable = (navButton.data('no-past') && navButton.data('date-pointer') < MeetingRequest.getTodayBeginningOfDayInUserTimeZone());
    if(makeUnclickable) {
      navButton.removeClass('pointer cjs-clickable').addClass('text-muted');
      navButton.find(".fa").addClass("fa-ban").removeClass("fa-backward fa-forward");
    } else {
      navButton.addClass('pointer cjs-clickable').removeClass('text-muted');
      var directionClass = (nextButton ? "fa-forward" : "fa-backward");
      navButton.find(".fa").removeClass("fa-ban").addClass(directionClass);
    }
  },

  getDateStr: function(date) {
    var targetDate = MeetingRequest.getAdjustedDate(date);
    return ("" + fullCalendarParamHash.monthNames[targetDate.getMonth()] + " " + targetDate.getDate() + ", " + targetDate.getFullYear());
  },

  getTodayBeginningOfDayInUserTimeZone: function() {
    return new Date(todayBeginningOfDayInUserTimeZoneInMillisecond);
  },

  getNextNDaysValidTimeSlots: function(jQueryElement, options) {
    if(!CalendarSyncV2.calendarSyncV2Enabled) return;
    if(!jQueryElement.hasClass("cjs-clickable")) return;
    options = getDefaultVal(options, {});

    // compute frame start end date
    var isEditForm = (jQueryElement.closest(".cjs_edit_meeting_form").length == 1);
    var closestForm = jQueryElement.closest("form");
    var currentOccurrenceTime = closestForm.find(".cjs_current_occurrence_time").val();
    var currentOccurrenceTimeBeginningOfDayInMillisecond = closestForm.find(".cjs_current_occurrence_time").data('beginning-of-day');
    var pickedDate; // will be in user's mentor app time zone, beginning of day
    if(options.pickedDate) pickedDate = options.pickedDate;
    else if(isEditForm && jQueryElement.data('init-click')) pickedDate = new Date(currentOccurrenceTimeBeginningOfDayInMillisecond);
    else pickedDate = getDefaultVal(jQueryElement.data('date-pointer'), MeetingRequest.getTodayBeginningOfDayInUserTimeZone());
    jQueryElement.data('init-click', false);
    var frameStartDate = new Date(pickedDate);
    var direction = (jQueryElement.hasClass("cjs-get-prev-n-days-slots-info") ? (-1) : 1);
    var meetingStripContainer = jQueryElement.closest(".cjs-meeting-strip-container");
    MeetingRequest.setSpan(jQueryElement, meetingStripContainer);
    var directedSpan = (CalendarAvailabilityInfo.span * direction);
    var frameEndDate = new Date((new Date(pickedDate)).setDate((new Date(pickedDate)).getDate() + (directedSpan - direction)));
    var adjustedDirectedSpan = directedSpan;

    var offset = 0;
    if(direction < 0 && jQueryElement.data('no-past')) {
      offset = (MeetingRequest.getTodayBeginningOfDayInUserTimeZone().getTime() - frameEndDate.getTime()) / 86400000;
      if(offset > 0) adjustedDirectedSpan = directedSpan + offset;
    }
    if(direction > 0 && jQueryElement.data('no-future')) {
      offset = (frameEndDate.getTime() - MeetingRequest.getTodayBeginningOfDayInUserTimeZone().getTime()) / 86400000;
      if(offset > 0) adjustedDirectedSpan = directedSpan - offset;
    }
    if(direction > 0) {
      var maxDate = new Date(jQueryElement.data('max-date'));
      if(frameEndDate > maxDate) {
        offset = (frameEndDate.getTime() - maxDate.getTime()) / 86400000;
        if(offset > 0) adjustedDirectedSpan = directedSpan - offset;
      }
    }
    if(offset > 0) {
      frameEndDate = new Date((new Date(pickedDate)).setDate((new Date(pickedDate)).getDate() + (adjustedDirectedSpan - direction)));
      frameStartDate = new Date((new Date(frameEndDate)).setDate((new Date(frameEndDate)).getDate() - (directedSpan - direction)));
    }
    if(frameStartDate > frameEndDate) { var tmp = frameEndDate; frameEndDate = frameStartDate; frameStartDate = tmp; }

    if(CalendarAvailabilityInfo.getValueFromDataCache(frameStartDate.getTime()) && CalendarAvailabilityInfo.getValueFromDataCache(frameEndDate.getTime())) {
      MeetingRequest.updateMeetingStrip(jQueryElement, frameStartDate, frameEndDate, {selectDateKey: options.selectDateKey});
    } else {
      var closestModal = jQueryElement.closest(".modal");
      var groupId = closestForm.find("#meeting_group_id").val();
      var slotIndex = jQueryElement.closest(".proposed_slots_container").find(".cjs_proposed_slot_index").val();
      var meetingId = closestForm.data('meeting-id');
      var attendeeId = closestForm.find("input[name='meeting[attendee_ids][]']:hidden").val()
      var pickedDateStr = MeetingRequest.getDateStr(pickedDate);

      MeetingRequest.meetingStripQueryButtonInContext = jQueryElement;
      MeetingRequest.framStartDateInContext = frameStartDate;
      MeetingRequest.frameEndDateInContext = frameEndDate;
      MeetingRequest.selectDateKeyInContext = options.selectDateKey;

      jQuery.ajax({
        url: jQueryElement.data("url"),
        type: 'POST',
        data: {pickedDate: pickedDateStr, span: (adjustedDirectedSpan - direction), slotIndex: slotIndex, groupId: groupId, meetingId: meetingId, attendeeId: attendeeId, isEditForm: isEditForm, currentOccurrenceTime: currentOccurrenceTime},
        beforeSend: function(){
          jQueryElement.closest('.cjs-meeting-date-container').find('.cjs-meeting-date-loader').show();
        },
        success: function(){
          MeetingRequest.updateMeetingStrip(MeetingRequest.meetingStripQueryButtonInContext, MeetingRequest.framStartDateInContext, MeetingRequest.frameEndDateInContext, {selectDateKey: MeetingRequest.selectDateKeyInContext});
          jQueryElement.closest('.cjs-meeting-date-container').find('.cjs-meeting-date-loader').hide();
        }
      });
    }
  },

  setSpan: function(jQueryElement, meetingStripContainer) {
    if(jQueryElement.data('set-default-span')) {
      CalendarAvailabilityInfo.span = (isMobileOrTablet() ? CalendarAvailabilityInfo.defaultMobileSpan : CalendarAvailabilityInfo.defaultSpan);
      jQueryElement.data('set-default-span', false);
    } else CalendarAvailabilityInfo.span = MeetingRequest.getMeetingStripSpanCount(meetingStripContainer);
  },

  getValidTimeSlots: function() {
    if(!Meetings.getValidTimeSlotsRegistered) {
      jQuery(document).on("change", ".cjs_meeting_slot_date, .cjs-meeting-date-input", function() {
        MeetingRequest.getValidTimeSlotsForSingle(jQuery(this));
      });
      jQuery(document).on("click", ".cjs-meeting-strip-date-box-handler", function(){ MeetingRequest.getValidTimeSlotsFunctionForStrip(jQuery(this)) });
      jQuery(document).on("click", ".cjs-get-next-n-days-slots-info, .cjs-get-prev-n-days-slots-info", function() { MeetingRequest.getNextNDaysValidTimeSlots(jQuery(this)) });
      jQuery(window).on("resize", function() {
        jQuery.each(jQuery(".cjs-meeting-strip-container:visible"), function(index, strip) {
          var meetingStripContainer = jQuery(strip);
          var nextButton = meetingStripContainer.find(".cjs-get-next-n-days-slots-info");
          var frameStartDate = new Date(meetingStripContainer.find(".cjs-meeting-strip-date-box-handler").first().data('date-key'));
          var frameSelectedDate;
          if(meetingStripContainer.find(".cjs-meeting-strip-date-box-handler.selected").length) frameSelectedDate = new Date(meetingStripContainer.find(".cjs-meeting-strip-date-box-handler.selected").first().data('date-key'));
          else frameSelectedDate = frameStartDate;
          CalendarAvailabilityInfo.span = MeetingRequest.getMeetingStripSpanCount(meetingStripContainer);
          MeetingRequest.getNextNDaysValidTimeSlots(nextButton, {pickedDate: frameSelectedDate, selectDateKey: frameSelectedDate.getTime()});
        });
      });
      Meetings.getValidTimeSlotsRegistered = true;
    }
  },

  getMeetingStripSpanCount: function(meetingStripContainer) {
    // CSV3_TODO : rework this later
    // cui-meeting-strip-box class width
    return Math.min(CalendarAvailabilityInfo.defaultSpan, (parseInt(meetingStripContainer.width() / 60) - 2));
  },

  initializeChangeForDate: function(selector){
    jQuery(selector).each(function(){
      if(jQuery(this).is(":visible") && (!(jQuery(this).val().blank())))
        jQuery(this).trigger('change');
    });
  },

  initializeChangeForDateRange: function(selector, valueSelector){
    jQuery(selector).each(function(){
      if((jQuery(this).length > 0) && jQuery(this).is(":visible") && (!(jQuery(valueSelector).val().blank()))) CalendarAvailabilityInfo.initialize({selector: this});
    });
  },

  initializeProposeSlotPopup: function(buttonClass, url){
    jQuery(document).on('click', buttonClass, function(){
      Meetings.renderMiniPopup(url)
    });
  },

  initializeDeclineSlotPopup: function(modalId, buttonId){
    jQuery(document).on('click', buttonId, function(){
      closeQtip();
      jQuery(modalId).modal('show');
    });
  },

  proposeSlotDetails: function(proposedSlotSelector){
    var slotDetails = {date: proposedSlotSelector.find(".cjs_meeting_slot_date").val(), location: proposedSlotSelector.find(".cjs_meeting_slot_location").val(), startTime: proposedSlotSelector.find(".cjs_slot_start_time").val(), endTime: proposedSlotSelector.find(".cjs_slot_end_time").val()};
    return slotDetails;
  },

  AcceptAndProposeSlot: function(disableText, buttonText, source, mentor_request_id){
    jQuery(".cjs_propose_meeting_form").on("click", ".cjs_propose_meeting", function(){
      var url = jQuery('.cjs_propose_meeting').data("url");
      var proposedSlotSelector = jQuery(this).closest(".cjs_meeting_slot_form");
      MeetingRequest.disableWithForLink(".cjs_propose_meeting", disableText);
      if(proposedSlotSelector.find(".cjs_meeting_slot_date").val().trim().length == 0){
        ValidateRequiredFields.showFieldError(jQuery(".cjs_meeting_slot_date"));
        MeetingRequest.enableWithForLink(".cjs_propose_meeting", buttonText);
      }
      else{
        var slotDetails = {proposedSlot: MeetingRequest.proposeSlotDetails(proposedSlotSelector), source: source, mentor_request_id: mentor_request_id, slotMessage: proposedSlotSelector.find(".cjs_slot_message_content").val().trim()};
        var eventLabel = source;
        var eventLabelId = MeetingRequest.gaGetRequestSourceId(source);
        chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.MEETING_REQUEST_ACTIVITY, MeetingRequest.GA_ACCEPTED_REQUEST_AND_PROPOSED_SLOT, eventLabel, eventLabelId);
        MeetingRequest.updateMeetingData(url, slotDetails);
      }
    });
  },

  AcceptAndSendMessage: function(disableText, buttonText, source, mentor_request_id){
    jQuery(".cjs_propose_meeting_form").on("click", ".cjs_propose_send_message", function(){
      var url = jQuery('.cjs_propose_send_message').data("url");
      var data = {acceptanceMessage: jQuery('.cjs_acceptance_message_content').val(), source: source, mentor_request_id: mentor_request_id };
      MeetingRequest.disableWithForLink(".cjs_propose_send_message", disableText);
      if(jQuery('.cjs_acceptance_message_content').val().trim().length == 0){
        ValidateRequiredFields.showFieldError(jQuery(".cjs_acceptance_message_content"));
        MeetingRequest.enableWithForLink(".cjs_propose_send_message", buttonText);
      }
      else{
        var eventLabel = source;
        var eventLabelId = MeetingRequest.gaGetRequestSourceId(source);
        chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.MEETING_REQUEST_ACTIVITY, MeetingRequest.GA_ACCEPTED_REQUEST_AND_SENT_MESSAGE, eventLabel, eventLabelId);
        MeetingRequest.updateMeetingData(url, data);
      }
    });
  },

  updateMeetingData: function(url, data){
    jQuery.ajax({
      url: url,
      data: data,
      type: 'POST'
    });
  },

  handleShowHideSlotAndMessageContent: function(){
    jQuery(".cjs_propose_meeting_form").on("click", ".cjs_toggle_slot_popup_content", function(){
      jQuery(".cjs_meeting_slot_content, .cjs_meeting_message_content").toggleClass('hide');
    });
  },

  handleStartTimeChangeProposeSlotPopup: function(allTime, slotDiff, unlimitedSlots){
    //mentor proposing slot
    jQuery(".cjs_meeting_slot_form").on("change", ".cjs_slot_start_time", function(){
      var proposedSlotContainer = jQuery(this).closest(".cjs_meeting_slot_form");
      var startTimeElement = ".cjs_slot_start_time";
      var endTimeElement = ".cjs_slot_end_time";

      if(unlimitedSlots){
        calendarSlot.changeEndTime(allTime, '0', startTimeElement, endTimeElement);
      }
      else{
        var meetingDateContainer = ".cjs_meeting_slot_form .meeting_date_container ";
        MeetingForm.toggle_end_date(allTime, slotDiff, meetingDateContainer, startTimeElement, endTimeElement);
      }
    });
  },

  trackDismissProposeSlotPopup: function(source){
    jQuery(document).on('click', '.cjs_dismiss_propose_slot_popup', function(event){
      event.preventDefault();
      var eventLabel = source;
      var eventLabelId = MeetingRequest.gaGetRequestSourceId(source);
      chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.MEETING_REQUEST_ACTIVITY, MeetingRequest.GA_DISMISSED_PROPOSE_SLOT_POPUP, eventLabel, eventLabelId);
      closeQtip();
    });
  },

  getEventActionForListing: function(element){
    if (element.hasClass("cjs_decline_meeting_request")){
      return MeetingRequest.GA_REJECTED_REQUEST;
    }

    else if (element.hasClass("cjs_accept_meeting_slot")){
      return MeetingRequest.GA_ACCEPTED_REQUEST_WITH_SLOT;
    }

    else if (element.hasClass("cjs_withdraw_meeting_request")){
      return MeetingRequest.GA_WITHDRAWN_MEETING_REQUEST;
    }

    else if (element.hasClass("cjs_close_meeting_request")){
      return MeetingRequest.GA_CLOSED_MEETING_REQUEST;
    }
  },

  trackMeetingRequestActions: function(source){
    jQuery(document).on('click', '.cjs_decline_meeting_request, .cjs_accept_meeting_slot, .cjs_withdraw_meeting_request, .cjs_close_meeting_request', function(event){
      var eventAction = MeetingRequest.getEventActionForListing(jQuery(this));
      var eventLabel = source;
      var eventLabelId = MeetingRequest.gaGetRequestSourceId(source);
      chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.MEETING_REQUEST_ACTIVITY, eventAction, eventLabel, eventLabelId);
    });
  }
};