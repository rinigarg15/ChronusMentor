require_relative './../../test_helper.rb'

class ProgramInvitationViewTest < ActiveSupport::TestCase
  def test_count
    program = programs(:albers)
    program_invitations = program.program_invitations.pending
    count = program_invitations.count
    assert count > 0

    view = ProgramInvitationView::DefaultViews.create_for(program).first
    assert_equal count, view.count

    invite = program_invitations[0]
    invite.update_attribute(:expires_on, 2.days.ago)
    assert_equal (count - 1), view.count

    view.filter_params = { include_expired_invitations: true }.to_yaml.gsub(/--- \n/, "")
    view.save!
    assert_equal count, view.count

    event_log = invite.event_logs.first
    event_log.event_type = CampaignManagement::EmailEventLog::Type::FAILED
    event_log.save
    assert_equal (count - 1), view.count
  end

  def test_count_with_alert
    program = programs(:albers)
    program_invitations = program.program_invitations.pending

    view = program.abstract_views.where(default_view: AbstractView::DefaultType::PENDING_INVITES).first
    metric = view.metrics.first
    alert_params = {target: 20, description: "alert description", operator: Report::Alert::OperatorType::LESS_THAN, filter_params: {cjs_alert_filter_params_0: {name: FilterUtils::ProgramInvitationViewFilters::FILTERS.first[1][:value], operator: FilterUtils::DateRange::IN_LAST, value: "10"}}.to_yaml.gsub(/--- \n/, "")}
    alert = create_alert_for_metric(metric, alert_params)
    old_count = view.count(alert)
    program_invitations.first.update_attribute(:sent_on, 11.days.ago)
    assert_equal old_count-1, view.count(alert)
  end

  def test_default_views
    program = programs(:albers)
    program.abstract_views.where(type: "ProgramInvitationView").destroy_all
    views = ProgramInvitationView::DefaultViews.create_for(program)
    assert_equal 1, views.size
    assert_equal "Invitations Awaiting Acceptance", views.first.title
    assert_equal "Users who have been invited to join the program, but have not finished their registration", views.first.description
    assert_equal "--- {}\n", views.first.filter_params
  end

  def test_default_views_create_for_portal
    program = programs(:primary_portal)
    program.abstract_views.where(type: "ProgramInvitationView").destroy_all
    assert_no_difference 'ProgramInvitationView.count' do
      ProgramInvitationView::DefaultViews.create_for(program)
    end
  end
end