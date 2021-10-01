# == Schema Information
#
# Table name: article_publications
#
#  id         :integer          not null, primary key
#  article_id :integer          not null
#  program_id :integer          not null
#  created_at :datetime
#  updated_at :datetime
#

#
# Represents the instance of an Article published in a Program.
#
class Article::Publication < ActiveRecord::Base

  ##############################################################################
  # ASSOCIATIONS
  ##############################################################################

  belongs_to :program
  belongs_to :article

  has_many  :comments,
            :foreign_key => 'article_publication_id',
            :dependent => :destroy

  has_many :job_logs, as: :loggable_object

  before_destroy :destroy_program_activities

  scope :in_program, -> (programs) {
    where({:program_id => programs})
  }

  ##############################################################################
  # VALIDATIONS
  ##############################################################################

  validates_presence_of   :program, :article

  # An article cannot be published more than once in a program.
  validates_uniqueness_of :article_id, :scope => [:program_id]

  validates_permission_of :author,
                          :write_article,
                          :on => :create,
                          :message => Proc.new{ "activerecord.custom_errors.publication.cant_write_article".translate }

  ##############################################################################
  # INSTANCE METHODS
  ##############################################################################


  #
  # Returns the author (+User+) of this publication by inferring from
  # Article#member and +self.program+
  #
  def author
    if self.article && self.article.author
      self.article.author.user_in_program(self.program)
    end
  end

  #
  # List of +User+ to be notified on comments to this publication which includes
  #
  # * author
  # * commenters
  # * admins
  #
  def watchers
    _watchers = []
    _watchers << self.article.author.user_in_program(self.program)  # Author
    _watchers += self.comments.includes(:user).collect(&:user)                      # All commenters
    _watchers += self.program.admin_users                           # And the administrators.
    _watchers.uniq
  end

  #
  # List of +Users+s to be notified on this publication.
  #
  def notification_list_for_creation
    # Get the admin users the published program sans the author User.
    self.program.admin_users - [self.author]
  end

  # If we add mails for edit/destroy of publications, then we need versioning
  def self.notify_users(publication_id, notif_type)
    publication = Article::Publication.find_by(id: publication_id)
    if publication
      JobLog.compute_with_historical_data(publication.notification_list_for_creation, publication, notif_type) do |user|
        user.send_email(
          publication.article, notif_type, initiator: publication.author
        )
      end
    end
  end

  def program_activities
    ProgramActivity.find_by_sql(["SELECT program_activities.* from program_activities
      INNER JOIN recent_activities ON program_activities.activity_id = recent_activities.id
      INNER JOIN articles ON (recent_activities.ref_obj_id = articles.id AND recent_activities.ref_obj_type = 'Article')
      INNER JOIN article_publications ON articles.id = article_publications.article_id
      WHERE article_publications.id = #{self.id} AND program_activities.program_id = #{self.program_id}"])
  end

  def destroy_program_activities
    self.program_activities.collect(&:destroy)
  end

  def self.es_reindex(article_publication)
    DelayedEsDocument.do_delta_indexing(Article, Array(article_publication), :article_id)
  end
end
