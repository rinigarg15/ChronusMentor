var MeetingRequests = {

  primaryCheckBoxSelector: "#meeting_requests #cjs_primary_checkbox",
  subCheckBoxesSelector: "#meeting_requests .cjs_meeting_request_record",
  selectAll: "#meeting_requests #cjs_select_all_option u#cjs_select_all_handler",
  clearAll: "#meeting_requests #cjs_select_all_option u#cjs_clear_all_handler",
  selectedIds: [],
  senderIds: [],
  recipientIds: [],
  maxLength: 0,

  inspectActions: function(selectionErrorMsg){
    jQuery(document).ready(function(){
      MeetingRequests.inspectPrimaryCheckBox();
      MeetingRequests.inspectSubCheckBox();
      MeetingRequests.inspectBulkActions(selectionErrorMsg);
      MeetingRequests.initIndividualLinks();
      MeetingRequests.inspectSelectClearAllSelection();
    });
  },

  inspectPrimaryCheckBox: function(){
    var primaryCheckBox = jQuery(MeetingRequests.primaryCheckBoxSelector);
    primaryCheckBox.change(function(){
      var isChecked = primaryCheckBox.is(":checked");
      var subCheckBoxes = jQuery(MeetingRequests.subCheckBoxesSelector);
      subCheckBoxes.attr("checked", isChecked);
      CommonSelectAll.computeSelectedIds(subCheckBoxes, MeetingRequests, {senderIds: 'sender-id', recipientIds: 'recipient-id'});
      MeetingRequests.showHideSelectAll(isChecked);
      if(!isChecked){
        CommonSelectAll.resetSelectedIds(MeetingRequests, ["senderIds", "recipientIds"]);
        MeetingRequests.resetTriStateCheckbox();
      }
      else{
        CommonSelectAll.indeterminateState(jQuery(MeetingRequests.primaryCheckBoxSelector), isChecked, MeetingRequests);
      }
    });
  },

  inspectSubCheckBox: function(){
    var subCheckBoxes = jQuery(MeetingRequests.subCheckBoxesSelector);
    subCheckBoxes.change(function(){
      CommonSelectAll.computeSelectedIds(subCheckBoxes, MeetingRequests, {senderIds: 'sender-id', recipientIds: 'recipient-id'});
      MeetingRequests.showHideSelectAll(false);
      if(MeetingRequests.selectedIds.length == 0)
        MeetingRequests.resetTriStateCheckbox();
      else
        MeetingRequests.maintainTriStateCheckbox(false);
    });
  },

  inspectBulkActions: function(selectionErrorMsg){
    jQuery(".cjs_bulk_action_meeting_requests").unbind("click").on("click",function(event){
      event.preventDefault();
      if(MeetingRequests.validateSelection(selectionErrorMsg)){
        var url = jQuery(this).data("url");
        var requestType = jQuery(this).data("request-type");
        var is_manage_view = jQuery(this).data("is-manage-view");
        var users = jQuery(this).attr('id') == 'cjs_send_message_to_senders' ? MeetingRequests.senderIds : MeetingRequests.recipientIds;
        var data = {bulk_action: {users: users, request_type: requestType, is_manage_view: is_manage_view, meeting_request_ids: MeetingRequests.selectedIds }};
        jQueryShowQtip('#meeting_requests', 600, url, data, {method: "post", modal: true});
      }
    });
  },

  initializeMaxLength: function(total_entries){
    MeetingRequests.maxLength = total_entries;
  }, 

  maintainTriStateCheckbox: function(shouldHighlight){
    if(MeetingRequests.selectedIds.length > 0){
      CommonSelectAll.indeterminateState(jQuery(MeetingRequests.primaryCheckBoxSelector), true, MeetingRequests);
      if(shouldHighlight){
        jQuery.each(MeetingRequests.selectedIds, function(index, selectedId){
          var selectedCheckbox = jQuery("#ct_meeting_request_checkbox_" + selectedId);
          if(selectedCheckbox.length > 0){
            selectedCheckbox.attr("checked", true);
          }
        });
      }
    }
  },

  resetTriStateCheckbox: function(){
    CommonSelectAll.indeterminateState(jQuery(MeetingRequests.primaryCheckBoxSelector), false, MeetingRequests);
  },

  initIndividualLinks: function(){
    jQuery(".cjs_individual_action_meeting_requests").unbind("click").on("click",function(event){
      event.preventDefault();
      var requestType = jQuery(this).data("request-type");
      var meetingRequest = jQuery(this).data("meeting-request");
      var url = jQuery(this).data("url");
      var user = jQuery(this).data("user");
      var is_manage_view = jQuery(this).data("is-manage-view");
      jQueryShowQtip('#meeting_requests', 600, url, {bulk_action: {users: [user],request_type: requestType, is_manage_view: is_manage_view, meeting_request_ids: [meetingRequest]}}, {method: "post", modal: true});
    });
  },

  validateSelection: function(selectionErrorMsg){
    if(MeetingRequests.selectedIds.length == 0){
      ChronusValidator.ErrorManager.ShowResponseFlash("cjs_meeting_requests_flash", selectionErrorMsg);
      return false;
    }
    else{
      ChronusValidator.ErrorManager.ClearResponseFlash("cjs_meeting_requests_flash");
      return true;
    }
  },

  showHideSelectAll: function(showBox){
    if(jQuery("#cjs_select_all_option").length > 0){
      if(showBox){
        jQuery("#cjs_select_all_option").show();
      }
      else{
        MeetingRequests.resetSelectClearAll();
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
    jQuery(MeetingRequests.selectAll).on('click', function(){
      var loaderImage = jQuery(this).parent().find("i.icon-all");
      var selectAllHandler = jQuery(this);
      jQuery.ajax({
        url : selectAllHandler.data("url"),
        beforeSend : function(){loaderImage.removeClass("hide");},
        success: function(responseText){
          CommonSelectAll.resetSelectedIds(MeetingRequests, ["senderIds", "recipientIds"]);
          MeetingRequests.selectedIds = responseText["meeting_request_ids"];
          MeetingRequests.senderIds = responseText["sender_ids"];
          MeetingRequests.recipientIds = responseText["receiver_ids"];
          loaderImage.addClass("hide");
          selectAllHandler.closest("div").hide();
          jQuery("div#cjs_clear_all_message").show();
          CommonSelectAll.indeterminateState(jQuery(MeetingRequests.primaryCheckBoxSelector), false, MeetingRequests);
        }
      });
    });

    jQuery(MeetingRequests.clearAll).click(function(){
      jQuery(MeetingRequests.primaryCheckBoxSelector).attr("checked", false);
      var subCheckBoxes = jQuery(MeetingRequests.subCheckBoxesSelector);
      subCheckBoxes.attr("checked", false);
      MeetingRequests.showHideSelectAll(false);
      CommonSelectAll.resetSelectedIds(MeetingRequests, ["senderIds", "recipientIds"]);
    });    
  },

  getMeetingRequestReportFilterData: function(){
    var data = {list: jQuery('#filter_tab').val(), filters: commonReportFilters.getFiltersData(), sort_field: jQuery('.cjs-sort-field').val(), sort_order: jQuery('.cjs-sort-order').val()};
    return data;
  },

  changeSortOptions: function(value){
    var tmp = value.split(",");
    jQuery('.cjs-sort-field').val(tmp[0]);
    jQuery('.cjs-sort-order').val(tmp[1]);
    commonReportFilters.submitData();
  }
}