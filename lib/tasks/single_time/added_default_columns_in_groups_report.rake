# JIRA Ticket: https://chronus.atlassian.net/browse/AP-17116
# More Info : Add default report view columns to existing programs

namespace :single_time do
desc 'added_default_columns_in_groups_report'
  task :added_default_columns_in_groups_report => :environment do
    report_view_columns_per_program = ReportViewColumn.for_groups_report.group_by(&:program_id)
    max_position_per_program = Hash[report_view_columns_per_program.map{ |k,v| [k, v.collect(&:position).max]}]
    column_keys_per_program = Hash[report_view_columns_per_program.map{ |k,v| [k, v.collect(&:column_key)]}]

    Program.all.includes(:translations).each do |program|
      position = max_position_per_program[program.id] || -1
      program.report_view_columns.create!(:report_type => ReportViewColumn::ReportType::GROUPS_REPORT, column_key: ReportViewColumn::GroupsReport::Key::SURVEY_RESPONSES_COUNT, position: position + 1) unless (column_keys_per_program[program.id].present? && column_keys_per_program[program.id].include?(ReportViewColumn::GroupsReport::Key::SURVEY_RESPONSES_COUNT)) || !(program.mentoring_connections_v2_enabled? && program.surveys.of_engagement_type.present?)

      program.report_view_columns.create!(:report_type => ReportViewColumn::ReportType::GROUPS_REPORT, column_key: ReportViewColumn::GroupsReport::Key::TOTAL_ACTIVITIES, position: position + 2) unless column_keys_per_program[program.id].present? && column_keys_per_program[program.id].include?(ReportViewColumn::GroupsReport::Key::TOTAL_ACTIVITIES)

      program.report_view_columns.create!(:report_type => ReportViewColumn::ReportType::GROUPS_REPORT, column_key: ReportViewColumn::GroupsReport::Key::CURRENT_STATUS, position: position + 3) unless column_keys_per_program[program.id].present? && column_keys_per_program[program.id].include?(ReportViewColumn::GroupsReport::Key::CURRENT_STATUS)

      puts "*** Added default report view columns for #{program.name} ***"
    end
  end
end