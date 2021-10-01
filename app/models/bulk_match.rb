# == Schema Information
#
# Table name: bulk_matches
#
#  id                   :integer          not null, primary key
#  mentor_view_id       :integer
#  mentee_view_id       :integer
#  program_id           :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  show_drafted         :boolean          default(FALSE)
#  show_published       :boolean          default(FALSE)
#  sort_value           :string(255)
#  sort_order           :boolean          default(TRUE)
#  request_notes        :boolean          default(TRUE)
#  max_pickable_slots   :integer
#  type                 :string(255)      default("BulkMatch")
#  max_suggestion_count :integer
#  default              :integer          default(0)
#

class BulkMatch < AbstractBulkMatch
  include BulkMatchCsvUtils

  has_many :groups, :dependent => :nullify

  MASS_UPDATE_ATTRIBUTES = {
   :update_notes => [:notes],
   :update_settings => [:show_drafted, :show_published, :request_notes, :max_pickable_slots]
  }

  module OrientationType
    MENTEE_TO_MENTOR = 0
    MENTOR_TO_MENTEE = 1
  end

  def self.generate_csv_for_all_pairs(students_hash, mentors_hash, student_mentor_map, options = {})
    BulkMatch.new(program: options.delete(:program), orientation_type: options.delete(:orientation_type)).generate_csv_for_all_pairs(students_hash, mentors_hash, student_mentor_map, options)
  end

  def generate_csv_for_drafted_pairs(groups, student_mentor_hash = {}, student_user_ids = [], mentor_user_ids = [], options={})
    CSV.generate do |csv|
      mentor_profile_ques_ids, student_profile_ques_ids = populate_csv_header(csv, self.program, options)
      groups.each do |group|
        student = group.students.first
        mentor = group.mentors.first
        if(mentor_user_ids.include?(mentor.id) && student_user_ids.include?(student.id))
          generate_drafted_pairs_csv(csv, student, mentor, student_mentor_hash, options.merge({group: group, mentor_profile_ques_ids: mentor_profile_ques_ids, student_profile_ques_ids: student_profile_ques_ids}))
        end
      end
    end
  end

  def generate_csv_for_all_pairs(students_hash, mentors_hash, student_mentor_map, options = {})
    CSV.generate do |csv|
      mentor_profile_ques_ids, student_profile_ques_ids = populate_csv_header(csv, self.program, options)
      options.merge!({mentor_profile_ques_ids: mentor_profile_ques_ids, student_profile_ques_ids: student_profile_ques_ids, student_mentor_map: student_mentor_map})
      mentor_to_mentee? ? generate_csv_for_all_pairs_mentor_to_mentee(csv, mentors_hash, options) : generate_csv_for_all_pairs_mentee_to_mentor(csv, students_hash, mentors_hash, options)
    end
  end

  private

  def generate_drafted_pairs_csv(csv, student, mentor, student_mentor_hash, options={})
    mentor_match_data = mentor_to_mentee? ? {pickable_slots: options[:pickable_slots][mentor.id]} : {}
    populate_csv_options = get_options(student, {group_status: "feature.connection.header.status.Drafted".translate}, mentor, mentor_match_data, options)
    populate_csv(csv, mentor.name, student.name, student_mentor_hash[student.id][mentor.id], populate_csv_options)
  end

  def mentor_to_mentee?
    self.orientation_type == BulkMatch::OrientationType::MENTOR_TO_MENTEE
  end
end
