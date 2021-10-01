class ProjectRequestObserver < ActiveRecord::Observer
  def self.create_not_for_display_recent_activity(project_request_id, action_type)
    project_request = ProjectRequest.find_by(id: project_request_id)
    return if project_request.nil?
    RecentActivity.create!(
      :programs => [project_request.program],
      :ref_obj => project_request,
      :action_type => action_type,
      :target => RecentActivityConstants::Target::NONE
    )
  end

  def after_create(project_request)
    ProjectRequestObserver.delay.create_not_for_display_recent_activity(
      project_request.id, RecentActivityConstants::Type::PROJECT_REQUEST_SENT
    )
    es_reindex_group(project_request) if project_request.active?
  end

  def after_update(project_request)
    if project_request.saved_change_to_status?
      ProjectRequestObserver.delay.create_not_for_display_recent_activity(
        project_request.id, get_action_type(project_request)
      )

      es_reindex_group(project_request)
    end
  end

  def after_destroy(project_request)
    es_reindex_group(project_request) if project_request.active?
  end

private
  
  def get_action_type(project_request)
    case project_request.status
    when AbstractRequest::Status::NOT_ANSWERED
      RecentActivityConstants::Type::PROJECT_REQUEST_SENT
    when AbstractRequest::Status::ACCEPTED
      RecentActivityConstants::Type::PROJECT_REQUEST_ACCEPTED
    when AbstractRequest::Status::REJECTED
      RecentActivityConstants::Type::PROJECT_REQUEST_REJECTED
    when AbstractRequest::Status::CLOSED
      RecentActivityConstants::Type::PROJECT_REQUEST_CLOSED
    when AbstractRequest::Status::WITHDRAWN
      RecentActivityConstants::Type::PROJECT_REQUEST_WITHDRAWN
    end
  end

  def es_reindex_group(project_request)
    ProjectRequest.es_reindex(project_request)
  end
end