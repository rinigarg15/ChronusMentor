var MembershipRequest = {

  membershipRequestsTable: "#cjs_mem_req_record",
  selectAllRow: "tr#cjs_select_all_option",
  primaryCheckBoxSelector: "#membership_requests #cjs_primary_checkbox",
  subCheckBoxesSelector: "#membership_requests .cjs_membership_request_record",
  selectAll: "#membership_requests #cjs_select_all_option u#cjs_select_all_handler",
  clearAll: "#membership_requests #cjs_select_all_option u#cjs_clear_all_handler",
  headerElements: "#cjs_mem_req_record tr.cjs_mem_req_header th.cjs_sortable_element",
  roleCheckboxes: "input:checkbox[name='roles[]']",
  roleCheckboxesChecked: "input:checkbox[name='roles[]']:checked",
  sortBoth: "sort_both",
  sortAsc: "sort_asc",
  sortDesc: "sort_desc",
  selectedIds: [],
  selectedMemberIds: [],
  maxLength: 0,

  validateAndSubmitApplyForForm: function(submitText, pleaseWaitText){
    jQuery(document).on("click", ".cjs_apply_for_form .cjs_submit_btn", function(){
      disableOrResetSubmitButton(".cjs_apply_for_form", submitText, pleaseWaitText, true);
      var applyForForm = jQuery(this).closest(".cjs_apply_for_form");
      var selectedRoles = jQuery("input[type='radio'][name='roles']:checked").val();
      applyForForm.find(".cjs_roles_apply_for").val(selectedRoles);

      var signUpEmail = applyForForm.find(".cjs_signup_email");
      var isEmailPresent = RequiredFields.checkNonMultiInputCase(".cjs_signup_email");
      var isCaptchaPresent = RequiredFields.checkNonMultiInputCase("#captcha");
      var requiredFieldsPresent = isEmailPresent && isCaptchaPresent;
      var isEmailFormatValid = verifyEmailFormat(signUpEmail.val());
      var isValid = requiredFieldsPresent && isEmailFormatValid;

      if(!isEmailFormatValid){
        ChronusValidator.ErrorManager.ShowFieldError(signUpEmail);
      }
      if(isValid) {
        applyForForm.submit();
      } else {
        disableOrResetSubmitButton(".cjs_apply_for_form", submitText, pleaseWaitText, false);
      }
    });
  },

  initialSignUpAjaxCall: function(url, selectedRoles){
    jQuery.ajax({
      url: url,
      data: { 'roles[]': selectedRoles },
      beforeSend: function(){
        jQuery("#cjs_signup_options").hide();
        jQuery(".cjs_signup_options_header").show();
        jQuery(".cjs_signup_options_loader").show();
      }
    });
  },

  initializeSignUpOptions: function(url){
    jQuery(document).on("change", ".cjs_signup_role", function(){
      selectedRoles = jQuery(this).val().split(", ");
      MembershipRequest.initialSignUpAjaxCall(url, selectedRoles);
    });
  },

  isBlankOrValid: function(elementId){
    return (jQuery(elementId).length == 0 || RequiredFields.checkNonMultiInputCase(elementId));
  },

  getSelectedRoles: function(isCheckbox){
    if(isCheckbox){
      return collectVals(MembershipRequest.roleCheckboxesChecked);
    }
    else{
      return [jQuery('#role_names_select').val()];
    }
  },

  initializeRolesAndEmailNameAnswers: function(email_question_id, name_question_id, isCheckbox){
    jQuery("#membership_request_roles_").val(MembershipRequest.getSelectedRoles(isCheckbox));
    if(jQuery('#profile_answers_' + email_question_id)){
      jQuery('#profile_answers_' + email_question_id).val(jQuery('#membership_request_email').val());
    }
    if(jQuery('#profile_answers_' + name_question_id)){
      jQuery('#profile_answers_' + name_question_id).val(jQuery('#membership_request_first_name').val() + " " + jQuery('#membership_request_last_name').val());
    }
  },

  validateForm: function(email_question_id, name_question_id, isCheckbox, submitText, pleaseWaitText, newRequest){
    jQuery(document).on("submit", ".cjs_new_membership_request", function(){
      disableOrResetSubmitButton(".cjs_new_membership_request", submitText, pleaseWaitText, true);
      if(newRequest){
        MembershipRequest.initializeRolesAndEmailNameAnswers(email_question_id, name_question_id, isCheckbox);
        var isRolesPresent =  RequiredFields.checkNonMultiInputCase("#membership_request_roles_");
        var isPasswordPresent = MembershipRequest.isBlankOrValid("#membership_request_password");
        var isPasswordConfirmationPresent = MembershipRequest.isBlankOrValid("#membership_request_password_confirm");
        var isCaptchaPresent = MembershipRequest.isBlankOrValid("#membership_request_captcha");
        var isSignUpTermsPresent = jQuery("#signup_terms_container").length == 0 || RequiredFields.checkMultiInputCase("#signup_terms_container");
      }
      var isFirstNamePresent = MembershipRequest.isBlankOrValid("#membership_request_first_name");
      var isLastNamePresent = MembershipRequest.isBlankOrValid("#membership_request_last_name");
      var isEmailPresent = RequiredFields.checkNonMultiInputCase("#membership_request_email");
      var isEmailFormatValid = verifyEmailFormat(jQuery("#membership_request_email").val());

      // Validates the presence of mandatory membership questions and basic fields
      var requiredFieldsPresent = RequiredFields.validate(false, true) && isFirstNamePresent && isLastNamePresent && isEmailPresent;
      if(newRequest){
        requiredFieldsPresent = requiredFieldsPresent && isRolesPresent && isPasswordPresent && isPasswordConfirmationPresent && isCaptchaPresent && isSignUpTermsPresent;
        var isPassValid = (jQuery("#membership_request_password").length == 0) || (jQuery("#membership_request_password").val() == jQuery("#membership_request_password_confirm").val());
      }
      else {
        var isRolesPresent = true;
        var isPassValid = true;
      }
      var isValid = requiredFieldsPresent && isEmailFormatValid && isPassValid;

      if(!requiredFieldsPresent){
        ChronusValidator.ErrorManager.ShowPageFlash(false, jsCommonTranslations.fillAppropriateValues);
        if(!isRolesPresent){
          ChronusValidator.ErrorManager.ShowFieldError(jQuery("#role_names_select"));
        }
        else{
          ChronusValidator.ErrorManager.HideFieldError(jQuery("#role_names_select"));
        }
      }
      else if(!isEmailFormatValid){
        ChronusValidator.ErrorManager.ShowFieldError(jQuery("#membership_request_email"));
        ChronusValidator.ErrorManager.ShowPageFlash(false, jsCommonTranslations.invalidEmailFormatError);
      }
      else if(!isPassValid){
        ChronusValidator.ErrorManager.ShowFieldError(jQuery("#membership_request_password"));
        ChronusValidator.ErrorManager.ShowFieldError(jQuery("#membership_request_password_confirm"));
        ChronusValidator.ErrorManager.ShowPageFlash(false, jsCommonTranslations.fixPasswordError);
      }
      else{
        ChronusValidator.ErrorManager.ClearPageFlash();
      }

      if(isValid)
        EditUser.renameEducationExperienceFields();
      else
        disableOrResetSubmitButton(".cjs_new_membership_request", submitText, pleaseWaitText, false);

      scroll(0,0);
      return isValid;
    });
  },

  hideFieldErrorsForAjaxRequest: function(){
    var fields_array = document.getElementsByClassName("cjs_new_membership_request")[0].elements;
    for (i = 0; i < fields_array.length; i++) {
      ChronusValidator.ErrorManager.HideFieldError(fields_array[i]);
    }
    RequiredFields.fieldIds = [];
    ChronusValidator.ErrorManager.ClearPageFlash();
  },

  doExtendedSerialize: function(isCheckbox) {
    formDetailsArray = jQuery("#new_membership_request").serializeArray();
    formDetailsArray.push({ name: 'email', value: jQuery('#membership_request_email')[0].value });
    // roles[] will be already present when isCheckbox is true.
    if(!isCheckbox) {
      selectedRoles = MembershipRequest.getSelectedRoles(isCheckbox);
      formDetailsArray.push({ name: 'roles[]', value: selectedRoles[0] });
    }
    return jQuery.param(formDetailsArray);
  },

  handleRoleChange: function(newmembershipUrl, pleaseWaitText, submitText, isCheckbox){
    button_object = jQuery(".cjs_new_membership_request .form-actions input")[0];
    jQuery.ajax({
      url: newmembershipUrl,
      data: MembershipRequest.doExtendedSerialize(isCheckbox),
      beforeSend: function(){
        jQuery('#loading_results').show();
        button_object.value = pleaseWaitText;
        button_object.disabled = true;
        MembershipRequest.hideFieldErrorsForAjaxRequest();
      },
      success: function(){
        button_object.value = submitText;
        button_object.disabled = false;
        jQuery('#loading_results').hide();
      }
    });
  },

  initializeRoleChange: function(isCheckbox, newmembershipUrl, pleaseWaitText, submitText){
    if(isCheckbox){
      jQuery(MembershipRequest.roleCheckboxes).on("change", function(){
        if(jQuery(MembershipRequest.roleCheckboxesChecked).length < 1){
          return false;
        }
        MembershipRequest.handleRoleChange(newmembershipUrl, pleaseWaitText, submitText, true);
      });
    }
    else{
      jQuery("#role_names_select").on("change", function(){
        if(jQuery(this).val().blank()){
          return false;
        }
        MembershipRequest.handleRoleChange(newmembershipUrl, pleaseWaitText, submitText, false);
      });
    }
  },

  handleRoleUpdate: function(roleUpdateUrl, role, role_id, profile_question_id){
    jQuery.ajax({
      url: roleUpdateUrl,
      data: {'role' : role, 'role_id' : role_id, 'profile_question_id' : profile_question_id}
    });
  },

  rejectRequest: function(id) {
    return RequiredFields.checkText(jQuery('#' + id));
  },

  /**
   * Bulk actions
   */
  inspectActions: function(selectionErrorMsg){
    jQuery(document).ready(function(){
      MembershipRequest.inspectPrimaryCheckBox();
      MembershipRequest.inspectSubCheckBox();
      MembershipRequest.inspectBulkActions(selectionErrorMsg);
      MembershipRequest.inspectIndividualActions();
      MembershipRequest.inspectSelectClearAllSelection();
      MembershipRequest.inspectSortableElements();
    });
  },

  initializeMaxLength: function(total_entries){
    MembershipRequest.maxLength = total_entries;
  },

  maintainTriStateCheckbox: function(shouldHighlight){
    if(MembershipRequest.selectedIds.length > 0){
      CommonSelectAll.indeterminateState(jQuery(MembershipRequest.primaryCheckBoxSelector), true, MembershipRequest);
      if(shouldHighlight){
        jQuery.each(MembershipRequest.selectedIds, function(index, selectedId){
          var selectedCheckbox = jQuery("#ct_membership_request_checkbox_" + selectedId);
          if(selectedCheckbox.length > 0){
            selectedCheckbox.attr("checked", true);
          }
        });
      }
    }
  },

  resetTriStateCheckbox: function(){
    CommonSelectAll.indeterminateState(jQuery(MembershipRequest.primaryCheckBoxSelector), false, MembershipRequest);
  },

  inspectPrimaryCheckBox: function(){
    var primaryCheckBox = jQuery(MembershipRequest.primaryCheckBoxSelector);
    primaryCheckBox.change(function(){
      var isChecked = primaryCheckBox.is(":checked");
      var subCheckBoxes = jQuery(MembershipRequest.subCheckBoxesSelector);
      subCheckBoxes.attr("checked", isChecked);
      CommonSelectAll.computeSelectedIds(subCheckBoxes, MembershipRequest, {selectedMemberIds: 'member-id'});
      MentorRequests.showHideSelectAll(isChecked);
      if(!isChecked){
        CommonSelectAll.resetSelectedIds(MembershipRequest, ["selectedMemberIds"]);
        MembershipRequest.resetTriStateCheckbox();
      }
      else{
        CommonSelectAll.indeterminateState(jQuery(MembershipRequest.primaryCheckBoxSelector), isChecked, MembershipRequest);
      }
    });
  },

  inspectSubCheckBox: function(){
    var subCheckBoxes = jQuery(MembershipRequest.subCheckBoxesSelector);
    subCheckBoxes.change(function(){
      CommonSelectAll.computeSelectedIds(subCheckBoxes, MembershipRequest, {selectedMemberIds: 'member-id'});
      MentorRequests.showHideSelectAll(false);
      if(MembershipRequest.selectedIds.length == 0)
        MembershipRequest.resetTriStateCheckbox();
      else
        MembershipRequest.maintainTriStateCheckbox(false);
    });
  },

  resetMembershipSelectedIds: function(){
    MembershipRequest.selectedIds.length = 0;
    MembershipRequest.selectedMemberIds.length = 0;
  },

  inspectBulkActions: function(selectionErrorMsg){
    jQuery(".cjs_membership_request_bulk_update, .cjs_bulk_send_message, .cjs_membership_request_export").click(function(event){
      validSelection = MembershipRequest.validateSelection(selectionErrorMsg);
    });

    jQuery(".cjs_membership_request_bulk_update").click(function(event){
      if(validSelection) {
        jQueryShowQtip('#membership_requests', 600, jQuery(this).data("url"), {membership_request_ids: MembershipRequest.selectedIds}, {method: "post", modal: true});
      }
    });

    jQuery(".cjs_bulk_send_message").click(function(event) {
      if(validSelection) {
        jQueryShowQtip('#membership_requests', 600, jQuery(this).data("url"), {bulk_action: {members: MembershipRequest.selectedMemberIds}, src: "MembershipRequest"}, {method: "post", modal: true});
      }
    });

    jQuery(".cjs_membership_request_export").click(function(event){
      if(validSelection) {
        if(jQuery(this).data('ajax')){
          jQuery.ajax({
            url: jQuery(this).data("url"),
            data: { membership_request_ids: MembershipRequest.selectedIds },
            type: 'POST',
            beforeSend: function(){
              jQuery('#loading_results').show();
            },
            complete: function(){
              jQuery('#loading_results').hide();
            }
          });
        }
        else
        {
          jQuery('#membership_requests_export_form').find('.membership_request_ids').val(MembershipRequest.selectedIds);
          jQuery('#membership_requests_export_form').attr('action', jQuery(this).data('url')).submit();
        }
      }
    });
  },

  inspectIndividualActions: function(){
    jQuery(".cjs_membership_request_individual_update, .cjs_send_message").click(function(event){
      jQueryShowQtip('#membership_requests', 600, jQuery(this).data("url"), {}, {method: "post", modal: true});
    });
  },

  validateSelection: function(selectionErrorMsg){
    if(MembershipRequest.selectedIds.length == 0){
      ChronusValidator.ErrorManager.ShowResponseFlash("cjs_membership_requests_flash", selectionErrorMsg);
      return false;
    }
    else{
      ChronusValidator.ErrorManager.ClearResponseFlash("cjs_membership_requests_flash");
      return true;
    }
  },

  inspectSelectClearAllSelection: function(){
    MembershipRequest.setSelectAllPosition();
    jQuery(MembershipRequest.selectAll).on('click', function(){
      var loaderImage = jQuery(this).parent().find("i.icon-all");
      var selectAllHandler = jQuery(this);
      jQuery.ajax({
        url : selectAllHandler.data("url"),
        beforeSend : function(){loaderImage.removeClass("hide");},
        success: function(responseText){
          CommonSelectAll.resetSelectedIds(MembershipRequest, ["selectedMemberIds"]);
          MembershipRequest.selectedIds = responseText["membership_request_ids"];
          MembershipRequest.selectedMemberIds = responseText["member_ids"];
          loaderImage.addClass("hide");
          selectAllHandler.closest("div").hide();
          jQuery("div#cjs_clear_all_message").show();
          CommonSelectAll.indeterminateState(jQuery(MembershipRequest.primaryCheckBoxSelector), false, MembershipRequest);
        }
      });
    });

    jQuery(MembershipRequest.clearAll).click(function(){
      jQuery(MembershipRequest.primaryCheckBoxSelector).attr("checked", false);
      var subCheckBoxes = jQuery(MembershipRequest.subCheckBoxesSelector);
      subCheckBoxes.attr("checked", false);
      MentorRequests.showHideSelectAll(false);
      CommonSelectAll.resetSelectedIds(MembershipRequest, ["selectedMemberIds"]);
    });
  },

  setSelectAllPosition: function(){
    var tableEnclosure = jQuery(MembershipRequest.membershipRequestsTable).closest(".cjs_table_enclosure");
    var tableWidth = tableEnclosure.width() || jQuery("#cjs_requests_listing").width();
    var position = ((tableWidth/2) - 300);
    jQuery(MembershipRequest.selectAllRow).find("td").css({"padding-left": position + "px"});
  },

  inspectViewLinks: function(url){
    jQuery.ajax({
      url: url,
      beforeSend: function(){
        jQuery("#loading_results").show();
      }
    });
  },

  resetSortImages: function(headElements){
    headElements.removeClass(MembershipRequest.sortDesc).removeClass(MembershipRequest.sortAsc).addClass(MembershipRequest.sortBoth);
  },

  inspectSortableElements: function(){
    var sortableElements = jQuery(MembershipRequest.headerElements);
    sortableElements.on('click', function(){
      var sortParam = jQuery(this).data("sort");
      var sortOrder = "";
      MembershipRequest.resetSortImages(sortableElements.not(jQuery(this)));
      if(jQuery(this).hasClass(MembershipRequest.sortBoth)){
        jQuery(this).removeClass(MembershipRequest.sortBoth).addClass(MembershipRequest.sortAsc);
        sortOrder = "asc";
      }
      else if(jQuery(this).hasClass(MembershipRequest.sortAsc)){
        jQuery(this).removeClass(MembershipRequest.sortAsc).addClass(MembershipRequest.sortDesc);
        sortOrder = "desc";
      }
      else if(jQuery(this).hasClass(MembershipRequest.sortDesc)){
        jQuery(this).removeClass(MembershipRequest.sortDesc).addClass(MembershipRequest.sortAsc);
        sortOrder = "asc";
      }
      jQuery('#filter_sort_field').val(sortParam);
      jQuery('#filter_sort_order').val(sortOrder);
      commonReportFilters.submitData();
    });
  },

  getReportFilterData: function(){
    var data = {tab: jQuery('#filter_tab').val(), filters: commonReportFilters.getFiltersData(), list_type: jQuery('#filter_view_field').val(), sort: jQuery('#filter_sort_field').val(), order: jQuery('#filter_sort_order').val(), items_per_page: jQuery('#filter_items_per_page').val()};
    return data;
  }
}

var MembershipRequestBulkActionPopup = {
  initializeCheckboxTooltips: function(){
    var elements = jQuery('.membership_request_role_checkboxes');
    elements.each(function(index) {
      if(jQuery(this).attr('readonly')){
        var tooltip_message = jQuery(this).data("tooltip-message");
        jQuery("#label_"+ jQuery(this).data("role-name") +"_role").tooltip({title: tooltip_message});
        jQuery(this).siblings('.icon-info-sign').removeClass('invisible');
      }
    });
  }
}