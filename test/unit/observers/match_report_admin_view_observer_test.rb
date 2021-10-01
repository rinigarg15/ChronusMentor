require_relative './../../test_helper.rb'

class MatchReportAdminViewObserverTest < ActiveSupport::TestCase

  def test_after_update
    program = programs(:albers)
    #cache already present
    AdminView.any_instance.expects(:refresh_user_ids_cache).twice
    match_report_admin_view = program.match_report_admin_views.first
    match_report_admin_view.update_attributes!(admin_view_id: program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTEES_REGISTERED_BUT_NOT_ACTIVE).id)
  end

end