class MatchReportAdminViewObserver < ActiveRecord::Observer

  def after_save(match_report_admin_view)
    create_admin_view_cache(match_report_admin_view)
  end

  def after_update(match_report_admin_view)
    return unless match_report_admin_view.saved_change_to_admin_view_id?
    create_admin_view_cache(match_report_admin_view)
  end

  private

  def create_admin_view_cache(match_report_admin_view)
    return if Program.skip_match_report_admin_view_observer
    admin_view = match_report_admin_view.admin_view
    return unless admin_view.present?
    admin_view.delay(queue: DjQueues::HIGH_PRIORITY).refresh_user_ids_cache
  end
end
