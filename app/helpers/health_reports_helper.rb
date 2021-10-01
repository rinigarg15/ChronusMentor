module HealthReportsHelper

  def date_range_format
    "date.formats.date_range".translate
  end

  ACTIVE_COLOR = '#80c65a'
  INACTIVE_COLOR = '#aa4643'
  REGISTERED_USERS_SERIES_COLOR = '#3072f3'
  ACTIVE_USERS_SERIES_COLOR = ACTIVE_COLOR
  ONGOING_MENTORING_USERS_SERIES_COLOR = '#b28ee5'
  OVERALL_MENTORING_USERS_SERIES_COLOR = '#3d96ae'
  ACTIVE_MENTORING_USERS_SERIES_COLOR = ACTIVE_COLOR
  COMMUNITY_USERS_SERIES_COLOR = '#625858'
  ARTICLE_USERS_SERIES_COLOR = '#ff9900'
  FORUM_USERS_SERIES_COLOR = '#76a4fb'
  QA_USERS_SERIES_COLOR = '#990066'
  RESOURCE_USERS_SERIES_COLOR = '#80c65a'
  MENTORED_PIE_CHART_COLOR = OVERALL_MENTORING_USERS_SERIES_COLOR
  NEVER_MENTORED_PIE_CHART_COLOR = '#aa4643'

  def program_activity_metric
    {
      :registered => {
        :trend_name => "registered",
        :trend_display_name => "feature.reports.content.registered.trend".translate,
        :summary_name => "feature.reports.content.registered.summary".translate,
        :summary_help_text => "feature.reports.content.registered.summary_help_v1".translate(:program => _program)
      },
      :active => {
        :trend_name => "active",
        :trend_display_name => "feature.reports.content.active.trend".translate,
        :summary_name => "feature.reports.content.active.summary".translate,
        :summary_help_text => "feature.reports.content.active.summary_help_v1".translate(:program => _program)
      },
      :inactive => {
        :trend_name => "inactive",
        :trend_display_name => "feature.reports.content.inactive.trend".translate,
        :summary_name => "feature.reports.content.inactive.summary".translate,
        :summary_help_text => "feature.reports.content.inactive.summary_help_v1".translate(:program => _program)
        }
    }
  end

  def mentoring_activity_metric
    {
      :mentoring => {
        :trend_name => "mentoring",
        :trend_display_name => "feature.reports.content.mentoring.trend_v1".translate(:mentoring_connections => _Mentoring_Connections),
        :summary_name => "feature.reports.content.mentoring.summary_v1".translate(:mentoring_connections => _mentoring_connections),
        :summary_help_text => "feature.reports.content.mentoring.summary_help_v2".translate(:mentoring_connections => _mentoring_connections, :mentoring_connection => _mentoring_connection)
      },
      :active => {
        :trend_name => "active",
        :trend_display_name => "feature.reports.content.active_mentoring.trend_v1".translate(:mentoring_connections => _Mentoring_Connections),
        :summary_name => "feature.reports.content.active_mentoring.summary_v1".translate(:mentoring_connections => _mentoring_connections),
        :summary_help_text => "feature.reports.content.active_mentoring.summary_help_v2".translate(:mentoring_connections => _mentoring_connections, :mentoring_connection => _mentoring_connection, :a_mentoring_connection => _a_mentoring_connection)
      },
      :inactive => {
        :trend_name => "inactive",
        :trend_display_name => "feature.reports.content.inactive_mentoring.trend_v1".translate(:mentoring_connections => _Mentoring_Connections),
        :summary_name => "feature.reports.content.inactive_mentoring.summary_v1".translate(:mentoring_connections => _mentoring_connections),
        :summary_help_text => "feature.reports.content.inactive_mentoring.summary_help_v2".translate(:mentoring_connections => _mentoring_connections, :mentoring_connection => _mentoring_connection, :program => _program)
      }
    }
  end

  def community_activity_metric(article_term)
    {
      :community => {
        :trend_name => "community",
        :trend_display_name => "feature.reports.content.community.trend".translate,
        :summary_name => "feature.reports.content.community.summary_v1".translate,
        :summary_help_text => "feature.reports.content.community.summary_help_v2".translate(articles: article_term.pluralize.downcase, resources: _resources, :program => _program)
      },
      :resource => {
        :trend_name => "resource",
        :trend_display_name => _Resource,
        :summary_name => "feature.reports.content.resource.summary".translate(Resource: _Resource),
        :summary_help_text => "feature.reports.content.resource.summary_help".translate(resources: _resources, :program => _program)
      },
      :article => {
        :trend_name => "article",
        :trend_display_name => "#{article_term}",
        :summary_name => "feature.reports.content.article.summary_v1".translate(article: article_term),
        :summary_help_text_v1 => "feature.reports.content.article.summary_help_v1".translate(articles: article_term.pluralize.downcase, :program => _program)
      },
      :forum => {
        :trend_name => "forum",
        :trend_display_name => "feature.reports.content.forum.trend".translate,
        :summary_name => "feature.reports.content.forum.summary_v1".translate,
        :summary_help_text => "feature.reports.content.forum.summary_help_v1".translate(:program => _program)
      },
      :qa => {
        :trend_name => "qa",
        :trend_display_name => "feature.reports.content.qa.trend".translate,
        :summary_name => "feature.reports.content.qa.summary_v1".translate,
        :summary_help_text => "feature.reports.content.qa.summary_help_v1".translate(:program => _program)
      }
    }
  end

  def translated_percent_metric_unit(value, unit)
    "percent_metric.unit.#{unit}".translate(count: value)
  end

  def translated_distributed_metric_name(name)
    "distributed_metric.name.#{name}".translate
  end

  def translated_health_report_content_name(name)
    case name
    when "articles"
      _Articles
    when "resources"
      "feature.reports.label.resources_rated_helpful".translate(:resources => _resources, :program => _program)
    else
      "feature.reports.label.#{name}".translate
    end
  end

  # Metric value presented in human readable format, based on the metric type.
  #
  # ==== Params:
  # * <tt>metric</tt> : PercentMetric to show the value string for
  # * <tt>is_point_scale</tt> : true if the metric should be shown in a 0-10 scale. 
  #
  def metric_value_string(metric, is_point_scale = false)
    if is_point_scale
      "feature.reports.content.n_of_ten_points".translate(n: (metric.value * 10.0).round)
    else
      metric.percent_based? ? "#{metric.effective_value.round}%" :
        translated_percent_metric_unit(metric.effective_value, metric.unit)
    end
  end

  def program_activity_trend_chart_data(program_health_report)
    program_activity_trend_oh = ActiveSupport::OrderedHash.new
    program_activity_trend_oh[program_activity_metric[:active][:trend_name]] = {:name => program_activity_metric[:active][:trend_display_name], :data => program_health_report.active_users_series, :visible => true, :color => ACTIVE_USERS_SERIES_COLOR}
    program_activity_trend_oh[program_activity_metric[:registered][:trend_name]] = {:name => program_activity_metric[:registered][:trend_display_name], :data => program_health_report.registered_users_series, :visible => true, :color => REGISTERED_USERS_SERIES_COLOR}
    program_activity_trend_oh
  end

  def program_activity_summary_chart_data(program_health_report)
    active_user_count_percent =
      program_health_report.active_users_summary_count.to_f / program_health_report.registered_users_summary_count.to_f * 100.0
    program_activity_summary_oh = ActiveSupport::OrderedHash.new
    program_activity_summary_oh[program_activity_metric[:active][:trend_name]] = {:name => program_activity_metric[:active][:summary_name], :data => active_user_count_percent, :color => ACTIVE_COLOR }
    program_activity_summary_oh[program_activity_metric[:inactive][:trend_name]] = {:name => program_activity_metric[:inactive][:summary_name], :data => 100.0 - active_user_count_percent, :color => INACTIVE_COLOR }
    program_activity_summary_oh
  end

  def mentoring_activity_trend_chart_data(program_health_report)
     mentoring_activity_trend_oh = ActiveSupport::OrderedHash.new
     mentoring_activity_trend_oh[mentoring_activity_metric[:active][:trend_name]] = {:name => mentoring_activity_metric[:active][:trend_display_name], :data => program_health_report.active_mentoring_activity_users_series, :visible => true, :color => ACTIVE_MENTORING_USERS_SERIES_COLOR}
     mentoring_activity_trend_oh[mentoring_activity_metric[:mentoring][:trend_name]] = {:name => mentoring_activity_metric[:mentoring][:trend_display_name], :data => program_health_report.ongoing_mentoring_activity_users_series, :visible => true, :color => ONGOING_MENTORING_USERS_SERIES_COLOR}
     mentoring_activity_trend_oh[program_activity_metric[:registered][:trend_name]] = {:name => program_activity_metric[:registered][:trend_display_name], :data => program_health_report.registered_users_series, :visible => false, :color => REGISTERED_USERS_SERIES_COLOR}
     mentoring_activity_trend_oh
  end

  def ongoing_mentoring_activity_summary_chart_data(program_health_report)
    mentoring_users_count_percent =
      program_health_report.active_mentoring_activity_users_summary_count.to_f / program_health_report.ongoing_mentoring_activity_users_summary_count.to_f * 100.0
    ongoing_mentoring_activity_summary_oh = ActiveSupport::OrderedHash.new
    ongoing_mentoring_activity_summary_oh[mentoring_activity_metric[:active][:trend_name]] = {:name => mentoring_activity_metric[:active][:summary_name], :data => mentoring_users_count_percent, :color => ACTIVE_COLOR }
    ongoing_mentoring_activity_summary_oh[mentoring_activity_metric[:inactive][:trend_name]] = {:name => mentoring_activity_metric[:inactive][:summary_name], :data => 100.0 - mentoring_users_count_percent, :color => INACTIVE_COLOR }

    ongoing_mentoring_activity_summary_oh
  end

  def community_activity_trend_chart_data(program_health_report, scope)
    com_activity_metric = community_activity_metric(_Article)

    community_activity_summary_oh = ActiveSupport::OrderedHash.new
    community_activity_summary_oh[com_activity_metric[:article][:trend_name]] = {:name => com_activity_metric[:article][:trend_display_name], :data => program_health_report.article_activity_users_series, :visible => true, :color => ARTICLE_USERS_SERIES_COLOR} if scope.articles_enabled?
    community_activity_summary_oh[com_activity_metric[:forum][:trend_name]] = {:name => com_activity_metric[:forum][:trend_display_name], :data => program_health_report.forum_activity_users_series, :visible => true, :color => FORUM_USERS_SERIES_COLOR} if scope.forums_enabled?
    community_activity_summary_oh[com_activity_metric[:qa][:trend_name]] = {:name => com_activity_metric[:qa][:trend_display_name], :data => program_health_report.qa_activity_users_series, :visible => true, :color => QA_USERS_SERIES_COLOR} if scope.qa_enabled?
    community_activity_summary_oh[com_activity_metric[:resource][:trend_name]] = {:name => com_activity_metric[:resource][:trend_display_name], :data => program_health_report.resource_activity_users_series, :visible => true, :color => RESOURCE_USERS_SERIES_COLOR} if scope.resources_enabled?
    community_activity_summary_oh[com_activity_metric[:community][:trend_name]] = {:name => com_activity_metric[:community][:trend_display_name], :data => program_health_report.community_activity_users_series, :visible => true, :color => COMMUNITY_USERS_SERIES_COLOR}
    community_activity_summary_oh[program_activity_metric[:registered][:trend_name]] = {:name => program_activity_metric[:registered][:trend_display_name], :data => program_health_report.registered_users_series, :visible => false, :color => REGISTERED_USERS_SERIES_COLOR}
    community_activity_summary_oh
  end

  def health_report_growth_chart_data(growth)
    hash = {}
    role_term_hash = RoleConstants.program_roles_mapping(growth.program, pluralize: true)
    growth.role_map.keys.each do |role_name|
      hash[role_name] = {:name => role_term_hash[role_name], :data => growth.graph_data[role_name], :visible => true}
    end
    hash[:connection] = {:name => "feature.reports.label.connections_v1".translate(Mentoring_Connections: _Mentoring_Connections), :data => growth.graph_data[:connection], :visible => true } if growth.program.ongoing_mentoring_enabled?
    hash
  end

  def health_report_mode_chart_data(engagement)
    {
      render_to: 'health_report_mode_chart',
      percentage: true,
      height: 210,
      data: engagement.connection_mode.distribution.map{|k, v| [translated_distributed_metric_name(k), (v * 100).round(2)]}
    }
  end

  def health_report_radio_button_filter(filter_name, cur_value, filter_value, param_name)

    label = (cur_value == filter_value) ? "<b>#{filter_name}</b>".html_safe : filter_name

    content_tag(:label, :class => 'radio') do
      should_be_checked = (cur_value == filter_value)
      radio_button_tag(param_name, filter_value, should_be_checked) + label
    end
  end

  def health_report_label_box_with_help_text(label_class, label_id, label_text, help_text)
    content_tag(:div, :class => "#{label_class} false-label", :id => label_id) do
      "#{label_text} ".html_safe + get_icon_content("fa fa-question-circle", :data => {:toggle => "tooltip", :title => help_text})
    end
  end

  def activity_report_metric_label_with_help_text(label_text, help_text, value, legend_class = nil)
    if legend_class.present?
      td_label_content = content_tag(:span, nil, :class => legend_class) + content_tag(:span, label_text)
    else
      td_label_content = label_text
    end

    content_tag(:tr, "data-toggle" => "tooltip", "data-title" => help_text) do
      content_tag(:td, td_label_content) + content_tag(:td, value)
    end
  end

  def activity_report_csv_data
    program_health_report_by_role = {}
    role_term_hash = RoleConstants.program_roles_mapping(@current_program, pluralize: true)
    role_string = @role_filters.map{|role_name| role_term_hash[role_name] }.join(" " + "feature.reports.label.or".translate + " ")
    program_health_report_by_role[role_string] = @program_health_report
    if @role_filters.size > 1
      @role_filters.each do |role_name|
        report = HealthReport::ProgramHealthReport.new(@current_program)
        report.compute(@start_time, @end_time, [role_name])
        program_health_report_by_role[role_term_hash[role_name]] = report
      end
    end
    activity_report_csv_headers = ["feature.reports.header.activity_report_header.activity_summary".translate(date: activity_report_daterange_display_name(@start_time, @end_time)), "feature.reports.header.activity_report_header.description".translate]
    com_activity_metric = community_activity_metric(_Article)

    CSV.generate do |csv|
      csv << activity_report_csv_headers.insert(1, *program_health_report_by_role.keys)
      csv << [program_activity_metric[:registered][:summary_name], program_activity_metric[:registered][:summary_help_text]].insert(1, *program_health_report_by_role.values.map{|x| x.registered_users_summary_count})
      csv << [program_activity_metric[:active][:summary_name], program_activity_metric[:active][:summary_help_text]].insert(1, *program_health_report_by_role.values.map{|x| x.active_users_summary_count})
      csv << [mentoring_activity_metric[:mentoring][:summary_name], mentoring_activity_metric[:mentoring][:summary_help_text]].insert(1, *program_health_report_by_role.values.map{|x| x.ongoing_mentoring_activity_users_summary_count}) if @current_program.ongoing_mentoring_enabled?
      csv << [mentoring_activity_metric[:active][:summary_name], mentoring_activity_metric[:active][:summary_help_text]].insert(1, *program_health_report_by_role.values.map{|x| x.active_mentoring_activity_users_summary_count}) if @current_program.ongoing_mentoring_enabled?
      csv << [com_activity_metric[:community][:summary_name], com_activity_metric[:community][:summary_help_text]].insert(1, *program_health_report_by_role.values.map{|x| x.community_activity_users_summary_count}) if @current_program.community_features_enabled?
      csv << [com_activity_metric[:resource][:summary_name], com_activity_metric[:resource][:summary_help_text]].insert(1, *program_health_report_by_role.values.map{|x| x.resource_activity_users_summary_count}) if @current_program.resources_enabled?
      csv << [com_activity_metric[:article][:summary_name], com_activity_metric[:article][:summary_help_text]].insert(1, *program_health_report_by_role.values.map{|x| x.article_activity_users_summary_count}) if @current_program.articles_enabled?
      csv << [com_activity_metric[:forum][:summary_name], com_activity_metric[:forum][:summary_help_text]].insert(1, *program_health_report_by_role.values.map{|x| x.forum_activity_users_summary_count}) if @current_program.forums_enabled?
      csv << [com_activity_metric[:qa][:summary_name], com_activity_metric[:qa][:summary_help_text]].insert(1, *program_health_report_by_role.values.map{|x| x.qa_activity_users_summary_count}) if @current_program.qa_enabled?
    end
  end

  def activity_report_daterange_display_name (start_time, end_time)
    "#{DateTime.localize(start_time, format: :full_display_no_time)} - #{DateTime.localize(end_time, format: :full_display_no_time)}"
  end

  def get_loader(id, options = {})
    content_tag(:div, :id => id, :class => "text-center #{options[:class] if options[:class].present?}") do
      image_tag('ajax-loader-progress-bar.gif')
    end
  end
end
