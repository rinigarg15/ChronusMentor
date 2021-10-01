# == Schema Information
#
# Table name: matching_documents
#
#  id                    :integer          not null, primary key
#  program_id            :integer
#  record_id             :integer
#  mentor                :boolean
#  data_fields           :json
#
# Indexing
#  index_on_program_id                               :program_id
#  index_on_program_id_and_is_mentor_and_record_id   :program_id + :mentor + :record_id
#

class MatchingDocument < ActiveRecord::Base
  # Associations
  belongs_to_program
  belongs_to :user, foreign_key: "record_id"
  # dependent destroy handled thrugh DJ for user deletion

  after_initialize :after_initializing

  attr_accessor :data_fields_by_name
  # Number of hits to this document. Defaults to 0.
  attr_accessor :hit_count

  # Relative score of this document as a <code>Float</code> in the scale of
  # 0..1
  attr_accessor :original_score

  # Relative score of this document as a <code>Float</code> in the scale of
  # 0..1
  attr_accessor :score

  # This is set inorder to make sure the score is 0 after normalization
  attr_accessor :not_match

  def after_initializing
    return unless new_record?
    self.data_fields_by_name = {}
    self.hit_count = 0
    self.score = 0
    self.not_match = false
  end

  ############# VALIDATIONS ##################
  validates :program_id, presence: true
  validates :record_id, presence: true
end