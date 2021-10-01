class UpdatingDefaultViewsAndMetrics< ActiveRecord::Migration[4.2]
  def up
    AbstractView.where(default_view: AbstractView::DefaultType::PENDING_FLAGS).find_each {|abstract_view| abstract_view.update_attributes!({title: ->{ "feature.abstract_view.flag_view.pending_title".translate}.call }) }
    AbstractView.where(default_view: AbstractView::DefaultType::PENDING_REQUESTS).includes(:program).find_each {|abstract_view| abstract_view.update_attributes!({title: ->{ "feature.abstract_view.mebership_request_view.pending_title".translate(abstract_view.program.management_report_related_custom_term_interpolations) }.call }) }
    Report::Metric.where(default_metric: Report::Metric::DefaultMetrics::PENDING_REQUESTS).find_each {|metric| metric.update_attributes!({title: ->{ "feature.reports.default.default_metric_0_title".translate }.call }) }
    Report::Metric.where(default_metric: Report::Metric::DefaultMetrics::UNSATISFIED_USERS_CONNECTION).includes(abstract_view: :program).find_each {|metric| metric.update_attributes!({title: ->{ "feature.reports.default.default_metric_11_title".translate(metric.abstract_view.program.management_report_related_custom_term_interpolations) }.call }) }
  end

  def down
    # no down migration
  end
end
