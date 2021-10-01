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

class Connection::Answer < CommonAnswer

  belongs_to :question, :foreign_key => 'common_question_id', :class_name => "Connection::Question"
  belongs_to :group

  validates_presence_of :group
  validates_uniqueness_of :group_id, :scope => [:common_question_id]

  private

  # Override CommonAnswer#check_user_presence? to return false so that user is not validated.
  def check_user_presence?
    false
  end
end
