module Report::MetricsUtils

  def self.included(controller)
    controller.helper_method :set_view_title
  end

  def get_source_metric(program, metric_id)
    if metric_id.present?
      program.report_sections.includes(:metrics).map(&:metrics).flatten.find{|m| m.id == metric_id.to_i}
    else
      nil
    end
  end

  def set_view_title(metric, default_title)
    metric.try(:title) || default_title
  end
end