class RoleObserver < ActiveRecord::Observer
  def after_create(role)
    role.set_default_customized_term
    create_default_permissions(role) unless role.is_default?
    role.update_attributes!(slot_config: RoleConstants::SlotConfig::OPTIONAL) if role.program.is_a?(Program) && role.program.project_based? && role.for_mentoring?
    Role.es_reindex(role, reindex_group: true, reindex_article: true, reindex_qa_question: true)
  end

  def after_update(role)
    if role.saved_change_to_name?
      Role.es_reindex(role, reindex_user: true, reindex_group: true)
    end
    if role.saved_change_to_max_connections_limit? && !role.no_limit_on_project_requests?
      old_limit = role.max_connections_limit_before_last_save
      close_pending_requests_if_required(role) if (old_limit.nil? || old_limit > role.max_connections_limit)
    end
  end

  def after_destroy(role)
    Role.es_reindex(role, reindex_group: true, reindex_article: true, reindex_qa_question: true)
  end

  private

  def create_default_permissions(role)
    # Adding only view permission.
    Permission.create_permission!("view_#{role.name.pluralize}")
  end

  def close_pending_requests_if_required(role)
    user_id_role_id_hash = {}
    role.users.pluck(:id).each{ |user_id| user_id_role_id_hash[user_id] = role.id }
    ProjectRequest.delay.close_pending_requests_if_required(user_id_role_id_hash)
  end

end