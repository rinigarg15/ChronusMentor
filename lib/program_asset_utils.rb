module ProgramAssetUtils
  def get_banner_logo_attributes(program_or_organization, program_or_organization_params)
    program_or_organization_params ||= {}
    updated_banner_logo, program_or_organization_asset = [false, nil]
    get_assets_for_object(program_or_organization).each do |program_asset_type|
      asset_param = program_or_organization_params.delete(ProgramAsset::ASSET_NAME[program_asset_type])
      next unless asset_param.present?
      if asset_param[:file_name].present?
        next unless asset_param[:code].present?
        program_or_organization_asset ||= ProgramAsset.find_or_create_by(program_id: program_or_organization.id)
        update_banner_logo(program_or_organization, program_or_organization_asset, program_asset_type, asset_param)
      else
        program_or_organization_asset ||= ProgramAsset.find_by(program_id: program_or_organization.id)
        next unless program_or_organization_asset.present?
        destroy_banner_logo(program_or_organization_asset, program_asset_type)
      end
      updated_banner_logo = true
    end
    [updated_banner_logo, program_or_organization_asset]
  end

  private

  def update_banner_logo(program_or_organization, program_or_organization_asset, program_asset_type, asset_param)
    path_to_file = FileUploader.get_file_path(program_asset_type, program_or_organization.id, "#{DROPZONE::TEMP_BASE_PATH}/#{ProgramAsset::TEMP_BASE_PATH}", asset_param.permit(:code, :file_name).to_h)
    program_or_organization_asset.send("#{ProgramAsset::ASSET_NAME[program_asset_type]}=", File.open(path_to_file, 'rb'))  if path_to_file.present?
  end

  def destroy_banner_logo(program_or_organization_asset, program_asset_type)
    program_or_organization_asset.send("#{ProgramAsset::ASSET_NAME[program_asset_type]}").try(:destroy)
  end

  def get_assets_for_object(program_or_organization)
    return [ProgramAsset::Type::BANNER, ProgramAsset::Type::LOGO] if program_or_organization.is_a?(Program)
    [ProgramAsset::Type::BANNER, ProgramAsset::Type::LOGO, ProgramAsset::Type::MOBILE_LOGO]
  end
end