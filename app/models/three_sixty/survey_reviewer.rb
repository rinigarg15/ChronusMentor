# == Schema Information
#
# Table name: three_sixty_survey_reviewers
#
#  id                                   :integer          not null, primary key
#  three_sixty_survey_assessee_id       :integer          not null
#  three_sixty_survey_reviewer_group_id :integer          not null
#  name                                 :string(255)
#  email                                :string(255)
#  invitation_code                      :string(255)
#  invite_sent                          :boolean          default(FALSE), not null
#  created_at                           :datetime         not null
#  updated_at                           :datetime         not null
#  inviter_id                           :integer
#

class ThreeSixty::SurveyReviewer < ActiveRecord::Base
  self.table_name = :three_sixty_survey_reviewers

  MASS_UPDATE_ATTRIBUTES = {
    create: [:name, :email, :three_sixty_survey_reviewer_group_id],
    update: [:name, :email, :three_sixty_survey_reviewer_group_id],
    answer: [:name]
  }

  belongs_to :survey_assessee, :foreign_key => "three_sixty_survey_assessee_id", :class_name => "ThreeSixty::SurveyAssessee"
  belongs_to :survey_reviewer_group, :foreign_key => "three_sixty_survey_reviewer_group_id", :class_name => "ThreeSixty::SurveyReviewerGroup"
  belongs_to :inviter, :foreign_key => "inviter_id", :class_name => "Member"

  has_many :answers, :dependent => :destroy, :foreign_key => "three_sixty_survey_reviewer_id", :class_name => "ThreeSixty::SurveyAnswer"
  has_many :job_logs, :as => :ref_obj

  validates :three_sixty_survey_reviewer_group_id, :three_sixty_survey_assessee_id, :name, :presence => true
  validates :invitation_code, :presence => true
  validates :email, :presence => true, :email_format => {:generate_message => true, :check_mx => false}, :uniqueness => { :scope => :three_sixty_survey_assessee_id, :message => Proc.new { "activerecord.custom_errors.three_sixty/survey_reviewer.email_already_exists".translate } }
  validate :survey_assessee_and_survey_reviewer_group_belong_to_same_survey

  before_validation :set_invitation_code, :on => :create

  delegate :survey, :to => :survey_assessee
  delegate :reviewer_group, :to => :survey_reviewer_group

  scope :except_self, -> { includes(:survey_reviewer_group => [:reviewer_group]).joins(:survey_reviewer_group => [:reviewer_group]).where("three_sixty_reviewer_groups.name != ?", ThreeSixty::ReviewerGroup::DefaultName::SELF) }
  scope :for_self, -> { includes(:survey_reviewer_group => [:reviewer_group]).joins(:survey_reviewer_group => [:reviewer_group]).where("three_sixty_reviewer_groups.name = ?", ThreeSixty::ReviewerGroup::DefaultName::SELF) }
  scope :invited, -> { where(:invite_sent => true)}
  scope :with_pending_invites, -> { where(:invite_sent => false)}

  def for_self?
    self.reviewer_group.is_for_self?
  end

  def notify
    return if self.invite_sent?
    self.update_attribute(:invite_sent, true)
    ChronusMailer.three_sixty_survey_reviewer_notification(self.survey, self).deliver_now
  end

  def answered?
    self.answers.any?
  end

  def group_name
    self.reviewer_group.name
  end

  def is_invited_by?(member)
    self.inviter == member
  end

  private

  def survey_assessee_and_survey_reviewer_group_belong_to_same_survey
    errors.add(:survey_reviewer_group, "activerecord.custom_errors.three_sixty/survey_reviewer.survey_assessee_and_survey_reviewer_group_belong_to_same_survey".translate) unless self.survey_reviewer_group && self.survey_reviewer_group.survey == self.survey
  end

  def set_invitation_code
    self.invitation_code = Digest::SHA1.hexdigest([Time.now, rand].join)
  end
end
