var InsecureContentHelper = {
  checkForInsecureContent: function(data) {
    var insecureContent = {};
    if(isProtocolHTTPS()) {
      var el = document.createElement('div');
      el.innerHTML = data;
      el = jQuery(el);

      /* Dirty Hack BEGIN: jQuery cannot read the elements inside obect tag for < IE8 . What is being done here is, removing the object tag and putting its HTML contents directly in the div that will be analyzed for insecure content.
      Links: 
      http://stackoverflow.com/questions/10318435/jquery-selector-bug-with-object-element-in-ie-6-7-or-did-i-miss-something
      http://bugs.jquery.com/ticket/11646
      http://bugs.jquery.com/ticket/9597
      */
      
      var objectContents = "";
      el.find('object').each(function  () {
        objectContents += jQuery(this).html();
      });
      el.find('object').remove();

      var objectContentsEle = jQuery('<div/>').html(objectContents);
      el.append(objectContentsEle);

      // Dirty Hack END

      var insecureUrls = [];
      var url = "";
      el.find("img[src^='http:'], embed[src^='http:'], iframe[src^='http:']").each(function() {
        url = jQuery(this).attr('src');
        insecureUrls.push(url);
      });
      el.remove();
      insecureContent["insecureUrls"] = insecureUrls;
    }
    else {
      insecureContent["insecureUrls"] = [];
    }

    var check_sanitization_url = jsStrings.sanitizationDiffPath;
    jQuery.ajax({
      type: "POST",
      url: check_sanitization_url,
      async: false,
      data: {content: data},
      success: function(response) {
        insecureContent["cleanContent"] = response['sanitized_content'];
        insecureContent["insecureSanitizedContent"] = response['diff'];
      }, 
      error: function(XMLHttpRequest, textStatus, errorThrown) { 
        alert("Status: " + textStatus); alert("Error: " + errorThrown); 
      }
    });
    return insecureContent;
  },

  showInsecureContentWarning: function (showPreview, insecureContent, previewCallback) {
    var insecure_text, warning_footer, is_proceed_anyway;
    var isAdmin = jsStrings.isAdmin;
    var allowVulnerableContentByAdmin = jsStrings.allowVulnerableContentByAdmin;

    if(insecureContent["insecureUrls"].length && insecureContent["insecureSanitizedContent"] != '') 
      insecure_text = htmlContentEmbedderTranslations.insecureUrlAndContentWarning;
    else if(insecureContent["insecureUrls"].length)
      insecure_text = htmlContentEmbedderTranslations.insecureUrlWarning;
    else
      insecure_text = htmlContentEmbedderTranslations.insecureContentWarning;

    if(showPreview)
      insecure_text += htmlContentEmbedderTranslations.previewForCurrentContent;

    if((insecureContent["insecureUrls"].length && insecureContent["insecureSanitizedContent"] == '') || (isAdmin)) {
      warning_footer = htmlContentEmbedderTranslations.insecureWarningAdminFooter;
      is_proceed_anyway = true;
    }
    else {
      warning_footer = htmlContentEmbedderTranslations.insecureWarningOthersFooter;
      is_proceed_anyway = false;
    }

    var jqModal = jQuery(JST["templates/common/insecure_content_warning"]({
      warning_header: htmlContentEmbedderTranslations.insecureWarningHeader,
      warning_footer: warning_footer,
      insecure_warning_text: insecure_text,
      show_insecure_links: htmlContentEmbedderTranslations.showInsecureLinks,
      hide_insecure_links: htmlContentEmbedderTranslations.hideInsecureLinks,
      show_insecure_content: htmlContentEmbedderTranslations.showInsecureContent,
      hide_insecure_content: htmlContentEmbedderTranslations.hideInsecureContent,
      continue_editing_text: htmlContentEmbedderTranslations.continueEditingText,
      proceed_anyways_text: htmlContentEmbedderTranslations.proceedAnywaysText,
      ask_approach: htmlContentEmbedderTranslations.askApproach,
      system_clean: htmlContentEmbedderTranslations.systemClean,
      system_clean_short: htmlContentEmbedderTranslations.systemCleanShort,
      self_clean: htmlContentEmbedderTranslations.selfClean,
      dont_clean: htmlContentEmbedderTranslations.dontClean,
      rm_content_and_link: htmlContentEmbedderTranslations.rmContentAndLink,
      rm_links: htmlContentEmbedderTranslations.rmLinks,
      prompt_to_clean: htmlContentEmbedderTranslations.promptToClean,
      close: htmlContentEmbedderTranslations.close,
      ok: htmlContentEmbedderTranslations.ok,
      proceed: htmlContentEmbedderTranslations.proceed,
      preview_text: htmlContentEmbedderTranslations.previewText,
      show_preview_button: showPreview,
      is_proceed_anyway: is_proceed_anyway,
      has_insecure_urls: insecureContent["insecureUrls"].length,
      has_insecure_content: (insecureContent["insecureSanitizedContent"] != ''),
      isAdmin: isAdmin,
      allowVulnerableContentByAdmin: allowVulnerableContentByAdmin
    })).modal();

    ShowAndHideToggle('.cjs_insecure_warning_links_show_hide_container','.cjs_insecure_warning_links_show_hide_subselector');
    ShowAndHideToggle('.cjs_insecure_warning_content_show_hide_container','.cjs_insecure_warning_content_show_hide_subselector');

    if(showPreview) {
      jqModal.find('.cjs_insecure_content_warning_preview').on('click',function() {
        previewCallback();
      });
    }

    return jqModal;
  },

  hasInsecureContent: function (insecureContent) {
    return (insecureContent["insecureUrls"].length) || (insecureContent["insecureSanitizedContent"] != '')
  },

  listInsecureLinks: function  (insecureUrls) {
    var ulEle = jQuery('<ul/>');
    var liEle;
    jQuery.each(insecureUrls,function(index, value){
      liEle = jQuery('<li/>');
      linkEle = jQuery('<a/>').attr('target','_blank').attr('href',value).html(value).addClass("cjs_external_link");
      ulEle.append(liEle.append(linkEle));
    });
    return ulEle;
  },

  clearAllInsecureContentHandlingClasses: function(formElement) {
    formElement.find('.cjs_insecure_content_button_clicked').removeClass('cjs_insecure_content_button_clicked');
    formElement.removeClass('cjs_insecure_content_parsed');
  },

  /*
    The registerForInsecureContentCheck functions takes jquery form-element as input, registers eventhandlers in such a way that the data will be validated in all scenarios including the form containing multiple submit buttons, form submit getting triggered with ajax calls. 

    The function adds a class 'cjs_registered_for_insecure_checks' so that duplicate event handlers are not registered.

    After validating the data, if the user still wishes to continue, it will add 'cjs_insecure_content_parsed' class to the form. 

    The function registers a callback on modal close such that it resets all the classes added (to maintain state) by this function. This is useful when the form submit is done through ajax.
  */

  registerForInsecureWarningCallbacks: function(insecureContent,showPreview,previewCallback,proceedCallback,editor){

    jqModal = InsecureContentHelper.showInsecureContentWarning(showPreview, insecureContent,function () {
      previewCallback();
    });

    jqInsecureLinks = InsecureContentHelper.listInsecureLinks(insecureContent["insecureUrls"]);
    jqModal.find('.cjs_ckeditor_http_links').append(jqInsecureLinks);
    jqModal.find('.cjs_ckeditor_insecure_content').append(jQuery(insecureContent["insecureSanitizedContent"]));
    var dataHsh = {
      editor: editor,
      insecureContent: insecureContent,
      proceedCallback: proceedCallback
    };
    jqModal.find('.cjs_insecure_content_proceed_actions').on('click', dataHsh, function(event) {
      var approach = jQuery("input:radio[name=cjs_insecure_warnings_approach]:checked").val();
      if(approach == 'autoclean') {
        event.data.editor.setData(event.data.insecureContent.cleanContent); // editor is must, cannot be null (see new article media case)
        if(event.data.editor.name == "mailer_template_source") jQuery("#has_source_changed").val("true");
      }  
      if(approach == 'noclean' || approach == 'autoclean') event.data.proceedCallback();
    });
    return jqModal;
  },


  registerForInsecureContentCheck: function  (params) {
    var formElement = params.formElement;
    var readDataCallback = params.readDataCallback;
    var showPreview = params.showPreview; 
    var previewCallback = params.previewCallback;
    var editor = params.editor;

    if(formElement.hasClass('cjs_registered_for_insecure_checks'))
      return;

    formElement.addClass('cjs_registered_for_insecure_checks');

    formElement.find(':submit').on('click',function (event) {
      var thisElement = jQuery(this);
      if(thisElement.hasClass('cjs_insecure_content_button_clicked'))
        return true;

      thisElement.addClass('cjs_insecure_content_button_clicked');
    });

    formElement.on('submit', function (event) {
      var tags = CkeditorConfig.getCkeditorTags(readDataCallback());

      // insecure contents check will not be made if it has tags to be removed
      if(!jQuery(this).hasClass('cjs_ckeditor_dont_register_for_tags_warning') && tags.length > 0){
        return;
      }

      if(jQuery(this).hasClass('cjs_insecure_content_parsed'))
        return true;

      var data_to_analyze = readDataCallback();
      var insecureContent = InsecureContentHelper.checkForInsecureContent(data_to_analyze);
      if (InsecureContentHelper.hasInsecureContent(insecureContent))
      {
        event.preventDefault();
        event.stopPropagation();

        jqModal = InsecureContentHelper.registerForInsecureWarningCallbacks(insecureContent,
          showPreview,
          previewCallback,
          function() {
            formElement.addClass('cjs_insecure_content_parsed');

            // Find the clicked button. If it is an ajax submit, simply call the form.submit.
            clickedButton = formElement.find(':submit .cjs_insecure_content_button_clicked');
            if(clickedButton.length)
              clickedButton.trigger('click');
            else //Handle the cases where the form submit is triggered through ajax
              formElement.submit();
          },
          editor);

        jqModal.on('hidden', function  () {
          InsecureContentHelper.clearAllInsecureContentHandlingClasses(formElement);
          jQuery(this).remove();
        });

      }
    });
  },

  generalSettingsShowCkeditorInsecureWarning: function(editor,proceedCallback) {
    var content = editor.getData();
    var insecureContent = InsecureContentHelper.checkForInsecureContent(content);
    if(InsecureContentHelper.hasInsecureContent(insecureContent))
    {
      var jqModal = InsecureContentHelper.registerForInsecureWarningCallbacks(insecureContent,
        false,
        function() {
          editor.execCommand('preview');
        },
        proceedCallback,
        editor
      );
      jqModal.on('hidden', function  () {
        jQuery(this).remove();
      });
    }
    else
    {
      hideQtip();
      proceedCallback();
    }
  }
}
