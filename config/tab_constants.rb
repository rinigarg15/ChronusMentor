# List of tabs we use in the application.
class TabConstants
  HOME                = 'Home'
  DASHBOARDS          = 'Dashboards'
  MANAGE              = 'Manage'
  FORUMS              = 'Forums'
  INVITE              = 'Invite'
  APP_HOME            = 'Home'
  ABOUT_PROGRAM       = 'Program Overview'
  QA                  = 'Question & Answers'
  ADVICE              = 'Advice'
  MEMBERSHIP_REQUESTS = 'Membership Requests'
  REPORT              = 'Program Status'
  MY_MEETINGS         = 'My Meetings'
  MY_AVAILABILITY     = 'My Availability'
  MENTORING_CALENDAR  = 'Mentoring Calendar'
  MEETINGS            = 'Meetings'
  MENTOR_REQUESTS     = 'Mentor Requests'
  REPORTS             = 'Reports'

  DIVIDER             = 'divider'

  LOCALE_TRANSLATION_MAP = {
    HOME                => 'home',
    DASHBOARDS          => 'dashboards',
    MANAGE              => 'manage',
    FORUMS              => 'forums',
    INVITE              => 'invite',
    APP_HOME            => 'app_home',
    ABOUT_PROGRAM       => 'program_overview',
    QA                  => 'qa',
    ADVICE              => 'advice',
    MEMBERSHIP_REQUESTS => 'membership_requests',
    REPORT              => 'program_status',
    MY_MEETINGS         => 'my_meetings',
    MY_AVAILABILITY     => 'my_availability',
    MENTORING_CALENDAR  => 'mentoring_calendar_v1',
    MEETINGS            => 'meetings',
    MENTOR_REQUESTS     => 'mentor_requests_v1',
    REPORTS             => 'reports'
  }
  TABS_BASE_LOCALE_TRANSLATION_KEY = "tab_constants"

  MAX_SUBTABS_FOR_CONNECTION_TAB = 3

  def self.translation_key(label)
    tab_translation_key = LOCALE_TRANSLATION_MAP[label]
    if tab_translation_key
      {value: [TABS_BASE_LOCALE_TRANSLATION_KEY, tab_translation_key].join("."), is_key?: true}
    else
      {value: label, is_key?: false}
    end
  end
end