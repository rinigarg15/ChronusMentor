class HealthReport::ProgramHealthReport

  DEFAULT_ACTIVE_USER_INTERVAL = 30
  attr_accessor :program, :start_time, :end_time, :roles,
                :registered_users_series,
                :active_user_interval_in_days,
                :active_users_series,
                :ongoing_mentoring_activity_users_series,
                :active_mentoring_activity_users_series,
                :community_activity_users_series,
                :article_activity_users_series,
                :resource_activity_users_series,
                :forum_activity_users_series,
                :qa_activity_users_series,
                :registered_users_summary_count,
                :active_users_summary_count,
                :ongoing_mentoring_activity_users_summary_count,
                :active_mentoring_activity_users_summary_count,
                :community_activity_users_summary_count,
                :resource_activity_users_summary_count,
                :article_activity_users_summary_count,
                :forum_activity_users_summary_count,
                :qa_activity_users_summary_count

  def initialize(program)
    self.program = program
    self.active_user_interval_in_days = program.inactivity_tracking_period_in_days || DEFAULT_ACTIVE_USER_INTERVAL
    reset_state!
  end

  def compute(start_time, end_time, roles)
    @start_time, @end_time, @roles = start_time, end_time, roles
    reset_state!
    generate_daterange_map!
    compute_data_series!
  end

private
  def reset_state!
    self.registered_users_series                 = []
    self.active_users_series                     = []
    self.ongoing_mentoring_activity_users_series = []
    self.active_mentoring_activity_users_series  = []
    self.community_activity_users_series         = []
    self.article_activity_users_series           = []
    self.resource_activity_users_series          = []
    self.forum_activity_users_series             = []
    self.qa_activity_users_series                = []

    self.registered_users_summary_count                 = 0
    self.active_users_summary_count                     = 0
    self.ongoing_mentoring_activity_users_summary_count = 0
    self.active_mentoring_activity_users_summary_count  = 0

    self.community_activity_users_summary_count = 0
    self.resource_activity_users_summary_count  = 0
    self.article_activity_users_summary_count   = 0
    self.forum_activity_users_summary_count     = 0
    self.qa_activity_users_summary_count        = 0
  end

  def active_users_data
    active_users_day_hash = {}
    active_users_array = self.program.activity_logs.joins(user: :roles).program_visits.
      select("DATE(activity_logs.created_at) as user_activity_at, activity_logs.user_id as activity_user_id").
      where(users: { state: [User::Status::ACTIVE] }).
      where(created_at: (start_time.beginning_of_day - active_user_interval_in_days)..end_time.end_of_day).
      where(roles: { name: roles })

    active_users_array.group_by(&:user_activity_at).each do |day, act|
      active_users_day_hash[day] = act.collect(&:activity_user_id)
    end
    active_users_day_hash
  end

  def compute_active_users(active_users_day_hash, active_day)
    start_index = @daterange_hash[active_day - active_user_interval_in_days]
    end_index   = @daterange_hash[active_day]

    active_user_array = []
    @daterange_map[start_index..end_index].each do |day|
      active_user_array += active_users_day_hash[day] if active_users_day_hash.has_key?(day)
    end
    active_user_array.uniq
  end

  def registered_users_data
    program.all_users.active.joins(:roles).
      select("DISTINCT users.id").
      where(roles: { name: roles }, users: { created_at: start_time.beginning_of_day..end_time.end_of_day }).
      group('date(users.created_at)').count
  end

  def registered_users_till_date
    prev_day_of_start_time = (start_time.beginning_of_day - 1).end_of_day

    program.all_users.active.joins(:roles).
      select("DISTINCT users.id").
      where(roles: { name: roles }).
      where('users.created_at<?', prev_day_of_start_time).count
  end

  def active_mentoring_users_data
    active_mentoring_days_hash = {}

    active_mentoring_users_array = self.program.activity_logs.joins(:user => :roles).mentoring_visits.
      select("DATE(activity_logs.created_at) as user_activity_at, activity_logs.user_id as activity_user_id").
      where(users: { state: [User::Status::ACTIVE] }).
      where(created_at: (start_time.beginning_of_day - active_user_interval_in_days)..end_time.end_of_day).
      where(roles: { name: roles })

    active_mentoring_users_array.group_by(&:user_activity_at).each do |day, act|
      active_mentoring_days_hash[day] = act.collect(&:activity_user_id).uniq
    end

    active_mentoring_days_hash
  end

  def ongoing_mentoring_users_data
    membership_role_ids = self.program.roles.where(:name => self.roles).pluck(:id)
    beginning_of_start_time = start_time.beginning_of_day
    start_date = (beginning_of_start_time - active_user_interval_in_days).to_date
    end_date   = end_time.to_date

    mentoring_users_by_day = Connection::Membership.joins(:group).
      select("connection_memberships.user_id as mentoring_user_id, date(connection_memberships.created_at) as mentoring_created_at, date(IFNULL(groups.closed_at, CURDATE())) as mentoring_closed_at").
      where('groups.program_id = ?', program.id).
      where('groups.status IN (?)', [Group::Status::ACTIVE, Group::Status::INACTIVE, Group::Status::CLOSED]).
      where('(connection_memberships.created_at < ? AND (groups.closed_at IS NULL OR groups.closed_at > ?)) OR
             (connection_memberships.created_at BETWEEN ? AND ?)',
             beginning_of_start_time, beginning_of_start_time, beginning_of_start_time, end_time.end_of_day).
      where(connection_memberships: { role_id: membership_role_ids })

    
    mentoring_days_hash = @daterange_map.inject({}) { |res, date| res[date] = {}; res }
    ActiveRecord::Base.connection.select_all(mentoring_users_by_day).each do |mentoring_user|
      mentoring_user_id = mentoring_user['mentoring_user_id']
      mentoring_begin_date = mentoring_user['mentoring_created_at']
      mentoring_end_date   = mentoring_user['mentoring_closed_at']

      mentoring_begin_date = start_date if start_date > mentoring_begin_date
      mentoring_end_date = end_date if end_date < mentoring_end_date
    
      start_index = @daterange_hash[mentoring_begin_date]
      end_index   = @daterange_hash[mentoring_end_date]
    
      @daterange_map[start_index..end_index].each do |mentoring_day|
        mentoring_days_hash[mentoring_day][mentoring_user_id] = mentoring_user_id
      end
    end

    mentoring_days_hash.inject({}) do |res, pair|
      res[pair[0]] = pair[1].keys
      res
    end
  end

  def compute_active_mentoring_users(active_users_day_hash, active_day, ongoing_mentoring_days_hash)
    active_user_array = []

    start_index = @daterange_hash[active_day - active_user_interval_in_days]
    end_index   = @daterange_hash[active_day]

    @daterange_map[start_index..end_index].each do |day|
      if active_users_day_hash.has_key?(day) && ongoing_mentoring_days_hash.has_key?(day)
        active_user_array += (active_users_day_hash[day] & ongoing_mentoring_days_hash[day])
      end
    end
    active_user_array.uniq
  end

  def community_users_data
    community_users_by_day_hash = {}
    resource_users_by_day_hash  = {}
    article_users_by_day_hash   = {}
    forum_users_by_day_hash     = {}
    qa_users_by_day_hash        = {}

    activity_logs = program.activity_logs.community_visits.joins(:user => :roles).
      select("date(activity_logs.created_at) as user_activity_at, users.id as activity_user_id, activity_logs.activity as activity_type").
      where(created_at: start_time.beginning_of_day..end_time.end_of_day).
      where(roles: { name: roles })

    activity_logs.group_by(&:user_activity_at).each_pair do |day, act|
      community_users_by_day_hash[day] = act.collect(&:activity_user_id).uniq
      resource_users_by_day_hash[day]  = act.select { |ac| ac.activity_type == ActivityLog::Activity::RESOURCE_VISIT }.collect(&:activity_user_id).uniq
      article_users_by_day_hash[day]   = act.select { |ac| ac.activity_type == ActivityLog::Activity::ARTICLE_VISIT }.collect(&:activity_user_id).uniq
      forum_users_by_day_hash[day]     = act.select { |ac| ac.activity_type == ActivityLog::Activity::FORUM_VISIT }.collect(&:activity_user_id).uniq
      qa_users_by_day_hash[day]        = act.select { |ac| ac.activity_type == ActivityLog::Activity::QA_VISIT }.collect(&:activity_user_id).uniq
    end

    {
      community: community_users_by_day_hash,
      resource: resource_users_by_day_hash,
      article: article_users_by_day_hash,
      forum: forum_users_by_day_hash,
      qa: qa_users_by_day_hash
    }
  end

  def generate_daterange_map!
    start_date = start_time.beginning_of_day.utc.to_date - active_user_interval_in_days
    end_date = end_time.end_of_day.utc.to_date

    @daterange_map = Array.new((end_date - start_date).to_i + 1)
    @daterange_hash = {}

    (start_date..end_date).each_with_index do |date, date_index|
      @daterange_map[date_index] = date
      @daterange_hash[date] = date_index
    end
  end

  def compute_data_series!
    registered_users_till_date_count = registered_users_till_date

    registered_users_days_hash = registered_users_data

    active_users_days_hash = active_users_data

    ongoing_mentoring_days_hash = ongoing_mentoring_users_data

    active_mentoring_days_hash = active_mentoring_users_data

    community_data = community_users_data
    community_users_by_day_hash = community_data[:community]
    resource_users_by_day_hash  = community_data[:resource]
    article_users_by_day_hash   = community_data[:article]
    forum_users_by_day_hash     = community_data[:forum]
    qa_users_by_day_hash        = community_data[:qa]

    active_users_array = []
    ongoing_mentoring_users_array = []
    active_mentoring_users_array = []

    start_index = @daterange_map.index(start_time.to_date)
    end_index = @daterange_map.index(end_time.to_date)

    @daterange_map[start_index..end_index].each do |date|
      registered_users_till_date_count += registered_users_days_hash[date].to_i
        self.registered_users_series << registered_users_till_date_count
  
      active_users_day_array = compute_active_users(active_users_days_hash, date)
  
      self.active_users_series << active_users_day_array.size
      active_users_array << active_users_day_array
  
      self.ongoing_mentoring_activity_users_series << ongoing_mentoring_days_hash[date].try(:size).to_i
        ongoing_mentoring_users_array << ongoing_mentoring_days_hash[date].to_a
  
      active_mentoring_users_day_array = compute_active_mentoring_users(active_mentoring_days_hash, date, ongoing_mentoring_days_hash)
  
      self.active_mentoring_activity_users_series << active_mentoring_users_day_array.size
        active_mentoring_users_array << active_mentoring_users_day_array
  
      self.community_activity_users_series << community_users_by_day_hash[date].try(:size).to_i
      self.resource_activity_users_series << resource_users_by_day_hash[date].try(:size).to_i
      self.article_activity_users_series << article_users_by_day_hash[date].try(:size).to_i
      self.forum_activity_users_series << forum_users_by_day_hash[date].try(:size).to_i
      self.qa_activity_users_series << qa_users_by_day_hash[date].try(:size).to_i
    end

    self.registered_users_summary_count = registered_users_till_date_count
    self.active_users_summary_count = active_users_array.flatten.uniq.size

    self.ongoing_mentoring_activity_users_summary_count = ongoing_mentoring_users_array.flatten.uniq.size
    self.active_mentoring_activity_users_summary_count = active_mentoring_users_array.flatten.uniq.size

    self.community_activity_users_summary_count = community_users_by_day_hash.values.flatten.uniq.size
    self.resource_activity_users_summary_count = resource_users_by_day_hash.values.flatten.uniq.size
    self.article_activity_users_summary_count = article_users_by_day_hash.values.flatten.uniq.size
    self.forum_activity_users_summary_count = forum_users_by_day_hash.values.flatten.uniq.size
    self.qa_activity_users_summary_count = qa_users_by_day_hash.values.flatten.uniq.size    
  end
end