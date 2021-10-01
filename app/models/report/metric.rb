# == Schema Information
#
# Table name: report_metrics
#
#  id               :integer          not null, primary key
#  title            :string(255)
#  description      :text(65535)
#  section_id       :integer
#  abstract_view_id :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  position         :integer          default(1000)
#  default_metric   :integer
#

class Report::Metric < ActiveRecord::Base
  self.table_name = "report_metrics"

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:title, :description, :abstract_view_id],
    :update => [:title, :description, :abstract_view_id]
  }

  # Modules
  module DefaultMetrics
    PENDING_REQUESTS = 0
    PENDING_INVITES = 1
    ACCEPTED_BUT_NOT_JOINED = 2
    REGISTERED_BUT_NOT_ACTIVE = 3
    PENDING_CONNECTION_REQUESTS = 4
    PENDING_MEETING_REQUESTS = 5
    NEVER_CONNECTED_MENTEES = 6
    CURRENTLY_NOT_CONNECTED_MENTEES = 7
    CONNECTIONS_NEVER_GOT_GOING = 8
    INACTIVE_CONNECTIONS = 9
    ACTIVE_BUT_BEHIND_CONNECTIONS = 10
    UNSATISFIED_USERS_CONNECTION = 11
    PENDING_PROJECT_REQUESTS = 14
    INACTIVE_CONNECTIONS_V1 = 15
    ACTIVE_BUT_BEHIND_CONNECTIONS_V1 = 16

    # The following (17-29) are added as a part of new dashboard
    MENTORS_REGISTERED_BUT_NOT_ACTIVE = 17
    MENTEES_REGISTERED_BUT_NOT_ACTIVE = 18
    MENTORS_WITH_LOW_PROFILE_SCORES = 19
    MENTEES_WITH_LOW_PROFILE_SCORES = 20
    DRAFTED_CONNECTIONS = 21
    MENTORS_IN_DRAFTED_CONNECTIONS = 22
    MENTEES_IN_DRAFTED_CONNECTIONS = 23
    MENTORS_YET_TO_BE_DRAFTED = 24
    MENTEES_YET_TO_BE_DRAFTED = 25
    NEVER_CONNECTED_MENTORS = 26
    MENTORS_WITH_PENDING_MENTOR_REQUESTS = 27
    MENTEES_WHO_SENT_REQUEST_BUT_NOT_CONNECTED = 28
    MENTEES_WHO_HAVENT_SENT_MENTORING_REQUEST = 29

    METRICS_WITH_UPDATED_DESCRIPTION = [CONNECTIONS_NEVER_GOT_GOING, INACTIVE_CONNECTIONS, ACTIVE_BUT_BEHIND_CONNECTIONS]

    DEFAULT_METRIC_MAPPING = {
      PENDING_REQUESTS => {section: Report::Section::DefaultSections::RECRUITMENT, abstract_view: AbstractView::DefaultType::PENDING_REQUESTS},
      PENDING_INVITES => {section: Report::Section::DefaultSections::RECRUITMENT, abstract_view: AbstractView::DefaultType::PENDING_INVITES},
      ACCEPTED_BUT_NOT_JOINED => {section: Report::Section::DefaultSections::RECRUITMENT, abstract_view: AbstractView::DefaultType::ACCEPTED_BUT_NOT_JOINED},
      PENDING_CONNECTION_REQUESTS => {section: Report::Section::DefaultSections::CONNECTION, abstract_view: AbstractView::DefaultType::PENDING_CONNECTION_REQUESTS},
      PENDING_MEETING_REQUESTS => {section: Report::Section::DefaultSections::CONNECTION, abstract_view: AbstractView::DefaultType::PENDING_MEETING_REQUESTS},
      NEVER_CONNECTED_MENTEES => {section: Report::Section::DefaultSections::CONNECTION, abstract_view: AbstractView::DefaultType::NEVER_CONNECTED_MENTEES},
      CURRENTLY_NOT_CONNECTED_MENTEES => {section: Report::Section::DefaultSections::CONNECTION, abstract_view: AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES},
      PENDING_PROJECT_REQUESTS => {section: Report::Section::DefaultSections::CONNECTION, abstract_view: AbstractView::DefaultType::PENDING_PROJECT_REQUESTS},

      MENTORS_REGISTERED_BUT_NOT_ACTIVE => {section: Report::Section::DefaultSections::RECRUITMENT, abstract_view: AbstractView::DefaultType::MENTORS_REGISTERED_BUT_NOT_ACTIVE},
      MENTEES_REGISTERED_BUT_NOT_ACTIVE => {section: Report::Section::DefaultSections::RECRUITMENT, abstract_view: AbstractView::DefaultType::MENTEES_REGISTERED_BUT_NOT_ACTIVE},
      MENTORS_WITH_LOW_PROFILE_SCORES => {section: Report::Section::DefaultSections::RECRUITMENT, abstract_view: AbstractView::DefaultType::MENTORS_WITH_LOW_PROFILE_SCORES},
      MENTEES_WITH_LOW_PROFILE_SCORES => {section: Report::Section::DefaultSections::RECRUITMENT, abstract_view: AbstractView::DefaultType::MENTEES_WITH_LOW_PROFILE_SCORES},
      DRAFTED_CONNECTIONS => {section: Report::Section::DefaultSections::CONNECTION, abstract_view: AbstractView::DefaultType::DRAFTED_CONNECTIONS, condition: :create_views_related_to_drafted_connections?},
      MENTORS_IN_DRAFTED_CONNECTIONS => {section: Report::Section::DefaultSections::CONNECTION, abstract_view: AbstractView::DefaultType::MENTORS_IN_DRAFTED_CONNECTIONS},
      MENTEES_IN_DRAFTED_CONNECTIONS => {section: Report::Section::DefaultSections::CONNECTION, abstract_view: AbstractView::DefaultType::MENTEES_IN_DRAFTED_CONNECTIONS},
      MENTORS_YET_TO_BE_DRAFTED => {section: Report::Section::DefaultSections::CONNECTION, abstract_view: AbstractView::DefaultType::MENTORS_YET_TO_BE_DRAFTED},
      MENTEES_YET_TO_BE_DRAFTED => {section: Report::Section::DefaultSections::CONNECTION, abstract_view: AbstractView::DefaultType::MENTEES_YET_TO_BE_DRAFTED},
      NEVER_CONNECTED_MENTORS => {section: Report::Section::DefaultSections::CONNECTION, abstract_view: AbstractView::DefaultType::NEVER_CONNECTED_MENTORS},
      MENTORS_WITH_PENDING_MENTOR_REQUESTS => {section: Report::Section::DefaultSections::CONNECTION, abstract_view: AbstractView::DefaultType::MENTORS_WITH_PENDING_MENTOR_REQUESTS},
      MENTEES_WHO_SENT_REQUEST_BUT_NOT_CONNECTED => {section: Report::Section::DefaultSections::CONNECTION, abstract_view: AbstractView::DefaultType::MENTEES_WHO_SENT_REQUEST_BUT_NOT_CONNECTED},
      MENTEES_WHO_HAVENT_SENT_MENTORING_REQUEST => {section: Report::Section::DefaultSections::CONNECTION, abstract_view: AbstractView::DefaultType::MENTEES_WHO_HAVENT_SENT_MENTORING_REQUEST}
    }

    class << self
      def ongoing_mentoring_related_default_metrics
        [PENDING_CONNECTION_REQUESTS, INACTIVE_CONNECTIONS, CONNECTIONS_NEVER_GOT_GOING, ACTIVE_BUT_BEHIND_CONNECTIONS]
      end

      def onetime_mentoring_related_default_metrics
        [PENDING_MEETING_REQUESTS]
      end

      def all
        constants.collect{|c| const_get(c)}
      end
    end
  end

  # Associations
  belongs_to :section, class_name: Report::Section.name, foreign_key: :section_id
  belongs_to :abstract_view
  has_many :alerts, dependent: :destroy, class_name: Report::Alert.name, foreign_key: :metric_id

  # Validations
  validates :abstract_view_id, :section, :title, presence: true
  validates :default_metric, inclusion: {in: DefaultMetrics.all}, allow_nil: true
  validate :abstract_view_belongs_to_section_program
  before_update :reset_alert_filter_params

  scope :without_perf_issues, -> { where("default_metric IS NULL OR default_metric NOT IN (?)", [DefaultMetrics::MENTORS_WITH_LOW_PROFILE_SCORES, DefaultMetrics::MENTEES_WITH_LOW_PROFILE_SCORES]) }

  # Instance Methods

  def count(alert = nil)
    abstract_view.count(alert)
  end

  def program
    section.program
  end

  def alert
    self.alerts.first
  end

  def alert_specific_count_needed?
    !(AbstractView::DefaultViewsCommons.no_filter_for_alert_classes.include?(abstract_view.class) || alert.nil?)
  end

  private

  def abstract_view_belongs_to_section_program
    if self.section_id && self.abstract_view_id && self.program != self.abstract_view.program
      program_term = program.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term_downcase
      self.errors.add(:abstract_view_id, "activerecord.custom_errors.report/metric.abstract_view_not_in_program".translate(program: program_term))
    end
  end

  def reset_alert_filter_params
    return unless self.abstract_view_id_changed? && AbstractView.where(id: [self.abstract_view_id_was, self.abstract_view_id]).pluck(:type).uniq.size > 1 && invalid_filter_params_present?
    self.alerts.update_all(filter_params: nil)
  end

  def invalid_filter_params_present?
    return unless self.alerts.present?
    applied_filter_params = self.alerts.map do |alert|
      next unless alert.filter_params_hash.present?
      alert.filter_params_hash.values.map{ |filter_param| filter_param[:name] }
    end.flatten.compact.uniq
    allowed_filter_params = FilterUtils.constants.include?("#{self.abstract_view.class.to_s}Filters".to_sym) ? "FilterUtils::#{self.abstract_view.class.to_s}Filters::FILTERS".constantize.keys.map(&:to_s) : []
    (applied_filter_params - allowed_filter_params).present?
  end
end
