require_relative './../../../../../../test_helper'

class MentorRecommendationPopulatorTest < ActiveSupport::TestCase
  def test_add_remove_mentor_recommendations
    program = programs(:albers)
    to_add_student_ids = program.student_users.pluck(:id).first(5)
    to_remove_student_ids = program.mentor_recommendations.pluck(:receiver_id).uniq.first(5)
    populator_add_and_remove_objects("mentor_recommendation", "user", to_add_student_ids, to_remove_student_ids, program: program) 
  end
end