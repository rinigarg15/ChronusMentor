class EngagementIndex

  SEPARATOR = ','

  module Activity
    LOGIN = 'Login'
    PUBLISH_PROFILE = 'Publish Profile'
    UPDATE_PROFILE = 'Update Profile'
    IMPORT_FROM_LINKEDIN = 'Linkedin Import'
    EDIT_PROFILE = 'Edit Profile'
    VIEW_SELF_PROFILE = 'View Self Profile'
    VIEW_RESOURCE = 'View Resource'
    VIEW_RESOURCE_LIST = 'Resource List'
    VIEW_ARTICLE = 'View Article'
    LIKE_ARTICLE = 'Like Article'
    COMMENT_ON_ARTICLE = 'Comment on an Article'
    POST_TO_FORUM = 'Post to a Forum'
    READ_A_FORUM_POST = 'Read a Forum Post'
    ATTEND_PROGRAM_EVENT = 'Attend a program event'
    VIEW_QA = 'View Question and Answers'
    POST_TO_QA = 'Post to Question and Answers'
    REPLY_TO_QA = 'Reply to Question and Answers'
    RECORD_NOTES = 'Record Notes'
    UPDATE_MEETING_STATE = 'Update Meeting State'
    COMPLETE_FLASH_MEETING_SURVEY = 'Completing flash meeting survey'
    ACCESS_MENTORING_AREA = 'Access Mentoring Area'
    CREATE_MESSAGE_MENTORING_AREA = 'Create Mentoring Area Message'
    REPLY_MESSAGE_MENTORING_AREA = 'Rep_connected_messages'
    READ_MESSAGE_MENTORING_AREA = 'Read Mentoring Area Message'
    COMPLETE_TASK = 'Complete Mentoring Area Task'
    COMPLETE_ENGAGEMENT_SURVEY = 'Complete Mentoring Area Engagement Survey'
    COMPLETE_CLOSURE_SURVEY = 'Complete Mentoring Area Closure Survey'
    CREATE_MILESTONE = 'Creating Milestone from Mentoring Area'
    CREATE_GOAL = 'Creating Goal from Mentoring Area'
    CREATE_TASK = 'Creating Task from Mentoring Area'
    CREATE_TASK_COMMENT = 'Creating Task Comment from Mentoring Area'
    CREATE_UPDATE_JOURNAL = 'Create or update your journal'
    RECORD_PAST_MEETING = 'Record Past Meeting in a Mentoring Connection'
    CLOSE_CONNECTION = 'Close the Mentoring Connection'
    LEAVE_CONNECTION = 'Leave the Mentoring Connection'
    EXTEND_MENTORING_SESSION = 'Extend a Mentoring Connection'
    RSVP_YES_MEETING = 'RSVP Yes for a Meeting'
    CREATE_GROUP_MEETING = 'Create an upcoming group meeting'
    UPDATE_MEETING = 'Update Meeting'
    ACCESS_FLASH_MEETING_AREA = 'Meeting Area for Flash Meetings'
    VISIT_REQUESTORS_PROFILE = 'Visit Requestor Profile'
    ACCEPT_MEETING_REQUEST = 'Accept Meeting Request'
    ACCEPT_MENTOR_REQUEST = 'Accept Mentor Request'
    ACCEPT_MENTORING_OFFER = 'Accept Mentoring Offer'
    REQUEST_ADMIN_MATCH = 'Request Admin Match'
    SEND_MEETING_REQUEST = 'Send Meeting Request'
    SEND_MENTORING_REQUEST = 'Send Mentoring Request'
    SEND_MENTORING_OFFER = 'Send Mentoring Offer'
    BROWSE_MENTORS = 'Browse Mentors'
    VISIT_MENTORS_PROFILE = 'Visit Mentor Profile'
    MESSAGE_USERS = 'Message other Users'
    REPLY_USERS = 'Reply to Users'
    SKYPE_CALL = 'Skype Call'
    APPLY_MENTOR_LIST_FILTERS = 'Apply Mentor List Filters'
    VISIT_HOME_PAGE = 'Visit home Page'
    ACTIVITY_BUTTON_MANAGMENT_REPORT = 'activity-button'
    INTIALIZE_CONNECT_CALENDAR = 'Initiated to connect personal calendar'
    COMPLETE_CONNECT_CALENDAR = 'Successfully connected to personal calendar'
    DISCONNECT_CALENDAR = 'Disconnected personal calendar'
    MARK_AS_FAVORITE = 'Mark as favorite'
    UNMARK_AS_FAVORITE = 'Unmark as favorite'
    MARK_AS_IGNORE = 'Mark as ignore'
    UNMARK_AS_IGNORE = 'Unmark as ignore'
    VIEW_FAVORITES = 'View Favorites'
    VIEW_MATCH_DETAILS = 'View Match Details'
  end

  module Src
    module EditProfile
      NAV_DROPDOWN = 'nav'
      PROFILE_ACTION_BUTTON = 'act'
      FIRST_TIME_COMPLETION = 'fir'
      UPDATING_PROFILE = 'upd'
      PROFILE_PENDING = 'pen'
      MAX_CONNECTION_LIMIT_REACHED = 'lim'
      SIDEBAR_COMPLETE_PROFILE = 'com'
      GLOBAL_PROFILE = 'glo'
      PROFILE_PICTURE = 'pic'
      HOMEPAGE_SIDEBAR = 'sid'
      HOMEPAGE_FLASH = 'fla'
      FIRST_TIME_COMPLETION_CHANGE_ROLES = 'chr'
    end
    module CreateGroupMeeting
      MENTORING_AREA_TITLE = 'Title'
      MENTORING_AREA_TASK = 'Task'
      MENTORING_AREA_MEETING_LIST = 'List'
      MENTORING_AREA_SIDE_PANE = 'Side Pane'
    end
    module UpdateMeeting
      MENTORING_AREA_MEETING_LISTING_CALANDER = "mamlc"
      MENTORING_AREA_MEETING_LISTING = 'maml'
      MEETING_AREA = 'ma'
      MEMBER_MEETING_LISTING = 'mml'
      RSVP_RESCHEDULE = 'rfr'
      MENTORING_SLOT = 'mens'
    end
    module AccessFlashMeetingArea
      HOME_PAGE_WIDGET = 'hpw'
      HOME_PAGE_SIDE_BAR = 'hpsb'
      MEETING_REQUEST_LISTING = 'mrlp'
      EMAIL = 'email'
      MEETING_LISTING = 'ml'
      PROVIDE_FEEDBACK_HOME_PAGE = 'pffhp'
      PROVIDE_FEEDBACK_MEETING_AREA = 'pffma'
      PROVIDE_FEEDBACK_MEETING_LISTING = 'pffml'
      PROVIDE_FEEDBACK = 'pf'
      PROVIDE_FEEDBACK_MENTORING_CALENDAR = 'pfmc'
      MEETING_AREA = 'ma'
      MEETING_REQUEST_ACCEPTANCE = 'mra'
    end
    module AccessMentoringArea
      HOME_PAGE_TITLE = 'ht'
      HOME_PAGE_FOOTNOTE = 'hf'
      module SubSource
        MESSAGES_TAB = 'mst'
        TASKS_TAB = 'tt'
        MEETINGS_TAB = 'met'
        DISCUSSIONS_TAB = 'dis'
      end
    end
    module AcceptMeetingRequest
      ACCEPT_AND_PROPOSE_SLOT = 'aps'
      ACCEPT_AND_SEND_MESSAGE = 'asm'
      ACCEPT = 'a'
    end
    module AcceptMentorRequest
      USER_LISTING_PAGE = 'ulp'
      USER_PROFILE_PAGE = 'upp'
      MENTOR_REQUEST_LISTING_PAGE = 'rlp'
    end
    module SendRequestOrOffers
      QUICK_CONNECT_BOX = 'quick_connect_box'
      USER_LISTING_PAGE = 'ulp'
      USER_PROFILE_PAGE = 'upp'
      HOVERCARD = 'HoverCard'
      MENTORING_CALENDAR = 'mc'
      MATCH_DETAILS = 'md'
      FAVORITE_MENTORS_POPUP = 'fmp'
    end
    module BrowseMentors
      SIDE_NAVIGATION = 'side_navigation'
      MENTOR_PROFILE_PAGE = 'mpp'
      MENTOR_LISTING_PAGE = 'mlp'
      QUICK_CONNECT_BOX = 'quick_connect_box'
      HEADER_NAVIGATION = 'header_nav'
      FLASH = 'Flash'
      REMOVE_USER_FAVORITE = 'duf'
      MENTORING_CALENDAR = 'mc'
      NEW_MENTOR_REQUEST = 'smr'
      QUICK_LINKS = 'quick_links'
      EMAIL = 'email'
      PUSH_NOTIFICTAION = 'push_notifs'
      SEARCH_BOX = 'search_box'
      FOOTER_NAVIGATION = 'fn'
      POPULAR_CATEGORIES = 'pbml'
    end
    module MessageUsers
      USER_LISTING_PAGE = 'ulp'
      USER_PROFILE_PAGE = 'upp'
      HOVERCARD = 'HoverCard'
      MENTOR_REQUEST_LISTING_PAGE = 'rlp'
      MENTORING_AREA_SIDE_PANE = 'masp'
    end
    module ExplicitPreferences
      HOME_PAGE = 'hppp'
      MENTOR_LISTING_PAGE_ACTION = 'mlpa'
      MENTOR_LISTING_BOTTOM_BAR = 'mlbb'
      MENTOR_LISTING_NO_RESULTS = 'mlnr'
      MATCH_DETAILS = "mddd"
    end
    module ReplyUsers
      EMAIL = 'email'
      INBOX = 'Inbox'
    end
    module VisitMentorsProfile
      HOME_PAGE_RECOMMENDATIONS = 'hpr'
      CAMPAIGN_WIDGET_RECOMMENDATIONS = 'cwr'
    end
    module ConnectCalendar
      EDIT_PROFILE_SETTINGS = 'direct_settings'
      HOMEPAGE_PROMPT = 'calendar_prompt'
      FIRST_TIME_COMPLETION = 'first_time_completion'
    end
    module AbstractPreference
      # Using AbstractPreference::Source for ignore_preference
      FAVORITE_LISTING_PAGE = "flp"
      USER_PROFILE_PAGE = 'upp'
      # Other sources for favorite_preferences are EngagementIndex::Src::BrowseMentors::MENTOR_LISTING_PAGE, 
      # MentorRecommendation::Source::ADMIN_QUICK_CONNECT, quick_connect_box, EngagementIndex::Src::SendRequestOrOffers::FAVORITE_MENTORS_POPUP
    end
    module MatchDetails
      MENTOR_LISTING_PAGE = 'mlp'
      PROFILE_PAGE = 'profile'
      # Other sources are EngagementIndex::Src::AbstractPreference::FAVORITE_LISTING_PAGE, AbstractPreference::Source
    end
    module MatchReport
      DASHBOARD = 'db'
      REPORT_LISTING = 'rl'
    end
    Announcement = "an"
    SIDEBAR_PROGRAM_LOGO_OR_BANNER = "sidebar_logo_or_banner"
    MENTORING_COMMUNITY_WIDGET = "community_widget"
    PUBLISH_CIRCLE_WIDGET = "publish_circle_widget"
    GROUP_LISTING = "group_listing"
    SIMILAR_CIRCLE_DROPDOWN = "similar_circles"
  end

  module SideBarSubSrc
    MEETINGS = 'Meetings'
    CONNECTION = 'mentoring_connection'
    MENTORING_COMMUNITY = 'mentoring_community'
  end

  def self.enabled?
    defined?(ENGAGEMENT_INDEX_ENABLED) && ENGAGEMENT_INDEX_ENABLED
  end

  def initialize(member, organization, user, program, browser, working_on_behalf)
    @member = member
    @organization = organization
    @user = user
    @program = program
    @browser = browser
    @working_on_behalf = working_on_behalf
  end

  def save_activity!(activity_type, options={})
    return false if to_be_ignored?
    data_hash = get_data_hash
    data_hash = options.reverse_merge(data_hash)
    data_hash[:activity] = activity_type
    UserActivity.create!(data_hash)
  end

  private

  def get_data_hash
    data_hash = {}
    data_hash[:happened_at] = Time.now.utc
    data_hash.merge!(user_details)
    data_hash.merge!(program_details)
    data_hash.merge!(browser_details) if @browser.present?
    return data_hash
  end

  def user_details
    {
      member_id: @member.id,
      user_id: @user.try(:id),
      roles: @user.try(:role_names).try(:join, SEPARATOR),
      current_connection_status: @user.try(:current_connection_status),
      past_connection_status: @user.try(:past_connection_status),
      join_date: @member.terms_and_conditions_accepted
    }
  end

  def program_details
    {
      organization_id: @organization.id,
      program_id: @program.try(:id),
      mentor_request_style: @program.try(:mentor_request_style),
      program_url: (@program||@organization).url,
      account_name: @organization.account_name
    }
  end

  def browser_details
    {
      browser_name: @browser.name,
      platform_name: @browser.platform.name,
      device_name: @browser.device.name
    }
  end

  def to_be_ignored?
    @working_on_behalf || @user && @user.is_admin_only?
  end
end