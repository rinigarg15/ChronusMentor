# == Schema Information
#
# Table name: feedback_responses
#
#  id               :integer          not null, primary key
#  feedback_form_id :integer          not null
#  group_id         :integer
#  user_id          :integer
#  created_at       :datetime
#  updated_at       :datetime
#  recipient_id     :integer
#  rating           :float(24)        default(0.5)
#

# Response given by a mentee for a mentor in a mentoring connection.
class Feedback::Response < ActiveRecord::Base
  self.table_name = 'feedback_responses'

  # constants for rating
  MIN_RATING = 0.5
  MAX_RATING = 5

  ##############################################################################
  # ASSOCIATIONS
  ##############################################################################

  # Feedback form to which this response belongs to
  belongs_to :feedback_form,
             :class_name  => "Feedback::Form",
             :foreign_key => 'feedback_form_id'

  # Connection on which the feedback reponse is given
  belongs_to :group

  belongs_to :rating_receiver, :class_name => "User", :foreign_key => "recipient_id"

  belongs_to :rating_giver, :class_name => "User", :foreign_key => "user_id"

  # Answers contained in this reponse.
  has_many :answers,
           :class_name => "Feedback::Answer",
           :foreign_key => 'feedback_response_id',
           :dependent => :destroy
  has_many :job_logs, :as => :loggable_object

  ##############################################################################
  # VALIDATIONS
  ##############################################################################

  validates_presence_of :feedback_form, :rating_receiver
  validate :check_users_belongs_to_group_with_valid_roles, on: :create
  validates :rating, numericality: {:greater_than_or_equal_to => MIN_RATING, :less_than_or_equal_to => MAX_RATING}, :presence => true

  ##############################################################################
  # CLASS METHODS
  ##############################################################################

  # Creates a new Response from the answers
  #
  # Params:
  #
  # *<tt>question_id_to_answer_map</tt> : Hash mapping question id to answer text.
  #
  # If some errors occurs while saving the answer of a question (say q1),
  # returns [false, q1]. Returns true otherwise
  #
  def self.create_from_answers(mentee, mentor, rating, group, feedback_form, question_id_to_answer_map)
    response =  self.new(:rating_giver => mentee, :rating_receiver => mentor, :rating => rating,:group => group, :feedback_form => feedback_form)

    question_id_to_answer_map ||= {}
    question_id_to_answer_map.each_pair do |question_id, answer_value|
      answer = response.answers.build(
        :common_question_id => question_id, :response => response)
      answer.answer_value = answer_value
    end

    response.save
    return response
  end

  def notify_admins
    admins = self.feedback_form.program.admin_users.active
    JobLog.compute_with_historical_data(admins, self, RecentActivityConstants::Type::COACH_RATING_ADMIN_NOTIFICATION) do |admin|
      ChronusMailer.coach_rating_notification_to_admin(admin, self, {sender: self.rating_giver}).deliver_now
    end
  end
  
  ##############################################################################
  # PRIVATE METHODS
  ##############################################################################

  private

  # Checks whether the +user+ belongs to the +group+ with valid roles
  def check_users_belongs_to_group_with_valid_roles
    return unless self.rating_giver.present? && self.group.present? && self.rating_receiver.present? && self.feedback_form.present?
    group = self.group

    if group.published?
      check_mentor_belongs_to_group(self.rating_receiver, group)
      check_mentee_belongs_to_group(self.rating_giver, group)
      check_group_and_response_belongs_to_same_program(group, self)
    else
      errors.add(:base, "activerecord.custom_errors.group.not_published_yet".translate(:mentoring_connection => group.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase))
    end
  end

  def check_mentor_belongs_to_group(mentor, group)
    unless group.mentors.include?(mentor)
      errors.add(:base, "activerecord.custom_errors.group.not_a_mentor_in_group".translate(:mentoring_connection => group.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase, :mentor_name => mentor.name, :mentor => group.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term_downcase))
    end
  end
  
  def check_mentee_belongs_to_group(mentee, group)
    unless group.students.include?(mentee)
      errors.add(:base, "activerecord.custom_errors.group.not_a_mentee_in_group".translate(:mentoring_connection => group.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase, :mentee_name => mentee.name, :mentee => group.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).term_downcase))
    end
  end

  def check_group_and_response_belongs_to_same_program(group, response)
    unless group.program == response.feedback_form.program
      errors.add(:base, "activerecord.custom_errors.group.does_not_belong_to_program_of_feedback_form".translate(:mentoring_connection => group.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase, :programs => group.program.term_for(CustomizedTerm::TermType::PROGRAM_TERM).pluralized_term_downcase))
    end
  end
end
