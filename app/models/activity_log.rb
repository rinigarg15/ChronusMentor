# == Schema Information
#
# Table name: activity_logs
#
#  id         :integer          not null, primary key
#  user_id    :integer
#  program_id :integer
#  activity   :integer
#  created_at :datetime
#  updated_at :datetime
#

class ActivityLog < ActiveRecord::Base
  module Activity
    PROGRAM_VISIT = 100
    ARTICLE_VISIT = 200
    FORUM_VISIT = 300
    QA_VISIT = 400
    MENTORING_VISIT = 500
    RESOURCE_VISIT = 600
  end

  acts_as_role_based

  belongs_to_program
  belongs_to :user

  validates :user_id, :presence => true
  validates :program_id, :presence => true
  validates :activity, :presence => true, :inclusion => { :in => [ActivityLog::Activity::PROGRAM_VISIT, ActivityLog::Activity::ARTICLE_VISIT, ActivityLog::Activity::FORUM_VISIT, ActivityLog::Activity::QA_VISIT, ActivityLog::Activity::MENTORING_VISIT, ActivityLog::Activity::RESOURCE_VISIT] }

  scope :program_visits, -> { where("activity_logs.activity = ?", ActivityLog::Activity::PROGRAM_VISIT)}
  scope :community_visits, -> { where(:activity => [ActivityLog::Activity::ARTICLE_VISIT, ActivityLog::Activity::FORUM_VISIT, ActivityLog::Activity::QA_VISIT, ActivityLog::Activity::RESOURCE_VISIT])}
  scope :mentoring_visits, -> { where("activity_logs.activity = ?", ActivityLog::Activity::MENTORING_VISIT)}

  after_save :reindex_user
  after_destroy :reindex_user

  def self.log_activity( user, activity )
    return if user.blank? || user.is_admin_only?
    options = {activity: activity, created_at: Time.now.utc.beginning_of_day, user_id: user.id}
    program = user.program
    # One type of activity should be logged once in a day only per user.
    unless program.activity_logs.where(options).exists?
      activity_log = program.activity_logs.build(options)
      activity_log.role_names = user.role_names
      activity_log.save!
    end
  end

  def self.log_mentoring_visit(user)
    ActivityLog.delay.log_activity(user, ActivityLog::Activity::MENTORING_VISIT)
  end

  def self.es_reindex(activity)
    DelayedEsDocument.do_delta_indexing(User, Array(activity), :user_id)
  end

  def reindex_user
    return unless self.activity == ActivityLog::Activity::PROGRAM_VISIT
    self.class.es_reindex(self)
  end

end
