module Program::Dashboard::CommunityResourcesReport
  extend ActiveSupport::Concern

  def community_resource_report_enabled?
    self.is_report_enabled?(DashboardReportSubSection::Type::CommunityResources::RESOURCES)
  end

  private

  def get_resources_data
    {resource_views: get_resources_viewed_data, resouce_helpful_count: get_resources_marked_helpful_data}
  end

  def get_resources_viewed_data
    data = []
    viewed_resources = get_resources.order("view_count desc").first(Resource::MARKED_HELPFUL_AND_VIEWED_COUNT)
    return data if viewed_resources.empty?
    viewed_resources.each do |resource|
      resource_hash = {}
      resource_hash[:resource] = resource
      resource_hash[:view_count] = resource.view_count
      data << resource_hash
    end
    data
  end

  def get_resources_marked_helpful_data
    data = []
    return data if get_resources.empty?
    resource_and_rating_count_hash = get_resource_and_rating_count_hash
    resource_and_rating_count_hash.each do |resource_and_rating_count|
      resource_hash = {}
      resource = resource_and_rating_count.first
      resource_hash[:resource] = resource
      resource_hash[:helpful_count] = resource_and_rating_count.second
      data << resource_hash
    end
    data
  end

  def get_resource_and_rating_count_hash
    resource_and_rating_count_map = Hash[get_resources.map{ |resource| [resource, resource.get_helpful_count]}]
    sorted_resource_and_rating_count_map = Hash[resource_and_rating_count_map.sort_by{|_k, v| v}.reverse]
    Hash[sorted_resource_and_rating_count_map.first(Resource::MARKED_HELPFUL_AND_VIEWED_COUNT)]
  end

  def get_resources
    @resources || compute_resources
  end

  def compute_resources
    resource_ids = self.resource_publications.pluck(:resource_id)
    @resources = Resource.where(id: resource_ids).includes(:ratings, :translations)
  end
end