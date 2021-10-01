require_relative './../../../test_helper.rb'

class Report::MetricsHelperTest < ActionView::TestCase
  def setup
    super
    @program = programs(:albers)
    @view = @program.abstract_views.first
    @section = @program.report_sections.create(title: "Users", description: "All users metrics")
    @metric = @section.metrics.create(title: "pending users", description: "see pending users counts", abstract_view_id: @view.id)
  end

  def test_get_metric_view_path_for_admin_view
    view = AdminView.first
    @metric.abstract_view = view
    assert_equal admin_view_path(view, src: ReportConst::ManagementReport::SourcePage), get_metric_view_path(@metric)
  end

  def test_get_metric_view_path_for_flag_view
    @program.enable_feature(FeatureName::FLAGGING)
    pending_flags_view = FlagView::DefaultViews.create_for(@program)[0]
    @metric.abstract_view = pending_flags_view
    assert_equal flags_path(abstract_view_id: pending_flags_view.id, src: ReportConst::ManagementReport::SourcePage, metric_id: @metric.id), get_metric_view_path(@metric)
  end

  def test_get_metric_view_path_for_meeting_request_view
    @program.enable_feature(FeatureName::CALENDAR)
    meeting_request_view = MeetingRequestView::DefaultViews.create_for(@program)[0]
    @metric.abstract_view = meeting_request_view
    assert_equal manage_meeting_requests_path(abstract_view_id: meeting_request_view.id, src: ReportConst::ManagementReport::SourcePage, metric_id: @metric.id), get_metric_view_path(@metric)
  end

  def test_get_metric_view_path_for_mentoring_request_view
    mentoring_request_view = MentorRequestView::DefaultViews.create_for(@program)[0]
    @metric.abstract_view = mentoring_request_view
    assert_equal manage_mentor_requests_path(view_id: mentoring_request_view.id, src: ReportConst::ManagementReport::SourcePage, metric_id: @metric.id), get_metric_view_path(@metric)
  end

  def test_get_metric_view_path_for_project_request_view
    @program.update_attribute(:engagement_type, Program::EngagementType::PROJECT_BASED)
    project_request_view = ProjectRequestView::DefaultViews.create_for(@program)[0]
    @metric.abstract_view = project_request_view
    assert_equal manage_project_requests_path(view_id: project_request_view.id, src: ReportConst::ManagementReport::SourcePage, metric_id: @metric.id), get_metric_view_path(@metric)
  end

  def test_program_invitations_view
    view = ProgramInvitationView::DefaultViews.create_for(programs(:albers)).first
    @metric.abstract_view = view
    assert_equal program_invitations_path(view_id: view.id, src: ReportConst::ManagementReport::SourcePage, metric_id: @metric.id), get_metric_view_path(@metric)
  end

  def test_connection_view
    view = ConnectionView::DefaultViews.create_for(programs(:albers)).first
    @metric.abstract_view = view
    assert_equal groups_path(abstract_view_id: view.id, src: ReportConst::ManagementReport::SourcePage, metric_id: @metric.id), get_metric_view_path(@metric)
  end

  def test_get_alert_links_hash
    organization = programs(:org_primary)
    program1 = organization.programs.first
    program2 = organization.programs.last
    instance_variable_set(:@organization, organization)
    program1_alerts_to_notify = program1.get_report_alerts_to_notify
    program2_alerts_to_notify = program2.get_report_alerts_to_notify
    program1_alerts_to_notify.each do |a|
      expects(:get_metric_view_path).with(a.metric, true, { host: organization.domain, subdomain: organization.subdomain, root: program1.root, src: ReportConst::ManagementReport::EmailSource, alert_id: a.id })
    end
    program2_alerts_to_notify.each do |a|
      expects(:get_metric_view_path).with(a.metric, true, { host: organization.domain, subdomain: organization.subdomain, root: program2.root, src: ReportConst::ManagementReport::EmailSource, alert_id: a.id })
    end
    assert_equal_unordered (program1_alerts_to_notify + program1_alerts_to_notify).collect(&:id), get_alert_links_hash({ program1 => program1_alerts_to_notify, program2 => program2_alerts_to_notify }).keys
  end
end