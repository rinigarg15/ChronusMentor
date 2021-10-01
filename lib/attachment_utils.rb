module AttachmentUtils
  def self.copy_attachment(source_obj, destination_obj)
    destination_obj.attachment = source_obj.get_attachment
    destination_obj.attachment_content_type = source_obj.attachment_content_type
  end

  def self.get_remote_data(url)
    io = open(URI.parse(url))
    def io.original_filename; base_uri.path.split('/').last; end
    io.original_filename.blank? ? nil : io
  end
end