module ReportAlertUtils
  module DefaultAlerts
    APPLICATION_AWAITING_ACCEPTANCE = 1
    INVITATIONS_AWAITING_ACCEPTANCE = 2
    MENTORING_REQUEST_RECEIVED_BUT_NOT_ANSWERED = 3
    MEETING_REQUEST_RECEIVED_BUT_NOT_ANSWERED = 4
    MENTEES_JOINED_BUT_NEVER_CONNECTED = 5
    MENTORS_JOINED_BUT_NEVER_CONNECTED = 6

    def self.affiliation_map
      metric_scope = Report::Metric::DefaultMetrics
      map = {
        APPLICATION_AWAITING_ACCEPTANCE => Proc.new {|program| {
          metric: ->{ metric_scope::PENDING_REQUESTS },
          description: ->{ "feature.reports.default.alert.default_alert_1_description".translate(program.management_report_related_custom_term_interpolations) },
          filter_params: ->{ {cjs_alert_filter_params_0: {name: FilterUtils::MembershipRequestViewFilters::SENT_BETWEEN, operator: FilterUtils::DateRange::BEFORE_LAST, value: 15}} },
          operator: ->{ Report::Alert::OperatorType::GREATER_THAN },
          target: ->{ 0 }
        }},
        INVITATIONS_AWAITING_ACCEPTANCE => Proc.new {|program| {
          metric: ->{ metric_scope::PENDING_INVITES },
          description: ->{ "feature.reports.default.alert.default_alert_2_description".translate(program.management_report_related_custom_term_interpolations) },
          filter_params: ->{ {cjs_alert_filter_params_0: {name: FilterUtils::ProgramInvitationViewFilters::SENT_BETWEEN, operator: FilterUtils::DateRange::BEFORE_LAST, value: 15}} },
          operator: ->{ Report::Alert::OperatorType::GREATER_THAN },
          target: ->{ 0 }
        }},
        MENTORING_REQUEST_RECEIVED_BUT_NOT_ANSWERED => Proc.new {|program| {
          metric: ->{ metric_scope::PENDING_CONNECTION_REQUESTS },
          description: ->{ "feature.reports.default.alert.default_alert_3_description".translate(program.management_report_related_custom_term_interpolations) },
          filter_params: ->{ {cjs_alert_filter_params_0: {name: FilterUtils::MentorRequestViewFilters::SENT_BETWEEN, operator: FilterUtils::DateRange::BEFORE_LAST, value: 15}} },
          operator: ->{ Report::Alert::OperatorType::GREATER_THAN },
          target: ->{ 0 }
        }},
        MEETING_REQUEST_RECEIVED_BUT_NOT_ANSWERED => Proc.new {|program| {
          metric: ->{ metric_scope::PENDING_MEETING_REQUESTS },
          description: ->{ "feature.reports.default.alert.default_alert_4_description".translate(program.management_report_related_custom_term_interpolations) },
          filter_params: ->{ {cjs_alert_filter_params_0: {name: FilterUtils::MeetingRequestViewFilters::SENT_BETWEEN, operator: FilterUtils::DateRange::BEFORE_LAST, value: 7}} },
          operator: ->{ Report::Alert::OperatorType::GREATER_THAN },
          target: ->{ 0 }
        }},
        MENTEES_JOINED_BUT_NEVER_CONNECTED => Proc.new {|program| {
          metric: ->{ metric_scope::NEVER_CONNECTED_MENTEES },
          description: ->{ "feature.reports.default.alert.default_alert_5_description".translate(program.management_report_related_custom_term_interpolations) },
          filter_params: ->{ {cjs_alert_filter_params_0: {name: FilterUtils::AdminViewFilters::SIGNED_UP_ON, operator: FilterUtils::DateRange::BEFORE_LAST, value: 30}, cjs_alert_filter_params_1: {name: FilterUtils::AdminViewFilters::CONNECTION_STATUS, operator: FilterUtils::Equals::EQUALS, value: UsersIndexFilters::Values::NEVERCONNECTED}} },
          operator: ->{ Report::Alert::OperatorType::GREATER_THAN },
          target: ->{ 0 }
        }},
        MENTORS_JOINED_BUT_NEVER_CONNECTED => Proc.new {|program| {
          metric: ->{ metric_scope::NEVER_CONNECTED_MENTORS },
          description: ->{ "feature.reports.default.alert.default_alert_6_description".translate(program.management_report_related_custom_term_interpolations) },
          filter_params: ->{ {cjs_alert_filter_params_0: {name: FilterUtils::AdminViewFilters::SIGNED_UP_ON, operator: FilterUtils::DateRange::BEFORE_LAST, value: 30}, cjs_alert_filter_params_1: {name: FilterUtils::AdminViewFilters::CONNECTION_STATUS, operator: FilterUtils::Equals::EQUALS, value: UsersIndexFilters::Values::NEVERCONNECTED}} },
          operator: ->{ Report::Alert::OperatorType::GREATER_THAN },
          target: ->{ 0 }
        }}
      }
      return map
    end

    def self.all
      constants.collect{|c| const_get(c)}
    end
  end
end