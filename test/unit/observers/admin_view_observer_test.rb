require_relative './../../test_helper.rb'

class AdminViewObserverTest < ActiveSupport::TestCase
  def test_after_destroy
    admin_view = programs(:albers).admin_views.find_by(default_view: AbstractView::DefaultType::ALL_USERS)
    organization = admin_view.program.organization
    assert_difference "CampaignManagement::AbstractCampaign.count", -6 do
      admin_view.destroy
    end
  end

  def test_after_update_admin_view
    admin_view = programs(:org_primary).admin_views.find_by(default_view: AbstractView::DefaultType::LICENSE_COUNT)
    admin_view.expects(:refresh_user_ids_cache).never
    admin_view.update_attributes(filter_params: AdminView.convert_to_yaml({}))

    admin_view = programs(:albers).admin_views.find_by(default_view: AbstractView::DefaultType::ALL_USERS)
    admin_view.expects(:refresh_user_ids_cache).once
    filter_params = AdminView.convert_to_yaml( { roles_and_status: { role_filter_1: { type: :include } } } )
    admin_view.update_attributes(filter_params: filter_params)
    admin_view.expects(:refresh_user_ids_cache).never
    admin_view.update_attributes(title: "new title")
  end
end