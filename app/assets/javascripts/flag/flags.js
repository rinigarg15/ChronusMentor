var Flags = {
  newFlagValidation: function(reasonError){
    jQuery(".cjs_popup_flag_content_button").click(function(){
      var flashId = jQuery("#new_flag_popup .alert").attr('id');
      if(!ValidateRequiredFields.checkNonMultiInputCase(jQuery("#flag_reason"))) {
        ChronusValidator.ErrorManager.ShowResponseFlash(flashId, reasonError);
        return false;
      } else {
        ChronusValidator.ErrorManager.ClearResponseFlash(flashId);
        return true;
      }
    })
  }
}