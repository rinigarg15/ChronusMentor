# == Schema Information
#
# Table name: report_alerts
#
#  id            :integer          not null, primary key
#  description   :text(65535)
#  filter_params :text(65535)
#  operator      :integer
#  target        :integer
#  metric_id     :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  default_alert :integer
#

class Report::Alert < ActiveRecord::Base
  self.table_name = "report_alerts"

  JOB_UUID_PREFIX = "a226dcca-8a35-47db-ae51-68bcb85f866e"
  MASS_UPDATE_ATTRIBUTES = {
    create: [:operator, :target, :description],
    update: [:operator, :target, :description]
  }

  module OperatorType
    LESS_THAN = 1
    GREATER_THAN = 2
    EQUAL = 3
    OperatorTypeToOperator = { LESS_THAN => "<", GREATER_THAN => ">", EQUAL => "==" }

    def self.all
      [LESS_THAN, GREATER_THAN, EQUAL]
    end
  end

  validates :description, :operator, :target, :metric_id, presence: true
  validates :operator, inclusion: { in: OperatorType.all }
  validates :default_alert, inclusion: { in: ReportAlertUtils::DefaultAlerts.all }, allow_nil: true

  belongs_to :metric, class_name: Report::Metric.name, foreign_key: :metric_id

  def self.send_alert_mails
    job_uuid = "#{JOB_UUID_PREFIX}-#{Date.current.week_of_year}-#{Date.current.year}"
    organizations = Organization.active.includes(:translations, programs: [:translations, report_alerts: { metric: { abstract_view: :program } } ])

    BlockExecutor.iterate_fail_safe(organizations) do |organization|
      program_alerts_hash = organization.get_program_alerts_hash
      next if program_alerts_hash.blank?

      admin_programs_hash = organization.get_admin_programs_hash
      JobLog.compute_with_uuid(admin_programs_hash.keys, job_uuid) do |admin_member|
        admin_member.send_report_alert(admin_programs_hash[admin_member], program_alerts_hash)
      end
    end
  end

  def can_notify_alert?
    metric_count = self.metric.count(self)
    metric_count.method(Report::Alert::OperatorType::OperatorTypeToOperator[self.operator]).(self.target)
  end

  def filter_params_hash
    ActiveSupport::HashWithIndifferentAccess.new(YAML.load(self.filter_params)) if self.filter_params.present?
  end

  def get_addition_filters
    return {} if self.filter_params.blank?
    if [MeetingRequestView, MentorRequestView, MembershipRequestView, ProgramInvitationView].include?(self.metric.abstract_view.class)
      return {self.filter_params_hash.first[1][:name].to_sym => self.get_date_range(self.filter_params_hash.first[1])}
    elsif self.metric.abstract_view.class == AdminView
      filters = {:timeline => []}
      self.filter_params_hash.each_pair do |key, filter_params|
        if AdminView::TimelineQuestions.all.include?(filter_params[:name].to_i)
          filters[:timeline] << {question: filter_params[:name], type: AdminView::TimelineQuestions::Type::DATE_RANGE.to_s, value: self.get_date_range(filter_params)}
        elsif filter_params[:name] == FilterUtils::AdminViewFilters::CONNECTION_STATUS
          if filters[:connection_status].present?
            filters[:connection_status].merge!(:status => filter_params[:value])
          else
            filters.merge!(:connection_status => {:status => filter_params[:value]})
          end
        elsif filter_params[:name] == FilterUtils::AdminViewFilters::CONNECTION_STATUS_LAST_CLOSED_CONNECTION
          if filters[:connection_status].present?
            filters[:connection_status].merge!(:last_closed_connection => { :type => AdminView::TimelineQuestions::Type::DATE_RANGE.to_s, :date_range =>self.get_date_range(filter_params)})
          else
          filters.merge!(:connection_status => {:last_closed_connection => { :type => AdminView::TimelineQuestions::Type::DATE_RANGE.to_s, :date_range =>self.get_date_range(filter_params)}})
          end
        end
      end
      return filters
    end
  end

  def get_date_range(filter_params)
    time_now = Time.now
    if filter_params[:operator] == FilterUtils::DateRange::IN_LAST
      return "#{(time_now - filter_params[:value].to_i.days).strftime("%m/%d/%Y")} - #{time_now.strftime("%m/%d/%Y")}"
    elsif filter_params[:operator] == FilterUtils::DateRange::BEFORE_LAST
      return "#{DEFAULT_START_TIME.strftime("%m/%d/%Y")} - #{(time_now - filter_params[:value].to_i.days).strftime("%m/%d/%Y")}"
    end
  end

  def filter_params=(value)
    value = value.to_yaml if value.is_a?(Hash)
    write_attribute(:filter_params, value)
  end
end
