# == Schema Information
#
# Table name: common_answers
#
#  id                      :integer          not null, primary key
#  user_id                 :integer
#  common_question_id      :integer
#  answer_text             :text(65535)
#  created_at              :datetime
#  updated_at              :datetime
#  type                    :string(255)
#  attachment_file_name    :string(255)
#  attachment_content_type :string(255)
#  attachment_file_size    :integer
#  attachment_updated_at   :datetime
#  feedback_response_id    :integer
#  group_id                :integer
#  survey_id               :integer
#  task_id                 :integer
#  response_id             :integer
#  member_meeting_id       :integer
#  meeting_occurrence_time :datetime
#  last_answered_at        :datetime
#  delta                   :boolean          default(FALSE)
#  is_draft                :boolean          default(FALSE)
#

# A field in the connection feedback form. The question is role based, and is
# either for mentor or student role.
class Feedback::Answer < CommonAnswer

  ##############################################################################
  # ASSOCIATIONS
  ##############################################################################

  # Feedback question to which this answer belongs to
  belongs_to :question,
             :class_name => "Feedback::Question",
             :foreign_key => 'common_question_id'

  # Feedback response to which this answer belongs to
  belongs_to :response,
             :class_name => "Feedback::Response",
             :foreign_key => 'feedback_response_id'

  ##############################################################################
  # VALIDATIONS
  ##############################################################################

  validates_presence_of :response

  ##############################################################################
  # CALLBACKS
  ##############################################################################

  before_validation :set_user_from_response

  def check_user_presence?
    false
  end
  
  private

  # Unconditionally sets user from the response
  def set_user_from_response
    self.user = self.response.rating_giver if self.response    
  end
end

