class CareerDev::PortalObserver < ActiveRecord::Observer
  observe CareerDev::Portal

  def after_create(portal)
    organization = portal.organization
    organization.reload_programs_count

    portal.populate_default_customized_terms
    portal.create_default_roles
    portal.create_notification_setting!
    portal.create_additional_roles_and_permissions unless portal.created_using_solution_pack?
    portal.create_recent_activity
    portal.create_organization_admins_sub_program_admins
    # TODO #CareerDev - Create default Career Dev Resources
    # Portal.delay.create_default_resource_publications(portal.id) unless portal.created_using_solution_pack?
    Program.create_default_admin_views_and_its_dependencies(portal.id)
    Program.delay.create_demographic_report_view_colums!(portal.id)
    Organization.delay.clone_program_asset!(organization.id, portal.id) if organization.program_asset.present? && !organization.standalone?
    portal.disable_features_by_default
    portal.disable_selected_mails_for_new_program_by_default
    CareerDev::Portal.delay.populate_default_static_content_for_globalization(portal.id)
  end
end