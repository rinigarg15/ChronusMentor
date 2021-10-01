require_relative './../../../../test_helper'

class MentorOfferElasticsearchQueriesTest < ActiveSupport::TestCase

  def test_get_filtered_mentor_offers
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)

    offer1 = create_mentor_offer(mentor: users(:f_mentor), group: groups(:mygroup))
    offer2 = create_mentor_offer(mentor: users(:f_mentor), group: groups(:mygroup), student: users(:mkr_student))
    offer2.update_attributes!(status: MentorOffer::Status::ACCEPTED)
    reindex_documents(created: [offer1, offer2])
    action_params = { program_id: program.id }

    # with out status => it will be considered as pending
    mentor_offers = MentorOffer.get_filtered_mentor_offers(action_params)
    assert_equal 1, mentor_offers.to_a.count
    expected = mentor_offers.first
    assert_equal offer1.id, expected.id.to_i
    assert_equal offer1.mentor_id, expected.mentor_id
    assert_equal offer1.student_id, expected.student_id

    # with status accepted
    action_params.merge!(status: MentorOffer::Status::STATE_TO_STRING[MentorOffer::Status::ACCEPTED])
    mentor_offers = MentorOffer.get_filtered_mentor_offers(action_params)
    assert_equal 1, mentor_offers.to_a.count
    expected = mentor_offers.first
    assert_equal offer2.id, expected.id.to_i
    assert_equal offer2.mentor_id, expected.mentor_id
    assert_equal offer2.student_id, expected.student_id
  end
end