class PreferenceBasedMentorList < ActiveRecord::Base
  MIN_CHOICES_NEEDED = 4
  MIN_MENTOR_ANSWERS = 10

  belongs_to :user
  belongs_to :ref_obj, polymorphic: true
  belongs_to :profile_question

  validates :user, :ref_obj, :profile_question, :weight, presence: true
  validates :weight, numericality: true

  scope :ignored, -> { where(ignored: true) }

  module Type
    def self.all
      [QuestionChoice.name, Location.name]
    end
  end

  def self.select_mentor_lists_meeting_criteria(mentor_lists, mentor_member_ids)
    mentor_lists.select{|mentor_list| mentor_list.meets_number_of_choices_creteria? && mentor_list.meets_number_of_mentors_answered_creteria?(mentor_member_ids)}
  end

  def type
    ref_obj.class.name
  end

  def meets_number_of_choices_creteria?
    (type == Location.name) || profile_question.question_choices.size >= MIN_CHOICES_NEEDED
  end

  def meets_number_of_mentors_answered_creteria?(mentor_member_ids)
    case type
    when Location.name
      locations = ref_obj.get_other_locations_in_the_city
      profile_question.profile_answers.where(location_id: locations.pluck(:id), ref_obj_id: mentor_member_ids, ref_obj_type: Member.name).count >= MIN_MENTOR_ANSWERS
    when QuestionChoice.name
      ref_obj.profile_answers.where(ref_obj_id: mentor_member_ids, ref_obj_type: Member.name).count >= MIN_MENTOR_ANSWERS
    end
  end
end