module Report::MetricsHelper

  def get_metric_view_path(metric, url = false, options = {})
    view = metric.abstract_view
    filter = YAML.load(view.filter_params)
    options[:src] = options[:src] || ReportConst::ManagementReport::SourcePage
    # we can refactor this when needed using underscorize etc, because this will be the
    # one function we need to touch which will be used everywhere
    result = case view
      when AdminView
        send("admin_view_#{url ? 'url' : 'path'}", view, options)
      when FlagView
        send("flags_#{url ? 'url' : 'path'}", options.merge(abstract_view_id: view.id, metric_id: metric.id))
      when MeetingRequestView
        send("manage_meeting_requests_#{url ? 'url' : 'path'}", options.merge(abstract_view_id: view.id, metric_id: metric.id))
      when ProgramInvitationView
        send("program_invitations_#{url ? 'url' : 'path'}", options.merge(view_id: view.id, metric_id: metric.id))
      when MentorRequestView
        send("manage_mentor_requests_#{url ? 'url' : 'path'}", options.merge(view_id: view.id, metric_id: metric.id))
      when ProjectRequestView
        send("manage_project_requests_#{url ? 'url' : 'path'}", options.merge(view_id: view.id, metric_id: metric.id))
      when ConnectionView
        send("groups_#{url ? 'url' : 'path'}", options.merge(abstract_view_id: view.id, metric_id: metric.id))
      when MembershipRequestView
        send("membership_requests_#{url ? 'url' : 'path'}", options.merge(view_id: view.id, metric_id: metric.id))
    end
  end

  def get_alert_links_hash(program_alerts_hash)
    alert_links_array = []
    program_alerts_hash.each do |program, alerts|
      alert_links_array += alerts.map{ |a| [a.id, get_metric_view_path(a.metric, true, { host: @organization.domain, subdomain: @organization.subdomain, root: program.root, src: ReportConst::ManagementReport::EmailSource, alert_id: a.id })] }
    end
    Hash[alert_links_array]
  end
end
