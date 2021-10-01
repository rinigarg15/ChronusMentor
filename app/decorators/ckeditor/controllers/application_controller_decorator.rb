Ckeditor::ApplicationController.class_eval do

  protected

  def respond_with_asset(asset)
    asset.organization = @current_organization
    asset.login_required = asset.is_a?(Ckeditor::AttachmentFile)

    asset_response = Ckeditor::AssetResponse.new(asset, request)

    if asset.save
      render asset_response.success(config.relative_url_root)
    else
      render asset_response.errors
    end
  end
end