module OutcomesReportUtils

  include MeetingStatsUtils

  module GraphColor
    CONNECTIONS = '#7cb5ec'
    USERS       = '#434348'
    ROLE_COLORS = ['#90ed7d', '#f7a35c', '#8085e9', '#f15c80', '#e4d354', '#8085e8', '#8d4653', '#91e8e1']

    def self.get_role_graph_color_mapping(mentoring_roles)
      role_graph_color_mapping = {}
      mentoring_roles.each_with_index do |role, index|
        role_graph_color_mapping.merge!({role.id => ROLE_COLORS[index%ROLE_COLORS.length]})
      end
      role_graph_color_mapping
    end
  end

  module GraphEnabledStatus
    ENABLED = "1"
    DISABLED = "0"

    def self.get_enabled_status_mapping(mentoring_roles, enabled_status, connections_or_meetings_report)
      enabled_status_mapping = {:users => (enabled_status[0] == ENABLED)}
      mentoring_roles.each_with_index do |role, index|
        enabled_status_mapping[role.id] = (enabled_status[index+1] == ENABLED)
      end
      if(connections_or_meetings_report)
        enabled_status_mapping[:total_connections_or_meetings] = (enabled_status[enabled_status.length-1] == ENABLED)
      end
      enabled_status_mapping
    end
  end

  module DataType
    GRAPH_DATA = "graph_data"
    NON_GRAPH_DATA = "non_graph_data"
    ALL_DATA = "all_data"
  end

  module DetailedConnectionOutcomesReport
    USER_TAB = 1
    CONNECTION_TAB = 2
  end

  module RoleData
    ALL_USERS = 0
  end

  def process_date_params(date_range)
    range = date_range.split(DATE_RANGE_SEPARATOR).collect do |date|
      date.strip.to_datetime
    end
    self.startDate = range[0]
    self.endDate = range[1]
  end

  def remove_program
    remove_instance_variable(:@program)
  end

  def get_diff_in_percentage(old_value, new_value)
    (old_value.nil? || old_value.zero?) ? nil : ((((new_value - old_value).to_f)/old_value)*100).round(2)
  end

  def get_aggregated_data(data)
    additions_per_day = data.response.aggregations.additions_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}
    removals_per_day = data.response.aggregations.removals_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}
    computed_data = []
    additions_per_day.size.times {|i| computed_data << additions_per_day[i] - removals_per_day[i] + (i>0 ? computed_data[i-1] : 0)}
    computed_data
  end

  def self.get_profile_filters_for_outcomes_report(program)
    profile_questions = program.profile_questions_for(program.roles.for_mentoring.pluck(:name), default: false, skype: false, fetch_all: true)
    return profile_questions.select{|pq| !pq.file_type? }
  end
end