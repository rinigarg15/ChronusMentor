;(function(jQuery){
  function AjaxFileUploader(element) {
    // File field we are working with
    this.upload_field_wrapper = jQuery(element);
    this.upload_field_wrapper.data('instance', this);
    this.upload_field = this.upload_field_wrapper.find("input[type='file']");
    this.isUploadFieldRequired = false;
  };

  function wcagFixForLabel(element) {
    var labelElement = element.find('label').first();
    var inputElement = labelElement.find('input').first();
    var id = inputElement.attr('name') + Math.floor((Math.random() * 100) + 1);
    labelElement.attr('for', id);
    inputElement.attr('id', id);
  };

  AjaxFileUploader.prototype.removeRequiredField = function (field) {
    var self = this;
    var sectionId = field.data("section-id");
    var questionId = field.data("question-id");
    var answerFieldId = "profile_answers_" + questionId;

    var index = RequiredFields.fieldIds.indexOf(answerFieldId);
    var scopedIndex = RequiredFields.scopedFieldIds[sectionId] && RequiredFields.scopedFieldIds[sectionId].indexOf(answerFieldId);

    if (index != -1 || (scopedIndex != null && scopedIndex != -1)) {
      self.isUploadFieldRequired = true;
    }

    if (index != -1) {
      RequiredFields.fieldIds.splice(index, 1);
    }

    if (scopedIndex != null && scopedIndex != -1) {
      RequiredFields.removeScopedField(sectionId, answerFieldId);
    }
  };

  AjaxFileUploader.prototype.addRequiredField = function (field) {
    var sectionId = field.data("section-id");
    var questionId = field.data("question-id");
    var answerFieldId = "profile_answers_" + questionId;

    var index = RequiredFields.fieldIds.indexOf(answerFieldId);
    var scopedIndex = RequiredFields.scopedFieldIds[sectionId] && RequiredFields.scopedFieldIds[sectionId].indexOf(answerFieldId);

    if (index == -1) {
      RequiredFields.fieldIds.push(answerFieldId);
    }

    if (scopedIndex == null || scopedIndex == -1) {
      RequiredFields.addScopedField(sectionId, answerFieldId);
    }
  };

  AjaxFileUploader.prototype.success = function (filename, code, message) {
    var self = this;

    self.show_checkbox(filename);
    self.file_placeholder_text.html(message).attr('class', 'file-placeholder alert-success');
    self.file_placeholder.before(self.upload_field_wrapper).delay(3000).fadeOut();
    //wcag fix for label
    wcagFixForLabel(self.file_placeholder.parent());
    jQuery("input[type='submit']").removeAttr('disabled');
    self.file_question_code.val(code);
  };

  AjaxFileUploader.prototype.failed = function (filename, errors) {
    var self = this;

    self.upload_field.val('');
    self.file_placeholder_text.html(errors.join('<br/>')).attr('class', 'file-placeholder alert-danger')
    self.file_placeholder.before(self.upload_field_wrapper);
    //wcag fix for label
    wcagFixForLabel(self.file_placeholder.parent());
    jQuery("input[type='submit']").removeAttr('disabled');
    self.file_question_code.val('');
  };

  AjaxFileUploader.prototype.show_checkbox = function (filename) {
    var self = this;

    self.removeRequiredField(self.upload_field);
    self.upload_field_wrapper.hide();
    self.upload_field.attr('disabled', 'disabled');
    self.upload_field.val('');
    self.file_checkbox_label.find('span').html(filename);
    self.file_checkbox_label.show();
    self.file_checkbox.removeAttr('disabled').attr('checked', 'checked').val(filename);
  };

  AjaxFileUploader.prototype.set_filefield_on_change = function () {
    var self = this;

    self.upload_field.on('change', function () {
      if(self.upload_field.val() != '') {
        self.file_placeholder_text.html(jsCommonTranslations.fileUploadProgressText).attr('class', 'file-placeholder alert-success');
        self.file_placeholder.show();
        self.file_checkbox_label.hide();
        self.upload_form.append(self.upload_field_wrapper).submit();
        jQuery("input[type='submit']").attr('disabled', 'disabled');
      }
    });
  };

  AjaxFileUploader.prototype.initialize = function (file_uploading_path) {
    var self = this;

    var questionId = self.upload_field.data('question-id');
    self.original_form = self.upload_field.closest('form');

    // Hidden field for question uniq code
    self.file_question_code = jQuery('<input/>').
      attr('type', 'hidden').
      attr('value', '').
      attr('name', 'question_' + questionId + '_code');

    // Attach code field after file field
    self.upload_field_wrapper.after(self.file_question_code);

    // Checkbox for file-field
    self.file_checkbox = jQuery('<input/>').
      attr('type', 'checkbox').
      attr('value', '').
      attr('name', self.upload_field.attr('name')).
      attr('disabled', 'disabled');

    self.file_checkbox.on("change", function (){
      if(jQuery(this).is(":checked")) {
        self.show_checkbox(self.file_checkbox.val());
      } else {
        var questionId = self.upload_field.data("question-id");
        var deleteCheckBox = jQuery("#delete_check_box_" + questionId);

        if(self.isUploadFieldRequired && !deleteCheckBox.is(":checked")) {
          self.addRequiredField(self.upload_field);
        }

        self.upload_field.removeAttr("disabled");
        self.upload_field_wrapper.find(".remove-file").trigger("click");
        self.upload_field_wrapper.show();
      }
    });

    // For Edit Profile Page
    jQuery(".cjs_delete_file_link").on("click", function(){
      var checkBox = jQuery(this);
      var isChecked = checkBox.is(":checked");
      var questionId = checkBox.data("question-id");
      var deleteAllowed = checkBox.data("delete-allowed");
      fileContainer = jQuery("#edit_profile_upload_toggle_profile_answers_" + questionId);

      if(isChecked) {
        fileContainer.hide();
        self.removeRequiredField(checkBox);
      } else {
        fileContainer.show();
        deleteAllowed ? self.removeRequiredField(checkBox) : self.addRequiredField(checkBox);
      }
    });

    var small_for_checkbox = jQuery("<small class='ans_file'/>").
      append(self.file_checkbox);

    self.file_checkbox_label = jQuery('<div/>').append(jQuery('<label/>').
      attr('class', 'checkbox').
      append(jQuery('<span>')).
      // wcag fix for empty label content
      append(jQuery("<span class='hide'>Blank</span>")).
      append(small_for_checkbox)).
      hide();

    // Attach label right after file field
    self.upload_field_wrapper.after(self.file_checkbox_label);

    // File field placeholder
    self.file_placeholder_text = jQuery("<span>").attr('class', 'file-placeholder alert-success');
    self.file_placeholder = jQuery("<div>").hide().append(self.file_placeholder_text);

    // Attach placeholder right after label
    self.file_checkbox_label.after(self.file_placeholder);

    // Security token
    var token_field = jQuery('<input/>').
      attr('type', 'hidden').
      attr('name', jQuery("meta[name='csrf-param']").attr("content")).
      attr('value', jQuery("meta[name='csrf-token']").attr("content"))

    // Question field
    var question_field = jQuery('<input/>').
      attr('type', 'hidden').
      attr('name', 'question_id').
      attr('value', questionId);

    // Create new form for AJAX uploading
    self.upload_form = jQuery("<form/>").
      attr('method', 'post').
      attr('data-remote', 'true').
      attr('enctype', 'multipart/form-data').
      attr('action', file_uploading_path).
      hide().
      append(token_field).
      append(question_field);

    // Attach to the bottom of the HTML
    jQuery('body').append(self.upload_form);

    self.set_filefield_on_change();
  };

  jQuery.fn.initFileUploader = function(file_uploading_path) {
    return this.each(function() {
      var uploader = new AjaxFileUploader(this);
      uploader.initialize(file_uploading_path);
    });
  };

  jQuery.fn.successFileUploading = function(filename, code, message) {
    return this.each(function() {
      jQuery(this).data('instance').success(filename, code, message);
    });
  };

  jQuery.fn.failedFileUploading = function(filename, error_messages) {
    return this.each(function() {
      jQuery(this).data('instance').failed(filename, error_messages);
    });
  };

  jQuery.fn.simulateFileUploadSuccess = function(fileName, code) {
    jQuery(this).data('instance').success(fileName, code, "");
  };
})(jQuery);
