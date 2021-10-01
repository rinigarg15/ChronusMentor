# == Schema Information
#
# Table name: admin_view_columns
#
#  id                  :integer          not null, primary key
#  admin_view_id       :integer
#  profile_question_id :integer
#  column_key          :text(16777215)
#  position            :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  column_sub_key      :string(255)
#

class AdminViewColumn < ActiveRecord::Base
  ROLES_SEPARATOR = ", "

  module ColumnsGroup
    BASIC_INFO = "basic_info"
    PROFILE = "profile"
    MATCHING_AND_ENGAGEMENT = "matching_and_engagement"
    TIMELINE = "timeline"
    ORG_LEVEL_ENGAGEMENT = "engagement"
  end

  COLUMN_SPLITTER = ":"
  LANGUAGE_NOT_SET_DISPLAY = "-"
  ID_SUBKEY_JOINER = "-"

  module ScopedProfileQuestion
    module Location
      CITY = "city"
      STATE = "state"
      COUNTRY = "country"
    end

    def self.all
      [Location::CITY, Location::STATE, Location::COUNTRY]
    end
  end

  module Columns
    module Key
      MEMBER_ID = "member_id"
      FIRST_NAME = "first_name"
      LAST_NAME = "last_name"
      EMAIL = "email" 
      ROLES = "roles"
      STATE = "state"
      LANGUAGE = "language"
      GROUPS = "groups"
      CLOSED_GROUPS = "closed_groups"
      DRAFTED_GROUPS = "drafted_groups"
      CREATED_AT = "created_at"
      MENTORING_MODE = 'mentoring_mode'
      LAST_SEEN_AT = "last_seen_at"
      AVAILABLE_SLOTS = "available_slots"
      NET_RECOMMENDED_COUNT = "net_recommended_count"
      ORG_LEVEL_ONGOING_ENGAGEMENTS = "ongoing_engagements"
      ORG_LEVEL_CLOSED_ENGAGEMENTS = "closed_engagements"
      MEETING_REQUESTS_RECEIVED = "meeting_requests_received"
      MEETING_REQUESTS_SENT = "meeting_requests_sent"
      MEETING_REQUESTS_RECEIVED_V1 = "meeting_requests_received_v1"
      MEETING_REQUESTS_SENT_V1 = "meeting_requests_sent_v1"
      MEETING_REQUESTS_ACCEPTED = "meeting_requests_accepted"
      MEETING_REQUESTS_PENDING = "meeting_requests_pending"
      MEETING_REQUESTS_SENT_AND_ACCEPTED = "meeting_requests_sent_and_accepted_v1"
      MEETING_REQUESTS_RECEIVED_AND_ACCEPTED = "meeting_requests_received_and_accepted_v1"
      MEETING_REQUESTS_SENT_AND_PENDING = "meeting_requests_sent_and_pending_v1"
      MEETING_REQUESTS_RECEIVED_AND_PENDING = "meeting_requests_received_and_pending_v1"
      MEETING_REQUESTS_RECEIVED_AND_REJECTED = "meeting_requests_received_and_rejected"
      MEETING_REQUESTS_RECEIVED_AND_CLOSED = "meeting_requests_received_and_closed"
      PROFILE_SCORE = "profile_score"
      PROGRAM_USER_ROLES = "program_user_roles"
      TERMS_AND_CONDITIONS = 'terms_and_conditions_accepted'
      LAST_CLOSED_GROUP_TIME = 'last_closed_group_time'
      RATING = "rating"
      MENTORING_REQUESTS_SENT = 'mentoring_requests_sent_v1'
      MENTORING_REQUESTS_RECEIVED = 'mentoring_requests_received_v1'
      MENTORING_REQUESTS_SENT_AND_PENDING = 'mentoring_requests_sent_and_pending_v1'
      MENTORING_REQUESTS_RECEIVED_AND_PENDING = 'mentoring_requests_received_and_pending_v1'
      MENTORING_REQUESTS_RECEIVED_AND_REJECTED = 'mentoring_requests_received_and_rejected'
      MENTORING_REQUESTS_RECEIVED_AND_CLOSED = 'mentoring_requests_received_and_closed'
      LAST_DEACTIVATED_AT = 'last_deactivated_at'
      LAST_SUSPENDED_AT = 'last_suspended_at'

      TRANSLATE_KEY = {
        LAST_DEACTIVATED_AT => 'last_deactivated_at_v1',
        GROUPS => 'groups_v1',
        CLOSED_GROUPS => 'closed_groups_v1',
        DRAFTED_GROUPS => 'drafted_groups_v1',
        AVAILABLE_SLOTS => 'available_slots_v1'
      }

      def self.mentor_only
        [MEETING_REQUESTS_RECEIVED_V1, MEETING_REQUESTS_RECEIVED_AND_ACCEPTED, MEETING_REQUESTS_RECEIVED_AND_PENDING, MEETING_REQUESTS_RECEIVED_AND_REJECTED, MEETING_REQUESTS_RECEIVED_AND_CLOSED, RATING, MENTORING_REQUESTS_RECEIVED, MENTORING_REQUESTS_RECEIVED_AND_PENDING, MENTORING_REQUESTS_RECEIVED_AND_REJECTED, MENTORING_REQUESTS_RECEIVED_AND_CLOSED, NET_RECOMMENDED_COUNT]
      end

      def self.student_only
        [MEETING_REQUESTS_SENT_V1, MEETING_REQUESTS_SENT_AND_ACCEPTED, MEETING_REQUESTS_SENT_AND_PENDING, MENTORING_REQUESTS_SENT, MENTORING_REQUESTS_SENT_AND_PENDING]
      end

      def self.meeting_request_columns
        [MEETING_REQUESTS_RECEIVED_V1, MEETING_REQUESTS_SENT_V1, MEETING_REQUESTS_SENT_AND_ACCEPTED, MEETING_REQUESTS_RECEIVED_AND_ACCEPTED, MEETING_REQUESTS_SENT_AND_PENDING, MEETING_REQUESTS_RECEIVED_AND_PENDING, MEETING_REQUESTS_RECEIVED_AND_REJECTED, MEETING_REQUESTS_RECEIVED_AND_CLOSED]
      end

      def self.received_mentoring_request_columns
        [AdminViewColumn::Columns::Key::MENTORING_REQUESTS_RECEIVED, AdminViewColumn::Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_PENDING, AdminViewColumn::Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_REJECTED, AdminViewColumn::Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_CLOSED]
      end

      def self.sent_mentoring_request_columns
        [AdminViewColumn::Columns::Key::MENTORING_REQUESTS_SENT, AdminViewColumn::Columns::Key::MENTORING_REQUESTS_SENT_AND_PENDING]
      end

      def self.received_meeting_request_columns
        [AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_V1, AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_PENDING, AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_ACCEPTED, AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_REJECTED, AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_CLOSED]
      end

      def self.sent_meeting_request_columns
        [AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_V1, AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_AND_PENDING, AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_AND_ACCEPTED]
      end

      def self.mentoring_request_columns
        [MENTORING_REQUESTS_SENT, MENTORING_REQUESTS_RECEIVED, MENTORING_REQUESTS_SENT_AND_PENDING, MENTORING_REQUESTS_RECEIVED_AND_PENDING, MENTORING_REQUESTS_RECEIVED_AND_REJECTED, MENTORING_REQUESTS_RECEIVED_AND_CLOSED]
      end
    end

    module ProgramDefaults
      module Titles
        def self.translate(key, options = {})
          key = AdminViewColumn::Columns::Key::TRANSLATE_KEY[key] if AdminViewColumn::Columns::Key::TRANSLATE_KEY[key]
          "feature.admin_view.program_defaults.title.#{key.to_s}".translate(options)
        end
      end

      def self.defaults(options = {})
        {
          Key::MEMBER_ID => { title: Titles.translate(Key::MEMBER_ID) },
          Key::FIRST_NAME => {:title => Titles.translate(Key::FIRST_NAME)},
          Key::LAST_NAME => {:title => Titles.translate(Key::LAST_NAME)},
          Key::EMAIL => {:title => Titles.translate(Key::EMAIL)},
          Key::ROLES => {:title => Titles.translate(Key::ROLES)},
          Key::STATE => {:title => Titles.translate(Key::STATE)},
          Key::GROUPS => {title: Titles.translate(Key::GROUPS, {Mentoring_Connections: options[:Mentoring_Connections]})},
          Key::CLOSED_GROUPS => {title: Titles.translate(Key::CLOSED_GROUPS, {Mentoring_Connections: options[:Mentoring_Connections]})},
          Key::DRAFTED_GROUPS => {title: Titles.translate(Key::DRAFTED_GROUPS, {Mentoring_Connections: options[:Mentoring_Connections]})},
          Key::CREATED_AT => {:title => Titles.translate(Key::CREATED_AT)}
        }
      end

      def self.basic_information_columns(admin_view, options = {})
        hsh = {
          Key::MEMBER_ID => { title: Titles.translate(Key::MEMBER_ID) },
          Key::FIRST_NAME => {:title => Titles.translate(Key::FIRST_NAME)},
          Key::LAST_NAME => {:title => Titles.translate(Key::LAST_NAME)},
          Key::EMAIL => {:title => Titles.translate(Key::EMAIL)},
          Key::ROLES => {:title => Titles.translate(Key::ROLES)},
          Key::STATE => {:title => Titles.translate(Key::STATE)}
        }
        hsh.merge!({Key::LANGUAGE => {:title => Titles.translate(Key::LANGUAGE)}}) if admin_view.languages_filter_enabled?
        hsh
      end

      def self.admin_defaults
        {
          Key::MEMBER_ID => { title: Titles.translate(Key::MEMBER_ID) },
          Key::FIRST_NAME => {:title => Titles.translate(Key::FIRST_NAME)},
          Key::LAST_NAME => {:title => Titles.translate(Key::LAST_NAME)},
          Key::EMAIL => {:title => Titles.translate(Key::EMAIL)},
          Key::ROLES => {:title => Titles.translate(Key::ROLES)},
          Key::STATE => {:title => Titles.translate(Key::STATE)},
          Key::CREATED_AT => {:title => Titles.translate(Key::CREATED_AT)}
        }
      end

      def self.non_defaults(options = {})
        {
          Key::LAST_SEEN_AT => {:title => Titles.translate(Key::LAST_SEEN_AT)},
          Key::LAST_DEACTIVATED_AT => {:title => Titles.translate(Key::LAST_DEACTIVATED_AT)},
          Key::MEETING_REQUESTS_RECEIVED_V1 => {:title => Titles.translate(Key::MEETING_REQUESTS_RECEIVED_V1, {:Meeting => options[:Meeting]})},
          Key::MEETING_REQUESTS_SENT_V1 => {:title => Titles.translate(Key::MEETING_REQUESTS_SENT_V1, {:Meeting => options[:Meeting]})},
          Key::MEETING_REQUESTS_SENT_AND_ACCEPTED => {:title => Titles.translate(Key::MEETING_REQUESTS_SENT_AND_ACCEPTED, {:Meeting => options[:Meeting]})},
          Key::MEETING_REQUESTS_RECEIVED_AND_ACCEPTED => {:title => Titles.translate(Key::MEETING_REQUESTS_RECEIVED_AND_ACCEPTED, {:Meeting => options[:Meeting]})},
          Key::MEETING_REQUESTS_SENT_AND_PENDING => {:title => Titles.translate(Key::MEETING_REQUESTS_SENT_AND_PENDING, {:Meeting => options[:Meeting]})},
          Key::MEETING_REQUESTS_RECEIVED_AND_PENDING => {:title => Titles.translate(Key::MEETING_REQUESTS_RECEIVED_AND_PENDING, {:Meeting => options[:Meeting]})},
          Key::MEETING_REQUESTS_RECEIVED_AND_REJECTED => {title: Titles.translate(Key::MEETING_REQUESTS_RECEIVED_AND_REJECTED, {Meeting: options[:Meeting]})},
          Key::MEETING_REQUESTS_RECEIVED_AND_CLOSED => {title: Titles.translate(Key::MEETING_REQUESTS_RECEIVED_AND_CLOSED, {Meeting: options[:Meeting]})},
          Key::AVAILABLE_SLOTS => {title: Titles.translate(Key::AVAILABLE_SLOTS, {:Mentoring_Connection => options[:Mentoring_Connection]})},
          Key::NET_RECOMMENDED_COUNT => {title: Titles.translate(Key::NET_RECOMMENDED_COUNT, {mentees: options[:mentees]})},
          Key::PROFILE_SCORE => {:title => Titles.translate(Key::PROFILE_SCORE)},
          Key::TERMS_AND_CONDITIONS => {title: Titles.translate(Key::TERMS_AND_CONDITIONS)},
          Key::LAST_CLOSED_GROUP_TIME => {title: Titles.translate(Key::LAST_CLOSED_GROUP_TIME, {:Mentoring_Connection => options[:Mentoring_Connection]})},
          Key::MENTORING_MODE => {:title => Titles.translate(Key::MENTORING_MODE, {:Mentoring => options[:Mentoring]})},
          Key::RATING => {:title => Titles.translate(Key::RATING)},
          Key::MENTORING_REQUESTS_SENT => {:title => Titles.translate(Key::MENTORING_REQUESTS_SENT, {:Mentoring => options[:Mentoring]})},
          Key::MENTORING_REQUESTS_RECEIVED => {:title => Titles.translate(Key::MENTORING_REQUESTS_RECEIVED, {:Mentoring => options[:Mentoring]})},
          Key::MENTORING_REQUESTS_SENT_AND_PENDING => {:title => Titles.translate(Key::MENTORING_REQUESTS_SENT_AND_PENDING, {:Mentoring => options[:Mentoring]})},
          Key::MENTORING_REQUESTS_RECEIVED_AND_PENDING => {:title => Titles.translate(Key::MENTORING_REQUESTS_RECEIVED_AND_PENDING, {:Mentoring => options[:Mentoring]})},
          Key::MENTORING_REQUESTS_RECEIVED_AND_REJECTED => {title: Titles.translate(Key::MENTORING_REQUESTS_RECEIVED_AND_REJECTED, {Mentoring: options[:Mentoring]})},
          Key::MENTORING_REQUESTS_RECEIVED_AND_CLOSED => {title: Titles.translate(Key::MENTORING_REQUESTS_RECEIVED_AND_CLOSED, {Mentoring: options[:Mentoring]})}
        }
      end

      def self.timeline_columns(options = {})
        {
          Key::LAST_SEEN_AT => {:title => Titles.translate(Key::LAST_SEEN_AT)},
          Key::TERMS_AND_CONDITIONS => {title: Titles.translate(Key::TERMS_AND_CONDITIONS)},
          Key::LAST_CLOSED_GROUP_TIME => {title: Titles.translate(Key::LAST_CLOSED_GROUP_TIME, {:Mentoring_Connection => options[:Mentoring_Connection]})},
          Key::CREATED_AT => {:title => Titles.translate(Key::CREATED_AT)},
          Key::LAST_DEACTIVATED_AT => {:title => Titles.translate(Key::LAST_DEACTIVATED_AT)}
        }
      end

      def self.matching_and_engagement_columns(options = {})
        {
          Key::GROUPS => {title: Titles.translate(Key::GROUPS, {Mentoring_Connections: options[:Mentoring_Connections]})},
          Key::CLOSED_GROUPS => {title: Titles.translate(Key::CLOSED_GROUPS, {Mentoring_Connections: options[:Mentoring_Connections]})},
          Key::DRAFTED_GROUPS => {title: Titles.translate(Key::DRAFTED_GROUPS, {Mentoring_Connections: options[:Mentoring_Connections]})},
          Key::MEETING_REQUESTS_RECEIVED_V1 => {:title => Titles.translate(Key::MEETING_REQUESTS_RECEIVED_V1, {:Meeting => options[:Meeting]})},
          Key::MEETING_REQUESTS_SENT_V1 => {:title => Titles.translate(Key::MEETING_REQUESTS_SENT_V1, {:Meeting => options[:Meeting]})},
          Key::MEETING_REQUESTS_SENT_AND_ACCEPTED => {:title => Titles.translate(Key::MEETING_REQUESTS_SENT_AND_ACCEPTED, {:Meeting => options[:Meeting]})},
          Key::MEETING_REQUESTS_RECEIVED_AND_ACCEPTED => {:title => Titles.translate(Key::MEETING_REQUESTS_RECEIVED_AND_ACCEPTED, {:Meeting => options[:Meeting]})},
          Key::MEETING_REQUESTS_SENT_AND_PENDING => {:title => Titles.translate(Key::MEETING_REQUESTS_SENT_AND_PENDING, {:Meeting => options[:Meeting]})},
          Key::MEETING_REQUESTS_RECEIVED_AND_PENDING => {:title => Titles.translate(Key::MEETING_REQUESTS_RECEIVED_AND_PENDING, {:Meeting => options[:Meeting]})},
          Key::MEETING_REQUESTS_RECEIVED_AND_REJECTED => {title: Titles.translate(Key::MEETING_REQUESTS_RECEIVED_AND_REJECTED, {Meeting: options[:Meeting]})},
          Key::MEETING_REQUESTS_RECEIVED_AND_CLOSED => {title: Titles.translate(Key::MEETING_REQUESTS_RECEIVED_AND_CLOSED, {Meeting: options[:Meeting]})},
          Key::AVAILABLE_SLOTS => {title: Titles.translate(Key::AVAILABLE_SLOTS, {Mentoring_Connection: options[:Mentoring_Connection]})},
          Key::NET_RECOMMENDED_COUNT => {title: Titles.translate(Key::NET_RECOMMENDED_COUNT, {mentees: options[:mentees]})},
          Key::MENTORING_MODE => {:title => Titles.translate(Key::MENTORING_MODE, {:Mentoring => options[:Mentoring]})},
          Key::RATING => {:title => Titles.translate(Key::RATING)},
          Key::MENTORING_REQUESTS_SENT => {:title => Titles.translate(Key::MENTORING_REQUESTS_SENT, {:Mentoring => options[:Mentoring]})},
          Key::MENTORING_REQUESTS_RECEIVED => {:title => Titles.translate(Key::MENTORING_REQUESTS_RECEIVED, {:Mentoring => options[:Mentoring]})},
          Key::MENTORING_REQUESTS_SENT_AND_PENDING => {:title => Titles.translate(Key::MENTORING_REQUESTS_SENT_AND_PENDING, {:Mentoring => options[:Mentoring]})},
          Key::MENTORING_REQUESTS_RECEIVED_AND_PENDING => {:title => Titles.translate(Key::MENTORING_REQUESTS_RECEIVED_AND_PENDING, {:Mentoring => options[:Mentoring]})},
          Key::MENTORING_REQUESTS_RECEIVED_AND_REJECTED => {title: Titles.translate(Key::MENTORING_REQUESTS_RECEIVED_AND_REJECTED, {Mentoring: options[:Mentoring]})},
          Key::MENTORING_REQUESTS_RECEIVED_AND_CLOSED => {title: Titles.translate(Key::MENTORING_REQUESTS_RECEIVED_AND_CLOSED, {Mentoring: options[:Mentoring]})}
        }
      end

      def self.meeting_request_defaults
        {
          Key::MEETING_REQUESTS_RECEIVED_V1 => {:title => Titles.translate(Key::MEETING_REQUESTS_RECEIVED_V1, {:Meeting => nil})},
          Key::MEETING_REQUESTS_SENT_V1 => {:title => Titles.translate(Key::MEETING_REQUESTS_SENT_V1, {:Meeting => nil})},
          Key::MEETING_REQUESTS_SENT_AND_ACCEPTED => {:title => Titles.translate(Key::MEETING_REQUESTS_SENT_AND_ACCEPTED, {:Meeting => nil})},
          Key::MEETING_REQUESTS_RECEIVED_AND_ACCEPTED => {:title => Titles.translate(Key::MEETING_REQUESTS_RECEIVED_AND_ACCEPTED, {:Meeting => nil})},
          Key::MEETING_REQUESTS_SENT_AND_PENDING => {:title => Titles.translate(Key::MEETING_REQUESTS_SENT_AND_PENDING, {:Meeting => nil})},
          Key::MEETING_REQUESTS_RECEIVED_AND_PENDING => {:title => Titles.translate(Key::MEETING_REQUESTS_RECEIVED_AND_PENDING, {:Meeting => nil})},
          Key::MEETING_REQUESTS_RECEIVED_AND_REJECTED => {title: Titles.translate(Key::MEETING_REQUESTS_RECEIVED_AND_REJECTED, {Meeting: nil})},
          Key::MEETING_REQUESTS_RECEIVED_AND_CLOSED => {title: Titles.translate(Key::MEETING_REQUESTS_RECEIVED_AND_CLOSED, {Meeting: nil})}
        }
      end

      def self.mentoring_request_for_mentors_defaults
        {
          Key::MENTORING_REQUESTS_RECEIVED => {:title => Titles.translate(Key::MENTORING_REQUESTS_RECEIVED, {:Mentoring => nil})},
          Key::MENTORING_REQUESTS_RECEIVED_AND_PENDING => {:title => Titles.translate(Key::MENTORING_REQUESTS_RECEIVED_AND_PENDING, {:Mentoring => nil})},
          Key::MENTORING_REQUESTS_RECEIVED_AND_REJECTED => {title: Titles.translate(Key::MENTORING_REQUESTS_RECEIVED_AND_REJECTED, {Mentoring: nil})},
          Key::MENTORING_REQUESTS_RECEIVED_AND_CLOSED => {title: Titles.translate(Key::MENTORING_REQUESTS_RECEIVED_AND_CLOSED, {Mentoring: nil})}
        }
      end

      def self.mentoring_request_for_mentees_defaults
        {
          Key::MENTORING_REQUESTS_SENT => {:title => Titles.translate(Key::MENTORING_REQUESTS_SENT, {:Mentoring => nil})},
          Key::MENTORING_REQUESTS_SENT_AND_PENDING => {:title => Titles.translate(Key::MENTORING_REQUESTS_SENT_AND_PENDING, {:Mentoring => nil})}
        }
      end

      def self.mentoring_mode_column
        [
          Key::MENTORING_MODE
        ]
      end

      def self.coach_rating_column
        [
          Key::RATING
        ]
      end

      def self.ongoing_mentoring_dependent_columns
        [
          Key::GROUPS, Key::DRAFTED_GROUPS, Key::GROUPS, Key::CLOSED_GROUPS, Key::LAST_CLOSED_GROUP_TIME, Key::AVAILABLE_SLOTS, Key::MENTORING_MODE, Key::MENTORING_REQUESTS_SENT, Key::MENTORING_REQUESTS_RECEIVED, Key::MENTORING_REQUESTS_SENT_AND_PENDING, Key::MENTORING_REQUESTS_RECEIVED_AND_PENDING
        ]
      end

      def self.all
        [
          Key::MEMBER_ID, Key::FIRST_NAME, Key::LAST_NAME, Key::EMAIL, Key::ROLES, Key::LANGUAGE, Key::STATE, Key::DRAFTED_GROUPS, Key::CLOSED_GROUPS, Key::GROUPS,
          Key::CREATED_AT, Key::LAST_SEEN_AT, Key::MEETING_REQUESTS_RECEIVED_V1, Key::MEETING_REQUESTS_SENT_V1,
          Key::MEETING_REQUESTS_SENT_AND_ACCEPTED, Key::MEETING_REQUESTS_RECEIVED_AND_ACCEPTED, Key::MEETING_REQUESTS_SENT_AND_PENDING, Key::MEETING_REQUESTS_RECEIVED_AND_REJECTED, Key::MEETING_REQUESTS_RECEIVED_AND_CLOSED, Key::MEETING_REQUESTS_RECEIVED_AND_PENDING, Key::AVAILABLE_SLOTS, Key::NET_RECOMMENDED_COUNT, Key::PROFILE_SCORE,
          Key::TERMS_AND_CONDITIONS, Key::LAST_CLOSED_GROUP_TIME, Key::MENTORING_MODE, Key::RATING, Key::MENTORING_REQUESTS_SENT, Key::MENTORING_REQUESTS_RECEIVED, Key::MENTORING_REQUESTS_SENT_AND_PENDING, Key::MENTORING_REQUESTS_RECEIVED_AND_PENDING, Key::MENTORING_REQUESTS_RECEIVED_AND_REJECTED, Key::MENTORING_REQUESTS_RECEIVED_AND_CLOSED, Key::LAST_DEACTIVATED_AT
        ]
      end

      ### These columns display the count, which have to be centered for display ###
      def self.count_columns
        [
          Key::DRAFTED_GROUPS, Key::CLOSED_GROUPS, Key::GROUPS, Key::PROFILE_SCORE, Key::AVAILABLE_SLOTS, Key::NET_RECOMMENDED_COUNT, Key::RATING, Key::MENTORING_REQUESTS_SENT, Key::MENTORING_REQUESTS_RECEIVED, Key::MENTORING_REQUESTS_SENT_AND_PENDING, Key::MENTORING_REQUESTS_RECEIVED_AND_PENDING, Key::MENTORING_REQUESTS_RECEIVED_AND_REJECTED, Key::MENTORING_REQUESTS_RECEIVED_AND_CLOSED, Key::MEETING_REQUESTS_RECEIVED_V1, Key::MEETING_REQUESTS_SENT_V1, Key::MEETING_REQUESTS_SENT_AND_ACCEPTED, Key::MEETING_REQUESTS_RECEIVED_AND_ACCEPTED, Key::MEETING_REQUESTS_SENT_AND_PENDING, Key::MEETING_REQUESTS_RECEIVED_AND_PENDING, Key::MEETING_REQUESTS_RECEIVED_AND_REJECTED, Key::MEETING_REQUESTS_RECEIVED_AND_CLOSED, Key::ORG_LEVEL_ONGOING_ENGAGEMENTS, Key::ORG_LEVEL_CLOSED_ENGAGEMENTS
        ]
      end

      # Columns with date range filter
      def self.date_range_columns
        [
          Key::CREATED_AT, Key::LAST_SEEN_AT, Key::TERMS_AND_CONDITIONS, Key::MENTORING_REQUESTS_SENT, Key::MENTORING_REQUESTS_RECEIVED, Key::MENTORING_REQUESTS_SENT_AND_PENDING, Key::MENTORING_REQUESTS_RECEIVED_AND_PENDING, Key::MENTORING_REQUESTS_RECEIVED_AND_REJECTED, Key::MENTORING_REQUESTS_RECEIVED_AND_CLOSED, Key::MEETING_REQUESTS_RECEIVED_V1, Key::MEETING_REQUESTS_SENT_V1,
          Key::MEETING_REQUESTS_SENT_AND_ACCEPTED, Key::MEETING_REQUESTS_RECEIVED_AND_ACCEPTED, Key::MEETING_REQUESTS_SENT_AND_PENDING, Key::MEETING_REQUESTS_RECEIVED_AND_PENDING, Key::MEETING_REQUESTS_RECEIVED_AND_REJECTED, Key::MEETING_REQUESTS_RECEIVED_AND_CLOSED, Key::LAST_CLOSED_GROUP_TIME, Key::LAST_DEACTIVATED_AT, Key::LAST_SUSPENDED_AT
        ]
      end

      def self.has?(key_string)
        self.all.include?(key_string)
      end
    end

    module OrganizationDefaults
      def self.defaults(options = {})
        hsh = {
          Key::MEMBER_ID => { title: ProgramDefaults::Titles.translate(Key::MEMBER_ID) },
          Key::FIRST_NAME => {:title => ProgramDefaults::Titles.translate(Key::FIRST_NAME)},
          Key::LAST_NAME => {:title => ProgramDefaults::Titles.translate(Key::LAST_NAME)},
          Key::EMAIL => {:title => ProgramDefaults::Titles.translate(Key::EMAIL)},
          Key::STATE => {:title => ProgramDefaults::Titles.translate(Key::STATE)},
          Key::PROGRAM_USER_ROLES => {:title => options[:program_title]},
          Key::LAST_SUSPENDED_AT => {:title => ProgramDefaults::Titles.translate(Key::LAST_SUSPENDED_AT)}
        }
        hsh.merge!({Key::LANGUAGE => {:title => ProgramDefaults::Titles.translate(Key::LANGUAGE)}}) if options[:include_language]
        hsh
      end

      def self.engagement_columns
        {
          Key::ORG_LEVEL_ONGOING_ENGAGEMENTS => {:title => ProgramDefaults::Titles.translate(Key::ORG_LEVEL_ONGOING_ENGAGEMENTS)},
          Key::ORG_LEVEL_CLOSED_ENGAGEMENTS => {title: ProgramDefaults::Titles.translate(Key::ORG_LEVEL_CLOSED_ENGAGEMENTS)}
        }
      end

      def self.all
        [
          Key::MEMBER_ID, Key::FIRST_NAME, Key::LAST_NAME, Key::EMAIL, Key::STATE, Key::PROGRAM_USER_ROLES, Key::LANGUAGE, Key::ORG_LEVEL_ONGOING_ENGAGEMENTS, Key::ORG_LEVEL_CLOSED_ENGAGEMENTS, Key::LAST_SUSPENDED_AT
        ]
      end

      def self.has?(key_string)
        self.all.include?(key_string)
      end
    end

    module DateRangeColumns
      def self.custom_date_range_columns(admin_view)
        return [] unless admin_view
        admin_view.get_columns_of_question_type(ProfileQuestion::Type::DATE).collect{ |id| "#{AdminViewsHelper::COLUMN}#{id}" }
      end

      def self.all(admin_view)
        ProgramDefaults.date_range_columns + custom_date_range_columns(admin_view)
      end
    end

    def self.all
      ProgramDefaults.all + OrganizationDefaults.all
    end
  end

  belongs_to :admin_view
  belongs_to :profile_question

  validates :admin_view, :presence => true

  validates :column_key, 
    :presence => true, 
    :uniqueness => {:scope => :admin_view_id}, 
    :inclusion => { :in => Columns.all }, #TODO_EXCEPTION_GLOBALIZATION This will cause exception when the server loads. by - Arun
    :if => Proc.new { |column| column.profile_question_id.blank? }

  validates :column_sub_key, allow_blank: true, inclusion: { in: ScopedProfileQuestion.all }

  validates :profile_question_id,
    :presence => true,
    :uniqueness => {:scope => [:admin_view_id, :column_sub_key]},
    :if => Proc.new { |column| column.column_key.blank? }

  scope :default, -> { where("column_key is NOT NULL")}
  scope :custom, -> { where("admin_view_columns.profile_question_id is NOT NULL")}

  def self.find_object(column_object_array, column_key, admin_view)
    module_obj = admin_view.is_program_view? ? AdminViewColumn::Columns::ProgramDefaults : AdminViewColumn::Columns::OrganizationDefaults
    module_obj.has?(column_key) ? 
      column_object_array.find{|column| column.column_key == column_key } :
      column_object_array.find{|column| column.key == column_key }
  end

  def key
    self.column_key || [self.profile_question_id.to_s, self.column_sub_key].compact.join(ID_SUBKEY_JOINER)
  end

  def is_default?
    self.column_key.present?
  end

  def self.get_column_sub_key(key)
    key.split(ID_SUBKEY_JOINER).last
  end

  def self.scoped_profile_question_text(admin_view, profile_question, key)
    if key.include?(ID_SUBKEY_JOINER)
      (->(pq,k){"#{pq.question_text} (#{"feature.admin_view_column.scoped_question.#{AdminViewColumn.get_column_sub_key(k)}".translate})#{" *" if pq.mandatory_for_any_roles_in?(admin_view.program.roles)}"})[profile_question, key]
    else
      profile_question.send(*admin_view.profile_question_text_method)
    end
  end

  def get_title(options = {})
    self.is_default? ? (Columns::ProgramDefaults.defaults(options)[self.column_key] || Columns::ProgramDefaults.non_defaults(options)[self.column_key] || Columns::OrganizationDefaults.defaults(options.merge(include_language: true))[self.column_key] || Columns::OrganizationDefaults.engagement_columns[self.column_key])[:title] : AdminViewColumn.scoped_profile_question_text(admin_view, profile_question, key)
  end

  def get_answer(user_or_member, profile_answers_hash = {}, options={})
    case user_or_member
    when User
      get_user_answer(user_or_member, profile_answers_hash, options)
    when Member
      get_member_answer(user_or_member, profile_answers_hash, options)
    when Hash
      get_hashed_answer(user_or_member, profile_answers_hash, options)
    end
  end

  def columns_count
    if profile_question.education?
      Education.export_column_names.size
    elsif profile_question.experience?
      Experience.export_column_names.size
    elsif profile_question.publication?
      Publication.export_column_names.size
    elsif profile_question.manager?
      Manager.export_column_names.size
    else
      1
    end
  end

  def column_headers
    if profile_question.education?
      Education.column_names_for_question(profile_question)
    elsif profile_question.experience?
      Experience.column_names_for_question(profile_question)
    elsif profile_question.publication?
      Publication.column_names_for_question(profile_question)
    elsif profile_question.manager?
      Manager.column_names_for_question(profile_question)
    else
      []
    end
  end

private

  def get_hashed_answer(user_or_member_hash, profile_answers_hash, options={})
    use_scope = options.delete(:use_scope)
    is_default? ?
      default_hash_answer(user_or_member_hash, column_key, profile_answers_hash, options) :
      profile_answer_by_hash(user_or_member_hash, profile_answers_hash, use_scope)
  end

  def get_user_answer(user, profile_answers_hash, options={})
    use_scope = options.delete(:use_scope)
    self.is_default? ? default_answer(user, self.column_key, options) : profile_answer(user, profile_answers_hash, use_scope)
  end

  def get_member_answer(member, profile_answers_hash, options={})
    self.is_default? ? default_member_answer(member, self.column_key, options) : profile_answer(member, profile_answers_hash)
  end

  def profile_answer_by_hash(user_or_member_hash, profile_answers_hash, use_scope = true)
    member_id = user_or_member_hash['member_id'] || user_or_member_hash['id']
    user_answers = profile_answers_hash[member_id]
    answer = user_answers[profile_question_id].try(:first)
    self.profile_question.format_profile_answer(answer, csv: true, scope: column_sub_key)
  end

  def profile_answer(user_or_member, profile_answers_hash, use_scope = true)
    member_id = user_or_member.is_a?(User) ? user_or_member.member_id : user_or_member.id
    answer = profile_answers_hash.present? ?
      profile_answers_hash[member_id][self.profile_question_id].try(:first) :
      user_or_member.answer_for(self.profile_question)
    self.profile_question.format_profile_answer(answer, scope: column_sub_key)
  end

  def default_hash_answer(user_or_member_hash, key, profile_answers_hash, options={})
    user_or_member_hash['member_id'].present? ? default_user_hash_answer(user_or_member_hash, key, profile_answers_hash, options) : default_member_hash_answer(user_or_member_hash, key, profile_answers_hash, options)
  end

  def default_user_hash_answer(user_hash, key, profile_answers_hash, options={})
    case key
    when Columns::Key::ROLES
      roles_array = options[:users_role_names][user_hash['id']]
      program = options[:program] || User.find(user_hash['id']).program
      RoleConstants.to_program_role_names(program, roles_array).join(ROLES_SEPARATOR)
    when Columns::Key::STATE
      UsersHelper.state_to_string_map[user_hash['state']]
    when Columns::Key::GROUPS
      user_hash['active_groups_count']
    when Columns::Key::CLOSED_GROUPS
      user_hash['closed_groups_count']
    when Columns::Key::DRAFTED_GROUPS
      user_hash['drafted_groups_count']
    when Columns::Key::CREATED_AT
      DateTime.localize(user_hash['created_at'], format: :default_dashed)
    when Columns::Key::LAST_DEACTIVATED_AT
      if user_hash['last_deactivated_at']
        DateTime.localize(user_hash['last_deactivated_at'], format: :default_dashed)
      else
        'feature.admin_view_column.content.never_deactivated'.translate
      end
    when Columns::Key::LAST_SEEN_AT
      DateTime.localize(user_hash['last_seen_at'], format: :default_dashed) || ""
    when Columns::Key::PROFILE_SCORE
      users_with_profile_score_hash = profile_answers_hash[:users_with_score_hash] || {}
      users_with_profile_score_hash[user_hash['id']]
    when Columns::Key::AVAILABLE_SLOTS
      options[:is_mentor] ? options[:slots_available] : "display_string.NA".translate
    when Columns::Key::NET_RECOMMENDED_COUNT
      get_net_recommended_count(options[:is_mentor], options)
    when Columns::Key::TERMS_AND_CONDITIONS
      if user_hash['terms_and_conditions_accepted']
        DateTime.localize(user_hash['terms_and_conditions_accepted'])
      else
        'feature.admin_view_column.content.terms_and_conditions_not_accepted'.translate
      end
    when Columns::Key::RATING
      if options[:is_mentor]
        !options[:rating][user_hash['id']].nil? ? options[:rating][user_hash['id']].round(2) : "feature.coach_rating.label.not_rated_yet".translate
      else
        "display_string.NA".translate
      end
    when Columns::Key::MEETING_REQUESTS_RECEIVED_V1
      options[:is_mentor] ? options[:received_meeting_requests][user_hash['id']].to_i : "display_string.NA".translate
    when Columns::Key::MEETING_REQUESTS_SENT_V1
      options[:is_student] ? options[:sent_meeting_requests][user_hash['id']].to_i : "display_string.NA".translate
    when Columns::Key::MEETING_REQUESTS_RECEIVED_AND_ACCEPTED
      options[:is_mentor] ? options[:accepted_received_meeting_requests][user_hash['id']].to_i : "display_string.NA".translate
    when Columns::Key::MEETING_REQUESTS_SENT_AND_ACCEPTED
      options[:is_student] ? options[:accepted_sent_meeting_requests][user_hash['id']].to_i : "display_string.NA".translate
    when Columns::Key::MEETING_REQUESTS_RECEIVED_AND_PENDING
      options[:is_mentor] ? options[:pending_received_meeting_requests][user_hash['id']].to_i : "display_string.NA".translate
    when Columns::Key::MEETING_REQUESTS_RECEIVED_AND_REJECTED
      options[:is_mentor] ? options[:rejected_received_meeting_requests][user_hash['id']].to_i : "display_string.NA".translate
    when Columns::Key::MEETING_REQUESTS_RECEIVED_AND_CLOSED
      options[:is_mentor] ? options[:closed_received_meeting_requests][user_hash['id']].to_i : "display_string.NA".translate
    when Columns::Key::MEETING_REQUESTS_SENT_AND_PENDING
      options[:is_student] ? options[:pending_sent_meeting_requests][user_hash['id']].to_i : "display_string.NA".translate
    when Columns::Key::MENTORING_REQUESTS_RECEIVED
      options[:is_mentor] ? options[:received_mentoring_requests][user_hash['id']].to_i : "display_string.NA".translate
    when Columns::Key::MENTORING_REQUESTS_SENT
      options[:is_student] ? options[:sent_mentoring_requests][user_hash['id']].to_i : "display_string.NA".translate
    when Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_PENDING
      options[:is_mentor] ? options[:pending_received_mentoring_requests][user_hash['id']].to_i : "display_string.NA".translate
    when Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_REJECTED
      options[:is_mentor] ? options[:rejected_received_mentoring_requests][user_hash['id']].to_i : "display_string.NA".translate
    when Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_CLOSED
      options[:is_mentor] ? options[:closed_received_mentoring_requests][user_hash['id']].to_i : "display_string.NA".translate
    when Columns::Key::MENTORING_REQUESTS_SENT_AND_PENDING
      options[:is_student] ? options[:pending_sent_mentoring_requests][user_hash['id']].to_i : "display_string.NA".translate
    when Columns::Key::MENTORING_MODE
      options[:mentoring_mode][user_hash['id']]
    else
      user_hash[key.to_s]
    end
  end

  def default_member_hash_answer(member_hash, key, profile_answers_hash, options={})
    case key
      when Columns::Key::PROGRAM_USER_ROLES
        program_with_roles = []
        if options[:members_program_role_names][member_hash['id']].present?
          options[:members_program_role_names][member_hash['id']].each do |program_name, user_suspended_and_roles|
            user_suspended = user_suspended_and_roles['user_suspended'] ? 'feature.admin_view.status.deactivated'.translate : nil
            roles = user_suspended_and_roles['roles'].join(', ')
            roles_with_state = [roles, user_suspended].compact.join(' - ') # result example: "Alumnus, Protege - Suspended"
            program_with_roles << "#{program_name} (#{roles_with_state})" # result example: "English CS Program (Alumnus, Protege - Suspended)"
          end
        end
        program_with_roles.join('; ')
      when Columns::Key::STATE
        MembersHelper.state_to_string_map[member_hash['state']]
      when Columns::Key::MEMBER_ID
        member_hash["id"]
      when Columns::Key::ORG_LEVEL_ONGOING_ENGAGEMENTS
        member_hash['ongoing_engagements_count']
      when Columns::Key::ORG_LEVEL_CLOSED_ENGAGEMENTS
        member_hash['closed_engagements_count']
      when Columns::Key::LAST_SUSPENDED_AT
        DateTime.localize(member_hash['last_suspended_at'], format: :default_dashed)
      else
        member_hash[key.to_s]
    end
  end

  def default_answer(user, key, options={})
    case key 
    when Columns::Key::ROLES
      roles_array = user.role_names.sort
      program_roles = RoleConstants.to_program_role_names(user.program, roles_array)
      program_roles.join(ROLES_SEPARATOR)
    when Columns::Key::STATE
      UsersHelper.state_to_string_map[user.state]
    when Columns::Key::GROUPS
      user.active_groups.size
    when Columns::Key::CLOSED_GROUPS
      user.closed_groups.size
    when Columns::Key::DRAFTED_GROUPS
      user.drafted_groups.size
    when Columns::Key::CREATED_AT
      DateTime.localize(user.created_at, format: :default_dashed)
    when Columns::Key::LAST_DEACTIVATED_AT
      if user.last_deactivated_at
        DateTime.localize(user.last_deactivated_at, format: :default_dashed)
      else
        'feature.admin_view_column.content.never_deactivated'.translate
      end
    when Columns::Key::MENTORING_MODE
      user.mentoring_mode_option_text
    when Columns::Key::LAST_SEEN_AT
      DateTime.localize(user.last_seen_at, format: :default_dashed) || ""
    when Columns::Key::PROFILE_SCORE
      user.profile_score(options).sum
    when Columns::Key::MEETING_REQUESTS_RECEIVED_V1 
      if user.is_mentor?
        received_requests = user.received_meeting_requests
        date_range = options[:date_ranges].present? && options[:date_ranges][Columns::Key::MEETING_REQUESTS_RECEIVED_V1].presence
        date_range.present? ? received_requests.created_in_date_range(date_range).size : received_requests.size
      else
        "display_string.NA".translate
      end
    when Columns::Key::MEETING_REQUESTS_SENT_V1 
      if user.is_student?
        sent_requests = user.sent_meeting_requests
        date_range = options[:date_ranges].present? && options[:date_ranges][Columns::Key::MEETING_REQUESTS_SENT_V1].presence
        date_range.present? ? sent_requests.created_in_date_range(date_range).size : sent_requests.size
      else
        "display_string.NA".translate
      end
    when Columns::Key::MEETING_REQUESTS_RECEIVED_AND_ACCEPTED
      if user.is_mentor?
        received_and_accepted_requests = user.accepted_received_meeting_requests
        date_range = options[:date_ranges].present? && options[:date_ranges][Columns::Key::MEETING_REQUESTS_RECEIVED_AND_ACCEPTED].presence
        date_range.present? ? received_and_accepted_requests.created_in_date_range(date_range).size : received_and_accepted_requests.size
      else
        "display_string.NA".translate
      end
    when Columns::Key::MEETING_REQUESTS_SENT_AND_ACCEPTED
      if user.is_student?
        sent_and_accepted_requests = user.accepted_sent_meeting_requests
        date_range = options[:date_ranges].present? && options[:date_ranges][Columns::Key::MEETING_REQUESTS_SENT_AND_ACCEPTED].presence
        date_range.present? ? sent_and_accepted_requests.created_in_date_range(date_range).size : sent_and_accepted_requests.size
      else
        "display_string.NA".translate
      end
    when Columns::Key::MEETING_REQUESTS_SENT_AND_PENDING
      if user.is_student?
        sent_and_pending_requests = user.pending_sent_meeting_requests
        date_range = options[:date_ranges].present? && options[:date_ranges][Columns::Key::MEETING_REQUESTS_SENT_AND_PENDING].presence
        date_range.present? ? sent_and_pending_requests.created_in_date_range(date_range).size : sent_and_pending_requests.size
      else
        "display_string.NA".translate
      end
    when Columns::Key::MEETING_REQUESTS_RECEIVED_AND_PENDING
      if user.is_mentor?
        received_and_pending_requests = user.pending_received_meeting_requests
        date_range = options[:date_ranges].present? && options[:date_ranges][Columns::Key::MEETING_REQUESTS_RECEIVED_AND_PENDING].presence
        date_range.present? ? received_and_pending_requests.created_in_date_range(date_range).size : received_and_pending_requests.size
      else
        "display_string.NA".translate
      end
    when Columns::Key::MEETING_REQUESTS_RECEIVED_AND_REJECTED
      if user.is_mentor?
        received_and_rejected_requests = user.rejected_received_meeting_requests
        date_range = options[:date_ranges].present? && options[:date_ranges][Columns::Key::MEETING_REQUESTS_RECEIVED_AND_REJECTED].presence
        date_range.present? ? received_and_rejected_requests.created_in_date_range(date_range).size : received_and_rejected_requests.size
      else
        "display_string.NA".translate
      end
    when Columns::Key::MEETING_REQUESTS_RECEIVED_AND_CLOSED
      if user.is_mentor?
        received_and_closed_requests = user.closed_received_meeting_requests
        date_range = options[:date_ranges].present? && options[:date_ranges][Columns::Key::MEETING_REQUESTS_RECEIVED_AND_CLOSED].presence
        date_range.present? ? received_and_closed_requests.created_in_date_range(date_range).size : received_and_closed_requests.size
      else
        "display_string.NA".translate
      end
    when Columns::Key::AVAILABLE_SLOTS
      user.is_mentor? ? (options[:slots_available] || user.slots_available) : "display_string.NA".translate
    when Columns::Key::NET_RECOMMENDED_COUNT
      get_net_recommended_count(user.is_mentor?, options.merge(user: user))
    when Columns::Key::TERMS_AND_CONDITIONS
      if user.terms_and_conditions_accepted
        DateTime.localize(user.terms_and_conditions_accepted)
      else
        'feature.admin_view_column.content.terms_and_conditions_not_accepted'.translate
      end
    when Columns::Key::LAST_CLOSED_GROUP_TIME
      DateTime.localize(user.last_closed_group.first.try(:closed_at))
    when Columns::Key::RATING
      if user.is_mentor? && user.program.coach_rating_enabled?
        user.user_stat.present? ? user.user_stat.average_rating.round(2) : "feature.coach_rating.label.not_rated_yet".translate
      else
        "display_string.NA".translate
      end
    when Columns::Key::MENTORING_REQUESTS_RECEIVED 
      if user.is_mentor?
        received_requests = user.received_mentor_requests
        date_range = options[:date_ranges].present? && options[:date_ranges][Columns::Key::MENTORING_REQUESTS_RECEIVED].presence
        date_range.present? ? received_requests.created_in_date_range(date_range).size : received_requests.size
      else
        "display_string.NA".translate
      end
    when Columns::Key::MENTORING_REQUESTS_SENT
      if user.is_student?
        sent_requests = user.sent_mentor_requests
        date_range = options[:date_ranges].present? && options[:date_ranges][Columns::Key::MENTORING_REQUESTS_SENT].presence
        date_range.present? ? sent_requests.created_in_date_range(date_range).size : sent_requests.size
      else
        "display_string.NA".translate
      end
    when Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_PENDING
      if user.is_mentor?
        pending_received_requests = user.pending_received_mentor_requests
        date_range = options[:date_ranges].present? && options[:date_ranges][Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_PENDING].presence
        date_range.present? ? pending_received_requests.created_in_date_range(date_range).size : pending_received_requests.size
      else
        "display_string.NA".translate
      end
    when Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_REJECTED
      if user.is_mentor?
        rejected_received_requests = user.rejected_received_mentor_requests
        date_range = options[:date_ranges].present? && options[:date_ranges][Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_REJECTED].presence
        date_range.present? ? rejected_received_requests.created_in_date_range(date_range).size : rejected_received_requests.size
      else
        "display_string.NA".translate
      end
    when Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_CLOSED
      if user.is_mentor?
        closed_received_requests = user.closed_received_mentor_requests
        date_range = options[:date_ranges].present? && options[:date_ranges][Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_CLOSED].presence
        date_range.present? ? closed_received_requests.created_in_date_range(date_range).size : closed_received_requests.size
      else
        "display_string.NA".translate
      end
    when Columns::Key::MENTORING_REQUESTS_SENT_AND_PENDING
      if user.is_student?
        pending_sent_requests = user.pending_sent_mentor_requests
        date_range = options[:date_ranges].present? && options[:date_ranges][Columns::Key::MENTORING_REQUESTS_SENT_AND_PENDING].presence
        date_range.present? ? pending_sent_requests.created_in_date_range(date_range).size : pending_sent_requests.size
      else
        "display_string.NA".translate
      end
    when Columns::Key::LANGUAGE
      default_member_answer(user.member, key)
    else
      user.send(key)
    end
  end

  def get_net_recommended_count(is_user_mentor, options = {})
    is_user_mentor ? (options[:net_recommended_count] || options[:user].try(:net_recommended_count)) : "display_string.NA".translate
  end

  def default_member_answer(member, key, options={})
    if key == Columns::Key::PROGRAM_USER_ROLES
      return
    end
    case key 
    when Columns::Key::STATE
      MembersHelper.state_to_string_map[member.state]
    when Columns::Key::LANGUAGE
      member.language_title
    when Columns::Key::MEMBER_ID
      member.id
    when Columns::Key::ORG_LEVEL_ONGOING_ENGAGEMENTS
      get_ongoing_engagements_member_count(member, options)
    when Columns::Key::ORG_LEVEL_CLOSED_ENGAGEMENTS
      get_closed_engagements_member_count(member, options)
    when Columns::Key::LAST_SUSPENDED_AT
      DateTime.localize(member.last_suspended_at, format: :default_dashed)
    else
      member.send(key)
    end
  end

  def get_ongoing_engagements_member_count(member, options)
    ongoing_engagements_map = options[:ongoing_engagements_map]
    ongoing_engagements_member_count = ongoing_engagements_map[member.id] if ongoing_engagements_map.present?
    ongoing_engagements_member_count || "0"
  end

  def get_closed_engagements_member_count(member, options)
    closed_engagements_map = options[:closed_engagements_map]
    closed_engagements_member_count = closed_engagements_map[member.id] if closed_engagements_map.present?
    closed_engagements_member_count || "0"
  end
end
