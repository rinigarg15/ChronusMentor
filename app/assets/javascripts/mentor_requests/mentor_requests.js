var MentorRequests = {

  primaryCheckBoxSelector: "#mentor_requests #cjs_primary_checkbox",
  subCheckBoxesSelector: "#mentor_requests .cjs_mentor_request_record",
  selectAll: "#mentor_requests #cjs_select_all_option u#cjs_select_all_handler",
  clearAll: "#mentor_requests #cjs_select_all_option u#cjs_clear_all_handler",
  selectedIds: [],
  senderIds: [],
  recipientIds: [],
  maxLength: 0,

  inspectActions: function(selectionErrorMsg){
    jQuery(document).ready(function(){
      MentorRequests.inspectPrimaryCheckBox();
      MentorRequests.inspectSubCheckBox();
      MentorRequests.inspectBulkActions(selectionErrorMsg);
      MentorRequests.initIndividualLinks();
      MentorRequests.inspectSelectClearAllSelection();
    });
  },

  initializeMaxLength: function(total_entries){
    MentorRequests.maxLength = total_entries;
  },

  maintainTriStateCheckbox: function(shouldHighlight){
    if(MentorRequests.selectedIds.length > 0){
      CommonSelectAll.indeterminateState(jQuery(MentorRequests.primaryCheckBoxSelector), true, MentorRequests);
      if(shouldHighlight){
        jQuery.each(MentorRequests.selectedIds, function(index, selectedId){
          var selectedCheckbox = jQuery("#ct_mentor_request_checkbox_" + selectedId);
          if(selectedCheckbox.length > 0){
            selectedCheckbox.attr("checked", true);
          }
        });
      }
    }
  },

  resetTriStateCheckbox: function(){
    CommonSelectAll.indeterminateState(jQuery(MentorRequests.primaryCheckBoxSelector), false, MentorRequests);
  },

  inspectPrimaryCheckBox: function(){
    var primaryCheckBox = jQuery(MentorRequests.primaryCheckBoxSelector);
    primaryCheckBox.change(function(){
      var isChecked = primaryCheckBox.is(":checked");
      var subCheckBoxes = jQuery(MentorRequests.subCheckBoxesSelector);
      subCheckBoxes.attr("checked", isChecked);
      CommonSelectAll.computeSelectedIds(subCheckBoxes, MentorRequests, {senderIds: 'sender-id', recipientIds: 'recipient-id'});
      MentorRequests.showHideSelectAll(isChecked);
      if(!isChecked){
        CommonSelectAll.resetSelectedIds(MentorRequests, ["senderIds", "recipientIds"]);
        MentorRequests.resetTriStateCheckbox();
      }
      else{
        CommonSelectAll.indeterminateState(jQuery(MentorRequests.primaryCheckBoxSelector), isChecked, MentorRequests);
      }
    });
  },

  inspectSubCheckBox: function(){
    var subCheckBoxes = jQuery(MentorRequests.subCheckBoxesSelector);
    subCheckBoxes.change(function(){
      CommonSelectAll.computeSelectedIds(subCheckBoxes, MentorRequests, {senderIds: 'sender-id', recipientIds: 'recipient-id'});
      MentorRequests.showHideSelectAll(false);
      if(MentorRequests.selectedIds.length == 0)
        MentorRequests.resetTriStateCheckbox();
      else
        MentorRequests.maintainTriStateCheckbox(false);
    });
  },

  inspectBulkActions: function(selectionErrorMsg){
    jQuery(".cjs_bulk_action_mentor_requests").unbind('click').on("click",function(event){
      event.preventDefault();
      if(MentorRequests.validateSelection(selectionErrorMsg)){
        var url = jQuery(this).data("url");
        var requestType = jQuery(this).data("request-type");
        var users = jQuery(this).attr('id') == 'cjs_send_message_to_senders' ? MentorRequests.senderIds : MentorRequests.recipientIds;
        jQueryShowQtip('#mentor_requests', 600, url, {bulk_action: {users: users, request_type: requestType, mentor_request_ids: MentorRequests.selectedIds }}, {method: "post", modal: true});
      }
    });

    jQuery(".cjs_mentor_request_export").unbind('click').on("click",function(event){
      event.preventDefault();
      if(MentorRequests.validateSelection(selectionErrorMsg)){
        jQuery('#mentor_request_ids').val(MentorRequests.selectedIds);
        jQuery('#mentor_requests_export_form').attr('action', jQuery(this).data("url")).submit();
      }
    });
  },

  initIndividualLinks: function(){
    jQuery(".cjs_individual_action_mentor_requests").unbind('click').on("click",function(event){
      event.preventDefault();
      var requestType = jQuery(this).data("request-type");
      var mentorRequest = jQuery(this).data("mentor-request");
      var url = jQuery(this).data("url");
      var user = jQuery(this).data("user");
      jQueryShowQtip('#mentor_requests', 600, url, {bulk_action: {users: [user],request_type: requestType, mentor_request_ids: [mentorRequest]}}, {method: "post", modal: true});
    });
  },

  validateSelection: function(selectionErrorMsg){
    if(MentorRequests.selectedIds.length == 0){
      ChronusValidator.ErrorManager.ShowResponseFlash("cjs_mentor_requests_flash", selectionErrorMsg);
      return false;
    }
    else{
      ChronusValidator.ErrorManager.ClearResponseFlash("cjs_mentor_requests_flash");
      return true;
    }
  },

  showHideSelectAll: function(showBox){
    if(jQuery("#cjs_select_all_option").length > 0){
      if(showBox){
        jQuery("#cjs_select_all_option").show();
      }
      else{
        MentorRequests.resetSelectClearAll();
        jQuery("#cjs_select_all_option").hide();
      }
    }
  },

  resetSelectClearAll: function(){
    if(jQuery("#cjs_select_all_option").is(":visible")){
      jQuery("div#cjs_clear_all_message").hide();
      jQuery("div#cjs_select_all_message").show();
    }
  },

  inspectSelectClearAllSelection: function(){
    jQuery(MentorRequests.selectAll).on('click', function(){
      var loaderImage = jQuery(this).parent().find("i.icon-all");
      var selectAllHandler = jQuery(this);
      jQuery.ajax({
        url : selectAllHandler.data("url"),
        beforeSend : function(){loaderImage.show();},
        success: function(responseText){
          CommonSelectAll.resetSelectedIds(MentorRequests, ["senderIds", "recipientIds"]);
          MentorRequests.selectedIds = responseText["mentor_request_ids"];
          MentorRequests.senderIds = responseText["sender_ids"];
          MentorRequests.recipientIds = responseText["receiver_ids"];
          loaderImage.hide();
          selectAllHandler.closest("div").hide();
          jQuery("div#cjs_clear_all_message").show();
          CommonSelectAll.indeterminateState(jQuery(MentorRequests.primaryCheckBoxSelector), false, MentorRequests);
        }
      });
    });

    jQuery(MentorRequests.clearAll).click(function(){
      jQuery(MentorRequests.primaryCheckBoxSelector).attr("checked", false);
      var subCheckBoxes = jQuery(MentorRequests.subCheckBoxesSelector);
      subCheckBoxes.attr("checked", false);
      MentorRequests.showHideSelectAll(false);
      CommonSelectAll.resetSelectedIds(MentorRequests, ["senderIds", "recipientIds"]);
    });
  },

  resetSelectedIds: function(){
    MentorRequests.selectedIds.length = 0;
    MentorRequests.senderIds.length = 0;
    MentorRequests.recipientIds.length = 0;
  },

  initializePreferredRequest: function(showSelectedUrl, canViewMentors){
    jQuery(document).ready(function(){
      MentorRequests.showSelectedUrl = showSelectedUrl;
      MentorRequests.canViewMentors = canViewMentors;
      MentorRequests.showSelected();
      MentorRequests.showPreferenceOnFocusIn();
      MentorRequests.hidePreferenceOnFocusOut();
      MentorRequests.changeLinkToTextBox();
      MentorRequests.hidePreferenceOnKeyPress();
      MentorRequests.initializeRemove();
    });
  },

  showPreferenceOnFocusIn: function(){
    jQuery(document).on('focusin', '.cjs_mentor_name', function(){
      if(jQuery(this).val().blank() && jQuery(".cjs_mentor_result").length > jQuery(".cjs_mentor_result.hide").length){
        jQuery("#add_new_mentor_link .cjs_preferred_list").show();
      }
    });
  },

  showSelected: function() {
    jQuery(document).on("click", ".cjs_mentor_result", function(){
      var buttonElement = jQuery(this);
      var userId = buttonElement.attr("id").replace("dropdown-","");
      var preferredUserContainer = jQuery("#preferred_list_" + userId);

      if(preferredUserContainer.length > 0){
        preferredUserContainer.fadeIn(100).fadeOut(100).fadeIn(100);
      }
      else{
        var userList = jQuery("#preferred_list_sortable");
        position = jQuery(".position-div").length + 1
        jQuery.ajax({
          url: MentorRequests.showSelectedUrl,
          type: "get",
          data: { user_id: userId, format: "js", position: position },
          success: function(data){
            userList.append(data);
            MentorRequests.updatePosition(0, 0);
            MentorRequests.toggleAddNewMentor();
          },
          complete: function(){
            jQuery(".cjs_mentor_name").val('');
          }
        });
      }
      buttonElement.addClass("hide");
      jQuery('.cjs_preferred_list').hide();
    });
  },

  hidePreferenceOnFocusOut: function(){
    jQuery(document).on('focusout', '.cjs_mentor_name', function(){
      setTimeout(function(){
        jQuery('.cjs_preferred_list').hide();
      }, 500);
    });
  },

  changeLinkToTextBox: function(){
    jQuery(document).on('click', '#cjs_add_another_favorite', function(){
      this.hide();
      jQuery('.cjs_name_text_box').show();
      jQuery('.cjs_preferred_list').hide();
    });
  },


  hidePreferenceOnKeyPress: function(){
    jQuery(document).on('keypress', '.cjs_mentor_name', function(){
      jQuery(this).siblings().find('.cjs_preferred_list').hide();
    });
  },

  initializeRemove: function(){
    jQuery(document).on('click', '.remove-mentor-request', function(){
      var draggableBox = jQuery(this).closest(".reorder_preferred_list").first();
      var userId = draggableBox.attr("id").replace("preferred_list_", "");

      hiddenPreferredBox = jQuery("#dropdown-" + userId);
      if(hiddenPreferredBox.length > 0){
        hiddenPreferredBox.show();
      }
      draggableBox.remove();
      MentorRequests.updatePosition(0,0);
      MentorRequests.toggleAddNewMentor();
    });
  },

  updatePosition: function(event, ui){
    var div_array = jQuery(".position-div");
    for(var i = 0; i < div_array.length; i++){
      div_array[i].innerHTML = MentorRequests.getPositionText(i + 1);
    }
  },

  getPositionText: function(number){
    switch(number){
      case 1:
        return positionText.one;
      case 2:
        return positionText.two;
      case 3:
        return positionText.three;
      case 4:
        return positionText.four;
      case 5:
        return positionText.five;
      case 6:
        return positionText.six;
      case 7:
        return positionText.seven;
      case 8:
        return positionText.eight;
      case 9:
        return positionText.nine;
      case 10:
        return positionText.ten;
      default:
        return number;
    }
  },

  validateRequiredFields: function(blankErrorMessage, minPreferenceMessage, minPreferences){
    var blankMessage = false;
    var insufficientPreference = false;
    var messageElement = jQuery("#mentor_request_message");

    if(minPreferences && jQuery(".mentor_preference").length < minPreferences ){
      insufficientPreference = true;
    }

    if(messageElement.val().blank()){
      blankMessage = true;
      ChronusValidator.ErrorManager.ShowFieldError(messageElement);
    }
    else{
      ChronusValidator.ErrorManager.HideFieldError(messageElement);
    }

    if(insufficientPreference){
      ChronusValidator.ErrorManager.ShowResponseFlash('mentor_request_response_flash', minPreferenceMessage);
    }
    else if(blankMessage){
      ChronusValidator.ErrorManager.ShowResponseFlash('mentor_request_response_flash', blankErrorMessage);
    }
    else{
      ChronusValidator.ErrorManager.ClearResponseFlash('mentor_request_response_flash');
    }
    return !(blankMessage || insufficientPreference);
  },

  trackDisablingDualRequestMode: function() {
    jQuery("#new_mentor_request_form").on("submit", function(){
      if(!jQuery(this).find("#mentor_request_allowed_request_type_change").is(':checked'))
        chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.MENTOR_REQUEST_ACTIVITY, chrGoogleAnalytics.action.GA_DISABLED_DUAL_REQUEST_MODE, "", "");
    });
  },

  toggleAddNewMentor: function(canViewMentors){
    canViewMentors = canViewMentors || MentorRequests.canViewMentors;
    var resultCount = jQuery("#add_new_mentor_link div.cjs_mentor_result:not(.hide)").length;

    if(resultCount == 0 && !canViewMentors){
      jQuery('#add_new_mentor_link').hide();
    }
    else{
      jQuery('#add_new_mentor_link').show();
    }
  },

  quickAssignPreventDefault: function(existingConnections) {
    if(existingConnections) {
      event.preventDefault();
    }
  },

  toggleRecommendMeetingContainer: function(formElement, showRecommendMeetingContainer) {
    formElement.find(".cjs_recommend_meeting_container").toggle(showRecommendMeetingContainer);
  },

  toggleActionSet: function(formElement, showActionSet) {
    formElement.find(".cjs_action_set_response_text_container").toggle(showActionSet);
  },

  handleRejectionTypeSelection: function(formElement, notAMatchValue) {
    formElement.find(".cjs_mentor_request_rejection_type").on("click", function() {
      var isNotAMatch = (jQuery(this).val() == notAMatchValue);
      if(isNotAMatch)
        formElement.find(".cjs_reject_meeting_recommendation").addClass("btn-outline");
      MentorRequests.toggleRecommendMeetingContainer(formElement, !isNotAMatch);
      MentorRequests.toggleActionSet(formElement, isNotAMatch);
    });
  },

  handleMeetingRecommendationRejection: function(formElement) {
    formElement.find(".cjs_reject_meeting_recommendation").on("click", function() {
      jQuery(this).removeClass("btn-outline");
      MentorRequests.toggleActionSet(formElement, true);
    });
  },

  handleMeetingRecommendationAcceptance: function(formElement) {
    formElement.find(".cjs_accept_meeting_recommendation").on("click", function() {
      formElement.find(".cjs_reject_meeting_recommendation").addClass("btn-outline");
      MentorRequests.toggleActionSet(formElement, false);
    });
  },

  initializeDualRequestMode: function(formId, notAMatchValue) {
    var formElement = jQuery("#" + formId);
    MentorRequests.handleRejectionTypeSelection(formElement, notAMatchValue);
    MentorRequests.handleMeetingRecommendationRejection(formElement);
    MentorRequests.handleMeetingRecommendationAcceptance(formElement);
  },

  acceptMeetingRecommendation: function(url, modalId, buttonText, disableText){
    MeetingRequest.disableWithForLink(".cjs_accept_meeting_recommendation", disableText);
    setTimeout(function(){
      jQuery("#" + modalId).modal('hide');
      MeetingRequest.enableWithForLink(".cjs_accept_meeting_recommendation", buttonText);
      Meetings.renderMiniPopup(url);
    }, 500);
  },

  renderPopup: function(url){
    jQueryShowQtip('#inner_content', 675, url,'',{modal: true});
  },

  showRequestConnectionPopup: function(){
    jQuery(document).on("click", ".cjs_request_mentoring_button", function(){
      var url = jQuery(this).data("url");
      MentorRequests.renderPopup(url);
    });
  },

  showPendingRequestsPane: function(){
    jQuery(document).on('click', '.cjs_pending_requests', function(){
      jQuery("#cjs-chevron-header").click();
    });
  },

  showConnectPopup: function(requestType){
    jQuery(requestType).click(); 
  },

  hideAutoComplete: function() {
    jQuery(".cjs_mentor_name").val("");
    jQuery(".cjs_name_text_box").hide();
    jQuery("#cjs_add_another_favorite").show();
  },

  getReportFilterData: function(){
    var data = commonReportFilters.getFiltersData();
    data["list"] = jQuery('#filter_tab').val();
    data["sort_field"] = jQuery('#filter_sort_field').val();
    data["sort_order"] = jQuery('#filter_sort_order').val();
    return data;
  },

  assignMentor: function() {
    jQuery('.cjs_assign_mentor_request').unbind("click").on('click', function(event){
      event.preventDefault();
      var element = jQuery(this);
      element.attr("disabled", "disabled");
      if(element.hasClass("cjs_assign_mentor_request_submit")) {
        var postUrl =  element.closest("form").prop("action");
        var postData = element.closest("form").serialize() + '&mentoring_model_id=' + jQuery(".cjs_assign_mentoring_model").val();
      }
      else {
        var postUrl = element.data('url');
        var postData = {mentoring_model_id: jQuery(".cjs_assign_mentoring_model").val()};
      }
      jQuery.ajax({
        url: postUrl,
        data: postData,
        type: 'POST',
        success: function(response){
          element.removeAttr("disabled");
        }
      });
    });
  }
}