var ProgramInvitationSearch = {
  filterFormSubmit: function() {
    jQuery('#program_invitations_filter').removeClass("open");
    jQuery('#search_filter_form').submit();
  },

  showLoading: function() {
    jQuery('#loading_results').show();
  },

  initFilterLoading: function() {
    jQuery(document).on('ajax:beforeSend', "#search_filter_form", function(){
      ProgramInvitationSearch.showLoading();
    });
  },

  clearFilter: function(resetSuffix) {
    jQuery('#reset_filter_' + resetSuffix).trigger('click');
  },

  initializeExpiredInvitationsCheckbox: function() {
    jQuery("#cjs_include_expired_invitations").click(function() {
      ProgramInvitationSearch.filterFormSubmit();
    });
  },

  initializeResetButtons: function() {
    jQuery("#reset_filter_sent_between").on('click', function() {
      jQuery('#cjs_sent_between').val('');
      ProgramInvitationSearch.filterFormSubmit();
    });

    jQuery("#reset_filter_expired_invitations").click(function() {
      jQuery("#cjs_include_expired_invitations").attr('checked', false);
      ProgramInvitationSearch.filterFormSubmit();
    });
  },

  initializeAll: function() {
    ProgramInvitationSearch.initFilterLoading();
    ProgramInvitationSearch.initializeExpiredInvitationsCheckbox();
    ProgramInvitationSearch.initializeResetButtons();
  }
}

var ProgramInvitationSelectAll = {
  inspectBulkActions: function(errorMsg, loadingExportMessage, progressBarAltText, exportCsvId) {
    var exportCsv = jQuery(exportCsvId);
    var otherBulkActions = jQuery(".cjs_program_invitations_bulk_actions div.btn-group li a").not(exportCsv);

    otherBulkActions.click(function(event){
      event.preventDefault();
      if(CommonSelectAll.validateSelection(errorMsg)){
        ProgramInvitationSelectAll.generateForm(jQuery(this));
      }
    });
    ProgramInvitationSelectAll.initializeExport(exportCsvId, errorMsg);
  },

  generateForm: function(jQueryObj) {
    var url = jQueryObj.data("url");
    var actionType = jQueryObj.data("type");
    var dataParameters = { bulk_action_confirmation: { selected_ids: CommonSelectAll.selectedIds.join(', '), type: actionType, title: jQueryObj.text()} };
    jQueryShowQtip(CommonSelectAll.parentContainer, 600, url, dataParameters, { method: "post", modal: true });
  },

  initializeExport: function(exportCsvId, errorMsg){
    jQuery(document).on('click', exportCsvId, function(event){
      event.preventDefault();
      if(CommonSelectAll.validateSelection(errorMsg)) {
        var hiddenForm = jQuery("#cjs_program_invitations_export_csv_form");
        hiddenForm.find("input.cjs_csv_invitation_ids").val(CommonSelectAll.selectedIds.join(', '));
        hiddenForm.submit();
      }
    });
  }
}