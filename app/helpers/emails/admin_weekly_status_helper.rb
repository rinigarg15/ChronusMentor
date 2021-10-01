module Emails::AdminWeeklyStatusHelper
  def items_to_display(program, data_hash)
    items_to_display = [] 
    items_to_display << {count: data_hash[:last_week_mem_requests] , text: "email_translations.admin_weekly_status.pending_membership_requests".translate} if data_hash[:show_mr_data] && data_hash[:mr_data_values_changed]

    program.roles_without_admin_role.default.collect(&:name).each do |role_name|
      role_pluralize = role_name.pluralize
      role_term_pluralize = Role.get_role_translation_term(role_name).pluralize
      items_to_display << {count: data_hash["last_week_#{role_pluralize}".to_sym] , text: "email_translations.admin_weekly_status.new_roles".translate(role_pluralize_term: instance_variable_get("@_#{role_term_pluralize}_string"))} if data_hash["show_#{role_pluralize}".to_sym]
    end

    items_to_display << {count: data_hash[:last_week_mentor_reqs] , text: "email_translations.admin_weekly_status.mentor_requests_received".translate(mentoring_term_cap: @_Mentoring_string)} if data_hash[:show_mentor_reqs].present?
    items_to_display << {count: data_hash[:last_week_active_mentor_reqs] , text: "email_translations.admin_weekly_status.mentoring_requests_pending".translate(mentoring_term_cap: @_Mentoring_string)} if data_hash[:show_mentor_reqs].present?
    items_to_display << {count: data_hash[:last_week_groups] , text: "email_translations.admin_weekly_status.connections_established".translate(connections_term_cap: @_Mentoring_Connections_string)} if data_hash[:show_groups].present?
    items_to_display << {count: data_hash[:last_week_meeting_reqs] , text: "email_translations.admin_weekly_status.meeting_requests_received".translate(meeting_term_cap: @_Meeting_string)} if data_hash[:show_meeting_reqs].present?
    items_to_display << {count: data_hash[:last_week_active_meeting_reqs] , text: "email_translations.admin_weekly_status.meeting_requests_pending".translate(meeting_term_cap: @_Meeting_string)} if data_hash[:show_active_meeting_reqs].present?
    items_to_display << {count: data_hash[:last_week_articles] , text: "email_translations.admin_weekly_status.new_articles".translate(articles: @_articles_string)} if data_hash[:show_articles_data]
    items_to_display << {count: data_hash[:proposed_groups] , text: "email_translations.admin_weekly_status.groups_pending_for_approval".translate(connections_term_cap: @_Mentoring_Connections_string)} if  data_hash[:proposed_groups].present? && data_hash[:proposed_groups] > 0
    items_to_display << {count: data_hash[:pending_project_requests] , text: "email_translations.admin_weekly_status.users_waiting_to_join_groups".translate(connections_term: @_mentoring_connections_string)} if data_hash[:pending_project_requests_data_values_changed].present?
    items_to_display << {count: data_hash[:new_survey_responses], text: "email_translations.admin_weekly_status.new_survey_responses".translate(connections_term_cap: @_Mentoring_Connections_string)} if data_hash[:new_survey_responses] > 0
    return items_to_display
  end
end