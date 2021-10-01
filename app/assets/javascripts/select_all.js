var CommonSelectAll = {
  selectedIds: [],
  parentContainer: ".cjs_select_all_result",
  primaryCheckBoxSelector: ".cjs_select_all_result #cjs_select_all_primary_checkbox",
  subCheckBoxesSelector: ".cjs_select_all_result .cjs_select_all_record",
  selectAllRow: ".cjs_select_all_result #cjs_select_all_option",
  selectAll: ".cjs_select_all_result #cjs_select_all_option u#cjs_select_all_handler",
  clearAll: ".cjs_select_all_result #cjs_select_all_option u#cjs_clear_all_handler",
  maxLength: 0,
  showHideSelect: true,
  gridId: "",

  initializeSelectAll: function(total_entries, grid_id){
    CommonSelectAll.initializeMaxLength(total_entries);
    CommonSelectAll.inspectPrimaryCheckBox();
    CommonSelectAll.inspectSubCheckBox();
    CommonSelectAll.inspectSelectClearAllSelection();
    CommonSelectAll.gridId = grid_id;
  },

  maintainTriStateCheckbox: function(shouldHighlight){
    if(CommonSelectAll.selectedIds.length > 0){
      CommonSelectAll.indeterminateState(jQuery(CommonSelectAll.primaryCheckBoxSelector), true, CommonSelectAll);
      if(shouldHighlight){
        jQuery.each(CommonSelectAll.selectedIds, function(index, selectedId){
          var selectedCheckbox = jQuery(".cjs_select_all_checkbox_" + selectedId);
          if(selectedCheckbox.length > 0){
            selectedCheckbox.attr("checked", true);
            CommonSelectAll.selectAndHighlight(selectedCheckbox, true);
          }
        });
      }
    }
  },

  indeterminateState: function(elementObj, state, namespace){
    if(namespace.selectedIds.length == namespace.maxLength){
      jQuery(elementObj).prop({"checked": true, "indeterminate": false});
    }
    else{
      elementObj.prop({"checked": state, "indeterminate": state});
    }
  },

  inspectPrimaryCheckBox: function(){
    jQuery(document).on('change', CommonSelectAll.primaryCheckBoxSelector, function(){
      var primaryCheckBox = jQuery(CommonSelectAll.primaryCheckBoxSelector);
      var isChecked = primaryCheckBox.is(":checked");
      var subCheckBoxes = jQuery(CommonSelectAll.subCheckBoxesSelector);
      var grid = jQuery(CommonSelectAll.gridId).data('kendoGrid');
      var totalResponses = grid.dataSource.total();

      if(totalResponses != CommonSelectAll.maxLength) {
        CommonSelectAll.initializeMaxLength(totalResponses);
      }

      var pageSize = grid.dataSource.pageSize();
      subCheckBoxes.attr("checked", isChecked);
      CommonSelectAll.selectAndHighlight(subCheckBoxes, isChecked);
      CommonSelectAll.showHideSelectAll(isChecked);
      CommonSelectAll.computeSelectedIds(subCheckBoxes, CommonSelectAll);
      if (totalResponses > pageSize){
        jQuery("#cjs_select_all_option .cjs_total_entries_size").html(totalResponses);
        jQuery("#cjs_select_all_option #objects_size").html(pageSize);
      }
      else{
        jQuery("#cjs_select_all_option").hide();
      }
      if(!isChecked){
        CommonSelectAll.resetSelectedIds(CommonSelectAll);
        CommonSelectAll.resetTriStateCheckbox();
      }
      else{
        CommonSelectAll.indeterminateState(jQuery(CommonSelectAll.primaryCheckBoxSelector), isChecked, CommonSelectAll);
      }
    });
  },

  resetTriStateCheckbox: function(){
    CommonSelectAll.indeterminateState(jQuery(CommonSelectAll.primaryCheckBoxSelector), false, CommonSelectAll);
  },

  initializeMaxLength: function(total_entries){
    CommonSelectAll.maxLength = total_entries;
  },

  inspectSubCheckBox: function(){
    jQuery(document).on('change', CommonSelectAll.subCheckBoxesSelector, function(){
      var subCheckBoxes = jQuery(CommonSelectAll.subCheckBoxesSelector);
      CommonSelectAll.selectAndHighlight(jQuery(this), jQuery(this).is(":checked"));
      CommonSelectAll.showHideSelectAll(false);
      CommonSelectAll.computeSelectedIds(subCheckBoxes, CommonSelectAll);
      if(CommonSelectAll.selectedIds.length == 0)
        CommonSelectAll.resetTriStateCheckbox();
      else
        CommonSelectAll.maintainTriStateCheckbox(false);
    });
  },

  inspectSelectClearAllSelection: function(){
    jQuery(document).on('click', CommonSelectAll.selectAll, function(){
      var loaderImage = jQuery(this).parent().find("i.icon-all");
      var selectAllHandler = jQuery(this);
      var grid = jQuery(CommonSelectAll.gridId).data('kendoGrid');
      var gridFilters = {};

      if(grid.dataSource.filter() && grid.dataSource.filter().filters){
        gridFilters["filters"] = kendoUtils.formatFilterData(grid.dataSource.filter(), CommonSelectAll.gridId).filters;
      }

      jQuery.ajax({
        url : selectAllHandler.data("url"),
        data: {filter: gridFilters},
        beforeSend : function(){loaderImage.removeClass("hide");},
        success: function(responseText){
          CommonSelectAll.resetSelectedIds(CommonSelectAll);
          CommonSelectAll.selectedIds = responseText["ids"];
          loaderImage.addClass("hide");
          selectAllHandler.closest("div").hide();
          jQuery("div#cjs_clear_all_message").show();
          jQuery("#cjs_select_all_option .cjs_total_entries_size").html(responseText["total_count"]);
          CommonSelectAll.indeterminateState(jQuery(CommonSelectAll.primaryCheckBoxSelector), false, CommonSelectAll);
        }
      });
    });

    jQuery(CommonSelectAll.clearAll).click(function(){
      jQuery(CommonSelectAll.primaryCheckBoxSelector).attr("checked", false);
      var subCheckBoxes = jQuery(CommonSelectAll.subCheckBoxesSelector);
      subCheckBoxes.attr("checked", false);
      CommonSelectAll.selectAndHighlight(subCheckBoxes, false);
      CommonSelectAll.showHideSelectAll(false);
      CommonSelectAll.resetSelectedIds(CommonSelectAll);
    });
  },

  selectAndHighlight: function(checkBoxes, checkBoxValue){
    if(checkBoxValue){
      checkBoxes.closest("tr").addClass("bg-highlight cui_disable_hover");
    }
    else{
      checkBoxes.closest("tr").removeClass("bg-highlight cui_disable_hover");
    }
  },

  showHideSelectAll: function(showBox){
    if(jQuery("#cjs_select_all_option").length > 0 && CommonSelectAll.showHideSelect){
      if(showBox){
        jQuery("#cjs_select_all_option").show();
      }
      else{
        CommonSelectAll.resetSelectClearAll();
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

  computeSelectedIds: function(checkBoxes, namespace, dataMap){
    checkBoxes.each(function(index, domElement){
      var selectedIds = namespace["selectedIds"];
      var element = jQuery(domElement);
      var value = domElement.value;
      var domElementValuePresent = jQuery.inArray(value, selectedIds) != -1;

      if(element.is(":checked")) {
        if(!domElementValuePresent) {
          selectedIds.push(value);
          for (var arrayName in dataMap) {
            namespace[arrayName].push(element.data(dataMap[arrayName]));
          }
        }
      } else if(domElementValuePresent) {
        removeFromArray(selectedIds, value);
        for (var arrayName in dataMap) {
          removeFromArray(namespace[arrayName], element.data(dataMap[arrayName]));
        }
      }
    });
  },

  resetSelectedIds: function(namespace, additionalArraysToBeEmptied){
    namespace["selectedIds"] = [];
    if(additionalArraysToBeEmptied){
      for (var i = 0; i < additionalArraysToBeEmptied.length; i++) {
        namespace[additionalArraysToBeEmptied[i]] = [];
      }
    }
  },

  validateSelection: function(selectionErrorMsg){
    if(CommonSelectAll.selectedIds.length == 0){
      ChronusValidator.ErrorManager.ShowResponseFlash("cjs_select_all_flash", selectionErrorMsg);
      return false;
    }
    else{
      ChronusValidator.ErrorManager.ClearResponseFlash("cjs_select_all_flash");
      return true;
    }
  }
}