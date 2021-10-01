var ProjectRequests = {
  primaryCheckBoxSelector: "#project_requests #cjs_primary_checkbox",
  subCheckBoxesSelector: "#project_requests .cjs_project_request_record",
  selectAll: "#project_requests #cjs_select_all_option u#cjs_select_all_handler",
  clearAll: "#project_requests #cjs_select_all_option u#cjs_clear_all_handler",
  selectedIds: [],
  maxLength: 0,

  inspectActions: function(selectionErrorMsg){
    jQuery(document).ready(function(){
      ProjectRequests.inspectPrimaryCheckBox();
      ProjectRequests.inspectSubCheckBox();
      ProjectRequests.inspectBulkActions(selectionErrorMsg);
      ProjectRequests.initIndividualLinks();
      ProjectRequests.inspectSelectClearAllSelection();
      ProjectRequests.initNewRequest(); //TODO:: move this to wherever join project link will be exposed
    });
  },

  initializeMaxLength: function(total_entries){
    ProjectRequests.maxLength = total_entries;
  },

  maintainTriStateCheckbox: function(shouldHighlight){
    if(ProjectRequests.selectedIds.length > 0){
      CommonSelectAll.indeterminateState(jQuery(ProjectRequests.primaryCheckBoxSelector), true, ProjectRequests);
      if(shouldHighlight){
        jQuery.each(ProjectRequests.selectedIds, function(index, selectedId){
          var selectedCheckbox = jQuery("#ct_project_request_checkbox_" + selectedId);
          if(selectedCheckbox.length > 0){
            selectedCheckbox.prop("checked", true);
          }
        });
      }
    }
  },

  resetTriStateCheckbox: function(){
    CommonSelectAll.indeterminateState(jQuery(ProjectRequests.primaryCheckBoxSelector), false, ProjectRequests);
  },

  inspectPrimaryCheckBox: function(){
    var primaryCheckBox = jQuery(ProjectRequests.primaryCheckBoxSelector);
    primaryCheckBox.change(function(){
      var isChecked = primaryCheckBox.is(":checked");
      var subCheckBoxes = jQuery(ProjectRequests.subCheckBoxesSelector);
      subCheckBoxes.prop("checked", isChecked);
      CommonSelectAll.computeSelectedIds(subCheckBoxes, ProjectRequests);
      ProjectRequests.showHideSelectAll(isChecked);
      if(!isChecked){
        CommonSelectAll.resetSelectedIds(ProjectRequests);
        ProjectRequests.resetTriStateCheckbox();
      }
      else{
        CommonSelectAll.indeterminateState(jQuery(ProjectRequests.primaryCheckBoxSelector), isChecked, ProjectRequests);
      }
    });
  },

  inspectSubCheckBox: function(){
    var subCheckBoxes = jQuery(ProjectRequests.subCheckBoxesSelector);
    subCheckBoxes.change(function(){
      CommonSelectAll.computeSelectedIds(subCheckBoxes, ProjectRequests);
      ProjectRequests.showHideSelectAll(false);
      if(ProjectRequests.selectedIds.length == 0)
        ProjectRequests.resetTriStateCheckbox();
      else
        ProjectRequests.maintainTriStateCheckbox(false);
    });
  },

  inspectBulkActions: function(selectionErrorMsg){
    jQuery(".cjs_bulk_action_project_requests").on("click", function(event){
      event.preventDefault();
      if(ProjectRequests.validateSelection(selectionErrorMsg)){
        var url = jQuery(this).data("url");
        var requestType = jQuery(this).data("request-type");
        jQueryShowQtip(null, null, url, {request_type: requestType, project_request_ids: ProjectRequests.selectedIds}, { method: "post" });
      }
    });
  },

  initIndividualLinks: function(){
    jQuery(".cjs_action_project_requests").on("click", function(event){
      event.preventDefault();
      var requestType = jQuery(this).data("request-type");
      var requestId = jQuery(this).data("id");
      var url = jQuery(this).data("url");
      jQueryShowQtip(null, null, url, { request_type: requestType, project_request_ids: [requestId] }, { method: "post" });
    });
  },

  validateSelection: function(selectionErrorMsg){
    if(ProjectRequests.selectedIds.length == 0){
      ChronusValidator.ErrorManager.ShowResponseFlash("cjs_project_requests_flash", selectionErrorMsg);
      return false;
    }
    else{
      ChronusValidator.ErrorManager.ClearResponseFlash("cjs_project_requests_flash");
      return true;
    }
  },

  showHideSelectAll: function(showBox){
    if(jQuery("#cjs_select_all_option").length > 0){
      if(showBox){
        jQuery("#cjs_select_all_option").show();
      }
      else{
        ProjectRequests.resetSelectClearAll();
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
    jQuery(ProjectRequests.selectAll).on('click', function(){
      var loaderImage = jQuery(this).parent().find("i.cjs_select_all_loader");
      var selectAllHandler = jQuery(this);
      jQuery.ajax({
        url : selectAllHandler.data("url"),
        beforeSend : function(){loaderImage.removeClass("hide");},
        success: function(responseText){
          CommonSelectAll.resetSelectedIds(ProjectRequests);
          ProjectRequests.selectedIds = responseText["project_request_ids"];
          loaderImage.addClass("hide");
          selectAllHandler.closest("div").hide();
          jQuery("div#cjs_clear_all_message").show();
          CommonSelectAll.indeterminateState(jQuery(ProjectRequests.primaryCheckBoxSelector), false, ProjectRequests);
        }
      });
    });

    jQuery(ProjectRequests.clearAll).on('click', function(){
      jQuery(ProjectRequests.primaryCheckBoxSelector).prop("checked", false);
      var subCheckBoxes = jQuery(ProjectRequests.subCheckBoxesSelector);
      subCheckBoxes.prop("checked", false);
      ProjectRequests.showHideSelectAll(false);
      CommonSelectAll.resetSelectedIds(ProjectRequests);
    });
  },

  showLoading: function(){
    jQuery('#loading_results').show();
  },

  applyFilters: function(){
    ProjectRequests.showLoading();
    jQuery('#filter_form').submit();
    return false;
  },

  resetAndApplyFilters: function(){
    jQuery(document).ready(function(){
      ProjectRequests.resetAndApply();
    });
  },

  resetAndApply: function(){
    jQuery("#reset_filter_status").on('click', function(){
      ProjectRequests.resetStatusFilter();
      ProjectRequests.applyFilters();
    });

    jQuery("#reset_filter_view").on('click', function(){
      ProjectRequests.resetViewFilter();
      ProjectRequests.applyFilters();
    });

    jQuery("#reset_filter_requestor").on('click', function(){
      jQuery("#filters_requestor").val("");
      ProjectRequests.applyFilters();
    });

    jQuery("#reset_filter_project").on('click', function(){
      jQuery("#filters_project").val("");
      ProjectRequests.applyFilters();
    });

    jQuery("#reset_filter_sent_between").on('click', function(){
      jQuery("#filters_sent_between").val("");
      ProjectRequests.applyFilters();
    });

    jQuery(".submit_project_request_filters").on('change click', function(){
      ProjectRequests.applyFilters();
    });
  },

  clearFilter: function(resetId){
    jQuery("#filter_pane").find('#reset_filter_' + resetId).trigger('click');
  },

  resetStatusFilter: function(){
    jQuery("#filter_pane").find('#filters_status_pending').prop("checked", true);
  },

  resetViewFilter: function(){
    jQuery("#filter_pane").find('#filters_view_0').prop("checked", true);
  },

  validateRequiredFields: function(errorMessage){
    var valid = true;
    var messageElement = jQuery("#project_request_message");

    if(messageElement.val().blank()){
      valid = false;
      ChronusValidator.ErrorManager.ShowFieldError(messageElement);
    }
    else{
      ChronusValidator.ErrorManager.HideFieldError(messageElement);
    }

    if(valid){
      ChronusValidator.ErrorManager.ClearResponseFlash("new_project_request_popup_flash_container");
    }
    else{
      ChronusValidator.ErrorManager.ShowResponseFlash("new_project_request_popup_flash_container", errorMessage);
    }
    return valid;
  },

  initNewRequestForm: function(selectionErrorMsg){
    jQuery("#new_project_request_form .cjs_project_request_sender_role_id:not([disabled]):first").prop("checked", true);
    jQuery("#new_project_request_submit").on("click", function(event){
      event.preventDefault();
      if(ProjectRequests.validateRequiredFields(selectionErrorMsg)){
        jQuery("#new_project_request_form").submit()
      }
    });
  },

  initNewRequest: function(){
    jQuery(".cjs_create_project_request").on("click", function(event){
      event.preventDefault();
      var url = jQuery(this).attr("href");
      jQueryShowQtip("#inner_content", 600, url, {}, {modal: true});
    });
  },

  loadJoinPopup: function(){
    jQuery(document).ready(function(){
      var joinRequest = jQueryReadUrlParam("join_request");
      var url = jQuery(".cjs_create_project_request").attr("href");
      if(joinRequest && !joinRequest.blank() && !url.blank()){
        jQueryShowQtip("#inner_content", 600, url, {}, {modal: true});
      }
    });
  },

  trackRequestAcceptReject: function(isAccepted, eventLabel, eventLabelID){
    action = chrGoogleAnalytics.action.GA_PROJECT_REQUEST_DECLINED;
    if(isAccepted){
      action = chrGoogleAnalytics.action.GA_PROJECT_REQUEST_ACCEPTED;
    }
    chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.CIRCLES, action, eventLabel, eventLabelID);
  },

  gaTrackProjectPublishWithdraw: function(isPublish, fromRequestPopup, fromProfile){
    action = chrGoogleAnalytics.action.GA_WITHDRAW_CIRCLE;
    if(isPublish){
      action = chrGoogleAnalytics.action.GA_PUBLISH_CIRCLE;
    }

    if(fromRequestPopup){
      chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.CIRCLES, action, chrGoogleAnalytics.eventLabel.GA_REQUEST_ACCEPTANCE_POPUP, chrGoogleAnalytics.eventLabelId.GA_REQUEST_ACCEPTANCE_POPUP_LABEL_ID);
    }
    else if(fromProfile){
      chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.CIRCLES, action, chrGoogleAnalytics.eventLabel.GA_CIRCLE_PROFILE, chrGoogleAnalytics.eventLabelId.GA_CIRCLE_PROFILE_LABEL_ID);
    }
    else{
      chrGoogleAnalytics.addEvent(chrGoogleAnalytics.category.CIRCLES, action, chrGoogleAnalytics.eventLabel.GA_CIRCLES_LISTING, chrGoogleAnalytics.eventLabelId.GA_CIRCLES_LISTING_LABEL_ID);
    }
  },

  getProjectRequestFilterData: function(){
    var data = commonReportFilters.getFiltersData();
    data = jQuery.extend(data, JSON.parse(jQuery('.cjs-filter-params-to-store').val()));
    data["filters[status]"] = jQuery('#filter_tab').val();
    return data;
  },

  setFiltersCount: function(filtersCount){
    if(filtersCount == 0){
      jQuery('.cjs-report-filter-count').hide();
    }
    else{
      jQuery('.cjs-report-filter-count').show();
      jQuery('.cjs-report-filter-count').text(filtersCount);
    }
  },

  resetFilters: function(){
    jQuery('#filters_project').val('');
    jQuery('#filters_requestor').val('');
    eval(commonReportFilters.preFilterFunction);
    commonReportFilters.submitData();
  }
}