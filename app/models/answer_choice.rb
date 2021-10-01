# == Schema Information
#
# Table name: answer_choices
#
#  id                 :integer          not null, primary key
#  ref_obj_id         :integer
#  ref_obj_type       :string(255)
#  question_choice_id :integer
#  position           :integer          default(0)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#

class AnswerChoice < ActiveRecord::Base
  has_paper_trail class_name: AnswerChoiceVersion.name, meta: { member_id: :member_id, question_choice_id: :question_choice_id }

  attr_accessor :skip_parent_destroy

  ############ ASSOCIATIONS #################

  belongs_to :ref_obj, polymorphic: true
  belongs_to :question_choice

  ############ SCOPES #######################

  default_scope -> { order(position: :asc) }

  ############# VALIDATIONS ##################

  validates :question_choice_id, presence: true, uniqueness: {scope: [:ref_obj_id, :ref_obj_type]}
  validates :ref_obj, presence: true

  class << self
    def create_initial_versions_in_chunks(answer_choice_start_id, answer_choice_end_id)
      answer_choices = AnswerChoice.includes(:ref_obj).where(id: (answer_choice_start_id..answer_choice_end_id))
      answer_choice_versions = []
      answer_choices.each do |answer_choice|
        answer_choice_versions << answer_choice.versions.new(answer_choice.paper_trail.data_for_create) # :data_for_create of :paper_trail, sets object_changes as nil, and can be used to differentiate in future if needed
      end
      AnswerChoiceVersion.import(answer_choice_versions, validate: false)
    end

    def bulk_create_initial_versions(answer_choice_start_id, answer_choice_end_id)
      start_id = answer_choice_start_id
      while start_id <= answer_choice_end_id do
        end_id = start_id + 999
        end_id = answer_choice_end_id if end_id > answer_choice_end_id
        AnswerChoice.delay(priority: DjPriority::NON_BLOCKING_CHUNK_CREATE).create_initial_versions_in_chunks(start_id, end_id)
        start_id = end_id + 1
      end
    end
  end

  def member_id
    case ref_obj_type
    when ProfileAnswer.name
      (ref_obj&.ref_obj_type == Member.name) ? ref_obj.ref_obj_id : nil
    else
      nil
    end
  end
end
