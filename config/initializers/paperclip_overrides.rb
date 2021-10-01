# Recent versions of paperclip add errors to both base attribute and secondary attributes like content type, earlier
# the errors were added only to the latter. This patch ensures that the errors are added only to secondary attributes.
# https://github.com/thoughtbot/paperclip/commit/2aeb491fa79df886a39c35911603fad053a201c0
# https://github.com/thoughtbot/paperclip/pull/1554
module PaperclipValidatorsRemoveBaseAttrDuplicateErrorMsg
  def validate_each(record, attr_name, value)
    ret = super
    record.errors.messages.keys.reject do |key|
      key == attr_name || record.errors.messages[attr_name].blank? || record.errors.messages[key].blank?
    end.each do |key|
      record.errors.messages[attr_name] -= record.errors.messages[key]
    end
    ret
  end
end

Paperclip::Validators::AttachmentContentTypeValidator.prepend(PaperclipValidatorsRemoveBaseAttrDuplicateErrorMsg)
Paperclip::Validators::AttachmentFileNameValidator.prepend(PaperclipValidatorsRemoveBaseAttrDuplicateErrorMsg)
Paperclip::Validators::AttachmentFileTypeIgnoranceValidator.prepend(PaperclipValidatorsRemoveBaseAttrDuplicateErrorMsg)
Paperclip::Validators::AttachmentSizeValidator.prepend(PaperclipValidatorsRemoveBaseAttrDuplicateErrorMsg)

module Paperclip
  # Using our own implemented filename updater function (ie, :transliterate_file_name)
  ClassMethods.module_eval do
    def has_attached_file(name, options = {})
      options.reverse_merge!(restricted_characters: nil)
      HasAttachedFile.define_on(self, name, options)
    end
  end

  # Spoof detection is not working properly, disabling it
  # https://github.com/thoughtbot/paperclip/issues/1429
  MediaTypeSpoofDetector.class_eval do
    def spoofed?; false; end
  end

  # Preserving the previous mime type calculation approach for now, this needs further analysis and update later
  ContentTypeDetector.class_eval do
    def calculated_type_matches
      possible_types
    end
  end

  UploadedFileAdapter.class_eval do
    def content_type_detector
      self.class.content_type_detector
    end
  end

end

# Porting the below changes from previously named file - paperclip_stuff.rb

# This patch will enable us to generate url based on our customized expires_in option

DEFAULT_SECURE_S3_FILE_EXPIRY_TIME = 5.minutes

#using aws-sdk v1 (which supports signature version 4 for EU Frankfurt region)
Paperclip.interpolates(:s3_secured_url) do |attachment, style|
  attachment.s3_object(style).presigned_url(:get,:expires_in => attachment.options[:expires_in] || DEFAULT_SECURE_S3_FILE_EXPIRY_TIME, :secure => true)
end

Paperclip.interpolates(:translation_id) do |attachment, style|
  attachment.instance.translations.where(:locale => I18n.locale).first.try(:id)
end

Paperclip::Attachment.class_eval do
  def content
    Paperclip.io_adapters.for(self).read
  end
end