var MailerTemplates = {
  
  initializeValidations: function(){
    jQuery("form.edit_mailer_template input[type=submit]").live("click",function(){
      var titleElement = jQuery(this).closest("form.edit_mailer_template").find("#mailer_template_subject");
      var ckeditorWrapper = jQuery(this).closest("form.edit_mailer_template").find(".cjs_ckeditor .controls");

      var istitlePresent =  ValidateRequiredFields.checkNonMultiInputCase(titleElement);
      var isContentPresent = !CKEDITOR.instances.mailer_template_source.getData().blank();

      if(isContentPresent){
        ValidateRequiredFields.hideFieldError(ckeditorWrapper);
      }else{
        ValidateRequiredFields.showFieldError(ckeditorWrapper);
      }
      return istitlePresent && isContentPresent;
    });
  },

  neutralizeCKEditorLinks: function(){
    var ckEditorContent = jQuery(".cjs_content_well .cjs_neutralize_ckeditor_links");
    var anchorLinks = ckEditorContent.find('a');
    anchorLinks.each(function(){
      jQuery(this).attr('title', jQuery(this).attr('href'));
      jQuery(this).attr('href', '#');
      jQuery(this).attr('target', '_self');
    });
  },

  showMailerTemplateStatus: function(message){
    if(jQuery('#show_mailer_template_status').hasClass('cjs_mailer_template_enabled_false'))
    {
      ChronusValidator.ErrorManager.ShowResponseFlash("show_mailer_template_status", message, true);
    }
  },

//Copy the subject and body params from the template form and send to the mailer_template/preview or facilitation_template/preview_email action
  submitPreviewEmail: function(selectorOptions){
    var previewEmailSelector = selectorOptions.previewEmailSelector;
    jQuery(previewEmailSelector + " a#cjs_preview_email_link").click(function(){
      var hasValidTags = true;
      if(selectorOptions.facilitationTemplateId != undefined)
        hasValidTags = FacilitationTemplateProgressiveForm.containsOnlyValidTags(CKEDITOR.instances[selectorOptions.editorId], selectorOptions.facilitationTemplateId);
      if(!hasValidTags)
        return false;

      for (instance in CKEDITOR.instances){
        CKEDITOR.instances[instance].updateElement();
      }
      jQuery.ajax({
        url : jQuery(this).attr('href'),
        type: "POST",
        data: jQuery(selectorOptions.subjectId + ", " + selectorOptions.sourceId).serialize(),
        beforeSend : function(){
          jQuery(previewEmailSelector + ' img.ajax_loading').show();
        },
        complete: function(){
          jQuery(previewEmailSelector + ' img.ajax_loading').hide();
        }
      });
      return false;
    });
  },

  initializeIndex: function(){
    MailerTemplates.handleLinkToRolloutPopup();
    MailerTemplates.handleKeepCurrentContentButton();
  },

  renderPopup: function(url){
    jQueryShowQtip('#inner_content', 850, url,'',{modal: true});
  },

  handleLinkToRolloutPopup: function(){
    jQuery(".cjs_email_rollout_link").on('click', function(){
      url = jQuery(this).data('url');
      MailerTemplates.renderPopup(url);
    });
  },

  handleKeepCurrentContentButton: function(){
    jQuery(document).on('click', '.cjs_keep_current_content_btn', function(e){
      jQuery.ajax({
        url : jQuery(this).data('url'),
        data : jQuery(this).data(),
        type: "POST",
        complete: function(){
          closeQtip();
        }
      });
    });
  },

  updateCountInEnabledDisabledInfo: function(){
    jQuery(".cjs_subtegory_enabled_disabled_info").each(function(){
      var emailListDom = jQuery(this).parents(".ibox-title").next();

      var enabledCount = emailListDom.find(".cjs_email_container.cjs_enabled_mail").filter(":visible").length;
      var disabledCount = emailListDom.find(".cjs_email_container.cjs_disabled_mail").filter(":visible").length;

      jQuery(this).find(".cjs_enabled_count").html(enabledCount);
      jQuery(this).find(".cjs_disabled_count").html(disabledCount);
    });
  },

  applyFilters: function(showCustomized, showNonCustomized, showEnabled, showDisabled){
    var enabledFilterValue = jQuery("#cjs_email_enabled_filter input:radio:checked").val();
    var customizedFilterValue = jQuery("#cjs_email_customized_filter input:radio:checked").val();

    jQuery(".cjs_email_container").parent().show();
    
    if(enabledFilterValue == showEnabled){
      jQuery(".cjs_email_container.cjs_disabled_mail").parent().hide();
    }
    else if(enabledFilterValue == showDisabled){
      jQuery(".cjs_email_container.cjs_enabled_mail").parent().hide();
    }

    if(customizedFilterValue == showCustomized){
      jQuery(".cjs_email_container.cjs_non_customized_mail").parent().hide();
    }
    else if(customizedFilterValue == showNonCustomized){
      jQuery(".cjs_email_container.cjs_customized_mail").parent().hide();
    }

    if(jQuery("#cjs-chevron-header").is(":visible")){
      jQuery("#cjs-chevron-header").click();
    }

    MailerTemplates.updateCountInEnabledDisabledInfo();
  },

  hasSourceOrSubjectChanged: function(old_email_source_or_subject, source_or_subject){
    if(source_or_subject == "source") 
      var new_email_source_or_subject = CKEDITOR.instances.mailer_template_source.getData();
    else
      var new_email_source_or_subject = jQuery("#mailer_template_subject").val();

    if(old_email_source_or_subject != new_email_source_or_subject)
      jQuery("#has_"+source_or_subject+"_changed").val("true");
    else
      jQuery("#has_"+source_or_subject+"_changed").val("false");
  },

  hasContentOrSubjectChanged: function(){
    var old_email_source = CKEDITOR.instances.mailer_template_source.getData();
    var old_email_subject = jQuery("#mailer_template_subject").val();

    jQuery(document).on('click', '.cke_button__source_label', function(){
      jQuery(document).on('change', '.cke_source', function(){
        MailerTemplates.hasSourceOrSubjectChanged(old_email_source, "source");
      });
    });

    CKEDITOR.instances.mailer_template_source.on('change', function(){
      MailerTemplates.hasSourceOrSubjectChanged(old_email_source, "source");
    });

    jQuery("#mailer_template_subject").on('change', function(){
      MailerTemplates.hasSourceOrSubjectChanged(old_email_subject, "subject");
    });
  }
}

var MailerWidgets = {
  initializeValidations: function(){
    jQuery("form.edit_mailer_widget input[type=submit]").live("click",function(){
      var ckeditorWrapper = jQuery(this).closest("form.edit_mailer_widget").find(".cjs_ckeditor .controls");

      var isContentPresent = !CKEDITOR.instances.mailer_widget_source.getData().blank();

      if(isContentPresent){
        ValidateRequiredFields.hideFieldError(ckeditorWrapper);
      }else{
        ValidateRequiredFields.showFieldError(ckeditorWrapper);
      }
      return isContentPresent;
    });
  }
}

var HighlightSubCatogory = {
  closeAllSubCatogories: function(){
    jQuery(".ibox.subcatogories").find(".ibox-title .ibox-tools a.collapse-link").click();
  },

  highlight: function(id){
    HighlightSubCatogory.closeAllSubCatogories();
    jQuery("#"+id).find(".ibox-title .ibox-tools a.collapse-link").click();
  }
}