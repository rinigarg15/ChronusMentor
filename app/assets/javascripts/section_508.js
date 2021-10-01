// These functions are used for Section 508 compliance changes

//This function is primarily used in add more functionality where we update labels and ids for the newly added object
var LinkLabelToInput = {
  updateIdAndLabelForAttribute: function(newComponent){
    var rand = Math.floor(Math.random()*1000);
    newComponent.find("label").each(function(){
      appendRandToAttribute(jQuery(this), "for", rand);
    });
    newComponent.find('input[type=text],input[type=password],textarea,select').each(function(){
      appendRandToAttribute(jQuery(this), "id", rand);
    });
  }
}

var CalendarLabels = {
  addAndAssociateLabel: function(element){
    if(typeof element == "undefined" || element == null){
      CalendarLabels.addIds(".ui-datepicker-month", "datepicker_month_", dateRangePickerTranslations.selectMonth);
      CalendarLabels.addIds(".ui-datepicker-year", "datepicker_year_", dateRangePickerTranslations.selectYear);
    }else{
      CalendarLabels.addIds(".ui-datepicker-month", "datepicker_month_", dateRangePickerTranslations.selectMonth, element);
      CalendarLabels.addIds(".ui-datepicker-year", "datepicker_year_", dateRangePickerTranslations.selectYear, element);
    }
  },

  addIds: function(selector, selectorPrefix, text, element){
    if(typeof element == "undefined" || element == null){
      var selectBoxes = jQuery(selector);
    }else{
      var selectBoxes = jQuery(element).parents().find(selector);
    }
    selectBoxes.each(function(){
      var randId = selectorPrefix + Math.floor(Math.random()*1000);
      jQuery(this).attr('id', randId);
      if(jQuery(this).find('label').length == 0){
        var labelObect = section508Common.createHiddenLabelWithText(randId, text)
        jQuery(this).append(labelObect);        
      } else{
        var labelObect = jQuery(this).find('label');
        labelObect.attr('for', randId);
      }
    });
  },

  updateLabelAndId: function(){
    jQuery(document).ready(function(){
      jQuery(".ui-daterangepicker").find(".ui-widget-content").find('li').on('click', function() {
        thisObject = this;
        setTimeout('CalendarLabels.addAndAssociateLabel(thisObject)', 1000);
      });
    });
  }
}

var UiWidgetLabels = {
  addAndAssociateLabels: function(selector, selectorPrefix, text){
    jQuery(selector).each(function(){
      var randId = selectorPrefix + Math.floor(Math.random()*1000);
      jQuery(this).attr('id', randId);
      var labelObect = section508Common.createHiddenLabelWithText(randId, text)
      jQuery(this).after(labelObect);        
    });
  }
}

var section508Common = {
  createHiddenLabelWithText: function(labelFor, labelText){
    var labelObect = jQuery("<label>").text(labelText);
    labelObect.prop({'for': labelFor, 'class': 'sr-only'});
    return labelObect;
  }
}