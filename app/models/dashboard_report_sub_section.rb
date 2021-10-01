class DashboardReportSubSection < ActiveRecord::Base
  module Type
    module Enrollment
      INVITATIONS_ACCEPTANCE_RATE = "invitations_acceptance_rate"
      APPLICATIONS_STATUS = "applications_status"
      PUBLISHED_PROFILES = "published_profiles"

      def self.all
        [INVITATIONS_ACCEPTANCE_RATE, APPLICATIONS_STATUS, PUBLISHED_PROFILES]
      end
    end

    module CommunityAnnouncementsEvents
      ANNOUNCEMENTS_AND_EVENTS = "announcements_and_events"

      def self.all
        [ANNOUNCEMENTS_AND_EVENTS]
      end
    end

    module CommunityResources
      RESOURCES = "resources"

      def self.all
        [RESOURCES]
      end
    end

    module CommunityForumsArticles
      FORUMS_AND_ARTICLES = "forums_and_articles"

      def self.all
        [FORUMS_AND_ARTICLES]
      end
    end

    module Engagements
      ENGAGEMENTS_HEALTH = "engagements_health"
      ENGAGEMENTS_SURVEY_RESPONSES = "engagements_survey_responses"
      
      def self.all
        [ENGAGEMENTS_HEALTH, ENGAGEMENTS_SURVEY_RESPONSES]
      end
    end

    # For both meeting and group activity
    module GroupsActivity
      GROUPS_ACTIVITY = "groups_activty"
      MEETING_ACTIVITY = "meeting_activity"
      
      def self.all
        [GROUPS_ACTIVITY, MEETING_ACTIVITY]
      end
    end

    module Matching
      CONNECTED_USERS = "connected_users"
      MENTOR_REQUESTS = "mentor_requests"
      PROJECT_REQUESTS = "project_requests"
      MEETING_REQUESTS = "meeting_requests"
      CONNECTED_FLASH_USERS = "connected_flash_users"

      def self.all
        [CONNECTED_USERS, MENTOR_REQUESTS, CONNECTED_FLASH_USERS, PROJECT_REQUESTS, MEETING_REQUESTS]
      end

      module ConnectedUsers
        ONLY_ONGOING = "only_ongoing"
        ONGOING_AND_CLOSED = "ongoing_and_closed"
        ONGOING_AND_DRAFTED = "ongoing_and_drafted"

        def self.sub_settings
          [ONGOING_AND_CLOSED, ONLY_ONGOING, ONGOING_AND_DRAFTED]
        end
      end
    end

    def self.all
      [Enrollment, CommunityAnnouncementsEvents, CommunityResources, CommunityForumsArticles, Engagements, GroupsActivity, Matching].inject([]){|array, type| array + type.all}
    end
  end

  module Tile
    ENROLLMENT = "enrollemnt"
    COMMUNITY_ANNOUNCEMENTS_EVENTS = "community_announcements_events"
    COMMUNITY_RESOURCES = "community_resources"
    COMMUNITY_FORUMS_AND_ARTICLES = "community_forums_articles"
    ENGAGEMENTS = "Engagements"
    GROUPS_ACTIVITY = "groups_activty"
    MATCHING = "matching"

    REPORTS_MAPPING = {
      ENROLLMENT => Type::Enrollment.all,
      COMMUNITY_ANNOUNCEMENTS_EVENTS => Type::CommunityAnnouncementsEvents.all,
      COMMUNITY_RESOURCES => Type::CommunityResources.all,
      COMMUNITY_FORUMS_AND_ARTICLES => Type::CommunityForumsArticles.all,
      ENGAGEMENTS => Type::Engagements.all,
      GROUPS_ACTIVITY => Type::GroupsActivity.all,
      MATCHING => Type::Matching.all
    }
  end

  belongs_to :program

  validates :program, presence: true
  validates :report_type, uniqueness: { scope: :program_id }, presence: true, inclusion: DashboardReportSubSection::Type.all
end