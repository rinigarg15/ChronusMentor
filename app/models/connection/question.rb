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

class Connection::Question < CommonQuestion
  acts_as_summarizable
  
  MASS_UPDATE_ATTRIBUTES = {
    create: [:question_type, :help_text, :question_text, :allow_other_option, :is_admin_only, :required],
    update: [:question_type, :help_text, :question_text, :allow_other_option, :is_admin_only, :required]
  }

  acts_as_list scope: [:program_id, :type]

  has_many :answers,
           :class_name => "Connection::Answer",
           :foreign_key => 'common_question_id',
           :dependent => :destroy
  has_many :group_view_columns,
           :foreign_key => 'connection_question_id',
           :dependent => :destroy

  def self.get_viewable_or_updatable_questions(program, is_admin_user)
    return [] unless program.connection_profiles_enabled?
    program.connection_questions.includes(:translations, question_choices: :translations).select{|question| (!question.is_admin_only? || question.is_admin_only? && is_admin_user)}
  end
end
