module SolutionPack::CkeditorExportImportUtils
  INVALID_URL = "<INVALID_ATTACHMENT_URL>"

  include SolutionPack::ExportImportCommonUtils
  def self.handle_ck_editor_export(program, content, solution_pack)
    return if content.nil?
    self.handle_ck_editor_export_without_solution_pack(program.organization.url, content, solution_pack.exported_ck_assets, solution_pack.all_ck_assets, solution_pack.ckeditor_base_path)
  end

  def self.handle_ck_editor_export_without_solution_pack(url, content, exported_ck_assets, all_ck_assets, ckeditor_base_path)
    links = scan_ckeditor_links(url, content)
    links.each do |link|
      asset_id = link[1].to_i
      unless exported_ck_assets.include?(asset_id)
        ckeditor_asset = all_ck_assets.select{|asset| asset.id == asset_id}.first
        image_directory = "#{ckeditor_base_path}#{asset_id}/"
        SolutionPack.create_if_not_exist_with_permission(image_directory, 0777)
        if ckeditor_asset.present? && ckeditor_asset.data.exists?
          open("#{image_directory}#{ckeditor_asset.data_file_name}", 'wb') do |file|
            file << open(self.get_object_file_path(ckeditor_asset.path_for_ckeditor_asset)).read
          end
        end
        exported_ck_assets << asset_id
      end
    end
  end

  def self.handle_ck_editor_import_without_solution_pack(ckeditor_old_base_url, content, imported_ck_assets, ckeditor_asset_column_names, ckeditor_asset_rows, ckeditor_base_path, organization, options = {})
    file_name_index = ckeditor_asset_column_names.index("data_file_name")
    login_required_index = ckeditor_asset_column_names.index("login_required")
    id_index = ckeditor_asset_column_names.index("id")
    file_path_index = ckeditor_asset_column_names.index("url")

    new_base_url = organization.url(true)

    links = scan_ckeditor_links(ckeditor_old_base_url, content)
    links.each do |link|
      old_asset_id = link[1].to_i
      old_url = "#{ckeditor_old_base_url}/#{link[0]}/#{old_asset_id}"
      if content.index(old_url).present?
        unless imported_ck_assets[old_asset_id.to_s].present?
          asset_type = ckeditor_asset_type(link[0])
          asset_details = get_row_with_id(ckeditor_asset_rows, old_asset_id, id_index)
          if asset_details.present?
            data_file_name = asset_details[file_name_index]
            file_path = file_path_index && !options[:is_sales_demo] ? self.get_object_file_path(asset_details[file_path_index]) : "#{ckeditor_base_path}#{old_asset_id}/#{data_file_name}"
            login_required = asset_details[login_required_index] == "true" ? true : false
            asset = create_ckeditor_asset(organization, asset_type, file_path, login_required)
          end
          imported_ck_assets[old_asset_id.to_s] = asset.id if asset.present?
        end

        replace_content = if imported_ck_assets[old_asset_id.to_s].present?
          "#{new_base_url}/#{link[0]}/#{imported_ck_assets[old_asset_id.to_s]}"
        else
          options[:from_solution_pack] ? INVALID_URL : "#"
        end
        content = content.gsub("http://#{old_url}", replace_content)
        content = content.gsub("https://#{old_url}", replace_content)
      end
    end
    return content
  end

  def self.handle_ck_editor_import(program, solution_pack, content, ckeditor_asset_column_names, ckeditor_asset_rows)
    return if content.nil?
    return self.handle_ck_editor_import_without_solution_pack(solution_pack.ckeditor_old_base_url, content, solution_pack.imported_ck_assets, ckeditor_asset_column_names, ckeditor_asset_rows, solution_pack.ckeditor_base_path, program.organization, { from_solution_pack: true, is_sales_demo: solution_pack.is_sales_demo })
  end

  def self.scan_ckeditor_links(org_url, content)
    return content.scan(/#{org_url}[\/](ck_attachments|ck_pictures)[\/](\d+)/)
  end

  def self.create_ckeditor_asset(organization, asset_type, file_path, login_required)
    return unless file_path =~ /http(s?):\/\// || File.exists?(file_path)
    asset = asset_type.new
    asset.data = open(file_path)
    asset.organization = organization
    asset.login_required = login_required
    asset.save!
    return asset
  end

  def self.ckeditor_asset_type(type)
    return Ckeditor.attachment_file_model if type == "ck_attachments"
    return Ckeditor.picture_model if type == "ck_pictures"
    return nil
  end

  def self.get_row_with_id(ckeditor_asset_rows, id, id_index)
    return nil if id.blank?
    ckeditor_asset_rows.each do |row|
      return row if row[id_index].to_s == id.to_s
    end
    return nil
  end

  def self.get_object_file_path(object_details)
    object_details = YAML.load(object_details)
    return object_details unless object_details.is_a?(Hash)
    ChronusS3Utils::S3Helper.get_object_link(object_details[:bucket_name], object_details[:key], region: object_details[:region])
  end

end