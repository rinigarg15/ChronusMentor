//= require v3/plugins/dropzone.min

var DropzoneConfig = {

  fileNameFieldIdExtension: "_params_file_name",
  fileCodeFieldIdExtension: "_params_file_code",
  fileNameFieldNameExtension: "[file_name]",
  fileCodeFieldNameExtension: "[code]",
  fileAddedClass: "dropzone-file-added",
  dropzoneElementExtension: "_dropzone_wrapper",
  dropzoneFilePreviewElementExtension: "_dropzone_file_preview_element",
  oneMegaByte: 1048576,

  getDropzoneConfiguration: function(fileElement){
    var details = fileElement.data();
    var urlConfiguration = {
      url: details["url"],
      params: details["urlParams"],
      headers: { 'X-CSRF-Token': jQuery('meta[name="csrf-token"]').attr('content') }
    };
    var defaultMessage = isMobileOrTablet() ? jsCommonTranslations.clickToUpload : jsCommonTranslations.dragToUpload;
    var messageConfiguration = {
      dictDefaultMessage: defaultMessage,
      dictRemoveFile: jsCommonTranslations.remove,
      dictRemoveFileConfirmation: jsCommonTranslations.sureToRemove,
      dictCancelUploadConfirmation: jsCommonTranslations.sureToCancel,
      dictFileTooBig: details["maxFileSizeLimitMessage"],
      dictResponseError: jsCommonTranslations.commonErrorMessage,
      dictUploadCanceled: jsCommonTranslations.cancelled,
      dictInvalidFileType: jsCommonTranslations.contentTypeRestricted
    };
    var dropzoneConfiguration = {
      acceptedFiles: details["acceptedTypes"],
      clickable: true,
      thumbnailWidth: null,
      uploadMultiple: false,
      maxFilesize: details["maxFileSize"]/DropzoneConfig.oneMegaByte,
      previewTemplate: JST["templates/dropzone/preview_template"]()
    };
    return jQuery.extend(jQuery.extend(urlConfiguration, messageConfiguration), dropzoneConfiguration);
  },

  initializeDropzone: function(){
    Dropzone.autoDiscover = false;
    Dropzone.confirm = function(question, accepted, rejected) {
      chronusConfirm(question, accepted, rejected);
    };
    jQuery(".cjs-dropzone").each(function(index, fileElement){
      DropzoneConfig.createDropzone(jQuery(fileElement));
    });
  },

  handleDefaultFileRemoval: function(removeLink){
    chronusConfirm(jsCommonTranslations.sureToRemove, function(){
      jQuery("#"+jQuery(removeLink).data("hidePane")).hide();
      var dropzoneElement = jQuery("#"+jQuery(removeLink).data("showPane"));
      DropzoneConfig.setParamsFieldElement(dropzoneElement, { fileName: "" });
      dropzoneElement.show();
    }, function(){return false;})
  },

  initializeFileNamePreview: function(fileElement, initFileDetails){
    var fileNamePreviewElement = jQuery("#"+DropzoneConfig.getFileNamePreviewElementId(fileElement));
    fileNamePreviewElement.find('.file-name').html(initFileDetails["name"]);
    if(isMobileOrTablet()){
      fileNamePreviewElement.on("click", function(){
        DropzoneConfig.handleDefaultFileRemoval(this);
      });
    }else{
      fileNamePreviewElement.find('.remove-file-name').on("click", function(){
        DropzoneConfig.handleDefaultFileRemoval(this);
      });
    }
    return fileNamePreviewElement;
  },

  setInitialFile: function(fileElement, dropzoneElement){
    var initFileDetails = fileElement.data("init-file");
    if(initFileDetails === undefined){
      return;
    }
    var fileNamePreviewElement = DropzoneConfig.initializeFileNamePreview(fileElement, initFileDetails);
    jQuery("#"+DropzoneConfig.getdropzoneElementId(fileElement)).hide();
    fileNamePreviewElement.show();
    DropzoneConfig.setParamsFieldElement(dropzoneElement, { fileName: initFileDetails["name"] });
  },

  wrapFileElement: function(fileElement){
    var wrapperElement = JST["templates/dropzone/wrapper_element"]({
      fileNameFieldElementId: DropzoneConfig.getFileNameFieldElementId(fileElement),
      fileCodeFieldElementId: DropzoneConfig.getFileCodeFieldElementId(fileElement),
      dropzoneElementId: DropzoneConfig.getdropzoneElementId(fileElement),
      fileNamePreviewElementId: DropzoneConfig.getFileNamePreviewElementId(fileElement),
      classList: fileElement.data("class-list")
    });
    fileElement.replaceWith(wrapperElement);
  },

  getDropzone: function(fileElement){
    var dropzone = new Dropzone(
      "#"+DropzoneConfig.getdropzoneElementId(fileElement),
      DropzoneConfig.getDropzoneConfiguration(fileElement)
    );
    DropzoneConfig.initializeDropzoneEvents(dropzone);
    return dropzone;
  },

  createDropzone: function(fileElement){
    DropzoneConfig.createParamsFieldElements(fileElement);
    DropzoneConfig.wrapFileElement(fileElement);
    var dropzone = DropzoneConfig.getDropzone(fileElement);
    DropzoneConfig.handleFastClick();
    DropzoneConfig.setInitialFile(fileElement, jQuery(dropzone.element));
  },

  initializeDropzoneEvents: function(dropzone){

    dropzone.on("addedfile", function(){
      if(this.files.length > 1){
        this.removeFile(this.files[0]);
      }
      var dropzoneElement = jQuery(this.element);
      dropzoneElement.addClass(DropzoneConfig.fileAddedClass);
    });

    dropzone.on("success", function(file, response) {
      var dropzoneElement = jQuery(this.element);
      DropzoneConfig.setParamsFieldElement(dropzoneElement, { "fileName" : file.name, "fileCode" : response });
    });

    dropzone.on("removedfile", function(file) {
      var dropzoneElement = jQuery(this.element);
      dropzoneElement.removeClass(DropzoneConfig.fileAddedClass);
      DropzoneConfig.setParamsFieldElement(dropzoneElement, { "fileName" : "", "fileCode" : "" });
    });

    dropzone.on("error", function(file, response) {
      this.removeFile(file);
      ChronusValidator.ErrorManager.ShowResponseFlash("", response);
    });
  },

  createParamsFieldElements: function(fileElement){
    var paramsFieldElements = JST["templates/dropzone/file_field_inputs"]({
      fileNameFieldElementId: DropzoneConfig.getFileNameFieldElementId(fileElement),
      fileNameFieldElementName: DropzoneConfig.getFileNameFieldElementName(fileElement),
      fileCodeFieldElementId: DropzoneConfig.getFileCodeFieldElementId(fileElement),
      fileCodeFieldElementName: DropzoneConfig.getFileCodeFieldElementName(fileElement)
    });
    fileElement.closest("form").append(paramsFieldElements);
  },

  setParamsFieldElement: function(dropzoneElement, value){
    jQuery("#"+dropzoneElement.data("fileNameFieldElementId")).val(value["fileName"]);
    jQuery("#"+dropzoneElement.data("fileCodeFieldElementId")).val(value["fileCode"]);
  },

  getFileNameFieldElementId: function(fileElement){
    return fileElement.attr("id")+DropzoneConfig.fileNameFieldIdExtension;
  },

  getFileCodeFieldElementId: function(fileElement){
    return fileElement.attr("id")+DropzoneConfig.fileCodeFieldIdExtension;
  },

  getFileNameFieldElementName: function(fileElement){
    return fileElement.attr("name")+DropzoneConfig.fileNameFieldNameExtension;
  },

  getFileCodeFieldElementName: function(fileElement){
    return fileElement.attr("name")+DropzoneConfig.fileCodeFieldNameExtension;
  },

  getdropzoneElementId: function(fileElement){
    return fileElement.attr("id")+DropzoneConfig.dropzoneElementExtension;
  },

  getFileNamePreviewElementId: function(fileElement){
    return fileElement.attr("id")+DropzoneConfig.dropzoneFilePreviewElementExtension;
  },

  handleFastClick: function(){
    jQuery(".dz-default").addClass("needsclick");
    jQuery(".dz-default > span").addClass("needsclick");
  }
}