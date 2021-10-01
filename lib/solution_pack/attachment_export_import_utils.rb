module SolutionPack::AttachmentExportImportUtils

  include SolutionPack::ExportImportCommonUtils

  def self.handle_attachment_export(base_export_path, object, attachment_field_name)
    return unless object.send(attachment_field_name).exists?
    attachment_directory = "#{base_export_path}#{object.id}/"
    attachment_file_name = attachment_file_name || object.send("#{attachment_field_name.to_s}_file_name")

    SolutionPack.create_if_not_exist_with_permission(attachment_directory, 0777)
    open("#{attachment_directory}#{attachment_file_name}", 'wb') do |file|
      file << open(path_for_attachment(object.send(attachment_field_name).url, attachment_file_name)).read
    end
  end

  def self.handle_attachment_import(base_import_path, object, attachment_field_name, attachment_file_name, old_object_id)
    if attachment_file_name.present?
      src_file = "#{base_import_path}#{old_object_id}/#{attachment_file_name}"
      object.send("#{attachment_field_name}=", File.open(src_file)) if File.exist?(src_file)
    end
    object.save!
  end

  private
  def self.path_for_attachment(attachment_url, attachment_file_name)
    (Rails.env.test? || Rails.env.development?) ? "#{Rails.root.to_s}/public#{File.dirname(attachment_url)}/#{attachment_file_name}" : attachment_url
  end
end