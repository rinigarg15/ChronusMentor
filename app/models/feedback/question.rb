# == Schema Information
#
# Table name: common_questions
#
#  id                       :integer          not null, primary key
#  program_id               :integer
#  question_text            :text(65535)
#  question_type            :integer
#  question_info            :text(65535)
#  position                 :integer
#  created_at               :datetime
#  updated_at               :datetime
#  required                 :boolean          default(FALSE), not null
#  help_text                :text(65535)
#  type                     :string(255)
#  survey_id                :integer
#  common_answers_count     :integer          default(0)
#  feedback_form_id         :integer
#  allow_other_option       :boolean          default(FALSE)
#  is_admin_only            :boolean
#  question_mode            :integer
#  positive_outcome_options :text(65535)
#  matrix_question_id       :integer
#  matrix_position          :integer
#  matrix_setting           :integer
#  condition                :integer          default(0)
#

# A field in the connection feedback form. The question is role based, and is
# either for mentor or student role.
class Feedback::Question < CommonQuestion
  ##############################################################################
  # ASSOCIATIONS
  ##############################################################################

  acts_as_list scope: :feedback_form_id

  belongs_to :feedback_form,
             :class_name => "Feedback::Form",
             :foreign_key => 'feedback_form_id'

  has_many :answers,
           :class_name => "Feedback::Answer",
           :foreign_key => 'common_question_id',
           :dependent => :destroy

  ##############################################################################
  # VALIDATIONS
  ##############################################################################

  validates_presence_of :feedback_form

  ##############################################################################
  # INSTANCE METHODS
  ##############################################################################

  # Updates the user's anwser for the question with the given value.
  #
  # ==== Params
  # * <tt>user</tt> : the user whose answer to update
  # * <tt>answer_text</tt> : Hash mapping question id to answer text.
  #
  def save_user_answer(user, answer_text, response)
    # See if there is already an answer by the user
    answer = self.answers.find_by(feedback_response_id: response.id)
    answer ||= self.answers.new(:user => user)

    # Save new answer.
    answer.answer_value = answer_text
    answer.response = response
    answer.save
  end
end
