var UserImport = {
  primaryCheckBoxSelector: "#cjs_user_result #cjs_user_primary_checkbox",
  subCheckBoxesSelector: "#cjs_user_result .cjs_user_record",
  headerElements: "#cjs_user_result tr.cjs_user_header th.cjs_sortable_element",
  selectAllRow: "#cjs_user_result tr#cjs_select_all_option",
  selectAll: "#cjs_user_result tr#cjs_select_all_option u#cjs_select_all_handler",
  clearAll: "#cjs_user_result tr#cjs_select_all_option u#cjs_clear_all_handler",

  sortBoth: "sort_both",
  sortAsc: "sort_asc",
  sortDesc: "sort_desc",
  selectedIds: [],
  maxLength: 0,
  filterIsOpen: false,

  inspectActions: function(selectionErrorMsg){
    jQuery(document).ready(function(){
      UserImport.inspectPrimaryCheckBox();
      UserImport.inspectSubCheckBox();
      UserImport.inspectSortableElements();
      UserImport.inspectSelectClearAllSelection();
      UserImport.inspectBulkActions(selectionErrorMsg);
      handleDoubleScroll("#cjs_user_result", ".cjs_table_enclosure");
    });

    jQuery(document).on('ajax:beforeSend', "#search_filter_form", function(){
      jQuery("#loading_results").show();
    });
  },

  initializeMaxLength: function(total_entries){
    UserImport.maxLength = total_entries;
  },

  resetAndApply: function(){
    jQuery(document).on('click', "#reset_filter_program_role", function(e){
      UserImport.resetProgramRoleFilter();
      UserImport.applyFilters();
    });

    jQuery(document).on('click', ".filter_role", function(e){
      UserImport.applyFilters();
    });

    jQuery(document).on('click', ".filter_program", function(e){
      UserImport.applyFilters();
    });
  },

  maintainTriStateCheckbox: function(shouldHighlight){
    if(UserImport.selectedIds.length > 0){
      CommonSelectAll.indeterminateState(jQuery(UserImport.primaryCheckBoxSelector), true, UserImport);
      if(shouldHighlight){
        jQuery.each(UserImport.selectedIds, function(index, selectedId){
          var selectedCheckbox = jQuery("#"+ "ct_user_checkbox_" + selectedId);
          if(selectedCheckbox.length > 0){
            selectedCheckbox.prop("checked", true);
            UserImport.selectAndHighlight(selectedCheckbox, true);
          }
        });
      }
    }
  },

  resetTriStateCheckbox: function(){
    CommonSelectAll.indeterminateState(jQuery(UserImport.primaryCheckBoxSelector), false, UserImport);
  },

  inspectPrimaryCheckBox: function(){
    var primaryCheckBox = jQuery(UserImport.primaryCheckBoxSelector);
    primaryCheckBox.change(function(){
      var isChecked = primaryCheckBox.is(":checked");
      var subCheckBoxes = jQuery(UserImport.subCheckBoxesSelector);
      subCheckBoxes.prop("checked", isChecked);
      UserImport.selectAndHighlight(subCheckBoxes, isChecked);
      UserImport.showHideSelectAll(isChecked);
      CommonSelectAll.computeSelectedIds(subCheckBoxes, UserImport);
      if(!isChecked){
        CommonSelectAll.resetSelectedIds(UserImport);
        UserImport.resetTriStateCheckbox();
      }
      else{
        CommonSelectAll.indeterminateState(jQuery(UserImport.primaryCheckBoxSelector), isChecked, UserImport);
      }
    });
  },

  inspectSubCheckBox: function(){
    var subCheckBoxes = jQuery(UserImport.subCheckBoxesSelector);
    subCheckBoxes.change(function(){
      UserImport.selectAndHighlight(jQuery(this), jQuery(this).is(":checked"));
      UserImport.showHideSelectAll(false);
      CommonSelectAll.computeSelectedIds(subCheckBoxes, UserImport);
      if(UserImport.selectedIds.length == 0)
        UserImport.resetTriStateCheckbox();
      else
        UserImport.maintainTriStateCheckbox(false);
    });
  },

  inspectSortableElements: function(){
    var sortableElements = jQuery(UserImport.headerElements);
    sortableElements.on('click', function(){
      var sortParam = jQuery(this).data("sort-param");
      var sortOrder = "";

      UserImport.resetSortImages(sortableElements.not(jQuery(this)));
      if(jQuery(this).hasClass(UserImport.sortBoth)){
        jQuery(this).removeClass(UserImport.sortBoth).addClass(UserImport.sortAsc);
        sortOrder = "asc";
      }
      else if(jQuery(this).hasClass(UserImport.sortAsc)){
        jQuery(this).removeClass(UserImport.sortAsc).addClass(UserImport.sortDesc);
        sortOrder = "desc";
      }
      else if(jQuery(this).hasClass(UserImport.sortDesc)){
        jQuery(this).removeClass(UserImport.sortDesc).addClass(UserImport.sortBoth);
        sortOrder = "asc";
        sortParam = "first_name";
      }

      jQuery('#filter_sort_field').val(sortParam);
      jQuery('#filter_sort_order').val(sortOrder);

      UserImport.applyFilters();
    });
  },

  applyFilters: function(){
    jQuery('#search_filter_form').submit();
    return false;
  },

  inspectSelectClearAllSelection: function(){
    jQuery(UserImport.selectAll).on('click', function(){
      var loaderImage = jQuery(this).parent().find("i.icon-all");
      var selectAllHandler = jQuery(this);
      jQuery.ajax({
        url : selectAllHandler.data("url"),
        beforeSend : function(){loaderImage.removeClass("hide");},
        success: function(responseText){
          CommonSelectAll.resetSelectedIds(UserImport);
          UserImport.selectedIds = responseText["member_ids"];
          loaderImage.addClass("hide");
          selectAllHandler.closest("div").hide();
          jQuery("div#cjs_clear_all_message").show();
          CommonSelectAll.indeterminateState(jQuery(UserImport.primaryCheckBoxSelector), false, UserImport);
        }
      });
    });

    jQuery(UserImport.clearAll).on('click', function(){
      jQuery(UserImport.primaryCheckBoxSelector).attr("checked", false);
      var subCheckBoxes = jQuery(UserImport.subCheckBoxesSelector);
      subCheckBoxes.prop("checked", false);
      UserImport.selectAndHighlight(subCheckBoxes, false);
      UserImport.showHideSelectAll(false);
      CommonSelectAll.resetSelectedIds(UserImport);
    });
  },

  inspectBulkActions: function(selectionErrorMsg){
    var bulkActions = jQuery("#cjs_add_to_program");

    bulkActions.on('click', function(event){
      event.preventDefault();
      if(UserImport.validateSelection(selectionErrorMsg)){
        UserImport.generateForm(jQuery(this));
      }
    });
  },

  initializeSearch: function(){
    var cancelSearch = jQuery(".cancel-search");
    jQuery(document).on('click', '.cancel-search', function(event){
      event.preventDefault();
      jQuery(this).hide();
      jQuery("#loading_results").show();
      jQuery("#search_content").val('');
      UserImport.applyFilters();
    });
  },

  generateForm: function(jQueryObj){
    var url = jQueryObj.data("url");
    var dataParameters = {bulk_action_confirmation: {users: UserImport.selectedIds, title: jQueryObj.text()}};
    // Though the request below should be a get, we make a post here to avoid the get request length restriction which
    // the web servers like nginx, webrick etc. have
    jQueryShowQtip('#cjs_user_result', 600, url, dataParameters, {method: "post", modal: true});
  },

  selectAndHighlight: function(checkBoxes, checkBoxValue){
    if(checkBoxValue){
      checkBoxes.closest("tr").addClass("bg-highlight cui_disable_hover");
    }
    else{
      checkBoxes.closest("tr").removeClass("bg-highlight cui_disable_hover");
    }
  },

  resetSortImages: function(headElements){
    headElements.removeClass(UserImport.sortDesc).removeClass(UserImport.sortAsc).addClass(UserImport.sortBoth);
  },

  resetSelectClearAll: function(){
    if(jQuery("#cjs_select_all_option").is(":visible")){
      jQuery("div#cjs_clear_all_message").hide();
      jQuery("div#cjs_select_all_message").show();
    }
  },

  showHideSelectAll: function(showBox){
    if(jQuery("#cjs_select_all_option").length > 0){
      if(showBox){
        jQuery("#cjs_select_all_option").show();
      }
      else{
        UserImport.resetSelectClearAll();
        jQuery("#cjs_select_all_option").hide();
      }
    }
  },

  validateSelection: function(selectionErrorMsg){
    if(UserImport.selectedIds.length == 0){
      ChronusValidator.ErrorManager.ShowResponseFlash("cjs_user_flash", selectionErrorMsg);
      return false;
    }
    else{
      ChronusValidator.ErrorManager.ClearResponseFlash("cjs_user_flash");
      return true;
    }
  },

  validateFields: function(form, field){
    jQuery("#" + form + " input[type=submit]").on('click', function(){
      return RequiredFields.checkMultiInputCase(jQuery("#" + field));
    });
  },

  clearFilter: function(reset_id){
    jQuery("#filter_pane_import_users").find('#reset_filter_' + reset_id).trigger('click');
  },

  resetProgramRoleFilter: function(){
    jQuery("#filter_pane_import_users").find('.cjs_reset_program_role_filter').prop("checked", false);
    jQuery("#filter_pane_import_users").find('.cjs_reset_program_role_filter').prop("indeterminate", false);
  },

  handleProgramRolesSelection: function() {
    jQuery("#filter_pane_import_users .cjs_filter_dormant_role").on("click", function(){
      jQuery("#filter_pane_import_users .cjs_filter_program").prop({"checked": false, "indeterminate": false});
      jQuery("#filter_pane_import_users .cjs_filter_role").prop("checked", false);
    });

    jQuery("#filter_pane_import_users .cjs_filter_program").on("click", function(){
      var programId = jQuery(this).val();
      jQuery("#filter_pane_import_users .cjs_filter_dormant_role").prop("checked", false);
      if(jQuery(this).prop('checked'))
      {
        jQuery("#filter_pane_import_users").find(".cjs_program_roles_" + programId).prop("checked", true);
      }
      else
      {
        jQuery("#filter_pane_import_users").find(".cjs_program_roles_" + programId).prop("checked", false);
      }
    });

    jQuery("#filter_pane_import_users .cjs_filter_role").on("click", function(){
      var programId = jQuery(this).data('program');
      var programSelector = jQuery('#filter_program_id_' + programId);
      var programRoleSelectors = jQuery("#filter_pane_import_users").find(".cjs_program_roles_" + programId);
      jQuery("#filter_pane_import_users .cjs_filter_dormant_role").prop("checked", false);
      UserImport.updateProgramSelectionStatus(programSelector, programRoleSelectors);
    });
  },

  handleIndeterminateStateForProgram: function(){
    var programSelectors = jQuery(".cjs_filter_program");
    programSelectors.each(function(){
      var programId = jQuery(this).val();
      var programSelector = jQuery(this);
      var programRoleSelectors = jQuery("#filter_pane_import_users").find(".cjs_program_roles_" + programId);
      UserImport.updateProgramSelectionStatus(programSelector, programRoleSelectors);
    })
  },

  updateProgramSelectionStatus: function(programSelector, programRoleSelectors){
    var checkedRolesLength = 0;
    programRoleSelectors.each(function(){
      if(jQuery(this).is(":checked")) {
        checkedRolesLength++;
      }
    })
    if(checkedRolesLength == programRoleSelectors.length) {
      programSelector.prop({"checked": true, "indeterminate": false});
    }
    else if(checkedRolesLength == 0) {
      programSelector.prop({"checked": false, "indeterminate": false});
    }
    else {
      programSelector.prop({"checked": false, "indeterminate": true});
    }
  }

};
