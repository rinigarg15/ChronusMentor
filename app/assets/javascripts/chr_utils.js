/*******************************************************************************
 * Common JavaScript utilities
 *
 * Copyright (c) 2008 Chronus Software India Pvt Ltd
 *
 * @author Vikram
 ******************************************************************************/

/**
 * Commonly used Effects across the application
 */
var ChronusEffect = {};

ChronusEffect.Defaults = {};

/*
 * Default Blind effect duration
 */
ChronusEffect.Defaults.BLIND_DURATION = 0.3;

/*
 * Default Effect.BlindDown effect for BLIND_DURATION seconds
 */
ChronusEffect.OpenContent = function(elementId){
    var duration = (arguments[1] ? arguments[1] : this.Defaults.BLIND_DURATION) * 1000
    jQuery('#' + elementId).slideDown(duration);
}

/*
 * Default Effect.BlindUp effect with BLIND_DURATION seconds duration
 */
ChronusEffect.CloseContent = function(elementId){
    var duration = (arguments[1] ? arguments[1] : this.Defaults.BLIND_DURATION) * 1000
    jQuery('#' + elementId).slideUp(duration);
}

/**
 * Toggles the display of the content with section as the header prefix.
 *
 * @params section the section prefix to expand or collapse. The header and
 * 				   content ids must be <section>_header and <section>_content
 *
 * @params otherSections If the second argument is passed, the sections given
 * 						in that	Array will also be updated in response to this
 * 						action

 * @params noDelay	boolean telling whether or not to use delay for the effect
 */
ChronusEffect.ExpandSection = function(section) {
    var otherSections = arguments[1] || [];
    var noDelay = arguments[2] || false;
	var dontCollapseIfExpanded = arguments[3] || false;
    var contentId = section + 'content';
    var headerId = section + 'header';
    var effectDuration = noDelay ? 0 : this.Defaults.BLIND_DURATION;
    var headerElement = jQuery('#' + headerId)
    // The section is currently open. Collapse it.
    if (!dontCollapseIfExpanded && jQuery('#' + contentId).css('display') != "none") {
        ChronusEffect.CloseContent(contentId, effectDuration);
        headerElement.removeClass("expanded")
        headerElement.addClass("collapsed")
        return;
    }

    ChronusEffect.OpenContent(contentId, effectDuration);
    headerElement.removeClass("collapsed")
    headerElement.addClass("expanded")

    for (var i = 0; i < otherSections.length; i++) {
        var sec = otherSections[i];

        // Collapse other sections if present.
        if (sec != section) {
            jQuery('#' + sec + 'header').attr('class',"collapsed");
            ChronusEffect.CloseContent(sec + 'content', effectDuration);
            jQuery('#' + sec + 'header').parent().addClass("unstacked");
        }
    }
}

/*******************************************************************************
 * This is to get users Time zone
 */

function determineTimeZone(validTimezonesArray, obsoleteTimezonesHash, urlToNotifyNewTimezone){
  tzObject = jstz.determine();
  tzValue = (tzObject instanceof Object) ? (tzObject.name() || 'Etc/UTC') : 'Etc/UTC';
  if (!jQuery.isEmptyObject(obsoleteTimezonesHash) && (tzValue in obsoleteTimezonesHash)){
    tzValue = obsoleteTimezonesHash[tzValue];
  }
  return {
    tzValue: tzValue,
    validity: validateTimeZone(tzValue, validTimezonesArray, urlToNotifyNewTimezone)
  }
}

function validateTimeZone(timezone, validTimezonesArray, urlToNotifyNewTimezone)
{
  if(jQuery.inArray(timezone, validTimezonesArray) !== -1) return true;
  jQuery.ajax({
    url: urlToNotifyNewTimezone,
    data: { detected_timezone: timezone }
  });
  return false;
}

function computeTimeZone(validTimezonesArray, obsoleteTimezonesHash, urlToNotifyNewTimezone){
  var timezoneObject = determineTimeZone(validTimezonesArray, obsoleteTimezonesHash, urlToNotifyNewTimezone);
  var tzValue = timezoneObject["validity"] ? timezoneObject["tzValue"] : "";
  jQuery(".cjs_time_zone").val(tzValue);
}

/*************************************************************************************************
// Triggers a customized confirm
// Pass the following parameters:
//  1. The message to be displayed in the popup
//  2. The method that executes actions when user clicks 'OK'
//  3. The method that executes actions when user clicks 'Cancel'
//  4. okText is optional param, pass it if you want to modify default text for Ok button
//  5. cancelText is optional param, pass it if you want to modify default text for Cancel button
//  6. noConfirm is optional param. If true the we will not show the confirmation popup
//
// Dismiss (x) behaves like Cancel
*/

function chronusConfirm(message, okMethod, cancelMethod, okText, cancelText, noConfirm) {
  okText = getValueforOptionalParam(jsCommonTranslations.popup.ok, okText);
  cancelText = getValueforOptionalParam(jsCommonTranslations.popup.cancel, cancelText);
  noConfirm = getValueforOptionalParam(false, noConfirm);
  if (noConfirm){
    okMethod();
    return;
  }

  var sweetAlertOptions = {
    title: "<span class=\"sr-only\">" + jsCommonTranslations.popup.confirmation + "<\/span>",
    text: message,
    showCancelButton: true,
    confirmButtonText: okText,
    cancelButtonText: cancelText
  };
  showSweetAlert(sweetAlertOptions, okMethod, cancelMethod);
}

var ChrDateFormatUtils = {
  getFullDateFromLocale: function(fullDate) {
    var day = fullDate.toString('dd');
    var month = fullDate.getMonth();
    var year = fullDate.getFullYear();
    var monthString = fullCalendarParamHash.monthNames[month];
    // Date formate is "MMMM dd, YYYY"
    return monthString + ' ' + day + ', ' + year;
  }
}

ChronusEffect.ToggleIbox = function(ibox_content_id){
  jQuery("#" + ibox_content_id).parent(".ibox").find(".ibox-title .ibox-tools a.collapse-link").click();
}

function isObjectEmpty(obj) {
  return Object.keys(obj).length === 0 && obj.constructor === Object
}

function disableOrResetSubmitButton(formSelector, submitText, pleaseWaitText, disable){
  var submitButton = jQuery(formSelector).find(".cjs_submit_btn").get(0);
  if(disable){
    submitButton.disabled = true;
    submitButton.value = pleaseWaitText;
  }
  else{
    submitButton.disabled = false;
    submitButton.value = submitText;
  }
}