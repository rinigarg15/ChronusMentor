SUPERADMIN_EMAIL = "mentoradmin@chronus.com"
SUPPORT_EMAIL = "support@chronus.com"
THEME_S3_DEST = "theme-files/"
DEFAULT_ALLOWED_FILE_UPLOAD_TYPES = ["aplication/pdf", "application/download", "application/file", "application/force-download", "application/haansoftdocx", "application/kswps", "application/mp4", "application/msword", "application/octet-stream", "application/pdf", "application/rar", "application/rtf", "application/text-plain:formatted", "application/unknown", "application/vdn.pdf", "application/vnd.ms-excel", "application/vnd.ms-excel.sheet.macroenabled.12", "application/vnd.ms-powerpoint", "application/vnd.ms-publisher", "application/vnd.ms-word", "application/vnd.ms-word.document.12", "application/vnd.ms-xpsdocument", "application/vnd.oasis.opendocument.spreadsheet", "application/vnd.oasis.opendocument.text", "application/vnd.openxmlformats", "application/vnd.openxmlformats-officedocument.presentationml.presentation", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "application/vnd.openxmlformats-officedocument.word", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "application/vnd.pdf", "application/word", "application/x", "application/x-compress", "application/x-compressed", "application/x-doc", "application/x-download", "application/x-gzip", "application/x-itunes-itlp", "application/x-iwork-pages-sffpages", "application/x-koan", "application/x-pdf", "application/x-rar", "application/x-rar-compressed", "application/x-shockwave-flash", "application/x-unknown", "application/x-webarchive", "application/x-zip", "application/x-zip-compressed", "application/xml", "application/zip", "appliction/pdf", "audio/ogg", "audio/x-ms-wma", "binary/octet-stream", "d2l/unknowntype", "image/bmp", "image/gif", "image/ipeg", "image/jpeg", "image/jpg", "image/pdf", "image/pjpeg", "image/png", "image/tiff", "image/vnd.adobe.photoshop", "image/x-png", "message/rfc822", "multipart/related", "multipart/x-zip", "text/css", "text/csv", "text/comma-separated-values", "text/plain", "text/rtf", "text/text", "text/x-sql", "text/x-vcard", "text/xml", "video/3gpp", "video/avi", "video/mp4", "video/mpeg", "video/ogg", "video/quicktime", "video/vnd.objectvideo", "video/webm", "video/x-flv", "video/x-matroska", "video/x-ms-wmv", "video/x-msvideo", "application/excel"]
DEFAULT_ALLOWED_COMPRESSED_FILE_TYPES = [
  'application/rar',
  'application/x-rar',
  'application/x-rar-compressed',
  'application/zip',
  'application/x-zip',
  'application/x-zip-compressed',
  'application/octet-stream',
  'application/x-compress',
  'application/x-compressed',
  'multipart/x-zip'
]

DEFAULT_MIN_PREFERRED_MENTORS = 3
ONE_MEGABYTE = 2**20
MAX_INT32 = (1<<31) - 1
MIN_INT32 = -(1<<31)
MAX_INT64 = (1<<63) - 1
MIN_INT64 = -(1<<63)
MEETING_ICS_S3_PREFIX = "meeting_ics_files"
PROGRAM_EVENT_ICS_S3_PREFIX = "program_event_ics_files"
ICS_CONTENT_TYPE = "text/calendar"
TEMP_FILE_NAME = "event.ics"
SAML_SSO_DIR = "saml-sso-files"
SALES_DEMO_DIR = "sales-demo-files"
PROGRESS_REPORTS_S3_PREFIX = "progress_reports_files"
COMMON_SEPARATOR = ", "
COMMA_SEPARATOR = ","
IDS_SEPARATOR = " "
UNDERSCORE_SEPARATOR = "_"
LAST_WORD_CONNECTOR = ", & "
TWO_WORDS_CONNECTOR = " & "
DEMO_URL_SUBDOMAIN = "demo"
CK_ASSETS_REGEX = /\/(?:ck_attachments|ck_pictures)\/([0-9]+)/
DISALLOWED_FILE_EXTENSIONS = /\.((aspx?|php[1-9]?|vbs?|js(p|px)?|exe|rb|tiff|jar|html?|xht(ml)?)$)/i
CK_ATTACHMENT_SESSION_TIMEOUT = 30.minutes
LOGIN_INSTANCES_TRACKING_STARTED = '31/12/2013'.to_date
UTF8MB4_VARCHAR_LIMIT = 191
GA_TRACKER_READ_SYSEMAIL = "read_sysemail"
SELECT2_PER_PAGE_LIMIT = 15
SOURCE_AUDIT_KEY = "source_audit_key"
# Change this to a new date
BROWSER_WARNING_DATE = DateTime.new(2017, 3, 15, 0, 0, 0, '+0')
SHOW_WARNING_INTERVAL_DAYS = 3
NOTIFICATION_SECTION_HTML_ID = 'notifications_section'
AUTOCOMPLETE_EMAIL_BEGINNING = "<"
AUTOCOMPLETE_EMAIL_END = ">"
MAX_BULK_SIZE = 250 #maximum approximate number for bulk read and bulk write of mongo documents
PRIVACY_POLICY_UPDATED_AT = '28/08/2018'.to_date

# We added Byte Order Mark(BOM) to the CSV exports that the CSV with accented characters is rendered properly in Excel 2007+
# But, importing CSV with BOM will raise error if the uploaded file is not read with UTF8_BOM_ENCODING
# http://stackoverflow.com/a/155176
# https://chronus.atlassian.net/browse/AP-14084?focusedCommentId=50542&page=com.atlassian.jira.plugin.system.issuetabpanels%3Acomment-tabpanel#comment-50542
UTF8_BOM = "\xEF\xBB\xBF"
UTF8_BOM_ENCODING = "bom|utf-8"
CREATE_PREFERENCE = 'POST'
DELETE_PREFERENCE = 'DELETE'
DEFAULT_NO_LIMIT_VALUE = 0

require File.join(Rails.root, 'config', 'tab_constants')

module HttpConstants
  SUCCESS = 200
  FORBIDDEN = 403
  NO_CONTENT = 204
end

module AttachmentSize
  END_USER_ATTACHMENT_SIZE = 20.megabytes
  ADMIN_ATTACHMENT_SIZE = 50.megabytes
  LOGO_OR_BANNER_ATTACHMENT_SIZE = 2.megabytes
end

module DjPriority
  MONGO_DELTA_INDEX = 0
  MONGO_BIG_INDEX = 1
  SALES_DEMO = 2
  NON_BLOCKING_CHUNK_CREATE = 20
  NON_BLOCKING_BULK_CREATE = 25
  SALES_DEMO_FAILED = 4000
end

module MatchingHighLoadOrganizations
  ORGANIZATION_IDS = [876]
end

module DjSourcePriority
  # The following number will be subtracted from the dj.priority field to make the web djs runs first and cron djs the last.
  CRON = 0
  API = 1000
  BULK = 2000
  WEB = 3000
  CRON_HIGH = 3000
end

module DjQueues
  ES_DELTA = "es_delta"
  MONGO_CACHE = "mongo_cache"
  MONGO_CACHE_HIGH_LOAD = "mongo_cache_high_load"
  HIGH_PRIORITY = "high_priority"
  NORMAL = "normal"
  SPLIT = "split"
  LONG_RUNNING = "long_running"
  SLA = {
    HIGH_PRIORITY => { DjSourcePriority::WEB => 5.minutes, DjSourcePriority::CRON_HIGH => 5.minutes, DjSourcePriority::BULK => 10.minutes, DjSourcePriority::API => 20.minutes, DjSourcePriority::CRON => 20.minutes },
    ES_DELTA => { DjSourcePriority::WEB => 5.minutes, DjSourcePriority::CRON_HIGH => 5.minutes, DjSourcePriority::BULK => 10.minutes, DjSourcePriority::API => 20.minutes, DjSourcePriority::CRON => 20.minutes }, 
    MONGO_CACHE => { DjSourcePriority::WEB => 5.minutes, DjSourcePriority::CRON_HIGH => 5.minutes, DjSourcePriority::BULK => 10.minutes, DjSourcePriority::API => 20.minutes, DjSourcePriority::CRON => 20.minutes },
    MONGO_CACHE_HIGH_LOAD => { DjSourcePriority::WEB => 5.minutes, DjSourcePriority::CRON_HIGH => 5.minutes, DjSourcePriority::BULK => 10.minutes, DjSourcePriority::API => 20.minutes, DjSourcePriority::CRON => 20.minutes },
    NORMAL => { DjSourcePriority::WEB => 5.minutes, DjSourcePriority::CRON_HIGH => 5.minutes, DjSourcePriority::BULK => 10.minutes, DjSourcePriority::API => 20.minutes, DjSourcePriority::CRON => 20.minutes },
    SPLIT => { DjSourcePriority::WEB => 5.minutes, DjSourcePriority::CRON_HIGH => 5.minutes, DjSourcePriority::BULK => 10.minutes, DjSourcePriority::API => 10.minutes, DjSourcePriority::CRON => 10.minutes }
  }
  WEEKLY_DIGEST = "weekly_digest"
  AWS_ELASTICSEARCH_SERVICE = "AWS_ELASTICSEARCH_SERVICE"
end

module RegexConstants
  #While updating this regex for validation, please also update the frontend side validation code, regex for which, can be found
  #in base_app_jquery.js.erb under the function verifyEmailFormat.

  # email format copied from authentication.rb
  RE_EMAIL_NAME   = '[A-Z0-9!#\$%&\'\*\+\/=?^_`{|}~-]+(?:\.[A-z0-9!#/$%&\'\*\+\/=?^_`{|}~-]+)*' # technically allowed by RFC-2822
  RE_DOMAIN_HEAD  = '(?:[A-Z0-9](?:[A-Z0-9-]*[A-Z0-9])?\.)+'
  RE_DOMAIN_TLD   = '(?:[A-Z]{2}|com|org|net|edu|gov|mil|biz|info|mobi|name|aero|jobs|museum|host|int|coop|travel|global)'
  MSG_EMAIL_BAD   = "common_text.error_msg.msg_bad_email_v2"
  RE_DOMAIN_NAME  = /#{RE_DOMAIN_HEAD}#{RE_DOMAIN_TLD}/i

  #Regex that will not allow any numeric character
  RE_NO_NUMBERS = /\A([^0-9]*)\z/
  MSG_NAME_INVALID = "common_text.error_msg.name_contains_digits"
end

# Model related constants
################################################################################

# Dont change the numbers ever. If you need to delete an RA, delete it with number
# Don't reuse missing numbers too.
module RecentActivityConstants
  module Type
    MENTOR_JOIN_PROGRAM               = 1
    # JOIN_GROUP                      = 2
    SCRAP_CREATION                    = 3
    # LEAVE_PROGRAM                   = 4
    ANNOUNCEMENT_CREATION             = 5
    ANNOUNCEMENT_UPDATE               = 6
    CREATE_MEMBERSHIP_REQUEST         = 7
    FORUM_CREATION                    = 8
    TOPIC_CREATION                    = 9
    POST_CREATION                     = 10
    MENTOR_REQUEST_CREATION           = 11
    MENTOR_REQUEST_ACCEPTANCE         = 12
    MENTOR_REQUEST_REJECTION          = 13
    PROGRAM_CREATION                  = 14
    ADMIN_ADD_MENTOR                  = 15
    USER_SUSPENSION                   = 16
    # USER_DELETION                   = 17 -- removed
    USER_ACTIVATION                   = 18
    USER_PROMOTION                    = 19
    QA_ANSWER_CREATION                = 20 # only emails
    ARTICLE_CREATION                  = 21
    # ARTICLE_UPDATED                 = 22 -- removed
    ARTICLE_COMMENT_CREATION          = 23
    ARTICLE_MARKED_AS_HELPFUL         = 24
    #NEW_MESSAGE_CREATION              = 25 --removed
    # TASK_CREATION                     = 27 --removed
    # FEEDBACK_FORWARDED              = 28 --removed
    ADMIN_CREATION                    = 29
    #MENTOR_REQUEST_FORWARDED          = 30 --removed
    #MENTOR_REQUEST_FORWARD_REJECTION  = 31 --removed
    #NEW_ADMIN_MESSAGE_CREATION        = 32 --removed
    VISIT_MENTORING_AREA              = 33 # Not for display
    GROUP_CREATION                    = 34 # Not for display
    GROUP_REACTIVATION                = 35 # Not for display
    # TASK_DUE_DATE_CHANGE              = 36 --removed
    # TASK_MARK_DONE                    = 37 --removed
    # TASK_MARK_UNDONE                  = 38 --removed
    GROUP_CHANGE_EXPIRY_DATE          = 39
    GROUP_PRIVATE_NOTE_CREATION       = 40 # Not for display
    GROUP_MEMBER_ADDITION             = 41
    GROUP_MEMBER_REMOVAL              = 42
    #REPLY_TO_MESSAGE                  = 43 -- removed
    #REPLY_TO_ADMIN_MESSAGE            = 44 --removed
    # ADMIN_ADD_MENTEE                = 45 --removed
    # COMMON_TASK_CREATION            = 46 --removed
    MENTORING_OFFER_CREATION          = 47 # Mentor send a mentor offer to mentee
    MENTORING_OFFER_ACCEPTANCE        = 48
    MENTORING_OFFER_REJECTION         = 49
    MENTORING_OFFER_DIRECT_ADDITION   = 50 # Mentor directly add a mentor to one of his/her connection
    MEETING_CREATED                   = 55
    MEETING_UPDATED                   = 56
    MEETING_DECLINED                  = 57
    # ADMIN_MILESTONE_CREATED           = 58 -- removed
    # ADMIN_MILESTONE_UPDATED           = 59 -- removed
    # END_USER_MILESTONE_CREATED        = 60 -- removed
    # END_USER_MILESTONE_UPDATED        = 61 -- removed
    # ADMIN_MILESTONE_TASK_CREATED      = 62 -- removed
    # ADMIN_MILESTONE_TASK_UPDATED      = 63 -- removed
    # END_USER_MILESTONE_TASK_CREATED    = 64 -- removed
    # END_USER_MILESTONE_TASK_UPDATED    = 65 -- removed
    # END_USER_MILESTONE_TASK_OWNER_UPDATED = 66 -- removed
    # MILESTONE_TASK_STATUS_UPDATED      = 67 -- removed
    # MILESTONE_STATUS_UPDATED            = 68 -- removed
    GROUP_MEMBER_LEAVING                = 70
    GROUP_TERMINATING                   = 71
    MENTOR_REQUEST_WITHDRAWAL          = 72
    PROGRAM_EVENT_CREATION            = 73
    PROGRAM_EVENT_UPDATE              = 74
    PROGRAM_EVENT_DELETE              = 75
    PROGRAM_EVENT_INVITE_ACCEPT       = 76
    PROGRAM_EVENT_INVITE_REJECT       = 77
    PROGRAM_EVENT_INVITE_MAYBE        = 78
    QA_QUESTION_CREATION              = 79
    MEETING_ACCEPTED                  = 80
    GROUP_MEMBER_UPDATE               = 81
    COACHING_GOAL_CREATION            = 82
    COACHING_GOAL_UPDATED            = 83
    COACHING_GOAL_ACTIVITY_CREATION   = 84
    USER_DEMOTION                    = 85  # Not for display
    MENTOR_REQUEST_CLOSED_SENDER     = 86
    MENTOR_REQUEST_CLOSED_RECIPIENT  = 87
  # PREFERRED_MENTOR_REQUEST_CLOSED  = 88
    SITUATION_MENTOR_REQUEST_TO_ADMIN = 89
    MENTOR_REQUEST_TO_ADMIN           = 90
    SITUATION_MENTOR_REQUEST          = 91
    MENTOR_REQUEST_WITHDRAWAL_TO_ADMIN = 92
    MENTORING_MODEL_TASK_CREATION     = 93
    THREE_SIXTY_SURVEY_ASSESSEE_NOTIFICATION = 94
    THREE_SIXTY_SURVEY_REVIEWER_NOTIFICATION = 95
    PROJECT_REQUEST_ACCEPTED = 96 # Used for emails and activity tracking on group, not for display
    PROJECT_REQUEST_REJECTED = 97 # Used for emails and activity tracking on group, not for display
    PROJECT_REQUEST_SENT = 98 # Not for display
    # Not using the already existing constants, as this is used exclusively for tracking.
    # This will not be used for display purposes, unlike other constants
    GROUP_MEMBER_ADDITION_REMOVAL = 99
    NEW_ADMIN_MESSAGE_TO_MEMBER = 100
    MEETING_REQUEST_CLOSED_SENDER     = 101
    MEETING_REQUEST_CLOSED_RECIPIENT  = 102
    AUTO_EMAIL_NOTIFICATION = 103
    GROUP_RELATED_ACTIVITY = 104
    USER_CAMPAIGN_EMAIL_NOTIFICATION = 105
    COACH_RATING_ADMIN_NOTIFICATION = 106
    MENTOR_OFFER_CLOSED_SENDER = 107
    MENTOR_OFFER_CLOSED_RECIPIENT = 108
    MENTOR_OFFER_WITHDRAWAL = 109
    ADMIN_MESSAGE_NOTIFICATION = 110
    INBOX_MESSAGE_NOTIFICATION = 111
    INBOX_MESSAGE_NOTIFICATION_FOR_TRACK = 112
    PROJECT_REQUEST_CLOSED = 113
    PROJECT_REQUEST_WITHDRAWN = 114

    def self.get_constant_name_by_value(value)
      constants.find { |name| const_get(name) == value }
    end

    def self.all
      constants.collect{|c| const_get(c)}
    end
  end

  module Target
    ALL = 1
    MENTORS = 2
    MENTEES = 3
    ADMINS = 4
    USER = 5
    NONE = 6
    OTHER_NON_ADMINISTRATIVE_ROLES = 7
  end

  module Scope
    ADMIN = 'admin'
    STUDENT = 'student'
    MENTOR = 'mentor'
    MENTOR_AND_STUDENT = 'mentor_and_student'
    OTHER_NON_ADMINISTRATIVE_ROLES = 'other_non_administrative_roles'
    ALL = 'all'
  end

  EmailTemplate = {
    Type::ANNOUNCEMENT_CREATION                     => 'announcement_notification',
    Type::ANNOUNCEMENT_UPDATE                       => 'announcement_update_notification',
    Type::MENTOR_REQUEST_ACCEPTANCE                 => 'mentor_request_accepted',
    Type::MENTOR_REQUEST_REJECTION                  => 'mentor_request_rejected',
    Type::MENTOR_REQUEST_WITHDRAWAL                 => 'mentor_request_withdrawn',
    Type::POST_CREATION                             => 'forum_notification',
    Type::TOPIC_CREATION                            => 'forum_topic_notification',
    Type::QA_ANSWER_CREATION                        => "qa_answer_notification",
    Type::ARTICLE_CREATION                          => 'new_article_notification',
    Type::ARTICLE_COMMENT_CREATION                  => 'article_comment_notification',
    Type::NEW_ADMIN_MESSAGE_TO_MEMBER                => 'new_admin_message_notification_to_member',
    Type::PROGRAM_EVENT_CREATION                    => 'new_program_event_notification',
    Type::PROGRAM_EVENT_UPDATE                      => 'program_event_update_notification',
    Type::PROGRAM_EVENT_DELETE                      => 'program_event_delete_notification',
    Type::MEETING_REQUEST_CLOSED_SENDER             => 'meeting_request_closed_for_sender',
    Type::MEETING_REQUEST_CLOSED_RECIPIENT          => 'meeting_request_closed_for_recipient',
    Type::MENTOR_REQUEST_CLOSED_SENDER              => 'mentor_request_closed_for_sender',
    Type::MENTOR_REQUEST_CLOSED_RECIPIENT           => 'mentor_request_closed_for_recipient',
    Type::MENTOR_REQUEST_CREATION                   => 'new_mentor_request',
    Type::MENTOR_REQUEST_TO_ADMIN                   => 'new_mentor_request_to_admin',
    Type::MENTOR_REQUEST_WITHDRAWAL_TO_ADMIN        => 'mentor_request_withdrawn_to_admin',
    Type::THREE_SIXTY_SURVEY_ASSESSEE_NOTIFICATION  => 'three_sixty_survey_assessee_notification',
    Type::THREE_SIXTY_SURVEY_REVIEWER_NOTIFICATION  => 'three_sixty_survey_reviewer_notification',
    Type::PROJECT_REQUEST_ACCEPTED                  => 'project_request_accepted',
    Type::PROJECT_REQUEST_REJECTED                  => 'project_request_rejected',
    Type::AUTO_EMAIL_NOTIFICATION                   => 'auto_email_notification',
    Type::USER_CAMPAIGN_EMAIL_NOTIFICATION          => 'user_campaign_email_notification',
    Type::MENTOR_OFFER_CLOSED_SENDER                => 'mentor_offer_closed_for_sender',
    Type::MENTOR_OFFER_CLOSED_RECIPIENT             => 'mentor_offer_closed_for_recipient',
    Type::MENTOR_OFFER_WITHDRAWAL                   => 'mentor_offer_withdrawn',
    Type::ADMIN_MESSAGE_NOTIFICATION                => 'admin_message_notification',
    Type::INBOX_MESSAGE_NOTIFICATION                => 'inbox_message_notification',
    Type::INBOX_MESSAGE_NOTIFICATION_FOR_TRACK      => 'inbox_message_notification_for_track'
  }

  PER_PAGE = 20
  PER_PAGE_SIDEBAR = 5
end

# This is retained for some old migrations
module ForumFor
  MENTOR = 0
  STUDENT = 1
end

module UserConstants

  module DigestV2Setting
    module ProgramUpdates
      IMMEDIATE = 0
      DAILY     = 1
      NONE      = 2
      WEEKLY    = 3
      DONT_SEND = 4 # this is transient state

      class << self
        def for_announcement
          [IMMEDIATE, WEEKLY, DONT_SEND]
        end

        def days_count
          { DAILY => 1, WEEKLY => 7, IMMEDIATE => 0, DONT_SEND => 1e18, NONE => 1e18 }
        end

        def all_db_valid
          [IMMEDIATE, DAILY, NONE, WEEKLY]
        end

        def all_transient
          [DONT_SEND]
        end

        def all
          all_db_valid + all_transient
        end
      end
    end

    module GroupUpdates
      WEEKLY    = 0
      DAILY     = 1
      NONE      = 2

      def self.days_count
        { DAILY => 1, WEEKLY => 7, NONE => 1e18 }
      end

      def self.all
        [DAILY, WEEKLY, NONE]
      end
    end
  end

  PROFILE_UPDATE_PROMPT = 'update_prompt'
  NEGATIVE_CONNECTIONS_LIMIT_ERROR_MESSAGE = 'negative_connections_limit_error'
  MAX_CONNECTIONS_LIMIT_ERROR_MESSAGE = 'max_connections_limit_error'
  CAN_CHANGE_CONNECTIONS_LIMIT_ERROR_MESSAGE = 'can_change_connections_limit_error'
  CONNECTIONS_LIMIT_ERRORS = [NEGATIVE_CONNECTIONS_LIMIT_ERROR_MESSAGE, MAX_CONNECTIONS_LIMIT_ERROR_MESSAGE, CAN_CHANGE_CONNECTIONS_LIMIT_ERROR_MESSAGE]
  PER_PAGE_OPTIONS = [10, 20, 30, 40]
end

module UserAvailabilityImages
  module Ongoing
    AVAILABLE = "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/ongoing_available.png"
    UNAVAILABLE = "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/ongoing_unavailable.png"
  end

  module Onetime
    AVAILABLE = "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/onetime_available.png"
    UNAVAILABLE = "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/onetime_unavailable.png"
  end
end

module PublicIcons
  MAP_MARKER = "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/map_marker.png"
  CIRCLE_CHECK = "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/circle_check.png"
  FAVORITE_STAR = "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/star.png"

  module DigestV2
    TASKS = "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/font-awesome_4-7-0_check-square-o_40_0_00566a_none.png"
    USERS = "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/material-icons_3-0-1_notifications-none_50_0_00566a_none.png"
    BULLET = "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/bullet_black.png"
    CARD_COMMENT_OR_POST_ICON = "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/font-awesome_4-7-0_comment_30_0_717073_none.png"
    QA_ANSWER_ICON = "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/font-awesome_4-7-0_question-circle_30_0_717073_none.png"
    ARTICLE_COMMENT_OR_ARTICLE_CREATION_ICON = "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/icomoon-free_2014-12-23_blog_30_0_717073_none.png"
    PROGRAM_EVENT_RELATED_ICON = "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/font_awesome_4_7_0_calendar_40_0_e2eef2_none.png"
    ANNOUNCEMENT_RELATED_ICON = "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/font-awesome_4-7-0_bullhorn_30_0_717073_none.png"
  end
end

module LocationConstants
  # Fix all JS validations when this constant is changed.
  PROMPT_TEXT = "City/town name"
end

module InviteConstants
  EXPIRY_NOTIFICATION_TIME = 5.days.from_now
  MAX_SECOND_NOTIFICATIONS_PER_DAY = 500
end

module ProfileConstants
  ACADEMIC_DEGREES = ["B.E.", "B.Tech", "B.Arch", "B.S.", "M.E.",
    "M.B.A.", "M.Tech", "M.S.", "M.C.A", "M.Arch", "M.Plan", "Ph.D"].sort + ["Other"]

  ACADEMIC_MAJORS = ["Computers", "Civil", "Environmental", "Water Resources",
    "Mechanical", "Printing", "Manufacturing", "Medicine",
    "Industrial", "Electrical", "Electronics and Communication", "Computer Science",
    "Electronics", "Media", "Mathematics", "Physics", "Chemistry", "Chemical",
    "Textile", "Bio-Technology", "Architecture and Planning"].sort + ["Other"]

  START_YEAR = 1945

  DEFAULT_ABOUT_ME = "Eg: I know what it takes to be successful and I am passionate about challenging and supporting you to be the very best you can."

  PROFILE_CHANGE_PROMPT_PERIOD = 2.weeks

  def self.valid_years
    (START_YEAR..Time.current.year).to_a
  end

  def self.valid_graduation_years
    (START_YEAR..(Time.current.year + 10)).to_a
  end
end

module PendingNotificationConstants
  ALLOWED_ACTION_TYPES = [
    RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
    RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE,
    RecentActivityConstants::Type::MENTOR_REQUEST_CREATION,
    RecentActivityConstants::Type::MENTOR_REQUEST_ACCEPTANCE,
    RecentActivityConstants::Type::MENTOR_REQUEST_REJECTION,
    RecentActivityConstants::Type::MENTOR_REQUEST_WITHDRAWAL,
    RecentActivityConstants::Type::POST_CREATION,
    RecentActivityConstants::Type::TOPIC_CREATION,
    RecentActivityConstants::Type::QA_ANSWER_CREATION,
    RecentActivityConstants::Type::ARTICLE_CREATION,
    RecentActivityConstants::Type::ARTICLE_MARKED_AS_HELPFUL,
    RecentActivityConstants::Type::ARTICLE_COMMENT_CREATION,
    RecentActivityConstants::Type::NEW_ADMIN_MESSAGE_TO_MEMBER,
    RecentActivityConstants::Type::PROGRAM_EVENT_CREATION,
    RecentActivityConstants::Type::PROGRAM_EVENT_UPDATE,
    RecentActivityConstants::Type::PROGRAM_EVENT_DELETE,
    RecentActivityConstants::Type::GROUP_MEMBER_LEAVING,
    RecentActivityConstants::Type::GROUP_MEMBER_UPDATE,
    RecentActivityConstants::Type::GROUP_CHANGE_EXPIRY_DATE,
    RecentActivityConstants::Type::USER_SUSPENSION,
    RecentActivityConstants::Type::MENTORING_OFFER_ACCEPTANCE,
    RecentActivityConstants::Type::COACHING_GOAL_CREATION,
    RecentActivityConstants::Type::COACHING_GOAL_UPDATED,
    RecentActivityConstants::Type::COACHING_GOAL_ACTIVITY_CREATION,
    RecentActivityConstants::Type::MENTOR_REQUEST_CLOSED_SENDER,
    RecentActivityConstants::Type::MENTOR_REQUEST_CLOSED_RECIPIENT,
    RecentActivityConstants::Type::MEETING_REQUEST_CLOSED_SENDER,
    RecentActivityConstants::Type::MEETING_REQUEST_CLOSED_RECIPIENT,
    RecentActivityConstants::Type::SITUATION_MENTOR_REQUEST_TO_ADMIN,
    RecentActivityConstants::Type::MENTOR_REQUEST_TO_ADMIN,
    RecentActivityConstants::Type::SITUATION_MENTOR_REQUEST,
    RecentActivityConstants::Type::MENTOR_REQUEST_WITHDRAWAL_TO_ADMIN,
    RecentActivityConstants::Type::THREE_SIXTY_SURVEY_ASSESSEE_NOTIFICATION,
    RecentActivityConstants::Type::THREE_SIXTY_SURVEY_REVIEWER_NOTIFICATION,
    RecentActivityConstants::Type::MENTORING_MODEL_TASK_CREATION,
    RecentActivityConstants::Type::PROJECT_REQUEST_ACCEPTED,
    RecentActivityConstants::Type::PROJECT_REQUEST_REJECTED,
    RecentActivityConstants::Type::AUTO_EMAIL_NOTIFICATION,
    RecentActivityConstants::Type::USER_CAMPAIGN_EMAIL_NOTIFICATION,
    RecentActivityConstants::Type::MENTOR_OFFER_CLOSED_SENDER,
    RecentActivityConstants::Type::MENTOR_OFFER_CLOSED_RECIPIENT,
    RecentActivityConstants::Type::MENTOR_OFFER_WITHDRAWAL,
    RecentActivityConstants::Type::INBOX_MESSAGE_NOTIFICATION,
    RecentActivityConstants::Type::ADMIN_MESSAGE_NOTIFICATION
 ]
end

module FacilitationMessageConstants
  module MentoringTips
    module MentorTips
      TIP_1 = "Demonstrate interest, helpful intent, and involvement. When you talk with your mentee, clear your mind of unnecessary thoughts and distractions, so that you can give her or him your undivided attention."
      TIP_2 = "Establish rapport by learning or remembering personal information about the mentees."
      TIP_3 = "Begin by focusing on mentee's strengths and potentials rather than limitations."
      TIP_4 = "Keep in frequent contact with mentees. Even a short email or phone call can make a big difference."
      TIP_5 = "Be available and keep office hours and appointments."
      TIP_6 = "Followup on mentee commitments and goals."
      TIP_7 = "Don't be critical of other faculty or staff to mentees."
      TIP_8 = "Consistently evaluate the effectiveness of your mentoring and adjust accordingly."
      TIP_9 = "Be yourself and give your mentee the room to be themselves."
      TIP_10 = "A sign of good listening is that your mentee feels s/he has been heard and understood. It allows your mentee to feel accepted by you and thus allows your mentoring relationship to build trust. Remembering or showing interest in things your mentee mentioned in the past is one form of active listening and is likely to be appreciated by your mentee."
      TIP_11 = "Did your mentee make her/his point clear? Do you understand what he/she is saying? Asking for clarification will allow your mentee to restate, elaborate, or reconsider what it is s/he is trying to convey."
      TIP_12 = "Your mentee may not have stated her/his assumptions, but can they be understood? What are the underlying assumptions in the question or message? Stating your understanding of it or asking your mentee about them can be useful toward preventing misinterpretations."
      TIP_13 = "We can't stress enough the importance of letting each other know your schedules in advance. This helps to prevent communication breakdown, which often results in unnecessary frustration."
      TIP_14 = "What makes mentors effective may very well rest in the ability to inspire their mentees. By setting an example, you may be able to motivate your mentee onto future paths beyond her/his original dreams. Challenge your mentee to find importance in what s/he aspires to do, and help create future visions for her/himself."
      TIP_16 = "All of us have probably found ourselves acting defensively at one time or another when we received feedback. Taking feedback well is not always easy, and hearing it in a motivating, encouraging tone can help your mentee to accept and apply it readily."
      TIP_17 = "Trusting that your discussions are confidential and that the mentoring relationship is mutually supportive are important building blocks for the mentoring relationship. When speaking of your mentee to others, provide only positive or neutral comments."
      TIP_18 = "By meeting people, connecting with them, and keeping in touch, you are probably constantly networking. We hope you will share some of your advice, approach, and insight into networking with your mentee."
      TIP_19 = "Revisit the goals that you have set for your mentoring partnership and for yourself. Are you on course to achieve what you had set out to do?"
      TIP_20 = "Could you have done something better? A renewed vigor can help you and your partner move forward."
      TIP_21 = "When the time comes, have a conversation that focuses on redefining the relationship (talk about how the relationship is to continue, whether it moves from professional mentoring relationship to colleague, friendship, or ceases to exist at all)"

      def self.all
        [TIP_1, TIP_2, TIP_3, TIP_4, TIP_5, TIP_6, TIP_7, TIP_8, TIP_9, TIP_10, TIP_11,
          TIP_12, TIP_13, TIP_14, TIP_16, TIP_17, TIP_18, TIP_19, TIP_20, TIP_21]
      end
    end

    module MenteeTips
      TIP_1 = "In order to have a successful mentoring relationship, you need to understand your needs, set your goals accordingly, convey the same to your mentor and discuss with her or him on how to accomplish the goals."
      TIP_2 = "Don't forget to learn about your mentor by asking her/him questions. We encourage you to voice your concerns with your mentor."
      TIP_3 = "Did your mentor make her/his point clear? Do you understand what he/she is saying? Asking for clarification will allow your mentor to restate, elaborate, or reconsider what it is s/he is trying to convey."
      TIP_4 = "When asking for a favor, ask politely. Examples of ways to ask are: \"Perhaps you can point me in the right direction\", and \"Maybe you could help me...\""
      TIP_5 = "Follow up using the 48-hour rule. Respond to phone messages and emails within 48 hours, and send thank you notes, nice-to-meet-you notes, or emails after a meeting within 48 hours."
      TIP_6 = "When calling a person to whom someone referred you, mention your contact's name. For example, \"John suggested I contact you about...\""
      TIP_7 = "Set goals for attending a presentation, a club meeting, etc., and set them small. For example, you can make your goal to set up one, one-on-one meeting with a person you meet at that event. Have a script ready for when you meet someone new, ask them about their work, or begin with a compliment on something about the person."
      TIP_8 = "Revisit the goals that you have set for your mentoring partnership and for yourself. Are you on course to achieve what you had set out to do?"
      TIP_9 = "Could you have done something better? A renewed vigor can help you and your partner move forward."
      TIP_10 = "Accept challenges willingly."
      TIP_11 = "When the time comes, have a conversation that focuses on redefining the relationship (talk about how the relationship is to continue, whether it moves from professional mentoring relationship to colleague, friendship, or ceases to exist at all)"
      TIP_12 = "Have faith and trust in your mentor"
      TIP_13 = "Be open and honest with your mentor about your challenges and weaknesses."
      TIP_14 = "Be patient."
      TIP_15 = "Networking is the developing of mutual relationships that begins with sharing your knowledge with others. If you help others willingly, when it comes time for you to ask for help, it will be easier for you to do so."

      def self.all
        [TIP_1, TIP_2, TIP_3, TIP_4, TIP_5, TIP_6, TIP_7, TIP_8,
          TIP_9, TIP_10, TIP_11, TIP_12, TIP_13, TIP_14, TIP_15]
      end
    end
  end

  # Handbooks
  MENTOR_HANDBOOK = "//s3.amazonaws.com/chronus-mentor/handbooks/Mentor_Handbook.pdf"
  MENTEE_HANDBOOK = "//s3.amazonaws.com/chronus-mentor/handbooks/Mentee_Handbook.pdf"
end

module SurveyConstants
  DEFAULT_SURVEY_NAME = "Partnership Effectiveness"
  DEFAULT_SURVEY_QUESTIONS = "#{Rails.root}/config/default_survey_questions.yml"

  HEALTH_SURVEY_NAME = "Mentoring Relationship Health"
  HEALTH_SURVEY_QUESTIONS = "#{Rails.root}/config/default_mentoring_relationship_health_survey_questions.yml"

  CLOSURE_SURVEY_NAME = "Mentoring Relationship Closure"
  CLOSURE_SURVEY_QUESTIONS = "#{Rails.root}/config/default_mentoring_relationship_closure_survey_questions.yml"

  MENTOR_SURVEY_NAME = lambda {|program| "#{program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term} Role User Experience Survey"}
  MENTOR_SURVEY_QUESTIONS = "#{Rails.root}/config/default_mentor_survey_questions.yml"

  MENTEE_SURVEY_NAME = lambda {|program| "#{program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).term} Role User Experience Survey"}
  MENTEE_SURVEY_QUESTIONS = "#{Rails.root}/config/default_mentee_survey_questions.yml"

  FEEDBACK_SURVEY_NAME = lambda {|program| "#{program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term} Activity Feedback"}
  DEFAULT_FEEDBACK_QUESTIONS = "#{Rails.root}/config/default_feedback_questions.yml"
  EFFECTIVENESS_LEVELS = ["Very good", "Good", "Satisfactory", "Poor", "Very poor"]
end

module Examples
  TYPE = {
    "rank_based_question_help" => "common_questions/rank_based_question_help"
  }
end

module MigrationConstants
  TRUE = 1
  FALSE = 0
end

# Default per_page size
PER_PAGE = 10

# for select_all_ids actions
SPHINX_MAX_PER_PAGE = 1_000_000
ES_MAX_PER_PAGE = 1_000_000

# Default rows count for show more/show less links
DEFAULT_TRUNCATION_ROWS_LIMIT = 5

# -- Blocked domain names
BlockedDomainNames = %w( admin ads advisor advisors audio blog calendar chat coach docs dotnet e email faq ftp groups help imap mail mentor mentors mobilemail pda pop production sandbox secure sites smtp staging support testing test video web webmail www )

DISABLE_PROFILE_PROMPT = '_disable_profile_update_prompt'
PROFILE_SUMMARY_TEXT = ["location", "education", "experience" ]

# -- Analytics
GOOGLE_ANALYTICS_IGNORE_COOKIE = '_groups_ignore'

# "If PM team wants some options, please reuse this hash" - Sai
PROFILE_MERGED_QUESTIONS = {
  # CommonQuestion::Type::MULTI_STRING => CommonQuestion::Type::STRING
  # CommonQuestion::Type::MULTI_CHOICE => CommonQuestion::Type::SINGLE_CHOICE,
  # ProfileQuestion::Type::MULTI_EDUCATION => ProfileQuestion::Type::EDUCATION,
  # ProfileQuestion::Type::MULTI_EXPERIENCE => ProfileQuestion::Type::EXPERIENCE,
  # ProfileQuestion::Type::MULTI_PUBLICATION => ProfileQuestion::Type::PUBLICATION
}

# Choice limit for which the search option need not be displayed
MUTLI_CHOICE_TYPE_OPTIONS_LIMIT = 9

PICTURE_CONTENT_TYPES = ['image/pjpeg', 'image/jpg', 'image/jpeg', 'image/gif', 'image/png', 'image/x-png', 'image/tiff', 'image/bmp', 'image/vnd.adobe.photoshop']
DAILY_UPDATE_PERIOD = 1.day
WEEKLY_UPDATE_PERIOD = 1.week
TOOLTIP_IMAGE = "icons/info.gif"
TOOLTIP_IMAGE_CLASS = 'fa fa-info-circle'

class VirusError < SecurityError; end

module MentorRequestConstants
  ACCEPT = "accept"
  REJECT = "reject"
end

module MessageConstants
  module Tabs
    INBOX = 0
    SENT = 1
    COMPOSE = 2
  end
end

module ProgramEventConstants
  module Tabs
    UPCOMING = 0
    PAST = 1
    DRAFTED = 2
  end
  module ResponseTabs
    ATTENDING = 0
    NOT_ATTENDING = 1
    MAYBE_ATTENDING = 2
    NOT_RESPONDED = 3
    INVITED = 4
    def self.all
      [ATTENDING, NOT_ATTENDING, MAYBE_ATTENDING, NOT_RESPONDED, INVITED]
    end
  end
end


module UsersIndexFilters
  module Values
    ALL                     = "all"
    CONNECTED               = "connected"
    UNCONNECTED             = "unconnected"
    NEVERCONNECTED          = "neverconnected"
    AVAILABLE               = "available"
    DRAFTS                  = "drafts"
    PROGRAM                 = "program"
    GLOBAL                  = "global"
    CALENDAR_AVAILABILITY   = "calendar_availability"
  end
end

# Random 9 colors to be assigned to subprogram labels when viewing from a parent
# program.
PROGRAM_LABEL_COLORS = [
  "DB9117",
  "00a7a7",
  "5e931a",
  "9C74F4",
  "20BD4C",
  "5A9ACB",
  "f05d5d",
  "df75be",
  "D67CFA"
]

module CronConstants
  MEETING_REMINDERS = 5.minutes
  PROGRAM_EVENT_REMINDERS = 1.day
  PROGRAM_EVENT_REMINDERS_INTERVAL = 5.minutes
end

module AutoLogout
  module Cookie
    SESSION_ACTIVE = 'session_active'
    CLIENT_TIME_DIFFERENCE = 'client_time_difference'
  end

  module TimeInterval
    CHECK_SESSION = 1000 #in milliseconds
    SAFETY_TIME = 1 # in minutes
  end
end

module BulkActionConstants
  DEFAULT_USER_COUNT = 5
end

module ReplyViaEmail
  SCRAP = '22xh64n0'
  MESSAGE = 'dce5t3k9'
  ADMIN_MESSAGE = '3edqy9q5'
  MEETING_REQUEST_ACCEPTED_CALENDAR = '3e7ruwxy'         #rand(36**8).to_s(36)
  MEETING_REQUEST_ACCEPTED_NON_CALENDAR = 'g5oqafrw'
  MEETING_CREATED_NOTIFICATION =  'hewcj8ap'
  MEETING_RSVP_NOTIFICATION_OWNER = 'rnsoq9wb'
  MEETING_UPDATE_NOTIFICATION = 'd5sqpyta'
  MEETING_REMINDER_NOTIFICATION = 'uwn7xjvh'

  def self.get_reply_to_meeting_emails
    [MEETING_REQUEST_ACCEPTED_CALENDAR, MEETING_REQUEST_ACCEPTED_NON_CALENDAR, MEETING_CREATED_NOTIFICATION, MEETING_RSVP_NOTIFICATION_OWNER, MEETING_UPDATE_NOTIFICATION, MEETING_REMINDER_NOTIFICATION]
  end

end

module CampaignConstants
  COMMUNITY_MAIL_ID = 'community_mail'
  MEMBERSHIP_MAIL_ID = 'membership_mail'
  PROMOTED_TO_ADMIN_MAIL_ID = 'promoted_to_admin_mail'
  DIGEST_MAIL_ID = 'digest_mail'
  MENTORING_REQUESTS_OFFERS_MAIL_ID = 'mentoring_requests_offers_mail'
  MENTORING_CONNECTION_MAIL_ID = 'mentoring_connection_mail'
  WELCOME_MESSAGE_MAIL_ID = 'welcome_message_mail'
  USER_SETTINGS_ROLES_MAIL_ID = 'user_settings_roles_mail'
  MESSAGE_MAIL_ID = 'message_mail'
  WEEKLY_UPDATE_MAIL_ID = 'weekly_update_mail'
  ENGAGEMENT_MAIL_ID = 'engagement_mail'
  WEEKLY_UPDATE_2_MAIL_ID = 'weekly_update_2_mail'
  DIGEST_2_MAIL_ID = 'digest_2_mail'
  MENTORING_AREA_DIGEST_MAIL_ID = 'mentoring_area_digest_mail'
  THREE_SIXTY_MAIL_ID = 'three_sixty_mail'
  PROJECT_REQUESTS_MAIL_ID = 'project_requests_mail'
  MEETING_REQUESTS_OFFERS_MAIL_ID = 'meeting_requests_offers_mail'
  MEETING_REQUEST_REMINDER_NOTIFICATION_ID = 'meeting_request_remainder_notification'
  MENTOR_REQUEST_REMINDER_NOTIFICATION_ID = 'mentor_request_reminder_notification'
  PROJECT_REQUEST_REMINDER_ID = 'project_requests_reminder_notification'
  PROGRAM_REPORT_ALERT_MAIL_ID = "program_report_alert_mail_notification"
  ORGANIZATION_REPORT_ALERT_MAIL_ID = "organization_report_alert_mail_notification"
  GROUP_CREATION_NOTIFICATION_TO_MENTOR_MAIL_ID = 'group_creation_notification_to_mentor_mail'
  MENTOR_ADDED_NOTIFICATION_MAIL_ID = 'mentor_added_notification_mail'
  NEW_ADMIN_MESSAGE_NOTIFICATION_TO_MEMBER_MAIL_ID = 'new_admin_message_notification_to_member_mail'
  GROUP_INACTIVITY_NOTIFICATION_MAIL_ID = 'group_inactivity_notification_mail'
  ARTICLE_COMMENT_NOTIFICATION_MAIL_ID = 'article_comment_notification_mail'
  PENDING_GROUP_REMOVED_NOTIFICATION_MAIL_ID = 'pending_group_removed_notification_mail'
  GROUP_CREATION_NOTIFICATION_TO_STUDENTS_MAIL_ID = 'group_creation_notification_to_students_mail'
  MENTORING_AREA_EXPORT_MAIL_ID = 'mentoring_area_export_mail'
  PROPOSED_PROJECT_REJECTED_MAIL_ID = 'proposed_project_rejected_mail'
  AVAILABLE_PROJECT_WITHDRAWN_MAIL_ID = 'available_project_withdrawn_mail'
  WELCOME_MESSAGE_TO_ADMIN_MAIL_ID = 'welcome_message_to_admin_mail'
  INVITE_EXPIRY_NOTIFICATION_MAIL_ID = 'invite_expiry_notification_mail'
  NEW_PROGRAM_EVENT_NOTIFICATION_MAIL_ID = 'new_program_event_notification_mail'
  RESEND_SIGNUP_INSTRUCTIONS_MAIL_ID = 'resend_signup_instructions_mail'
  PROJECT_REQUEST_ACCEPTED_MAIL_ID = 'project_request_accepted_mail'
  MEETING_REQUEST_STATUS_WITHDRAWN_NOTIFICATION_NON_CALENDAR_MAIL_ID = 'meeting_request_status_withdrawn_notification_non_calendar_mail'
  THREE_SIXTY_SURVEY_ASSESSEE_NOTIFICATION_MAIL_ID = 'three_sixty_survey_assessee_notification_mail'
  AUTO_EMAIL_NOTIFICATION_MAIL_ID = 'auto_email_notification_mail'
  MEMBER_ACTIVATION_NOTIFICATION_MAIL_ID = 'member_activation_notification_mail'
  MEETING_REQUEST_STATUS_ACCEPTED_NOTIFICATION_MAIL_ID = 'meeting_request_status_accepted_notification_mail'
  WELCOME_MESSAGE_TO_MENTOR_MAIL_ID = 'welcome_message_to_mentor_mail'
  MEMBERSHIP_REQUEST_NOT_ACCEPTED_MAIL_ID = 'membership_request_not_accepted_mail'
  GROUP_OWNER_ADDITION_NOTIFICATION_MAIL_ID = 'group_owner_addition_notification_mail'
  ADMIN_ADDED_NOTIFICATION_MAIL_ID = 'admin_added_notification_mail'
  MENTOR_REQUEST_WITHDRAWN_TO_ADMIN_MAIL_ID = 'mentor_request_withdrawn_to_admin_mail'
  THREE_SIXTY_SURVEY_REVIEWER_NOTIFICATION_MAIL_ID = 'three_sixty_survey_reviewer_notification_mail'
  PASSWORD_EXPIRY_NOTIFICATION_MAIL_ID = 'password_expiry_notification_mail'
  USER_WITH_SET_OF_ROLES_ADDED_NOTIFICATION_MAIL_ID = 'user_with_set_of_roles_added_notification_mail'
  GROUP_PUBLISHED_NOTIFICATION_MAIL_ID = 'group_published_notification_mail'
  PROGRAM_EVENT_UPDATE_NOTIFICATION_MAIL_ID = 'program_event_update_notification_mail'
  GROUP_PROPOSED_NOTIFICATION_TO_ADMINS_MAIL_ID = 'group_proposed_notification_to_admins_mail'
  MEETING_EDIT_NOTIFICATION_MAIL_ID = 'meeting_edit_notification_mail'
  MEETING_EDIT_NOTIFICATION_TO_SELF_MAIL_ID = 'meeting_edit_notification_to_self_mail'
  MEETING_RSVP_SYNC_NOTIFICATION_FAILURE_MAIL_ID = 'meeting_rsvp_sync_notification_failure_mail'
  MEETING_REQUEST_STATUS_DECLINED_NOTIFICATION_MAIL_ID = 'meeting_request_status_declined_notification_mail'
  GROUP_CREATION_NOTIFICATION_TO_CUSTOM_USERS_MAIL_ID = 'group_creation_notification_to_custom_users_mail'
  CONTENT_MODERATION_ADMIN_NOTIFICATION_MAIL_ID = 'content_moderation_admin_notification_mail'
  PENDING_GROUP_ADDED_NOTIFICATION_MAIL_ID = 'pending_group_added_notification_mail'
  MEETING_REQUEST_CREATED_NOTIFICATION_MAIL_ID = 'meeting_request_created_notification_mail'
  NEW_ARTICLE_NOTIFICATION_MAIL_ID = 'new_article_notification_mail'
  GROUP_MENTORING_OFFER_NOTIFICATION_TO_NEW_MENTEE_MAIL_ID = 'group_mentoring_offer_notification_to_new_mentee_mail'
  MENTOR_OFFER_CLOSED_FOR_SENDER_MAIL_ID = 'mentor_offer_closed_for_sender_mail'
  GROUP_MEMBER_ADDITION_NOTIFICATION_TO_NEW_MEMBER_MAIL_ID = 'group_member_addition_notification_to_new_member_mail'
  MEETING_REQUEST_STATUS_WITHDRAWN_NOTIFICATION_MAIL_ID = 'meeting_request_status_withdrawn_notification_mail'
  MEETING_CREATION_NOTIFICATION_TO_OWNER_MAIL_ID = 'meeting_creation_notification_to_owner_mail'
  NEW_MENTOR_REQUEST_MAIL_ID = 'new_mentor_request_mail'
  DEMOTION_NOTIFICATION_MAIL_ID = 'demotion_notification_mail'
  MEETING_REQUEST_STATUS_DECLINED_NOTIFICATION_NON_CALENDAR_MAIL_ID = 'meeting_request_status_declined_notification_non_calendar_mail'
  DIRECT_JOIN_MEMBERSHIP_REQUEST_ACCEPTED_MAIL_ID = 'direct_join_membership_request_accepted_mail'
  COACH_RATING_NOTIFICATION_TO_STUDENT_MAIL_ID = 'coach_rating_notification_to_student_mail'
  PROGRAM_EVENT_DELETE_NOTIFICATION_MAIL_ID = 'program_event_delete_notification_mail'
  GROUP_MENTORING_OFFER_ADDED_NOTIFICATION_TO_NEW_MENTEE_MAIL_ID = 'group_mentoring_offer_added_notification_to_new_mentee_mail'
  MENTOR_OFFER_ACCEPTED_NOTIFICATION_TO_MENTOR_MAIL_ID = 'mentor_offer_accepted_notification_to_mentor_mail'
  PROGRAM_EVENT_REMINDER_NOTIFICATION_MAIL_ID = 'program_event_reminder_notification_mail'
  MENTOR_REQUEST_ACCEPTED_MAIL_ID = 'mentor_request_accepted_mail'
  ANNOUNCEMENT_NOTIFICATION_MAIL_ID = 'announcement_notification_mail'
  MEETING_REQUEST_STATUS_ACCEPTED_NOTIFICATION_TO_SELF_MAIL_ID = 'meeting_request_status_accepted_notification_to_self_mail'
  COACH_RATING_NOTIFICATION_TO_ADMIN_MAIL_ID = 'coach_rating_notification_to_admin_mail'
  NEW_MESSAGE_TO_OFFLINE_USER_NOTIFICATION_MAIL_ID = 'new_message_to_offline_user_notification_mail'
  MENTOR_OFFER_REJECTED_NOTIFICATION_TO_MENTOR_MAIL_ID = 'mentor_offer_rejected_notification_to_mentor_mail'
  MENTOR_REQUESTS_EXPORT_MAIL_ID = 'mentor_requests_export_mail'
  PROJECT_REQUEST_REJECTED_MAIL_ID = 'project_request_rejected_mail'
  REACTIVATE_ACCOUNT_MAIL_ID = 'reactivate_account_mail'
  MEETING_REQUEST_STATUS_ACCEPTED_NOTIFICATION_NON_CALENDAR_MAIL_ID = 'meeting_request_status_accepted_notification_non_calendar_mail'
  CAMPAIGN_EMAIL_NOTIFICATION_MAIL_ID = 'campaign_email_notification_mail'
  MENTOR_REQUEST_REJECTED_MAIL_ID = 'mentor_request_rejected_mail'
  MANAGER_NOTIFICATION_MAIL_ID = 'manager_notification_mail'
  MENTOR_REQUEST_EXPIRED_TO_SENDER_MAIL_ID = 'mentor_request_expired_to_sender_mail'
  POSTING_IN_MENTORING_AREA_FAILURE_MAIL_ID = 'posting_in_mentoring_area_failure_mail'
  POSTING_IN_MEETING_AREA_FAILURE_MAIL_ID = 'posting_in_meeting_area_failure_mail'
  CONTENT_MODERATION_USER_NOTIFICATION_MAIL_ID = 'content_moderation_user_notification_mail'
  MEMBER_SUSPENSION_NOTIFICATION_MAIL_ID = 'member_suspension_notification_mail'
  FORUM_NOTIFICATION_MAIL_ID = 'forum_notification_mail'
  PROPOSED_PROJECT_ACCEPTED_MAIL_ID = 'proposed_project_accepted_mail'
  MEETING_REMINDER_MAIL_ID = 'meeting_reminder_mail'
  GROUP_REACTIVATION_NOTIFICATION_MAIL_ID = 'group_reactivation_notification_mail'
  INVITE_NOTIFICATION_MAIL_ID = 'invite_notification_mail'
  MENTOR_REQUEST_WITHDRAWN_MAIL_ID = 'mentor_request_withdrawn_mail'
  WELCOME_MESSAGE_TO_MENTEE_MAIL_ID = 'welcome_message_to_mentee_mail'
  MEETING_RSVP_NOTIFICATION_MAIL_ID = 'meeting_rsvp_notification_mail'
  MEETING_RSVP_NOTIFICATION_TO_SELF_MAIL_ID = 'meeting_rsvp_notification_mail_to_self_mail'
  INVITE_EXPIRY_NOTIFICATION_WITHOUT_ROLES_MAIL_ID = 'invite_expiry_notification_without_roles_mail'
  MEETING_CANCELLATION_NOTIFICATION_MAIL_ID = 'meeting_cancellation_notification_mail'
  MEETING_CANCELLATION_NOTIFICATION_TO_SELF_MAIL_ID = 'meeting_cancellation_notification_to_self_mail'
  QA_ANSWER_NOTIFICATION_MAIL_ID = 'qa_answer_notification_mail'
  ANNOUNCEMENT_UPDATE_NOTIFICATION_MAIL_ID = 'announcement_update_notification_mail'
  USER_SUSPENSION_NOTIFICATION_MAIL_ID = 'user_suspension_notification_mail'
  MEETING_REQUEST_SENT_NOTIFICATION_MAIL_ID = 'meeting_request_sent_notification_mail'
  EMAIL_CHANGE_NOTIFICATION_MAIL_ID = 'email_change_notification_mail'
  AGGREGATED_MAIL_MAIL_ID = 'aggregated_mail_mail'
  FORGOT_PASSWORD_MAIL_ID = 'forgot_password_mail'
  GROUP_MEMBER_REMOVAL_NOTIFICATION_TO_REMOVED_MEMBER_MAIL_ID = 'group_member_removal_notification_to_removed_member_mail'
  NEW_MENTOR_REQUEST_TO_ADMIN_MAIL_ID = 'new_mentor_request_to_admin_mail'
  MEETING_REQUEST_CLOSED_FOR_SENDER_MAIL_ID = 'meeting_request_closed_for_sender_mail'
  GROUP_INACTIVITY_NOTIFICATION_WITH_AUTO_TERMINATE_MAIL_ID = 'group_inactivity_notification_with_auto_terminate_mail'
  GROUP_CONVERSATION_CREATION_NOTIFICATION_MAIL_ID = 'group_conversation_creation_notification_mail'
  REPLY_TO_ADMIN_MESSAGE_FAILURE_NOTIFICATION_MAIL_ID = 'reply_to_admin_message_failure_notification_mail'
  MEMBERSHIP_REQUESTS_EXPORT_MAIL_ID = 'membership_requests_export_mail'
  MEETING_CREATION_NOTIFICATION_MAIL_ID = 'meeting_creation_notification_mail'
  MENTOR_OFFER_CLOSED_FOR_RECIPIENT_MAIL_ID = 'mentor_offer_closed_for_recipient_mail'
  MENTOR_OFFER_WITHDRAWN_MAIL_ID = 'mentor_offer_withdrawn_mail'
  NEW_PROJECT_REQUEST_TO_ADMIN_AND_OWNER_MAIL_ID = 'new_project_request_to_admin_and_owner_mail'
  WEEKLY_UPDATES_MAIL_ID = 'weekly_updates_mail'
  MENTOR_REQUEST_CLOSED_FOR_SENDER_MAIL_ID = 'mentor_request_closed_for_sender_mail'
  MENTOR_REQUEST_CLOSED_FOR_RECIPIENT_MAIL_ID = 'mentor_request_closed_for_recipient_mail'
  PROMOTION_NOTIFICATION_MAIL_ID = 'promotion_notification_mail'
  MEETING_REQUEST_EXPIRED_NOTIFICATION_TO_SENDER_MAIL_ID = 'meeting_request_expired_notification_to_sender_mail'
  USER_ACTIVATION_NOTIFICATION_MAIL_ID = 'user_activation_notification_mail'
  ADMIN_ADDED_DIRECTLY_NOTIFICATION_MAIL_ID = 'admin_added_directly_notification_mail'
  MENTEE_ADDED_NOTIFICATION_MAIL_ID = 'mentee_added_notification_mail'
  MEMBERSHIP_REQUEST_ACCEPTED_MAIL_ID = 'membership_request_accepted_mail'
  MEETING_REQUEST_CREATED_NOTIFICATION_NON_CALENDAR_MAIL_ID = 'meeting_request_created_notification_non_calendar_mail'
  MEETING_REQUEST_CLOSED_FOR_RECIPIENT_MAIL_ID = 'meeting_request_closed_for_recipient_mail'
  CONTENT_FLAGGED_ADMIN_NOTIFICATION_MAIL_ID = 'content_flagged_admin_notification_mail'
  INVITE_NOTIFICATION_FROM_ADMIN_MAIL_ID = 'invite_notification_from_admin_mail'
  MEMBERSHIP_REQUEST_SENT_NOTIFICATION_MAIL_ID = 'membership_request_sent_notification_mail'
  GROUP_TERMINATION_NOTIFICATION_MAIL_ID = 'group_termination_notification'
  INBOX_MESSAGE_NOTIFICATION_MAIL_ID = 'inbox_message_notification_mail'
  INBOX_MESSAGE_NOTIFICATION_FOR_TRACK_MAIL_ID = 'inbox_message_notification_for_track_mail'
  ADMIN_MESSAGE_NOTIFICATION_MAIL_ID = 'admin_message_notification_mail'
  NOT_ELIGIBLE_TO_JOIN = "not_eligible_to_join"
  MENTOR_RECOMMENDATION_NOTIFICATION_ID = 'mentor_recommendation_notification'
  EMAIL_REPORT_ID = 'email_report'
  DIGEST_V2_CAMPAIGN_MAIL_ID = 'facilitation_message_mail' # we will use this existing campaign in mailgun
  MOBILE_APP_LOGIN_MAIL_ID = 'mobile_app_login'

  # Career Dev Related
  WELCOME_MESSAGE_TO_PORTAL_USER_MAIL_ID = 'welcome_message_to_portal_user_mail'
  PORTAL_MEMBER_WITH_SET_OF_ROLES_ADDED_NOTIFICATION_MAIL_ID = 'portal_member_with_set_of_roles_added_notification_mail'
  PORTAL_MEMBER_WITH_SET_OF_ROLES_ADDED_NOTIFICATION_TO_REVIEW_PROFILE_MAIL_ID = 'cd_user_with_set_of_roles_added_notification_to_review_profile'
end

module AdminViewConstants
  PER_PAGE_OPTIONS = [25, 50, 100]
  SUCCESS_STATUS = 200
end

module FORMAT
  PDF = "pdf"
  HTML = "html"
end

module HealthReports
  GROWTH = "growth"
  CONNECTIVITY = "connectivity"
  ENGAGEMENT = "engagement"
  CONTENT_OVERVIEW = "content_overview"

  def self.cumulative_reports
    [CONNECTIVITY, ENGAGEMENT, CONTENT_OVERVIEW]
  end

  def self.cumulative_reports_if_ongoing_mentoring_is_disabled
    [CONTENT_OVERVIEW]
  end

  def self.all
    [GROWTH, CONNECTIVITY, ENGAGEMENT, CONTENT_OVERVIEW]
  end
end

module ScannerConstants
  ADMIN_EMAIL = "test_admin@chronus.com"
  PROGRAM_DOMAIN = "realizegoal.com"
  PROGRAM_SUBDOMAIN = "scanner"
end

module BookListItemPresenterConstants
  AMAZON_SSL_URL = "images-na.ssl-images-amazon.com"
end

module CookiesConstants
  MENTORING_AREA_VISITED = :mentoring_area_visited

  def self.all
    [MENTORING_AREA_VISITED]
  end
end

module ThemeBuilder
  THEME_VARIABLES = {
    "button-bg-color" => {"default" => ["#00bc8c","Button background color","Button background color (also reflective in emails)"]},
    "button-font-color" => {"default" => ["white","Button font color","Button font color (also reflective in emails)"]},
    "header-bg-color" => {"default" => ["#375a7f","Header background color","If none, it takes the background color set for the page as seen in sample"]},
    "header-font-color" => {"default" => ["white","Header font color","If none, it takes the font color set for the page as seen in sample"]}
  }
end

module ToastrType
  SUCCESS = "success"
  INFO = "info"
  WARNING = "warning"
  ERROR = "error"

  OPTIONS = {
    SUCCESS => { progressBar: true, timeOut: 7000, extendedTimeOut: 2000 },
    INFO => {},
    WARNING => {},
    ERROR => {}
  }
end

module AnalyticParams
  FAKEDOOR = "/mobile_v2/home/fakedoor"
end

module SubSource
  module Meeting
    UPCOMING_MEETINGS_WIDGET = "upcoming_meetings_widget"
  end
end

module MobileTab
  MAX_LABEL_LENGTH = 8
  module QuickLink
    MentorRequest = 0
    MeetingRequest = 1
    MentorOffer = 2
    ProjectRequest = 3
    Meeting = 4
    ProgramEvent = 5
  end
  Home = 0
  Connection = 1
  Match = 2
  Discover = 3
  Request = 4
  Manage = 5
  Message = 6
  More = 7
  Notification = 8
end

module ReportConst
  module ManagementReport
    SectionCount = 4
    SourcePage = "dmetric"
    EmailSource = "emetric"
  end
end

module AnnouncementConstants
  ANNOUNCEMENT_SIZE = 350
end

DEFAULT_START_TIME = Time.new(2007)

module SolutionPackConstants
  BASE_PATH = "../solution_pack/"
end

DATE_RANGE_SEPARATOR = " - "

module DateRangePresets
  TODAY = "today"
  LAST_7_DAYS = "last_7_days"
  MONTH_TO_DATE = "month_to_date"
  YEAR_TO_DATE = "year_to_date"
  LAST_MONTH = "last_month"
  PROGRAM_TO_DATE = "program_to_date"
  QUARTER_TO_DATE = "quarter_to_date"
  LAST_QUARTER = "last_quarter"
  LAST_YEAR = "last_year"
  LAST_30_DAYS = "last_30_days"
  NEXT_7_DAYS = "next_7_days"
  NEXT_15_DAYS = "next_15_days"
  NEXT_30_DAYS = "next_30_days"
  LAST_N_DAYS = "last_n_days"
  NEXT_N_DAYS = "next_n_days"
  BEFORE_LAST_N_DAYS = "before_last_n_days"
  AFTER_NEXT_N_DAYS = "after_next_n_days"
  CUSTOM = "custom"

  def self.keys
    {
      TODAY => "chronus_date_range_picker_strings.preset_ranges.today",
      LAST_7_DAYS => ["common_text.date_range.last_n_days", day_count: 7],
      MONTH_TO_DATE => "chronus_date_range_picker_strings.preset_ranges.month_to_date",
      YEAR_TO_DATE => "chronus_date_range_picker_strings.preset_ranges.year_to_date",
      LAST_MONTH => "chronus_date_range_picker_strings.preset_ranges.last_month",
      PROGRAM_TO_DATE => "chronus_date_range_picker_strings.preset_ranges.program_to_date",
      QUARTER_TO_DATE => "chronus_date_range_picker_strings.preset_ranges.quarter_to_date",
      LAST_QUARTER => "chronus_date_range_picker_strings.preset_ranges.last_quarter",
      LAST_YEAR => "chronus_date_range_picker_strings.preset_ranges.last_year",
      LAST_30_DAYS => ["common_text.date_range.last_n_days", day_count: 30],
      NEXT_7_DAYS => ["common_text.date_range.next_n_days", day_count: 7],
      NEXT_15_DAYS => ["common_text.date_range.next_n_days", day_count: 15],
      NEXT_30_DAYS => ["common_text.date_range.next_n_days", day_count: 30],
      LAST_N_DAYS => ["common_text.date_range.last_n_days", day_count: " _ "],
      NEXT_N_DAYS => ["common_text.date_range.next_n_days", day_count: " _ "],
      BEFORE_LAST_N_DAYS => ["common_text.date_range.before_last_n_days", day_count: " _ "],
      AFTER_NEXT_N_DAYS => ["common_text.date_range.after_next_n_days", day_count: " _ "],
      CUSTOM => "chronus_date_range_picker_strings.custom"
    }
  end

  def self.defaults
    [TODAY, LAST_7_DAYS, MONTH_TO_DATE, YEAR_TO_DATE, LAST_MONTH, CUSTOM]
  end

  def self.for_reports
    [TODAY, LAST_7_DAYS, MONTH_TO_DATE, YEAR_TO_DATE, PROGRAM_TO_DATE, CUSTOM]
  end

  def self.diversity_reports
    [PROGRAM_TO_DATE, YEAR_TO_DATE, QUARTER_TO_DATE, LAST_QUARTER, CUSTOM]
  end

  def self.for_overall_impact
    [PROGRAM_TO_DATE, YEAR_TO_DATE, QUARTER_TO_DATE, LAST_QUARTER, CUSTOM]
  end
  
  def self.for_date_profile_field_quick_filter
    [CUSTOM]
  end

  def self.for_date_profile_field_admin_view_filter
    [CUSTOM, NEXT_N_DAYS, LAST_N_DAYS, BEFORE_LAST_N_DAYS, AFTER_NEXT_N_DAYS]
  end

  def self.all
    [TODAY, LAST_7_DAYS, MONTH_TO_DATE, YEAR_TO_DATE, LAST_MONTH, PROGRAM_TO_DATE, QUARTER_TO_DATE, LAST_QUARTER, LAST_YEAR, LAST_30_DAYS, NEXT_7_DAYS, NEXT_15_DAYS, NEXT_30_DAYS, CUSTOM]
  end

  def self.translate(key)
    translate_options = self.keys[key]
    translate_key = translate_options.is_a?(Array) ? translate_options[0] : translate_options
    translate_params = translate_options.is_a?(Array) ? translate_options[1] : {}
    translate_key.translate(translate_params)
  end
end

module MobileV2Constants
  ORGANIZATION_SETUP_COOKIE = :organization_url
  COOKIE_EXPIRY = 365 #Days
  VERIFY_ORG_TIMEOUT = 10000 #milliseconds
  PUSH_NOTIFICATION_MIN_DURATION = 1 #days
  MOBILE_V2_AUTH_TOKEN = :mobile_remember_me_v2
  MOBILE_APP_PROMPT = 'mobile_prompt'
  MOBILE_PROMPT_COOKIE_EXPIRY = 5
  HISTORY_LINK = "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/fakedoor_history/history.html"
  LOGIN_PATH_MOBILE = "/login?mode=strict"
  CURRENT_PROGRAM_COOKIE = :last_visited_program
  LANGUAGE_TEXT_SIZE = 10
  MAX_TAB_SIZE = 5
  module MobilePrompt
    IOS = 1
    ANDROID = 2
    GA_NAME = {
      IOS => "ios",
      ANDROID => "android"
    }
    OPEN_APP_GA = 'opened the app'
    DOWNLOAD_GA = 'downloaded the app'
    CONTINUE_GA = 'continued to the site'
  end
end

module TimezoneConstants
  DEFAULT_TIMEZONE = "Etc/UTC"
  OBSOLETE_TIMEZONES_HASH = YAML.load(File.open(Dir.glob("#{Rails.root}/app/files/obsolete_timezones_*.yml").first, 'r'))
  VALID_TIMEZONE_IDENTIFIERS = TZInfo::Timezone.all_identifiers - OBSOLETE_TIMEZONES_HASH.keys
end

module LhmConstants
  LHM_MIGRATION_STATEMENTS = File.join(Rails.root, "tmp", "lhm_migration_statements")
end

MAILGUN_DOMAIN_ENVIRONMENT_MAP = {
  "academywomen" => "academywomenmg.chronus.com",
  "production" => "mentormg.chronus.com",
  "productioneu" => "productioneumg.chronus.com",
  "veteransadmin" => "veteransadminmg.chronus.com",
  "demo" => "demomg.chronus.com",
  "generalelectric" => "generalelectricmg.chronus.com",
  "nch" => "nchmg.chronus.com",
  "scanner" => "scannermg.chronus.com",
  "opstesting" => "opstestingmg.realizegoal.com",
  "performance" => "performancemg.realizegoal.com",
  "releasestaging1" => "releasestaging1mg.realizegoal.com",
  "releasestaging2" => "releasestaging2mg.realizegoal.com",
  "staging" => "stagingmg.realizegoal.com",
  "standby" => "standbymg.realizegoal.com",
  "training" => "trainingmg.chronus.com",
  "development" => "developmentmg.realizegoal.com",
  "test" => "testmg.realizegoal.com"
}

INVERTED_MAILGUN_DOMAIN_ENVIRONMENT_MAP = MAILGUN_DOMAIN_ENVIRONMENT_MAP.invert
GRID_SIZE = 12
TRUNCATE_SPACE_SEPARATOR = ' '

module EmailValidation
  LOCAL_LENGTH_LIMIT = 64
  DOMAIN_LENGTH_LIMIT = 255
end

module Kendo
  CHECK_BOX_WIDTH = "40px"
  ACTIONS_WIDTH = "65px"
  DEFAULT_WIDTH = "200px"
end

module DROPZONE
  TEMP_BASE_PATH = "data/dropzone_files"
  DEFAULT_FILE_UPLOAD_OPTIONS = { base_path: TEMP_BASE_PATH }
end

module HostingRegions
  US = "us"
  EUROPE = "europe"
  OTHER = "other"

  SUBDOMAIN_MAPPING = {
    US => "mentor.chronus.com",
    EUROPE => "mentoreu.chronus.com",
    OTHER =>"mentor.realizegoal.com"
  }
end
