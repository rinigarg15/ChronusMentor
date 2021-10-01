# More Info : Remove engagement section metrics default_metric values CONNECTIONS_NEVER_GOT_GOING and INACTIVE_CONNECTIONS

namespace :single_time do
desc 'remove_engagement_section_default_metrics'
  task :remove_engagement_section_default_metrics => :environment do
    ActiveRecord::Base.transaction do
      metrics = Report::Metric.where(default_metric: [Report::Metric::DefaultMetrics::CONNECTIONS_NEVER_GOT_GOING, Report::Metric::DefaultMetrics::INACTIVE_CONNECTIONS])
      Report::Alert.where(metric_id: metrics.pluck(:id)).delete_all
      metrics.delete_all
    end
  end
end