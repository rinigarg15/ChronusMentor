module Common::RakeModule::DataExporter

  def self.fetch_data_and_store_in_s3(objects, columns_for_export, program, download_attachments = false, attachment_download_options = {})
    if objects.blank?
      Common::RakeModule::Utils.print_alert_messages("No objects found!")
    else
      klass_name = objects.first.class.name
      base_directory = "/tmp/#{Time.now.to_i}_#{SecureRandom.uuid}_data_exporter/#{klass_name.downcase}"
      s3_prefix = "custom_data_exports/#{Rails.env}/#{program.id}/#{klass_name}"
      messages = []

      begin
        FileUtils.mkdir_p(base_directory)
        csv_file_in_local = File.join(base_directory, "data.csv")
        self.generate_csv(objects, columns_for_export, csv_file_in_local)
        csv_file_in_s3 = ChronusS3Utils::S3Helper.store_in_s3(csv_file_in_local, s3_prefix)
        messages << "#{klass_name} CSV Export In: #{csv_file_in_s3} - Validity: 7 days"

        if download_attachments.try(:to_boolean)
          attachments_directory = File.join(base_directory, "attachments")
          zip_file_in_local = self.download_and_zip_attachments(objects, program, attachments_directory, attachment_download_options)
          zip_file_in_s3 = ChronusS3Utils::S3Helper.store_in_s3(zip_file_in_local, s3_prefix, content_type: "application/zip")
          messages << "#{klass_name} Attachments In: #{zip_file_in_s3} - Validity: 7 days"
        end
      ensure
        FileUtils.rm_rf(base_directory)
      end
      Common::RakeModule::Utils.print_success_messages(messages)
    end
  end

  private

  def self.generate_csv(objects, columns_for_export, file_path)
    CSV.open(file_path, "w") do |csv|
      csv << columns_for_export.keys
      objects.find_each do |object|
        csv << columns_for_export.values.map { |proc_or_symbol| proc_or_symbol.to_proc.call(object) }
      end
    end
  end

  def self.download_and_zip_attachments(objects, program, attachments_directory, options = {})
    options.reverse_merge!({
      columns: [:attachment],
      embed_columns: [:body],
      organization_url: program.organization.url,
      id_to_ck_asset_map: Ckeditor::Asset.where(program_id: program.parent_id).index_by(&:id)
    })

    objects.find_each do |object|
      options[:columns].each { |column| download_to_file(object.send(column), object, attachments_directory) }
      options[:embed_columns].each do |embed_column|
        value = object.send(embed_column)
        if value.present?
          links = SolutionPack::CkeditorExportImportUtils.scan_ckeditor_links(options[:organization_url], value)
          links.each do |link|
            attachment = options[:id_to_ck_asset_map].try(:[], link[1].to_i).try(:data)
            download_to_file(attachment, object, attachments_directory, link.join("_"))
          end
        end
      end
    end
    SolutionPack::ExportImportCommonUtils.zip_all_files_in_dir(attachments_directory)
  end

  def self.download_to_file(attachment, object, attachments_directory, file_name_without_extension = "")
    return unless attachment.try(:exists?)

    file_name = file_name_without_extension.present? ? "#{file_name_without_extension}#{File.extname(attachment.original_filename)}" : attachment.original_filename
    file_path = File.join(attachments_directory, object.id.to_s, file_name)
    FileUtils.mkdir_p(File.dirname(file_path))
    data = open(URI.parse(attachment.url))
    File.open(file_path, 'wb') { |file| file.write(data.read) }
  end
end