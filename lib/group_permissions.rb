module GroupPermissions

  def is_owner_of?(group)
    if group.memberships.loaded?
      group.memberships.select{|membership| membership.user_id == self.id && membership.owner == true}.any?
    else
      Connection::Membership.where(group_id: group.id, user_id: self.id, owner: true).exists?
    end
  end

  def can_manage_or_own_group?(group)
    self.can_manage_connections? || self.is_owner_of?(group)
  end

  def project_manager_or_owner?
    self.can_manage_project_requests? || self.owned_groups.exists?
  end

  def can_approve_project_requests?(group)
    self.can_manage_project_requests? || self.is_owner_of?(group)
  end

  def has_owned_groups?
    self.owned_groups.exists?
  end

  def can_be_shown_project_request_quick_link?
    self.can_send_project_request? || self.has_owned_groups?
  end

  def can_manage_members_of_group?(group)
    self.can_manage_connections? || (self.is_owner_of?(group) && group.program.roles.for_mentoring.collect(&:can_be_added_by_owners).include?(true))
  end

  def can_manage_role_in_group?(group, role)
    self.can_manage_connections? || (self.is_owner_of?(group) && role.can_be_added_by_owners?)
  end

  def is_only_owner_of?(group)
    self.is_owner_of?(group) && !self.can_manage_connections?
  end
end