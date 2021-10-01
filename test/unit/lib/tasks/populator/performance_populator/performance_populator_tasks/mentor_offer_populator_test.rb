require_relative './../../../../../../test_helper'

class MentorOfferPopulatorTest < ActiveSupport::TestCase
  def test_add_mentor_offers
    program = programs(:albers)
    to_add_mentor_ids = program.users.active.includes(:groups).select{|user| user.is_mentor? && !user.groups.count.zero?}.collect(&:id).first(5)
    to_remove_mentor_ids = program.mentor_offers.pluck(:mentor_id).uniq.last(5)
    populator_add_and_remove_objects("mentor_offer", "mentor", to_add_mentor_ids, to_remove_mentor_ids, {program: program})
  end
end