# == Schema Information
#
# Table name: admin_views
#
#  id            :integer          not null, primary key
#  title         :string(255)
#  program_id    :integer          not null
#  filter_params :text(16777215)
#  default_view  :integer
#  created_at    :datetime
#  updated_at    :datetime
#  description   :text(16777215)
#  type          :string(255)      default("AdminView")
#  favourite     :boolean          default(FALSE)
#  favourited_at :datetime
#  role_id       :integer
#

class AbstractView < ActiveRecord::Base
  TABLE_NAME = "admin_views"
  self.table_name = TABLE_NAME

  # Constants
  module DefaultType
    ALL_USERS = 1
    MENTORS = 2
    MENTEES = 3
    ALL_MEMBERS = 4
    NEVER_SIGNEDUP_USERS = 5
    ALL_ADMINS = 6
    PENDING_REQUESTS = 7
    PENDING_INVITES = 8
    ACCEPTED_BUT_NOT_JOINED = 9
    REGISTERED_BUT_NOT_ACTIVE = 10
    PENDING_CONNECTION_REQUESTS = 11
    PENDING_MEETING_REQUESTS = 12
    NEVER_CONNECTED_MENTEES = 13
    CURRENTLY_NOT_CONNECTED_MENTEES = 14
    CONNECTIONS_NEVER_GOT_GOING = 15
    INACTIVE_CONNECTIONS = 16
    ACTIVE_BUT_BEHIND_CONNECTIONS = 17
    UNSATISFIED_USERS_CONNECTION = 18
    PENDING_FLAGS = 19
    PENDING_PROJECT_REQUESTS = 21
    USERS_WITH_LOW_PROFILE_SCORES = 24
    ELIGIBILITY_RULES_VIEW = 25
    TEACHERS = 26
    EMPLOYEES = 27
    LICENSE_COUNT = 28
    MENTORS_REGISTERED_BUT_NOT_ACTIVE = 29
    MENTEES_REGISTERED_BUT_NOT_ACTIVE = 30
    MENTORS_WITH_LOW_PROFILE_SCORES = 31
    MENTEES_WITH_LOW_PROFILE_SCORES = 32
    DRAFTED_CONNECTIONS = 33
    MENTORS_IN_DRAFTED_CONNECTIONS = 34
    MENTEES_IN_DRAFTED_CONNECTIONS = 35
    MENTORS_YET_TO_BE_DRAFTED = 36
    MENTEES_YET_TO_BE_DRAFTED = 37
    NEVER_CONNECTED_MENTORS = 38
    MENTORS_WITH_PENDING_MENTOR_REQUESTS = 39
    MENTEES_WHO_SENT_REQUEST_BUT_NOT_CONNECTED = 40
    MENTEES_WHO_HAVENT_SENT_MENTORING_REQUEST = 41
    AVAILABLE_MENTORS = 42

    CONDITION_MAPPING = {
      MENTORS_IN_DRAFTED_CONNECTIONS => Proc.new{|program| program.create_views_related_to_drafted_connections? },
      MENTEES_IN_DRAFTED_CONNECTIONS => Proc.new{|program| program.create_views_related_to_drafted_connections? },
      MENTORS_YET_TO_BE_DRAFTED => Proc.new{|program| program.create_views_related_to_drafted_connections? },
      MENTEES_YET_TO_BE_DRAFTED => Proc.new{|program| program.create_views_related_to_drafted_connections? },
      NEVER_CONNECTED_MENTORS => Proc.new{|program| program.create_views_related_to_connections? },
      PENDING_MEETING_REQUESTS => Proc.new{|program| program.calendar_enabled? || program.organization_features.empty?},
      MENTORS_WITH_PENDING_MENTOR_REQUESTS => Proc.new{|program| program.create_views_related_to_mentoring_requests? && program.matching_by_mentee_alone? },
      MENTEES_WHO_SENT_REQUEST_BUT_NOT_CONNECTED => Proc.new{|program| program.create_views_related_to_mentoring_requests? },
      MENTEES_WHO_HAVENT_SENT_MENTORING_REQUEST => Proc.new{|program| program.create_views_related_to_mentoring_requests? },
      AVAILABLE_MENTORS => Proc.new{|program| !program.only_one_time_mentoring_enabled?}
    }

    def self.all
      constants.collect{|c| const_get(c)}
    end

    def self.default_program_management_report_type
      [
        PENDING_REQUESTS, PENDING_INVITES, ACCEPTED_BUT_NOT_JOINED, REGISTERED_BUT_NOT_ACTIVE, PENDING_CONNECTION_REQUESTS,
        PENDING_MEETING_REQUESTS, NEVER_CONNECTED_MENTEES, CURRENTLY_NOT_CONNECTED_MENTEES, CONNECTIONS_NEVER_GOT_GOING,
        INACTIVE_CONNECTIONS, ACTIVE_BUT_BEHIND_CONNECTIONS, UNSATISFIED_USERS_CONNECTION, PENDING_FLAGS,
        PENDING_PROJECT_REQUESTS, USERS_WITH_LOW_PROFILE_SCORES
      ]
    end

    def self.is_view_applicable_to_program?(program, default_view)
      !CONDITION_MAPPING[default_view].present? || CONDITION_MAPPING[default_view].call(program)
    end
  end

  # Ordering
  module DefaultOrder
    WEIGHTS = {
      "AdminView" => 10,
      "MeetingRequestView" => 20,
      "MembershipRequestView" => 30,
      "MentorRequestView" => 40,
      "ProgramInvitationView" => 50,
      "ProjectRequestView" => 60,
      "ConnectionView" => 70,
      "FlagView" => 80
    }
  end

  module DependentViews
    ONGOING_MENTORING = ["MentorRequestView", "ConnectionView"]
  end

  # Associations
  belongs_to_program_or_organization
  has_many :metrics, dependent: :destroy, class_name: Report::Metric.name
  has_many :alerts, through: :metrics

  # Validations
  validates :program, :title, :filter_params, :presence => true
  validates :title, uniqueness: {scope: :program_id}
  validates :default_view, inclusion: {in: AbstractView::DefaultType.all}, allow_nil: true

  # Scopes
  scope :default, -> { where("default_view IS NOT NULL")}
  scope :defaults_first, -> { order("ISNULL(#{TABLE_NAME}.default_view), #{TABLE_NAME}.default_view ASC") }
  scope :without_metrics, -> { includes(:metrics).where( :report_metrics => {:abstract_view_id=>nil} ) }
  scope :without_ongoing_mentoring_style, -> { where("type NOT IN (?)", DependentViews::ONGOING_MENTORING)}

  # The following class vars have to be available for every child class of abstract view class
  def self.inherited(*args)
    super(*args)
    child_class = args[0]
    child_class.instance_eval do
      cattr_accessor :available_sub_views_for_current_program, :sub_view_display_name
    end
  end

  # modules
  module DefaultViewsCommons
    class << self
      def default_subview_classes
        [
          AdminView, FlagView, MeetingRequestView, MembershipRequestView,
          MentorRequestView, ProgramInvitationView, ProjectRequestView, ConnectionView
        ]
      end

      def get_valid_subviews_for_view(view_class)
        view_class::DefaultViews.all
      end

      def no_filter_for_alert_classes
        [ConnectionView, ProjectRequestView, FlagView]
      end

      def with_filter_for_alert_classes
        default_subview_classes - no_filter_for_alert_classes
      end
    end

    def create_for(program)
      klass = self.name.constantize
      subview_klass = klass.name.deconstantize.constantize
      all_subviews = AbstractView::DefaultViewsCommons.get_valid_subviews_for_view(subview_klass)
      create_views_for(program, all_subviews, subview_klass)
    end

    def create_views_for(program, subviews, subview_klass)
      subviews.map do |attr_container|
        attr_hsh = attr_container.respond_to?(:call) ? attr_container.call(program) : attr_container.dup
        enabled_for = attr_hsh.delete(:enabled_for)
        next unless enabled_for.include?(program.class)
        attrs = Hash[attr_hsh.to_a.map{|k, v| [k, v.call]}]
        attrs.merge!(program_id: program.id)
        title = attrs[:title]
        default_view = attrs[:default_view]
        unless AbstractView::DefaultType.is_view_applicable_to_program?(program, default_view)
          AbstractView.handle_invalid_subview_klass_view(program, default_view, title)
          next
        end
        raise "default_view is not set" if default_view.nil?
        create_or_update_view_for(program, subview_klass, default_view, title, attrs)
      end
    end

    def create_or_update_view_for(program, subview_klass, default_view, title, attrs)
      abstract_view = program.abstract_views.where("title = ? OR default_view = ?", title, default_view).first
      if abstract_view.nil? # create one
        abstract_view = subview_klass.create!(attrs)
        abstract_view.create_default_columns if subview_klass == AdminView
        abstract_view
      else # update the existing
        abstract_view.update_attributes!(attrs)
        abstract_view
      end
    end
  end

  # Class Methods
  class << self
    def convert_to_yaml(attrs_hash)
      attrs_hash.to_yaml.gsub(/--- \n/, "")
    end

    def handle_invalid_subview_klass_view(program, default_view, title)
      program.abstract_views.where(title: title).or(program.abstract_views.where(default_view: default_view)).first.try(:destroy)
    end
  end

  # Instance Methods

  def filter_params_hash
    ActiveSupport::HashWithIndifferentAccess.new(YAML.load(self.filter_params))
  end

  def is_program_view?
    self.program.is_a?(Program)
  end

  def is_organization_view?
    self.program.is_a?(Organization)
  end

  def organization
    self.is_organization_view? ? self.program : self.program.organization
  end

  def default?
    self.default_view.present?
  end

  def non_default?
    !default?
  end

  alias_method :editable?, :non_default?
  # Here, for the default admin views, this will return false
  # Though, the default admin views can edit their columns :p

  def count
    raise "AbstractView count method called, code should not reach here"
  end
end
