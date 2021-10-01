# == Schema Information
#
# Table name: comments
#
#  id                     :integer          not null, primary key
#  article_publication_id :integer
#  user_id                :integer
#  body                   :text(65535)
#  created_at             :datetime
#  updated_at             :datetime
#

#
# Comments provided by users for an article.
#
class Comment < ActiveRecord::Base

  ##############################################################################
  # ASSOCIATIONS
  ##############################################################################

  # The instance of the publication (within a program) that is commented on.
  belongs_to  :publication,
              :class_name  => "Article::Publication",
              :foreign_key => "article_publication_id"

  # The user who has provided the comment.
  belongs_to :user

  has_many :recent_activities, :as => :ref_obj, :dependent => :destroy

  # attr_protected :article_publication_id, :user_id
  delegate :article, :to => :publication

  has_many :flags, as: :content, dependent: :nullify

  has_many :job_logs, :as => :loggable_object

  has_many :pending_notifications, as: :ref_obj, dependent: :destroy

  has_many :push_notifications, :as => :ref_obj

  ##############################################################################
  # VALIDATIONS
  ##############################################################################

  validates_presence_of :publication, :user, :body
  validate :check_program

  scope :created_in_date_range, Proc.new { |date_range| where(created_at: date_range) }

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:body]
  }

  def self.notify_watchers(comment_id, notif_type)
    comment = Comment.find_by(id: comment_id)
    return if comment.nil?
    # Send mail to everyone else but the commenter
    mail_receivers = comment.publication.watchers - [comment.user]
    JobLog.compute_with_historical_data(mail_receivers, comment, notif_type) do |watcher|
      # Notify only those to whom the commenter is visible.
      next unless comment.user.visible_to?(watcher)
      Push::Base.queued_notify(PushNotification::Type::ARTICLE_COMMENT_CREATED, comment, {user_id: watcher.id}) if notif_type == RecentActivityConstants::Type::ARTICLE_COMMENT_CREATION
      watcher.send_email(comment, notif_type, sender: comment.user)
    end    
  end

  protected

  #
  # Checks whether the user belongs to the program in which the article is published.
  #
  def check_program
    if self.publication && self.user && self.publication.program != self.user.program
      self.errors[:base] << "activerecord.custom_errors.comment.comment_in_invalid_program".translate
    end
  end
end
