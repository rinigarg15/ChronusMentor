And /^I hover over metric with title "([^\"]*)"$/ do |metric_title|
  metric = Report::Metric.find_by(title: metric_title)
  page.execute_script(%Q[jQuery("#cui-metrics-dropdown-icon-#{metric.id}").css("visibility", "visible");])
end

And /^I click config dropdown from the metric with title "([^\"]*)"$/ do |metric_title|
  metric = Report::Metric.find_by(title: metric_title)
  step "I click \"#cui-metrics-dropdown-icon-#{metric.id}\""
end

And /^I hover over metric description with title "([^\"]*)"$/ do |metric_title|
  metric = Report::Metric.find_by(title: metric_title)
  step "I hover over \"#cui-metric-desc-#{metric.id}\""
end

And /^I hover over metric description icon of metric with title "([^\"]*)"$/ do |metric_title|
  metric = Report::Metric.find_by(title: metric_title)
  step "I hover over \"cui-metric-description-tooltip-#{metric.id}\""
end

And /^I hover over alert icon of metric with title "([^\"]*)"$/ do |metric_title|
  metric = Report::Metric.find_by(title: metric_title)
  step "I hover over \"cui-alert-description-tooltip-#{metric.id}\""
end

And /^I edit the section with title "([^\"]*)"$/ do |section_title|
  section = Report::Section.find_by(title: section_title)
  within ("div#cjs-report-section-#{section.id}") do
      step "I click \"span.caret\""
  end  
  step "I click \"#cui-section-edit-#{section.id}\""
end

And /^I delete the section with title "([^\"]*)"$/ do |section_title|
  section = Report::Section.find_by(title: section_title)
  within ("div#cjs-report-section-#{section.id}") do
      step "I click \"span.caret\""
  end
  step "I click \"#cui-section-delete-#{section.id}\""
end

And /^I trigger_on alert with description "([^\"]*)"$/ do |alert_title|
  alert = Report::Alert.find_by(description: alert_title)
  metric = alert.metric
  page.execute_script("jQuery('#report_alert_target').val('#{metric.count+1}')")
end

And /^I trigger_off alert with description "([^\"]*)"$/ do |alert_title|
  alert = Report::Alert.find_by(description: alert_title)
  metric = alert.metric
  page.execute_script("jQuery('#report_alert_target').val('#{metric.count-1}')")
end

And /^I should see basic section from "([^\"]*)":"([^\"]*)"$/ do |subdomain, program_root|
  program = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain).programs.find_by(root: program_root)
  section_name = program.report_sections.first.title
  step "I should see \"#{section_name}\""
end
  
And /^I create one RA in "([^\"]*)":"([^\"]*)"$/ do |subdomain, program_root|
  program = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain).programs.find_by(root: program_root)
  RecentActivity.create!(
      :programs => [program],
      :action_type => RecentActivityConstants::Type::FORUM_CREATION,
      :target => program.forums.first.recent_activity_target,
      :ref_obj => program.forums.first
    )
end

And /^I should see alert description for metric with title "([^\"]*)"$/ do |metric_title|
  metric = Report::Metric.find_by(title: metric_title)
  alert = metric.alerts.first
  step "I should see \"#{metric.count} - #{alert.description}\""
end

And /^I follow metric with DefaultMetrics value "([^\"]*)"$/ do |default_metric|
  metric = Report::Metric.find_by(default_metric: default_metric.constantize)
  step "I follow \"cui-metric-#{metric.id}\""
end

And /^I add new metric with default view id "([^\"]*)" and default metric "([^\"]*)"$/ do |default_view_id, default_metric|
  metric = Report::Metric.new(title: "title", abstract_view_id: AbstractView.find_by(default_view: default_view_id.constantize).id)
  metric.section_id = Section.first.id
  metric.default_metric = default_metric.constantize
  metric.save!
  step "I reload the page"
end

And /^I should see "([^"]*)"  in the new report popup$/ do |text|
  within "#edit_report_metric" do
    step "I should see \"#{text}\""
  end
end

And /^I should not see "([^"]*)"  in the new report popup$/ do |text|
  within "#edit_report_metric" do
    step "I should not see \"#{text}\""
  end
end

When /^I Remove Default Metrics$/ do
  Report::Metric.destroy_all
end

Then /^I create default program management report for program with root "([^\"]*)"$/ do |program_name|
  program = Program.find_by(root: program_name)
  program.abstract_views.where(default_view: AbstractView::DefaultType.default_program_management_report_type).destroy_all
  program.report_sections.destroy_all
  program.create_default_abstract_views_for_program_management_report
  Program.create_default_program_management_report(program.id)
end

And /^I should see metric with DefaultMetrics value "([^\"]*)"$/ do |default_metric|
  metric = Report::Metric.where(:default_metric => default_metric.constantize).last
  assert find("#cui-metric-#{metric.id}").present?
end

Then /^I change default_metric field of metric with title "([^\"]*)" to "([^\"]*)" and title to "([^\"]*)"$/ do |original_title, new_default_metric, new_title|
  metric = Report::Metric.find_by(title: original_title)
  if new_default_metric == "PENDING_MEETING_REQUESTS"
    change_to_default_metric = Report::Metric::DefaultMetrics::PENDING_MEETING_REQUESTS
  end
  metric.update_attribute(:default_metric, change_to_default_metric)
  metric.update_attribute(:title, new_title)
  metric.reload
end

Then /^I fill in "([^"]*)" with number "([^"]*)"$/ do |id, number|
  page.execute_script("jQuery('##{id}').val(#{number.to_i})")  
end

Then /^I should not see "([^\"]*)" in title of metric with title "([^\"]*)"$/ do |word_in_title, metric_title|
  metric_id = Report::Metric.find_by(title: metric_title).id
  step "I should not see \"#{word_in_title}\" within \"#cjs-section-metric-#{metric_id} .cui-metric-title\""
end
