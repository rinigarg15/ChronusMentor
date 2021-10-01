class MobileApi::V1::ResourcesPresenter < MobileApi::V1::BasePresenter

  def list(params = {})
    if resources_feature_enabled?
      accessible_resources = params[:acting_user].accessible_resources(params.to_h.pick(:only_quick_links, :sort_field))
      success_hash(accessible_resources.map {|resource| resource_hash(resource)})
    else
      errors_hash(ApiConstants::ACCESS_UNAUTHORISED)
    end
  end

  def find(resource_id, params = {})
    resource = params[:acting_user].accessible_resources(params.to_h.pick(:only_quick_links, :sort_field)).where(id: resource_id)
    if resource.exists?
      success_hash(resource_hash(resource.first))
    else
      resource_not_found_hash(resource_id)      
    end
  end

  protected

  def resources_feature_enabled?
    program.resources_enabled?
  end

  def resource_not_found_hash(resourceid)
    errors_hash([ApiConstants::ResourceErrors::RESOURCE_NOT_FOUND % resourceid.to_s])
  end

  def resource_hash(resource)
    {
      id: resource.id,
      title: resource.title,
      content: resource.content
    }
  end

end