module FilterUtils
  include TranslationsService

  module FILTER_TYPE
    DateRange = 1
    Numeric = 2
    Custom = 3
    Equals = 4
  end

  module DateRange
    IN_LAST = "in_last"
    BEFORE_LAST = "before_last"
  end

  module Equals
    EQUALS  = "equals"
  end

  module MeetingRequestViewFilters
    SENT_BETWEEN = "expiry_date"
    FILTERS = {
      MeetingRequestViewFilters::SENT_BETWEEN.to_sym => {name: Proc.new{"feature.reports.content.sent_on".translate}, value: MeetingRequestViewFilters::SENT_BETWEEN, type: FilterUtils::FILTER_TYPE::DateRange}
    }

    def self.process_filter_hash_for_alert(filter_params, alert)
      return filter_params if alert.nil?
      if filter_params[:search_filters].present?
        filter_params[:search_filters].merge!(alert.get_addition_filters)
      else
        filter_params.merge!({:search_filters => alert.get_addition_filters})
      end
      filter_params
    end
  end

  module MembershipRequestViewFilters
    SENT_BETWEEN = "sent_between"
    FILTERS = {
      MembershipRequestViewFilters::SENT_BETWEEN.to_sym => {name: Proc.new{"feature.reports.content.sent_on".translate}, value: MembershipRequestViewFilters::SENT_BETWEEN, type: FilterUtils::FILTER_TYPE::DateRange}
    }

    def self.process_filter_hash_for_alert(filter_params, alert)
      return filter_params if alert.nil?
      filter_params.merge!(alert.get_addition_filters)
    end
  end

  module MentorRequestViewFilters
    SENT_BETWEEN = "expiry_date"
    FILTERS = {
      MentorRequestViewFilters::SENT_BETWEEN.to_sym => {name: Proc.new{"feature.reports.content.sent_on".translate}, value: MentorRequestViewFilters::SENT_BETWEEN, type: FilterUtils::FILTER_TYPE::DateRange}
    }

    def self.process_filter_hash_for_alert(filter_params, alert)
      return filter_params if alert.nil?
      if filter_params[:search_filters].present?
        filter_params[:search_filters].merge!(alert.get_addition_filters)
      else
        filter_params.merge!({:search_filters => alert.get_addition_filters})
      end
      filter_params
    end
  end

  module AdminViewFilters
    LAST_LOGIN_DATE = AdminView::TimelineQuestions::LAST_LOGIN_DATE.to_s
    SIGNED_UP_ON = AdminView::TimelineQuestions::SIGNED_UP_ON.to_s
    TNC_ACCEPTED_ON = AdminView::TimelineQuestions::TNC_ACCEPTED_ON.to_s
    CONNECTION_STATUS = "connection_status_status"
    CONNECTION_STATUS_LAST_CLOSED_CONNECTION = "connection_status_last_closed_connection"
    CONNECTION_STATUS_FILTER_OPTIONS = [
      [ Proc.new{"common_text.prompt_text.Select".translate}, "" ],
      [ Proc.new{"feature.admin_view.status.Never_connected".translate}, UsersIndexFilters::Values::NEVERCONNECTED ],
      [ Proc.new{"feature.admin_view.status.Currently_connected".translate}, UsersIndexFilters::Values::CONNECTED ],
      [ Proc.new{"feature.admin_view.status.Currently_not_connected".translate}, UsersIndexFilters::Values::UNCONNECTED ]
    ]
    FILTERS = {
      AdminViewFilters::LAST_LOGIN_DATE.to_sym => {name: Proc.new{"feature.admin_view.select_option.Last_login_date_alert".translate}, value: AdminView::TimelineQuestions::LAST_LOGIN_DATE.to_s, type: FilterUtils::FILTER_TYPE::DateRange},
      AdminViewFilters::SIGNED_UP_ON.to_sym => {name: Proc.new{"feature.admin_view.select_option.Signed_up_on_alert".translate}, value: AdminView::TimelineQuestions::SIGNED_UP_ON.to_s, type: FilterUtils::FILTER_TYPE::DateRange},
      AdminViewFilters::CONNECTION_STATUS.to_sym => {name: Proc.new{|connection_term| "feature.admin_view.label.mentoring_connection_status_v1".translate(Mentoring_Connection: connection_term)}, value: AdminViewFilters::CONNECTION_STATUS.to_s, type: FilterUtils::FILTER_TYPE::Equals},
       AdminViewFilters::CONNECTION_STATUS_LAST_CLOSED_CONNECTION.to_sym => {name: Proc.new{|connection_term| "feature.admin_view.label.last_closed_group_time".translate(Mentoring_Connection: connection_term)}, value: AdminViewFilters::CONNECTION_STATUS_LAST_CLOSED_CONNECTION.to_s, type: FilterUtils::FILTER_TYPE::DateRange}
    }

    def self.connection_status_filter_translated_options
      AdminViewFilters::CONNECTION_STATUS_FILTER_OPTIONS.map{|translation_proc, value| [translation_proc.call, value]}
    end

    def self.process_filter_hash_for_alert(filter_params, alert)
      return filter_params if alert.nil?
      filter_added = false
      addition_filters = alert.get_addition_filters
      addition_filters.each_pair do |filter_key, filter_value|
        if (filter_key == "timeline".to_sym)
          filter_value.each do |timeline_filter_value|
            if(filter_params[:timeline].present? && filter_params[:timeline][:timeline_questions].present?)
              filter_params[:timeline][:timeline_questions].each_pair do |timeline_key, questions|
                if questions[:question] == timeline_filter_value[:question]
                  filter_params[:timeline][:timeline_questions][timeline_key].merge!(timeline_filter_value)
                  filter_added = true
                end
              end
            end
            if !filter_added
              if filter_params[:timeline].present? && filter_params[:timeline][:timeline_questions].present?
                last_key = filter_params[:timeline][:timeline_questions].keys.last
                arr = filter_params[:timeline][:timeline_questions].keys.last.split(UNDERSCORE_SEPARATOR)
                question_index = arr.pop.to_i + 1
                arr.push(question_index.to_s)
                question_index = arr.join(UNDERSCORE_SEPARATOR)
                filter_params[:timeline][:timeline_questions].merge!(question_index.to_sym => timeline_filter_value)
              elsif filter_params[:timeline].present?
                filter_params[:timeline].merge!({timeline_questions: {:question_0 => timeline_filter_value}})
              else
                filter_params.merge!(:timeline => {timeline_questions: {:question_0 => timeline_filter_value}})
              end
            end
          end
        elsif filter_key == "connection_status".to_sym
          if filter_params[:connection_status].present?
            filter_params[:connection_status].merge!(filter_value)
          else
            filter_params.merge!({connection_status: filter_value})
          end
        end
      end
      return filter_params
    end
  end

  module ProgramInvitationViewFilters
    SENT_BETWEEN = "sent_between"
    FILTERS = {
      ProgramInvitationViewFilters::SENT_BETWEEN.to_sym => {name: Proc.new{"feature.reports.content.sent_on".translate}, value: ProgramInvitationViewFilters::SENT_BETWEEN, type: FilterUtils::FILTER_TYPE::DateRange }
    }
    def self.process_filter_hash_for_alert(filter_params, alert)
      return filter_params if alert.nil?
      filter_params.merge!(alert.get_addition_filters)
      return filter_params
    end
  end

  def self.process_filter_hash_for_alert(view, filter_params, alert)
    "FilterUtils::#{view.class.name}Filters".constantize.process_filter_hash_for_alert(filter_params, alert)
  end
end