var MentorOffers = {

  primaryCheckBoxSelector: "#mentor_offers #cjs_primary_checkbox",
  subCheckBoxesSelector: "#mentor_offers .cjs_mentor_offer_record",
  selectAll: "#mentor_offers #cjs_select_all_option u#cjs_select_all_handler",
  clearAll: "#mentor_offers #cjs_select_all_option u#cjs_clear_all_handler",
  selectedIds: [],
  senderIds: [],
  recipientIds: [],
  maxLength: 0,

  // Add all initializations here.
  inspectActions: function(selectionErrorMsg){
    jQuery(document).ready(function(){
      MentorOffers.inspectPrimaryCheckBox();
      MentorOffers.inspectSubCheckBox();
      MentorOffers.inspectBulkActions(selectionErrorMsg);
      MentorOffers.initIndividualLinks();
      MentorOffers.inspectSelectClearAllSelection();
    });
  },

  clearFilter: function(reset_id) {
    jQuery("#filter_pane").find('#reset_filter_' + reset_id).trigger('click');
  },

  showLoading: function() {
    jQuery('#loading_results').show();
  },

  hideLoading: function() {
    jQuery('#loading_results').hide();
  },

  applyFilters: function() {
    MentorOffers.showLoading();
    MentorOffers.resetMentorOfferSelectedIds();
    jQuery('#search_filter_form').submit();
    return false;
  },

  initIndividualLinks: function(){
    jQuery(document).on("click", '.cjs_individual_action_mentor_offers', function(event){
      event.preventDefault();
      var offerStatus = jQuery(this).data("offer-status");
      var mentorOffer = jQuery(this).data("mentor-offer");
      var is_manage_view = jQuery(this).data("is-manage-view");
      var url = jQuery(this).data("url");
      var user = jQuery(this).data("user");
      jQueryShowQtip('#mentor_offers', 600, url, {bulk_action: {users: [user], offer_status: offerStatus, is_manage_view: is_manage_view, mentor_offer_ids: [mentorOffer]}}, {method: "post", modal: true});
    });
  },

  initializeMaxLength: function(total_entries){
    MentorOffers.maxLength = total_entries;
  },

  resetMentorOfferSelectedIds: function(){
    MentorOffers.selectedIds.length = 0;
    MentorOffers.senderIds.length = 0;
    MentorOffers.recipientIds.length = 0;
  },

  maintainTriStateCheckbox: function(shouldHighlight){
    if(MentorOffers.selectedIds.length > 0){
      CommonSelectAll.indeterminateState(jQuery(MentorOffers.primaryCheckBoxSelector), true, MentorOffers);
      if(shouldHighlight){
        jQuery.each(MentorOffers.selectedIds, function(index, selectedId){
          var selectedCheckbox = jQuery("#ct_mentor_offer_checkbox_" + selectedId);
          if(selectedCheckbox.length > 0){
            selectedCheckbox.attr("checked", true);
          }
        });
      }
    }
  },

  resetTriStateCheckbox: function(){
    CommonSelectAll.indeterminateState(jQuery(MentorOffers.primaryCheckBoxSelector), false, MentorOffers);
  },

  inspectPrimaryCheckBox: function(){
    jQuery(document).on("change", MentorOffers.primaryCheckBoxSelector, function(){
      var primaryCheckBox = jQuery(MentorOffers.primaryCheckBoxSelector);
      var isChecked = primaryCheckBox.is(":checked");
      var subCheckBoxes = jQuery(MentorOffers.subCheckBoxesSelector);
      subCheckBoxes.attr("checked", isChecked);
      CommonSelectAll.computeSelectedIds(subCheckBoxes, MentorOffers, {senderIds: 'recipient-id', recipientIds: 'sender-id'});
      MentorOffers.showHideSelectAll(isChecked);
      if(!isChecked){
        CommonSelectAll.resetSelectedIds(MentorOffers, ["senderIds", "recipientIds"]);
        MentorOffers.resetTriStateCheckbox();
      }
      else{
        CommonSelectAll.indeterminateState(jQuery(MentorOffers.primaryCheckBoxSelector), isChecked, MentorOffers);
      }
    });
  },

  inspectSubCheckBox: function(){
    jQuery(document).on("change", MentorOffers.subCheckBoxesSelector, function(){
      var subCheckBoxes = jQuery(MentorOffers.subCheckBoxesSelector);
      CommonSelectAll.computeSelectedIds(subCheckBoxes, MentorOffers, {senderIds: 'recipient-id', recipientIds: 'sender-id'});
      MentorOffers.showHideSelectAll(false);
      if(MentorOffers.selectedIds.length == 0)
        MentorOffers.resetTriStateCheckbox();
      else
        MentorOffers.maintainTriStateCheckbox(false);
    });
  },

  inspectBulkActions: function(selectionErrorMsg){
    jQuery(document).on("click", '.cjs_bulk_action_mentor_offers', function(event){
      event.preventDefault();
      if(MentorOffers.validateSelection(selectionErrorMsg)){
        var url = jQuery(this).data("url");
        var offerStatus = jQuery(this).data("offer-status");
        var is_manage_view = jQuery(this).data("is-manage-view");
        var users = jQuery(this).attr('id') == 'cjs_send_message_to_senders' ? MentorOffers.senderIds : MentorOffers.recipientIds;
        jQueryShowQtip('#mentor_offers', 600, url, {bulk_action: {users: users, offer_status: offerStatus, is_manage_view: is_manage_view, mentor_offer_ids: MentorOffers.selectedIds }}, {method: "post", modal: true});
      }
    });

    jQuery(document).on("click", '.cjs_mentor_offer_export', function(event){
      event.preventDefault();
      if(MentorOffers.validateSelection(selectionErrorMsg)){
        jQuery('#mentor_offer_ids').val(MentorOffers.selectedIds);
        jQuery('#mentor_offers_export_form').attr('action', jQuery(this).attr('href')).submit();
      }
    });
  },

  validateSelection: function(selectionErrorMsg){
    if(MentorOffers.selectedIds.length == 0){
      ChronusValidator.ErrorManager.ShowResponseFlash("cjs_mentor_offers_flash", selectionErrorMsg);
      return false;
    }
    else{
      ChronusValidator.ErrorManager.ClearResponseFlash("cjs_mentor_offers_flash");
      return true;
    }
  },

  showHideSelectAll: function(showBox){
    if(jQuery("#cjs_select_all_option").length > 0){
      if(showBox){
        jQuery("#cjs_select_all_option").show();
      }
      else{
        MentorOffers.resetSelectClearAll();
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
    jQuery(document).on('click', MentorOffers.selectAll, function(){
      var selectAllHandler = jQuery(this);
      jQuery.ajax({
        url : selectAllHandler.data("url"),
        success: function(responseText){
          CommonSelectAll.resetSelectedIds(MentorOffers, ["senderIds", "recipientIds"]);
          MentorOffers.selectedIds = responseText["mentor_offer_ids"];
          MentorOffers.senderIds = responseText["sender_ids"];
          MentorOffers.recipientIds = responseText["receiver_ids"];
          selectAllHandler.closest("div").hide();
          jQuery("div#cjs_clear_all_message").show();
          CommonSelectAll.indeterminateState(jQuery(MentorOffers.primaryCheckBoxSelector), false, MentorOffers);
        }
      });
    });

    jQuery(MentorOffers.clearAll).on('click', function(){
      jQuery(MentorOffers.primaryCheckBoxSelector).attr("checked", false);
      var subCheckBoxes = jQuery(MentorOffers.subCheckBoxesSelector);
      subCheckBoxes.attr("checked", false);
      MentorOffers.showHideSelectAll(false);
      CommonSelectAll.resetSelectedIds(MentorOffers, ["senderIds", "recipientIds"]);
    });
  },

  getMentorOfferReportFilterData: function(){
    var data = {status: jQuery('#filter_tab').val(), filters: commonReportFilters.getFiltersData(), sort_field: jQuery('.cjs-sort-field').val(), sort_order: jQuery('.cjs-sort-order').val()};
    return data;
  }
}