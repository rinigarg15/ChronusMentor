namespace :single_time do
  desc 'Updating invalid filter params of alerts'
  task update_invalid_alert_filter_params: :environment do
    start_time = Time.now
    invalid_alert_ids = []
    abstract_views_with_filters = [ProgramInvitationView, AdminView, MentorRequestView, MembershipRequestView, MeetingRequestView]
    abstract_view_filter_map = {}
    abstract_views_with_filters.each do |abstract_view|
      abstract_view_filter_map[abstract_view.to_s] = "FilterUtils::#{abstract_view.to_s}Filters::FILTERS".constantize.keys.map(&:to_s)
    end
    Report::Metric.includes(:abstract_view, :alerts).each do |metric|
      abstract_view_type = metric.abstract_view.class.to_s
      allowed_params_for_abstract_view = abstract_view_filter_map[abstract_view_type]
      metric.alerts.each do |alert|
        filter_params_hash = alert.filter_params_hash
        next unless filter_params_hash.present?
        applied_params_of_alert = filter_params_hash.values.map{|filter_param| filter_param[:name]}.uniq
        next unless (applied_params_of_alert - allowed_params_for_abstract_view.to_a).present?
        invalid_alert_ids << alert.id
      end
    end
    Report::Alert.where(id: invalid_alert_ids).update_all(filter_params: nil)
    puts "Time taken : #{Time.now - start_time} seconds"
  end
end