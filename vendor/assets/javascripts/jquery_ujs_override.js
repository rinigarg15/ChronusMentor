// This file contains code for supporting usage of custom popups inplace of browser confirmation and alert dialog

// Override for browser confirmation dialog - BEGIN
//
// Accomplished by overriding rails.allowAction method of jquery_ujs with custom implementation
// It works as below
//   Create a custom confirm dialog and bind a click event handler for the custom dialog .
//   Cancel the click event by returning false. 
//   The click event handler of the custom dialog does the below.
//      1. Dummys the allowAction so that the recursion is avoided.
//      2. Fires the click event on the original element.
//      3. Restores the dummied custom allow action function.
//      4. Fires the confirm:complete event on the original element like original implementation of allowAction.
//
// The below links were used to get the idea
// http://lesseverything.com/blog/archives/2012/07/18/customizing-confirmation-dialog-in-rails/
// http://stackoverflow.com/questions/4421072/jquery-ui-dialog-instead-of-alert-for-rails-3-data-confirm-attribute
//
jQuery.rails.allowAction = function(element) {
  var message = element.data('confirm');

  if (!message) { return true; }

  if (jQuery.rails.fire(element, 'confirm')) {
    jQuery.rails.showConfirmDialog(message, function() {
      var oldAllowAction = jQuery.rails.allowAction;
      jQuery.rails.allowAction = function() { return true; };
      jQuery.rails.fire(element, 'click');
      jQuery.rails.allowAction = oldAllowAction;
      return jQuery.rails.fire(element, 'confirm:complete');
    });
  }
  return false;
}

jQuery.rails.showConfirmDialog = function(message, confirmCallback) {
  jQuery.rails.displayDialog(message, confirmCallback);
}

// Sweetalert customization options are available in: http://t4t5.github.io/sweetalert/
jQuery.rails.displayDialog = function(message, confirmCallback) {
  var sweetAlertOptions = {
    title: "<span class=\"sr-only\">" + jsCommonTranslations.popup.confirmation + "<\/span>",
    text: message,
    showCancelButton: true,
    cancelButtonText: jsCommonTranslations.popup.cancel
  };
  showSweetAlert(sweetAlertOptions, confirmCallback);
}
// Override for browser confirmation dialog - END

// Override for browser alert dialog
window.alert = function(message) {
  var sweetAlertOptions = {
    title: "<span class=\"sr-only\">" + jsCommonTranslations.popup.alert + "<\/span>",
    text: message
  };
  showSweetAlert(sweetAlertOptions);
}