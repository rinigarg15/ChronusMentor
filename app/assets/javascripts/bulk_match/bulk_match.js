var BulkMatch = {

  student: {},
  mentors: {},
  bulk_match_vars: {},

  stepOneSubmit: "#bulk_match_step_one input[type=submit]",
  stepOneLink: "#bulk_match .nav-tabs li a#select_users",
  stepOneTab: "#bulk_match #select_views_content",
  stepTwoLink: "#bulk_match .nav-tabs li a#find_matches",
  stepTwoTab: "#bulk_match #find_match_content",
  menteeViewSelect: "#bulk_match_mentee_view_id",
  mentorViewSelect: "#bulk_match_mentor_view_id",
  hiddenMenteeViewSelect: "#bulk_match_mentee_view_hidden_id",
  hiddenMentorViewSelect: "#bulk_match_mentor_view_hidden_id",
  loadingResultsImage: "#loading_results",
  errorFlash: "cjs_bulk_match_flash",
  successFlash: "#inner_content #flash_container",
  stickyBanner: "#bulk_match .cui_bulk_match_top_banner",
  exportCSVLink: ".cjs_bulk_match_export",
  settingsSubmit: "#bulk_match_settings_content #bulk_match_settings_submit",
  settingsForm: "#bulk_match_settings_content #bulk_match_settings",
  settingsLoadingResults: "#bulk_match_settings_content #bulk_match_setting_update_results",
  refreshResults: "#bulk_match #cjs_refresh_results",
  radioButtons: "#bulk_match_step_one #cjs_bulk_match_type input:radio",
  orientationRadioButtons: "#bulk_match_step_one #cjs_bulk_match_orientation_type input:radio",
  hiddenMaxSuggestionCount: "#bulk_match_settings_content input#bulk_recommendation_hidden_max_suggestion_count",
  maxSuggestionCount: "#bulk_match_settings_content input#bulk_recommendation_max_suggestion_count",
  maxPickableSlots: function() {
    return "#bulk_match_settings_content input#" + BulkMatch.type_underscore + "_max_pickable_slots"
  },
  hiddenMaxPickableSlots: function() {
    return "#bulk_match_settings_content input#" + BulkMatch.type_underscore +  "_hidden_max_pickable_slots"
  },

  initalizeActions: function(bulkMatchType, recommendMentors, orientationType){
    BulkMatch.type = bulkMatchType;
    BulkMatch.type_underscore = bulkMatchType.underscore();
    BulkMatch.recommendMentors = recommendMentors;
    jQuery(document).ready(function(){
      BulkMatch.initalizeTabs();
      BulkMatch.validateTabSwitch();
      AdminViews.handleViewChange();
      BulkMatch.initializeSubmitSettings(orientationType);
      BulkMatch.handleRefresh();
      BulkMatch.initializeRadioActions();
    });
    
    jQuery(document).on("click", ".cjs_bulk_match_export_all, .cjs_bulk_match_csv_drafted_pairs", function(){
      var form = jQuery(this).hasClass("cjs_bulk_match_export_all") ? jQuery("#cjs_export_all_form") : jQuery("#cjs_bulk_match_export_drafted_pairs");
      BulkMatch.submitExportForm(form, orientationType);
    });

    jQuery(document).on('click', '.cjs-blur-on-click', function(){ jQuery(this).blur() });
  },

  submitExportForm: function(form, orientationType){
    var students_mentors_hash;
    if(orientationType == BulkMatch.mentorOrientationType){
      students_mentors_hash = BulkMatch.setStudentsAndMentorsHashForMentorToMentee();
    }else{
      students_mentors_hash = BulkMatch.setStudentsAndMentorsHashForMenteeToMentor();
    }
    var students = students_mentors_hash[0];
    var mentors = students_mentors_hash[1];
    jQuery(".cjs_students_field").val(JSON.stringify(students));
    jQuery(".cjs_mentors_field").val(JSON.stringify(mentors));
    form.submit();
  },

  setStudentsAndMentorsHashForMenteeToMentor: function(){
    var students = BulkMatch.students.map(function(s) { return {id: s.id, group_status: s.group_status, group_id: s.group_id, selected_mentors: s.selected_mentors}; });
    var mentors = BulkMatch.mentors.map(function(m) { return {id: m.id, connections_count: m.connections_count, recommended_count: m.recommended_count}; });
    return [students, mentors]
  },

  setStudentsAndMentorsHashForMentorToMentee: function(){
    var students = BulkMatch.students.map(function(s) { return {id: s.id}; });
    var mentors = BulkMatch.mentors.map(function(m) { return {id: m.id, connections_count: m.connections_count, recommended_count: m.recommended_count, pickable_slots: m.pickable_slots, group_status: m.group_status, group_id: m.group_id, selected_students: m.selected_students}; });
    return [students, mentors]
  },

  initalizeOrientationOptions: function(menteeOrientation, mentorOrientation){
    BulkMatch.menteeOrientationType = menteeOrientation;
    BulkMatch.mentorOrientationType = mentorOrientation;
  },

  initalizeTabs: function(){
    if(jQuery(BulkMatch.stepTwoLink).data("disabled")){
      jQuery(BulkMatch.stepTwoLink).addClass("disabled_link");
    }
  },

  fetchStepContent: function(link1, link2){
    var tabElement = jQuery(link1).closest("li");
    if(!tabElement.hasClass("active")){
      tabElement.addClass("active");
      jQuery(link2).closest("li").removeClass("active");
    }
  },

  initializeRadioActions: function() {
    jQuery(BulkMatch.radioButtons + ", " + BulkMatch.orientationRadioButtons).on('click', function() {
      var type = jQuery(this).val();
      var ajaxLoader = jQuery(this).parent().find("img.ajax_loading");
      jQuery.ajax({
        url: jQuery(this).data("url"),
        data: {type: type},
        beforeSend: function(){
          ajaxLoader.removeClass("invisible");
        },
        success: function(){
          ajaxLoader.addClass("invisible");
        }
      });
    });
  },

  isValidTabSwitch: function(){
    var menteeViewExist = RequiredFields.checkNonMultiInputCase(BulkMatch.menteeViewSelect);
    var mentorViewExist = RequiredFields.checkNonMultiInputCase(BulkMatch.mentorViewSelect);
    var menteeViewSelect2Box = jQuery(BulkMatch.menteeViewSelect).closest(".controls").find(".select2-choice");
    var mentorViewSelect2Box = jQuery(BulkMatch.mentorViewSelect).closest(".controls").find(".select2-choice");

    ChronusValidator.ErrorManager.ShowHideFieldError(menteeViewSelect2Box, !menteeViewExist);
    ChronusValidator.ErrorManager.ShowHideFieldError(mentorViewSelect2Box, !mentorViewExist);
    if(menteeViewExist && mentorViewExist){
      ChronusValidator.ErrorManager.ClearResponseFlash(BulkMatch.errorFlash);
      return true;
    }
    else{
      ChronusValidator.ErrorManager.ShowResponseFlash(BulkMatch.errorFlash, BulkMatch.locale.tabSwitchMsg);
      return false;
    }
  },

  validateTabSwitch: function(){
    jQuery(BulkMatch.stepOneSubmit+", "+BulkMatch.stepTwoLink).click(function(event){
      event.preventDefault();
      var tabElement = jQuery(BulkMatch.stepTwoLink).closest("li");
      if(!tabElement.hasClass('active') && BulkMatch.isValidTabSwitch()){
        var menteeViewId = jQuery(BulkMatch.menteeViewSelect).val();
        var mentorViewId = jQuery(BulkMatch.mentorViewSelect).val();
        var type = jQuery(BulkMatch.radioButtons + ":checked").val() || BulkMatch.type;
        var orientationType = jQuery(BulkMatch.orientationRadioButtons + ":checked").val();
        var requestUrl = jQuery(this).data("url");

        jQuery.ajax({
          url: requestUrl,
          data: {mentee_view_id: menteeViewId, mentor_view_id: mentorViewId, type: type, orientation_type: orientationType},
          beforeSend: function(){
            jQuery(BulkMatch.successFlash).hide();
            BulkMatch.enableStepTwo();
            jQuery(BulkMatch.loadingResultsImage).show();
            jQuery(BulkMatch.stepOneTab).hide();
          },
          success: function(){
            jQuery(BulkMatch.hiddenMenteeViewSelect).val(menteeViewId);
            jQuery(BulkMatch.hiddenMentorViewSelect).val(mentorViewId);
            if(BulkMatch.recommendMentors) {jQuery(BulkMatch.exportCSVLink).show();}
          }
        });
      }
      else{
        return false;
      }
    });

    jQuery(BulkMatch.stepOneLink).click(function(){
      var stepOneTabElement = jQuery(BulkMatch.stepOneLink).closest("li");
      var stepTwoTabElement = jQuery(BulkMatch.stepTwoLink).closest("li");
      if(!stepOneTabElement.hasClass('active') && stepTwoTabElement.hasClass('active')) {
        chronusConfirm(BulkMatch.locale[BulkMatch.type].tabSwitchConfirmMsg, function() {
          if(BulkMatch.recommendMentors) {
            window.location.href = jQuery(BulkMatch.stepOneLink).data("url");
          }
          else {
            BulkMatch.fetchStepContent(BulkMatch.stepOneLink, BulkMatch.stepTwoLink);
            jQuery(BulkMatch.stepTwoTab).hide();
            jQuery(BulkMatch.stepOneTab).show();
            jQuery(BulkMatch.exportCSVLink).hide();
            jQuery(".cjs_view_drafted_pairs").hide();
          }
        });
      }
    });
  },

  enableStepTwo: function(){
    jQuery(BulkMatch.stepTwoLink).data("disabled", false);
    jQuery(BulkMatch.stepTwoLink).removeClass("disabled_link");
    BulkMatch.fetchStepContent(BulkMatch.stepTwoLink, BulkMatch.stepOneLink);
  },

  initalizeSticky: function(){
    var headerHeight = jQuery("#chronus_header_wrapper").height()
    var offsetTop = jQuery('.cui_bulk_match_top_banner').offset().top - headerHeight;
    jQuery('.cui_bulk_match_top_banner').affix({
      offset: {
        top: offsetTop
      }
    });
    jQuery(".cui_bulk_match_top_banner").on("affix.bs.affix", function(){
      jQuery(this).css('top', headerHeight + 'px');
    })
  },

  toggleFormElement: function(studentId){
    jQuery('#cjs_bulk_match_notes_popup_'+studentId).show();
    jQuery('#cjs_notes_'+studentId).hide();
  },

  initializeSubmitSettings: function(orientationType){
    if(orientationType == BulkMatch.menteeOrientationType){
      jQuery(BulkMatch.settingsSubmit).live('click', function(){
        var maxPickableVal = jQuery(BulkMatch.maxPickableSlots()).val();
        var maxSuggestionCount = jQuery(BulkMatch.maxSuggestionCount).val();
        if(maxPickableVal.match(/^[0-9]+$/) && (!BulkMatch.recommendMentors || maxSuggestionCount.match(/^[0-9]+$/)) ) {
          ChronusValidator.ErrorManager.ClearResponseFlash("cjs_bulk_match_settings_flash");
          var suggestionCountChanged = false;
          if(BulkMatch.recommendMentors) {
            var oldSuggestionCount = parseInt(jQuery(BulkMatch.hiddenMaxSuggestionCount).val());
            suggestionCountChanged = (oldSuggestionCount != maxSuggestionCount);
          }
          var oldPicakableVal = parseInt(jQuery(BulkMatch.hiddenMaxPickableSlots()).val());
        }
        else{
          ChronusValidator.ErrorManager.ShowResponseFlash("cjs_bulk_match_settings_flash", BulkMatch.locale.validLimit);
          return false;
        }
      });
    }
  },

  checkStatus: function(bulkMatch, user, statusLabel, statusList) {
    var returnVal = (user.group_status == statusLabel);
    if(bulkMatch && !returnVal) {
      returnVal = (statusList.length > 0);
    }
    return returnVal;
  },

  handleRefresh: function(){
    jQuery(BulkMatch.refreshResults).live('click', function(){
      jQuery.ajax({
        url: jQuery(this).data('url'),
        beforeSend: function(){
          jQuery(BulkMatch.loadingResultsImage).show();
        }
      });
    });
  },
  
  showGroupsAlert: function(groupsAlert) {
    jQuery("#cjs_bulk_match_groups_alert_modal .modal-body").html(groupsAlert);
    jQuery("#cjs_bulk_match_groups_alert_modal").modal("show");
  },

  initializeTooltipInsideModal: function(){
    jQuery("[data-toggle=tooltip]").tooltip({placement: 'top'})
  },

  addSupplementaryMatchingPair: function(errorText) {
    // CAUTION : don't use this class to bind any other event
    jQuery(".cjs-add-supplementary-match-pair").unbind('click').on('click', function() {
      var mentorQuestionId = jQuery("#supplementary_matching_pair_mentor_role_question_id").val();
      var studentQuestionId = jQuery("#supplementary_matching_pair_student_role_question_id").val();
      if(BulkMatch.checkExistingPairs(mentorQuestionId, studentQuestionId)) {
        ChronusValidator.ErrorManager.ShowPageFlash(false, errorText);
      }
      else {
        jQueryShowQtip(null, null, jQuery(this).data('url'), {add_supplementary_question: true, mentor_question_id: mentorQuestionId, student_question_id: studentQuestionId}, {largeModal: true});
      }
    });
  },

  checkExistingPairs: function(mentorQuestionId, studentQuestionId) {
    var mentorQuestionElements = jQuery("div").find('[data-mentor-question-id="' + mentorQuestionId + '"]');
    var flag = false;
    if(mentorQuestionElements.length > 0) {
      var studentQuestionElements = mentorQuestionElements.closest(".cjs-question-pair").find(".cjs-student-question");
      studentQuestionElements.each(function() {
        if(jQuery(this).data('student-question-id') == studentQuestionId) { flag = true; return false; }
      });
    }
    return flag;
  },

  deleteSupplementaryMatchingPair: function() {
    jQuery(".cjs-delete-supplementary-match-pair").unbind('click').on('click', function() {
      jQueryShowQtip(null, null, jQuery(this).data('url'), {delete_supplementary_question: true}, {largeModal: true});
    });
  },

  UserIdGroupIdList: {
    pushIntoList: function(userIdGroupIdList, userId, groupId) {
      if(BulkMatch.UserIdGroupIdList.lookupList(userIdGroupIdList, userId, groupId) == -1) {
        userIdGroupIdList.push([userId, groupId]);
      }
    },

    popFromList: function(userIdGroupIdList, userId, groupId) {
      var foundAt = BulkMatch.UserIdGroupIdList.lookupList(userIdGroupIdList, userId, groupId);

      if(foundAt != -1) {
        userIdGroupIdList.splice(foundAt, 1);
      }
    },

    lookupList: function(userIdGroupIdList, userId, groupId) {
      var foundAt = -1;

      jQuery.each(userIdGroupIdList, function(index, userIdGroupId) {
        if(userIdGroupId[0] == userId && userIdGroupId[1] == groupId) {
          foundAt = index;
          return false;
        }
      });
      return foundAt;
    },

    getUserIds: function(userIdGroupIdList) {
      var userIds = [];

      jQuery.each(userIdGroupIdList, function(index, userIdGroupId) {
        userId = userIdGroupId[0];
        if(userIds.indexOf(userId) == -1) {
          userIds.push(userId);
        }
      });
      return userIds;
    }
  }
}