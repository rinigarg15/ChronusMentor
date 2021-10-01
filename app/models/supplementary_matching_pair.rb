class SupplementaryMatchingPair < ActiveRecord::Base

  module Type
    def self.all
      ProfileQuestion::Type.all - [ProfileQuestion::Type::NAME, ProfileQuestion::Type::EMAIL, ProfileQuestion::Type::FILE]
    end
  end

  belongs_to :program, inverse_of: :supplementary_matching_pairs
  belongs_to :student_role_question, class_name: RoleQuestion.name, inverse_of: :supplementary_student_matching_pairs
  belongs_to :mentor_role_question, class_name: RoleQuestion.name, inverse_of: :supplementary_mentor_matching_pairs

  validates :program, :student_role_question, :mentor_role_question, presence: true
  validates :student_role_question_id, uniqueness: {scope: [:mentor_role_question_id, :program_id]}

  alias_attribute :student_question_id, :student_role_question_id
  alias_attribute :mentor_question_id, :mentor_role_question_id
  alias_method :student_question, :student_role_question
  alias_method :mentor_question, :mentor_role_question
end
