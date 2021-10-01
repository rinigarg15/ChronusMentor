//= require ckeditor/init

var CkeditorConfig = {
  registerForTagsWarnings: function(params){
    var formElement = params.formElement;
    var readDataCallback = params.readDataCallback;
    var editor = params.editor;

    formElement.on('submit', function(event) {
      var tags = CkeditorConfig.getCkeditorTags(readDataCallback());
      if(tags.length > 0)
      {
        event.preventDefault();
        event.stopPropagation();
        CkeditorConfig.registerForTagsCallbacks(tags, editor);
      }
    });
  },

  getCkeditorTags: function(data){
    tags = data.unescapeHTML().match(/{{(.*?)}}/g);
    return tags ? tags.uniq() : []
  },

  registerForTagsCallbacks: function(tags, editor){
    jqModal = CkeditorConfig.showTagsWarningModal(tags);
    jqModal.find('.cjs_ckeditor_tags_content').text(tags);
  },

  showTagsWarningModal: function(tags){
    var jqModal = jQuery(JST["templates/common/ckeditor_prevent_tags"]({
      warning_header: htmlContentEmbedderTranslations.tagsWarningHeader,
      tags_warning_text: htmlContentEmbedderTranslations.tagsWarningText,
      ok: htmlContentEmbedderTranslations.ok,
    })).modal();

    ShowAndHideToggle('.cjs_tags_warning_links_show_hide_container','.cjs_tags_warning_links_show_hide_subselector');
    ShowAndHideToggle('.cjs_tags_warning_content_show_hide_container','.cjs_tags_warning_content_show_hide_subselector');
    return jqModal;
  },

  generalSettingsShowTagsWarning: function(editor) {
    var content = editor.getData();
    var tags = CkeditorConfig.getCkeditorTags(content);
    (tags.length > 0) ? CkeditorConfig.registerForTagsCallbacks(tags, editor) : hideQtip();
  },

  ckEditorModalMapping: {
    admin_message_content: "new_admin_message_popup",
    agreement_text: "modal_add_agreement_link",
    privacy_text: "modal_add_privacy_link",
    browser_warning_text: "cjs_add_browser_warning_link_popup"
  },

  filebrowserOptions: {
    filebrowserBrowseUrl: "/ckeditor/attachment_files",
    filebrowserFlashBrowseUrl: "/ckeditor/attachment_files",
    filebrowserFlashUploadUrl: "/ckeditor/attachment_files",
    filebrowserImageBrowseLinkUrl: "/ckeditor/pictures",
    filebrowserImageBrowseUrl: "/ckeditor/pictures",
    filebrowserImageUploadUrl: "/ckeditor/pictures",
    filebrowserUploadUrl: "/ckeditor/attachment_files"
  },

  disableBrowseServerOptions:{
    filebrowserBrowseUrl : "",
    filebrowserFlashBrowseUrl : "",
    filebrowserImageBrowseLinkUrl : "",
    filebrowserImageBrowseUrl : ""
  },

  ckOptions: {
    baseFloatZIndex: 2100,	//should be same as .modal-dialog and .cke_dialog
    enterMode      : CKEDITOR.ENTER_BR,
    language       : jsCommonTranslations.i18nLocale,
    disableNativeSpellChecker : jsCommonTranslations.i18nLocale !== "en",// Set Native Browser Spell Check highlight only if the language is english, not enabling it since the french/other language users have to install the particular dictionaries in the browser and they will have all their other language text highlighted
    //customConfig : '',
    extraPlugins : 'mediaembed,strinsert,font,justify,colorbutton,flash,pagebreak,preview', //preview plugin code modified by  ARUNKUMAR N @arunn. The preview is a sanitized preview. The sanitization is done at the server level.
    removePlugins: 'elementspath',
    width: 'auto',
    allowedContent: {
      $1: {
        elements: CKEDITOR.dtd, attributes: true, styles: true, classes: true
      }
    },
    extraAllowedContent: {
      a: {
        attributes: '_cke_saved_href'
      }
    },
    toolbar_Minimal : [
      { name: 'basicstyles', items : ['Bold','Italic','Underline'] },
      { name: 'list', items : ['NumberedList','BulletedList'] },
      { name: 'links', items : ['Link','Unlink'] }
    ],
    toolbar_Default : [
      { name: 'basicstyles', items : ['Bold','Italic','Underline'] },
      { name: 'list', items : ['NumberedList','BulletedList','Outdent','Indent','Blockquote'] },
      { name: 'align', items : ['JustifyLeft','JustifyCenter','JustifyRight','JustifyBlock'] },
      { name: 'styles', items : ['Format'] },
      { name: 'links', items : ['Link','Unlink'] },
      { name : 'insert', items : ['Table', 'Image'] },
      { name: 'clipboard', items : ['Cut','Copy','Paste','PasteText','PasteFromWord'] },
      { name: 'document', items : ['Source','-','Preview'] }
    ],
    toolbar_Without_Preview : [
      { name: 'basicstyles', items : ['Bold','Italic','Underline','Strike','-','Subscript','Superscript','-','RemoveFormat'] },
      { name: 'list', items : ['NumberedList','BulletedList','-','Outdent','Indent','Blockquote'] },
      { name: 'align', items : ['JustifyLeft','JustifyCenter','JustifyRight','JustifyBlock'] },
      { name: 'styles', items : ['Format','Font','FontSize'] },
      { name: 'colors', items : ['TextColor', 'BGColor'] },
      { name: 'links', items : ['Link','Unlink','Anchor'] },
      { name: 'insert', items : ['Image','Flash','MediaEmbed','-','Table','HorizontalRule','SpecialChar','PageBreak'] },
      { name: 'editing', items : ['SelectAll'] },
      { name: 'clipboard', items : ['Cut','Copy','Paste','PasteText','PasteFromWord'] },
      { name: 'undo', items: ['Undo','Redo'] },
      { name: 'document', items :['Source'] }
    ],
    toolbar_Advanced : [
      { name: 'basicstyles', items : ['Bold','Italic','Underline','Strike','-','Subscript','Superscript','-','RemoveFormat'] },
      { name: 'list', items : ['NumberedList','BulletedList','-','Outdent','Indent','Blockquote'] },
      { name: 'align', items : ['JustifyLeft','JustifyCenter','JustifyRight','JustifyBlock'] },
      { name: 'styles', items : ['Format','Font','FontSize'] },
      { name: 'colors', items : ['TextColor', 'BGColor'] },
      { name: 'links', items : ['Link','Unlink','Anchor'] },
      { name: 'insert', items : ['Image','Flash','MediaEmbed','-','Table','HorizontalRule','SpecialChar','PageBreak'] },
      { name: 'editing', items : ['SelectAll'] },
      { name: 'clipboard', items : ['Cut','Copy','Paste','PasteText','PasteFromWord'] },
      { name: 'undo', items: ['Undo','Redo'] },
      { name: 'document', items :['Source','-','Preview'] }
    ],
    toolbar_Mobile : [
      { name: 'basicstyles', items : ['Bold','Italic','Underline'] },
      { name: 'list', items : ['NumberedList','BulletedList','-','Outdent','Indent','Blockquote'] },
      { name: 'links', items : ['Link','Unlink'] },
      { name: 'styles', items : ['Format'] }
    ]
  },

  getCkOptions: function(){
    return jQuery.extend(true, CkeditorConfig.ckOptions, CkeditorConfig.filebrowserOptions);
  },

  adminCkOptions: function(){ return jQuery.extend(true, { toolbar : 'Default'}, CkeditorConfig.getCkOptions());},
  enduserCkOptions: function(){ return jQuery.extend(true, {}, CkeditorConfig.adminCkOptions(), CkeditorConfig.disableBrowseServerOptions);},

  // Use defaultCkOptions unless you are sure otherwise
  defaultCkOptions: function(){
    return ((UserInfo.isProgramAdmin == 'true' || UserInfo.isOrganizationAdmin == 'true') ? CkeditorConfig.adminCkOptions() : CkeditorConfig.enduserCkOptions());
  },

  fullCkOptions: function(){
    return jQuery.extend(true, { toolbar : 'Advanced'}, CkeditorConfig.getCkOptions());
  },

  fullCkOptionsWithAppStylesInEditMode: function(){
    return jQuery.extend(true, CkeditorConfig.fullCkOptions(), { extraPlugins : CkeditorConfig.ckOptions['extraPlugins'] + ',divarea', toolbar: 'Without_Preview'});
  },

  defaultCkOptionsWithAppStylesInEditMode: function(){
    return jQuery.extend(true, CkeditorConfig.fullCkOptions(), { extraPlugins : CkeditorConfig.ckOptions['extraPlugins'] + ',divarea', toolbar: 'Default'});
  },

  minimalCkOptions: function(){
    if (UserInfo.isProgramAdmin == 'true' || UserInfo.isOrganizationAdmin == 'true') {
      return jQuery.extend(true,  {toolbar : 'Minimal'}, CkeditorConfig.getCkOptions());
    }else{
      return jQuery.extend(true,  {toolbar : 'Minimal'}, CkeditorConfig.getCkOptions(), CkeditorConfig.disableBrowseServerOptions);
    }
  },

  mobileCkOptions: function() {
    return jQuery.extend(true,  {toolbar : 'Mobile'}, CkeditorConfig.getCkOptions(), CkeditorConfig.disableBrowseServerOptions);
  },

  initCkeditor: function(selector, options, ckoptions, isMinimal){
    if(!isMinimal && UserInfo.isMobileApp == 'true')
      ckoptions = CkeditorConfig.mobileCkOptions();
    var element = jQuery(selector);
    if(element.length == 1){
      if(UserInfo.isMobileApp == 'true') {
        element.css("visibility", "hidden");
        setTimeout(function() { CKEDITOR.replace(element.attr('id'), jQuery.extend(true, {}, ckoptions, options)) }, 1500);
      }
      else {
        CKEDITOR.replace(element.attr('id'), jQuery.extend(true, {}, ckoptions, options));
      }
    }
  },

  dropdownCkOptions: function(){
    var options = CkeditorConfig.defaultCkOptions();
    options.toolbar_Default.push({ name: 'strinsert', items : ['strinsert'] });
    return options;
  },

  ckeditorConfigure: function(){
    CkeditorConfig.initCkeditor('#article_body', {height : "300px"}, CkeditorConfig.defaultCkOptions());
    CkeditorConfig.initCkeditor('#new_announcement_body', {height : "250px"}, CkeditorConfig.defaultCkOptionsWithAppStylesInEditMode());
    CkeditorConfig.initCkeditor('#announcement_message_body', {height : "250px"} , CkeditorConfig.defaultCkOptionsWithAppStylesInEditMode());
    CkeditorConfig.initCkeditor('#campaign_management_abstract_campaign_message_mailer_template_source', {height : "200px"}, CkeditorConfig.dropdownCkOptions());
    CkeditorConfig.initCkeditor('#program_overview_content', {height : "350px"}, CkeditorConfig.fullCkOptionsWithAppStylesInEditMode());
    CkeditorConfig.initCkeditor('#resource_content', {height : "350px"}, CkeditorConfig.fullCkOptions());
    CkeditorConfig.initCkeditor('#mailer_template_source', {height : "350px"}, CkeditorConfig.defaultCkOptions());
    CkeditorConfig.initCkeditor('#new_program_event_details', {height : "250px"}, CkeditorConfig.fullCkOptions());
    CkeditorConfig.initCkeditor('#message', {height : "250px"}, CkeditorConfig.defaultCkOptions());
    CkeditorConfig.initCkeditor('#mentor_request_instruction_content', {height : "250px"}, CkeditorConfig.minimalCkOptions());
    CkeditorConfig.initCkeditor("#cjs_auth_config_password_message", { height: "250px" }, CkeditorConfig.minimalCkOptions());
    CkeditorConfig.initCkeditor('.cjs_admin_message_content', {height : "250px"}, CkeditorConfig.defaultCkOptions());

    if (!jQuery('#mailer_widget_source').data("skip-ckeditor")) CkeditorConfig.initCkeditor('#mailer_widget_source', {height : "200px"}, CkeditorConfig.defaultCkOptions());
  },

  initializeTopicBody: function(instance) {
    if (CKEDITOR.instances[instance] == undefined) {
      CkeditorConfig.initCkeditor("#" + instance, { height : "200px" }, CkeditorConfig.minimalCkOptions());
    }
  },

  agreementTextInitialize: function() {
    if (CKEDITOR.instances['agreement_text'] == undefined ) {
      CkeditorConfig.initCkeditor('#agreement_text', {height : "200px"}, CkeditorConfig.defaultCkOptions());
      ProgramAgreement.discardChanges();
    }
  },

  browserWarningTextInitialize: function() {
    if (CKEDITOR.instances['browser_warning_text'] == undefined ) {
      CkeditorConfig.initCkeditor('#browser_warning_text', {}, CkeditorConfig.defaultCkOptions());
      BrowserWarning.discardChanges();
    }
  },

  privacyTextInitialize: function() {
    if(CKEDITOR.instances['privacy_text'] == undefined ) {
      CkeditorConfig.initCkeditor('#privacy_text', {height : "200px"}, CkeditorConfig.defaultCkOptions());
      ProgramPrivacy.discardChanges();
    }
  },

  messageReplyTextInitialize: function(program_invitation_id) {
    CkeditorConfig.initCkeditor("#program_invitation_message_"+program_invitation_id, {height : "250px"}, CkeditorConfig.defaultCkOptions());
  }
};

CKEDITOR.on('dialogDefinition', function(ev) {
  // Take the dialog window name and its definition from the event data.
  var dialogName = ev.data.name;
  var dialogDefinition = ev.data.definition;
  if(dialogName == 'link') {
    /* Getting the contents of the info tab and changing protocol to other as a default option*/
    var protocol = dialogDefinition.getContents('info').get('protocol');
    protocol['default'] = '';

    // Setting the target type as 'notSet' when 'Link to anchor in the text option' is selected and '_blank' otherwise.
    var linkType = dialogDefinition.getContents('info').get('linkType');
    var currentLinkTypeOnChangeFunction = linkType['onChange'];
    linkType['onChange'] = function(){
      currentLinkTypeOnChangeFunction.call(this);

      var targetTypeElement = this.getDialog().getContentElement('target', 'linkTargetType');
      if(this.getValue() == 'anchor'){
        targetTypeElement.setValue("notSet");
      } else {
        targetTypeElement.setValue("_blank");
      }
    }
  } else if(dialogName == 'image') {
    var targetTab = dialogDefinition.getContents('Link');
    var targetField = targetTab.get('cmbTarget');
    targetField['default'] = '_blank';

    // WCAG Compliance - Link must have a discernible text
    dialogDefinition.dialog.on('show', function() {
      setLabelForCKEditorImagePreviewLink();
    });
  }
});

CKEDITOR.on('instanceReady',function  (event) {
  var editor = event.editor;
  var editorContainerId = editor.element.getAttribute('id');
  // Outlook expects image width and height as attributes. So disallowing the styles. AP-14878. Refer:
  // 1. http://stackoverflow.com/questions/2051896/ckeditor-prevent-adding-image-dimensions-as-a-css-style
  // 2. http://docs.ckeditor.com/#!/api/CKEDITOR.filter.transformationsTools-method-sizeToAttribute
  editor.filter.addTransformations([['img: sizeToAttribute']]);

  if (navigator.userAgent.toLowerCase().match(/iphone|ipod|ipad/)) {
    editor.on("focus", function(ev) {
      jQuery(".navbar-fixed-top").css({"position": "absolute", "top": "-" + jQuery('.navbar-fixed-top').outerHeight().toString() + "px"});
    });

    editor.on("blur", function(ev) {
      jQuery(".navbar-fixed-top").css({"position": "fixed", "top": "0"});
    });
  }

  var formElement = jQuery("#"+editorContainerId).closest('form');

  if(!formElement.hasClass('cjs_ckeditor_dont_register_for_tags_warning')) {
    CkeditorConfig.registerForTagsWarnings({
      formElement: formElement,
      readDataCallback: function(){
        return editor.getData();
      },
      editor: editor
    });
  }

  if(!formElement.hasClass('cjs_ckeditor_dont_register_for_insecure_content'))
  {
    InsecureContentHelper.registerForInsecureContentCheck({
      formElement: formElement,
      readDataCallback: function () {
        return editor.getData();
      },
      showPreview: false,
      previewCallback: function() {
        editor.execCommand('SanitizedPreview');
      },
      editor: editor
    });
  }

  var modalElement = document.getElementById(CkeditorConfig.ckEditorModalMapping[editorContainerId]);
  if(modalElement){
    var modalCkEditorElement = new CKEDITOR.dom.element(modalElement);
    var ckEditorToolbarItems = editor.ui.items;
    for(var key in ckEditorToolbarItems){
      var toolbarItem = ckEditorToolbarItems[key];
      if(toolbarItem.type ==  CKEDITOR.UI_RICHCOMBO){
        toolbarItem.panel.parent = modalCkEditorElement;
      }
    }
  }
});

jQuery(document).ready(function() {
    CkeditorConfig.ckeditorConfigure();
    if(document.getElementById("inner_content"))
      document.getElementById("inner_content").style.filter=""; // IE8 Fix for invisible menu colors
});

/*
  removeEmpty: empty <i> tags should not be removed by default.
  protectedSource: To prevent ckedior from removing <i> tags on toggling 'Source', which it does by default.
*/

CKEDITOR.dtd.$removeEmpty['i'] = false;
CKEDITOR.config.protectedSource.push(/<i[^>]*><\/i>/g);

/*
//Run this script on browser console to get list of allowed tags and attrubutes by that ckeditor instance
//Use the returned values to sanitize the output of ckeditor in rails views/controllers

//Any change in ckeditor options change the corresponding santize helpers

Array.prototype.unique = function(){
    var tmp = {}, out = [];
    for(var i = 0, n = this.length; i < n; ++i){
        if(!tmp[this[i]]) { tmp[this[i]] = true; out.push(this[i]); }
    }
    return out;
}

var instance = 'mailer_template_source'; #TO find this type CKEDITOR.instances
var attr =[]; var tags = [];
jQuery.each(CKEDITOR.instances[instance].filter.allowedContent, function(i,ac){
  //console.log(ac);
  if(ac.attributes){
    if(ac.attributes === true){
      // Allow all attributes - Happens only for iframe tags from mediaembed plugin
      console.log(ac.elements);
    }else{
      var as = Object.keys(ac.attributes);
      jQuery.each(as,function(i,v){
        if(ac.attributes[v]){ attr.push(v)};
      });
    }
  }
  if(ac.elements){
    var el = Object.keys(ac.elements);
    jQuery.each(el,function(i,v){
      if(ac.elements[v]){ tags.push(v)};
    })
  }
});
var tags= tags.unique().sort();
var attr = attr.unique().sort();
console.log(tags.join(' '));
console.log(attr.join(' '));

*/