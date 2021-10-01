require_relative './../../test_helper.rb'

class MembershipRequestViewTest < ActiveSupport::TestCase
  def test_count
    program = programs(:albers)
    mem_req = program.membership_requests.not_joined_directly.pending
    count = mem_req.count

    view = MembershipRequestView::DefaultViews.create_for(program).first
    assert_equal count, view.count
    req = mem_req[0]
    req.status = MembershipRequest::Status::ACCEPTED
    req.accepted_as = "mentor"
    req.admin = users(:f_admin)
    req.save!
    assert_equal (count - 1), view.count
  end

  def test_default_views
    program = programs(:albers)
    program.abstract_views.where(type: "MembershipRequestView").destroy_all
    views = MembershipRequestView::DefaultViews.create_for(program)
    assert_equal 1, views.size
    assert_equal "Pending Membership Applications", views.first.title
    assert_equal "Program applicants who are awaiting your acceptance", views.first.description
    assert_equal "--- {}\n", views.first.filter_params
  end

  def test_default_views_create_for_portal
    program = programs(:primary_portal)
    program.abstract_views.where(type: "MembershipRequestView").destroy_all
    assert_difference 'MembershipRequestView.count', 1 do
      MembershipRequestView::DefaultViews.create_for(program)
    end
  end

end
