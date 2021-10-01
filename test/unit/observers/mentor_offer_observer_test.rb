require_relative './../../test_helper.rb'

class MentorOfferObserverTest < ActiveSupport::TestCase
  def setup
    super
    # Required for testing mails
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)
  end

  def test_after_create
    Push::Base.expects(:queued_notify).once
    MentorOffer.expects(:send_group_mentoring_offer_notification_to_new_mentee).once
    assert_difference 'RecentActivity.count' do
      create_mentor_offer
    end
    assert_equal RecentActivityConstants::Type::MENTORING_OFFER_CREATION, RecentActivity.last.action_type
  end

  def test_observers_reindex_es
    MentorOffer.expects(:send_group_mentoring_offer_notification_to_new_mentee).once
    DelayedEsDocument.expects(:delayed_update_es_document).with(MentorOffer, any_parameters).once
    Push::Base.expects(:queued_notify).once
    DelayedEsDocument.expects(:delayed_update_es_document).with(User, users(:f_mentor).id).once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [users(:f_mentor).id]).times(3)
    mentor_offer = create_mentor_offer
    mentor_offer.update_attribute(:status, MentorOffer::Status::WITHDRAWN)
    mentor_offer.destroy
  end

  def test_after_update_mentor_offer_accepted
    Group.any_instance.stubs(:set_member_status)
    offer = create_mentor_offer(:group => groups(:mygroup))
    Push::Base.expects(:queued_notify).with(PushNotification::Type::MENTOR_OFFER_ACCEPTED, offer).once
    MentorOffer.expects(:send_mentor_offer_accepted_notification_to_mentor).once.with(offer.id)
    assert_difference 'RecentActivity.count' do
      assert_difference 'PendingNotification.count' do
        offer.update_attribute(:status, MentorOffer::Status::ACCEPTED)
      end
    end

    assert_equal RecentActivityConstants::Type::MENTORING_OFFER_ACCEPTANCE, RecentActivity.last.action_type
  end

  def test_after_update_mentor_offer_rejected
    Group.any_instance.stubs(:set_member_status)
    offer = create_mentor_offer(:group => groups(:mygroup))
    Push::Base.expects(:queued_notify).with(PushNotification::Type::MENTOR_OFFER_REJECTED, offer).once
    MentorOffer.expects(:send_mentor_offer_rejected_notification_to_mentor).once.with(offer.id)
    assert_difference 'RecentActivity.count' do
      offer.status = MentorOffer::Status::REJECTED
      offer.response = "Test Response"
      offer.save!
    end
    assert_equal RecentActivityConstants::Type::MENTORING_OFFER_REJECTION, RecentActivity.last.action_type
  end

  def test_after_update_mentor_offer_withdrawn
    Group.any_instance.stubs(:set_member_status)
    offer = create_mentor_offer(:group => groups(:mygroup))

    Push::Base.expects(:queued_notify).never
    MentorOffer.expects(:send_mentor_offer_withdrawn_notification).once.with(offer.id)
    assert_difference 'RecentActivity.count' do
      offer.status = MentorOffer::Status::WITHDRAWN
      offer.save!
    end
    assert_equal RecentActivityConstants::Type::MENTOR_OFFER_WITHDRAWAL, RecentActivity.last.action_type
  end
end
