class MembershipRequestService
  
  module Filter
    module Role
      ALL ='all'
    end
  end

  class << self
    def filters_to_apply(filters_hash, list_type, program)
      processed_filters = {}
      processed_filters[:sort_field] = filters_hash[:sort].presence || get_default_sort_field(list_type)
      processed_filters[:sort_order] = filters_hash[:order].presence || get_default_sort_order(list_type)
      processed_filters[:sort_scope] = [:order_by, processed_filters[:sort_field], processed_filters[:sort_order]]

      filters_hash[:filters] ||= {}
      processed_filters[:filters] = filters_hash[:filters]
      processed_filters[:filters][:date_range] = filters_hash[:sent_between] if filters_hash[:sent_between].present?
      processed_filters[:filters][:start_date], processed_filters[:filters][:end_date] = ReportsFilterService.get_report_date_range(processed_filters[:filters], program.created_at)
      processed_filters[:filters][:role] = Filter::Role::ALL unless processed_filters[:filters][:role].present?

      return processed_filters
    end

    def get_filtered_membership_requests(program, filters_hash, list_type, tab, only_requests = false)
      @program = program
      @other_filters_count = 0
      processed_filters = filters_to_apply(filters_hash, list_type, program)
      membership_request_ids, prev_period_ids = apply_filters(processed_filters)
      filtered_membership_requests = get_membership_requests(membership_request_ids).send_only(tab, [:pending, :accepted, :rejected])
      if only_requests
        return filtered_membership_requests
      else
        tiles_data = get_tiles_data(prev_period_ids, membership_request_ids)
        return [processed_filters, tiles_data, @other_filters_count, filtered_membership_requests]
      end
    end

    private

    def get_default_sort_field(list_type)
      (list_type == MembershipRequest::ListStyle::LIST) ? "first_name" : "id"
    end

    def get_default_sort_order(list_type)
      (list_type == MembershipRequest::ListStyle::LIST) ? "asc" : "desc"
    end

    def apply_filters(processed_filters)
      membership_requests = @program.membership_requests.includes(:member).not_joined_directly

      # Role Filter
      if processed_filters[:filters][:role].present? && processed_filters[:filters][:role] != Filter::Role::ALL
        @other_filters_count += 1
        membership_requests = membership_requests.for_role(processed_filters[:filters][:role])
      end

      # Questions filter
      member_ids = get_member_ids_based_on_profile(membership_requests.pluck(:member_id), processed_filters)
      membership_requests = membership_requests.where(member_id: member_ids)

      # Time Filter - Returns ids of current period and previous
      apply_time_filter(membership_requests, processed_filters)
    end

    def get_member_ids_based_on_profile(member_ids, processed_filters)
      profile_filter_params = Survey::Report.remove_incomplete_report_filters(processed_filters[:filters][:report][:profile_questions]) if processed_filters[:filters][:report].present? && processed_filters[:filters][:report][:profile_questions].present?
      if profile_filter_params.present?
        @other_filters_count += 1
        dynamic_profile_filter_params = ReportsFilterService.dynamic_profile_filter_params(profile_filter_params)
        UserAndMemberFilterService.apply_profile_filtering(member_ids, dynamic_profile_filter_params, {:for_report_filter => true})
      else
        member_ids
      end
    end

    def apply_time_filter(membership_requests, processed_filters)
      start_date, end_date = processed_filters[:filters][:start_date], processed_filters[:filters][:end_date]
      prev_period_start_date, prev_period_end_date = ReportsFilterService.get_previous_time_period(start_date, end_date, @program)
      prev_period_ids = get_membership_request_ids_between(membership_requests, prev_period_start_date, prev_period_end_date) if prev_period_start_date.present? && prev_period_end_date.present?

      membership_request_ids = get_membership_request_ids_between(membership_requests, start_date, end_date)
      return membership_request_ids, prev_period_ids
    end

    def get_membership_request_ids_between(membership_requests, start_date, end_date)
      sent_between_range = (start_date.in_time_zone(Time.zone).beginning_of_day)..(end_date.in_time_zone(Time.zone).end_of_day)
      membership_requests.where(created_at: sent_between_range).pluck(:id)
    end

    def get_tiles_data(prev_period_ids, membership_request_ids)
      percentage, prev_periods_count = ReportsFilterService.set_percentage_from_ids(prev_period_ids, membership_request_ids)
      prev_periods_count = 0 if prev_periods_count.blank?
      get_scoped_membership_request_counts(membership_request_ids).merge({percentage: percentage, prev_periods_count: prev_periods_count})
    end

    def get_scoped_membership_request_counts(membership_request_ids)
      {pending: get_membership_requests(membership_request_ids).pending.count, accepted: get_membership_requests(membership_request_ids).accepted.count, rejected: get_membership_requests(membership_request_ids).rejected.count, received:  get_membership_requests(membership_request_ids).count}
    end

    def get_membership_requests(membership_request_ids)
      @program.membership_requests.not_joined_directly.where(id: membership_request_ids)
    end
  end
end