# https://chronus.atlassian.net/browse/AP-17254
namespace :single_time do
  desc 'Creating additional default abstract views for new dashboard'
  task :create_abstract_views_for_new_dashboard => :environment do
    new_abstract_views = {
      AdminView => [AdminView::DefaultViews::MENTORS_REGISTERED_BUT_NOT_ACTIVE, AdminView::DefaultViews::MENTEES_REGISTERED_BUT_NOT_ACTIVE, 
                    AdminView::DefaultViews::MENTORS_WITH_LOW_PROFILE_SCORES, AdminView::DefaultViews::MENTEES_WITH_LOW_PROFILE_SCORES, 
                    AdminView::DefaultViews::MENTORS_IN_DRAFTED_CONNECTIONS, AdminView::DefaultViews::MENTEES_IN_DRAFTED_CONNECTIONS, 
                    AdminView::DefaultViews::MENTORS_YET_TO_BE_DRAFTED, AdminView::DefaultViews::MENTEES_YET_TO_BE_DRAFTED, 
                    AdminView::DefaultViews::NEVER_CONNECTED_MENTORS, AdminView::DefaultViews::MENTORS_WITH_PENDING_MENTOR_REQUESTS, 
                    AdminView::DefaultViews::MENTEES_WHO_SENT_REQUEST_BUT_NOT_CONNECTED, AdminView::DefaultViews::MENTEES_WHO_HAVENT_SENT_MENTORING_REQUEST],
      ConnectionView => [ConnectionView::DefaultViews::DRAFTED_CONNECTIONS]
    }

    new_metrics = [Report::Metric::DefaultMetrics::MENTORS_REGISTERED_BUT_NOT_ACTIVE, Report::Metric::DefaultMetrics::MENTEES_REGISTERED_BUT_NOT_ACTIVE, Report::Metric::DefaultMetrics::MENTORS_WITH_LOW_PROFILE_SCORES,
                   Report::Metric::DefaultMetrics::MENTEES_WITH_LOW_PROFILE_SCORES, Report::Metric::DefaultMetrics::DRAFTED_CONNECTIONS, Report::Metric::DefaultMetrics::MENTORS_IN_DRAFTED_CONNECTIONS, 
                   Report::Metric::DefaultMetrics::MENTEES_IN_DRAFTED_CONNECTIONS, Report::Metric::DefaultMetrics::MENTORS_YET_TO_BE_DRAFTED, Report::Metric::DefaultMetrics::MENTEES_YET_TO_BE_DRAFTED, 
                   Report::Metric::DefaultMetrics::NEVER_CONNECTED_MENTORS, Report::Metric::DefaultMetrics::MENTORS_WITH_PENDING_MENTOR_REQUESTS, Report::Metric::DefaultMetrics::MENTEES_WHO_SENT_REQUEST_BUT_NOT_CONNECTED, 
                   Report::Metric::DefaultMetrics::MENTEES_WHO_HAVENT_SENT_MENTORING_REQUEST]
    metrics_mapping = Report::Metric::DefaultMetrics::DEFAULT_METRIC_MAPPING.select { |key, _| new_metrics.include?(key) }

    new_alerts = [ReportAlertUtils::DefaultAlerts::MENTORS_JOINED_BUT_NEVER_CONNECTED]
    alerts_mapping = ReportAlertUtils::DefaultAlerts.affiliation_map.select { |key, _| new_alerts.include?(key) }

    Program.active.each do |program|
      next if program.is_career_developement_program?
      ActiveRecord::Base.transaction do
        begin
          puts "Starting for program with id #{program.id}"
          new_abstract_views.each do |subview_klass, subviews|
            subview_klass::DefaultViews.create_views_for(program, subviews, subview_klass)
          end
          program.create_metrics_for_program_management_report(metrics_mapping)
          program.create_default_alerts_for_program_management_report(alerts_mapping)
        rescue => error
          puts "Error:: #{error.message} for program with id #{program.id}"
        end
      end
    end
  end

  desc 'Move other section metrics to the corresponding section as per the csv'
  task :move_metrics_from_other_section => :environment do
    input_file = "lib/tasks/files/other_section_report_metrics/#{Rails.env}.csv"
    abort("Aborting... Missing File") unless File.exist?(input_file)
    csv_text = File.read(input_file)
    csv = CSV.parse(csv_text, :headers => true)
    other_section_mapping = Report::Section.where(default_section: [Report::Section::DefaultSections::OTHER]).includes(:metrics).index_by(&:program_id)
    sections_hash = Program.active.includes(:report_sections).inject({}){|hash_map, program| hash_map[program.id] = program.report_sections.index_by(&:default_section); hash_map}
    ActiveRecord::Base.transaction do
      csv.each do |row|
        data = row.to_hash
        program_id = data["program_id"].to_i
        if !program_id.zero?
          if sections_hash[program_id]
            puts "Processing for program with id #{program_id}"
            metrics = other_section_mapping[program_id].metrics
            move_metrics_with_ids_to(metrics, data["recruitment"], sections_hash[program_id][Report::Section::DefaultSections::RECRUITMENT])
            move_metrics_with_ids_to(metrics, data["matching"], sections_hash[program_id][Report::Section::DefaultSections::CONNECTION])
            move_metrics_with_ids_to(metrics, data["engagement"], sections_hash[program_id][Report::Section::DefaultSections::ENGAGEMENT])
          else
            puts "No Sections for program with id #{program_id}"
          end
        end
      end
    end
    Report::Section.where(default_section: [Report::Section::DefaultSections::OTHER]).destroy_all
  end

  desc 'Create missing default report sections'
  task :create_missing_default_report_sections => :environment do
    Report::Section::DefaultSections.all_default_sections_in_order.each_with_index do |default_section, section_index|
      get_programs_with_section_unavailable(default_section).each do |program|
        create_report_section!(program, default_section, section_index)
      end
    end
  end

  def move_metrics_with_ids_to(metrics, ids, new_section)
    if ids.present?
      ids = ids.split("|")
      ids.each do |id|
        metric = metrics.find{|m| m.id == id.to_i}
        metric.update_attributes!(section_id: new_section.id)
      end
    end
  end

  def get_programs_with_section_unavailable(default_section)
    Program.active.where.not(id: Report::Section.where(default_section: default_section).pluck(:program_id))
  end

  def create_report_section!(program, default_section, section_index)
    puts "Creating report section - #{default_section} for program with id #{program.id}"
    report_section = program.report_sections.where(default_section: default_section).first_or_initialize
    report_section.update_attributes!({
        position: section_index,
        title: ->{ "feature.reports.default.default_section_#{default_section}_title".translate(program.management_report_related_custom_term_interpolations) }.call,
        description: ->{ "feature.reports.default.default_section_#{default_section}_description".translate(program.management_report_related_custom_term_interpolations) }.call
      })
    create_metrics!(program, default_section)
  end

  def create_metrics!(program, default_section)
    metrics_mapping = get_metrics_mapping_for_section(default_section)
    program.create_metrics_for_program_management_report(metrics_mapping)
  end

  def get_metrics_mapping_for_section(default_section)
    Report::Metric::DefaultMetrics::DEFAULT_METRIC_MAPPING.select{|k,v| v[:section] == default_section}
  end
end