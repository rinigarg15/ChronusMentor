class RolePermissionExporter < SolutionPack::Exporter

  AssociatedExporters = ["PermissionExporter"]
  FileName = 'role_permission'
  AssociatedModel = "RolePermission"

  def initialize(program, parent_exporter)
    self.objs = []
    if parent_exporter.class == RoleExporter
      self.objs = collect_invite_and_add_role_permissions(program)
      self.objs += collect_article_related_permissions(program)
    end
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

  private

  def can_include_role_permission?(invite_permission_names, add_role_permission_names, role_permission)
    permission_name = role_permission.permission.name
    invite_permission_names.include?(permission_name) || add_role_permission_names.include?(permission_name)
  end

  def collect_article_related_permissions(program)
    article_permissions = []
    program.class::Permissions::PUBLISH_ARTICLES.each do |publish_article|
      role = publish_article[:role]
      if program.find_role(role).present? && program.has_role_permission?(role, "write_article")
        article_permissions += program.get_role(role).role_permissions.select{|rp| rp.permission.name == "write_article"}
      end
    end
    return article_permissions
  end

  def collect_invite_and_add_role_permissions(program)
    invite_permission_names = program.roles.map{|role| "invite_#{role.name.pluralize}"}
    add_role_permission_names = program.roles_applicable_for_auto_approval.map{|role| "become_#{role.name}"}
    role_permissions = program.roles_without_admin_role.collect(&:role_permissions).flatten
    role_permissions.select do |rp|
      can_include_role_permission?(invite_permission_names, add_role_permission_names, rp)
    end
  end

end