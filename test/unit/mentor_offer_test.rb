require_relative './../test_helper.rb'


class MentorOfferTest < ActiveSupport::TestCase
  TEMP_CSV_FILE = "tmp/test_file_mentor_offer_#{ENV["TEST_ENV_NUMBER"]}.csv"
  def setup
    super
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)
  end

  def test_belongs_to_program
    cache_key = users(:f_mentor).cache_key
    offer = create_mentor_offer(:mentor => users(:f_mentor))
    assert_not_equal cache_key, users(:f_mentor).cache_key
    assert_equal programs(:albers), offer.program
    assert offer.valid?
    offer.program = nil
    assert_false offer.valid?
  end

  def test_can_be_accepted_based_on_mentors_limits
    mentor = users(:f_mentor)
    offer = create_mentor_offer(:mentor => mentor, :group => groups(:mygroup), :max_connection_limit => 2)
    assert_equal MentorOffer::Status::PENDING, offer.status
    assert_equal 2, offer.mentor.max_connections_limit
    assert_equal 1, offer.mentor.max_connections_limit - offer.mentor.students(:active_or_drafted).size
    assert offer.can_be_accepted_based_on_mentors_limits?
    offer.update_attributes!(status: MentorOffer::Status::ACCEPTED)
    offer2 = create_mentor_offer(:mentor => mentor, :group => groups(:mygroup), :student => users(:mkr_student))
    mentor.update_attributes!(max_connections_limit: 1)
    assert_equal 1, offer2.reload.mentor.max_connections_limit
    assert_equal 0, offer2.mentor.max_connections_limit - offer.mentor.students(:active_or_drafted).size
    assert_false offer2.can_be_accepted_based_on_mentors_limits?
  end

  def test_validates_presence_of_status_and_response
    offer = create_mentor_offer(:mentor => users(:f_mentor), :group => groups(:mygroup))
    assert_equal MentorOffer::Status::PENDING, offer.status
    assert offer.response.nil?
    assert offer.valid?

    offer.status = MentorOffer::Status::ACCEPTED
    assert_equal MentorOffer::Status::ACCEPTED, offer.status
    assert offer.response.nil?
    assert offer.valid?

    offer.status = MentorOffer::Status::CLOSED
    assert_equal MentorOffer::Status::CLOSED, offer.status
    assert_false offer.valid?
    offer.closed_at = Time.now
    assert offer.valid?

    offer.status = MentorOffer::Status::REJECTED
    assert_equal MentorOffer::Status::REJECTED, offer.status
    assert offer.response.nil?
    assert_false offer.valid?
    offer.response = "Test response"
    assert_false offer.response.nil?
    assert offer.valid?

    offer.status = 99
    assert_equal 99, offer.status
    assert_false offer.valid?
  end

  def test_named_scopes
    Group.any_instance.stubs(:set_member_status)
    offer = create_mentor_offer(:mentor => users(:f_mentor), :group => groups(:mygroup))
    assert_equal MentorOffer::Status::PENDING, offer.status

    assert_equal [offer], MentorOffer.pending
    assert_blank MentorOffer.accepted
    assert_blank MentorOffer.rejected
    assert_blank MentorOffer.closed
    assert_blank MentorOffer.withdrawn


    offer.status = MentorOffer::Status::ACCEPTED
    offer.save
    assert_equal MentorOffer::Status::ACCEPTED, offer.reload.status

    assert_equal [offer], MentorOffer.accepted
    assert_blank MentorOffer.pending
    assert_blank MentorOffer.rejected
    assert_blank MentorOffer.closed
    assert_blank MentorOffer.withdrawn


    offer.status = MentorOffer::Status::REJECTED
    offer.response = "Test Response"
    offer.save
    assert_equal MentorOffer::Status::REJECTED, offer.reload.status

    assert_equal [offer], MentorOffer.rejected
    assert_blank MentorOffer.pending
    assert_blank MentorOffer.accepted
    assert_blank MentorOffer.closed
    assert_blank MentorOffer.withdrawn


    offer.status = MentorOffer::Status::CLOSED
    offer.response = "Test Response"
    offer.closed_at = Time.now
    offer.save
    assert_equal MentorOffer::Status::CLOSED, offer.reload.status

    assert_equal [offer], MentorOffer.closed
    assert_blank MentorOffer.pending
    assert_blank MentorOffer.accepted
    assert_blank MentorOffer.rejected
    assert_blank MentorOffer.withdrawn

    offer.status = MentorOffer::Status::WITHDRAWN
    offer.save
    assert_equal MentorOffer::Status::WITHDRAWN, offer.reload.status

    assert_equal [offer], MentorOffer.withdrawn
    assert_blank MentorOffer.pending
    assert_blank MentorOffer.accepted
    assert_blank MentorOffer.rejected
    assert_blank MentorOffer.closed
  end

  def test_accepted_rejected_pending
    Group.any_instance.stubs(:set_member_status)
    offer = create_mentor_offer(:mentor => users(:f_mentor), :group => groups(:mygroup))
    assert_equal MentorOffer::Status::PENDING, offer.status

    assert offer.pending?
    assert_false offer.accepted?
    assert_false offer.rejected?

    offer.status = MentorOffer::Status::ACCEPTED
    offer.save
    assert_equal MentorOffer::Status::ACCEPTED, offer.reload.status

    assert_false offer.pending?
    assert offer.accepted?
    assert_false offer.rejected?

    offer.status = MentorOffer::Status::REJECTED
    offer.response = "Test Response"
    offer.save
    assert_equal MentorOffer::Status::REJECTED, offer.reload.status

    assert_false offer.pending?
    assert_false offer.accepted?
    assert offer.rejected?
  end

  def test_mark_accepted_with_group
    Group.any_instance.stubs(:create_ra_and_notify_mentee_about_mentoring_offer)
    offer = create_mentor_offer(:group => groups(:mygroup))
    assert_equal MentorOffer::Status::PENDING, offer.status
    assert_no_difference 'Group.count' do
      offer.mark_accepted!(offer.group)
    end

    assert_equal MentorOffer::Status::ACCEPTED, offer.reload.status
    assert offer.group.students.include?(offer.student)
  end

  def test_mark_accepted_new_group
    offer = create_mentor_offer
    assert_equal MentorOffer::Status::PENDING, offer.status
    assert_difference 'Group.count' do
      offer.mark_accepted!
    end
    assert_equal MentorOffer::Status::ACCEPTED, offer.reload.status
    assert offer.group.students.include?(offer.student)

    assert_no_difference 'Group.count' do
      assert_nothing_raised do
        offer.mark_accepted!
      end
    end
    assert offer.reload.accepted?
  end

  def test_should_not_call_mentor_can_mentor_on_create
    offer1 = create_mentor_offer(:mentor => users(:robert), :max_connection_limit => 3)
    assert_false users(:robert).reload.can_mentor?
    assert_equal MentorOffer::Status::PENDING, offer1.status
    assert_difference 'Group.count' do
      offer1.mark_accepted!
    end

    assert_equal MentorOffer::Status::ACCEPTED, offer1.reload.status
    assert offer1.group.students.include?(offer1.student)
  end

  def test_validation_on_create_when_feature_disabled
    program = programs(:albers)
    program.enable_feature(FeatureName::OFFER_MENTORING, false)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    assert_false program.mentor_offer_enabled?
    assert program.mentor_offer_needs_acceptance?
    offer = MentorOffer.new({
      program: program,
      mentor: users(:f_mentor),
      student: users(:f_student),
      message: "some offer message",
      status: MentorOffer::Status::PENDING
    })
    assert_false offer.valid?
    assert_equal ["does not have the permission to offer_mentoring"], offer.errors[:mentor]
  end

  def test_validation_on_create_when_acceptance_not_needed
    program = programs(:albers)
    program.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attribute(:mentor_offer_needs_acceptance, false)
    assert program.mentor_offer_enabled?
    assert_false program.mentor_offer_needs_acceptance?
    offer = MentorOffer.new({
      program: program,
      mentor: users(:f_mentor),
      student: users(:f_student),
      message: "some offer message",
      status: MentorOffer::Status::PENDING
    })
    assert_false offer.valid?
    assert_equal ["doesn't allow you to offer mentoring"], offer.errors[:program]
  end

  def test_header_for_exporting
    assert_equal ["Sender", "Recipient", "Offer", "Sent"], MentorOffer.header_for_exporting
  end

  def test_data_for_exporting
    mentor_offer = create_mentor_offer(:mentor => users(:f_mentor), :group => groups(:mygroup))
    mentor_offer.message = "Hi"
    mentor_offer.save!

    assert_equal [["Good unique name", "student example", "Hi", DateTime.localize(mentor_offer.created_at, format: :short)]], MentorOffer.data_for_exporting([mentor_offer])
  end

  def test_export_to_stream
    mentor_offer = create_mentor_offer(:mentor => users(:f_mentor), :group => groups(:mygroup))
    mentor_offer.message = "Hi"
    mentor_offer.save!
    body = Enumerator.new do |stream|
      MentorOffer.export_to_stream(stream, users(:f_admin), [mentor_offer.id])
    end
    csv_array = CSV.parse(body.to_a.join)
    assert_equal 2, csv_array.size
    mentor_offer.message = "Hi"
    mentor_offer.save!

    assert_equal ["Good unique name", "student example", "Hi", DateTime.localize(mentor_offer.created_at, format: :short)], csv_array[1]
  end

  def test_send_group_mentoring_offer_notification_to_new_mentee
    mentor_offer = create_mentor_offer

    assert_emails 1 do
      MentorOffer.send_group_mentoring_offer_notification_to_new_mentee(mentor_offer.id)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [users(:f_student).email], email.to
    assert_equal "You have received a new offer for mentoring!", email.subject

    assert_no_emails do
      MentorOffer.send_group_mentoring_offer_notification_to_new_mentee(0)
    end
  end

  def test_mentor_offer_accepted_notification_to_mentor
    mentor_offer = create_mentor_offer(:group => groups(:mygroup))

    assert mentor_offer.pending?
    assert_no_emails do
      MentorOffer.send_mentor_offer_accepted_notification_to_mentor(mentor_offer.id)
    end

    mentor_offer.update_column(:status, MentorOffer::Status::ACCEPTED)

    assert_emails 1 do
      MentorOffer.send_mentor_offer_accepted_notification_to_mentor(mentor_offer.id)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [users(:f_mentor).email], email.to
    assert_equal "#{users(:f_student).name} has accepted to be your student!", email.subject

    assert_no_emails do
      MentorOffer.send_mentor_offer_accepted_notification_to_mentor(0)
    end
  end

  def test_send_mentor_offer_rejected_notification_to_mentor
    mentor_offer = create_mentor_offer(:group => groups(:mygroup))

    assert mentor_offer.pending?
    assert_no_emails do
      MentorOffer.send_mentor_offer_rejected_notification_to_mentor(mentor_offer.id)
    end

    mentor_offer.update_column(:status, MentorOffer::Status::REJECTED)

    assert_emails 1 do
      MentorOffer.send_mentor_offer_rejected_notification_to_mentor(mentor_offer.id)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [users(:f_mentor).email], email.to
    assert_equal "#{users(:f_student).name} has declined your mentoring offer", email.subject

    assert_no_emails do
      MentorOffer.send_mentor_offer_rejected_notification_to_mentor(0)
    end
  end

  def test_send_mentor_offer_withdrawn_notification
    mentor_offer = create_mentor_offer(:group => groups(:mygroup))

    assert mentor_offer.pending?
    assert_no_emails do
      MentorOffer.send_mentor_offer_withdrawn_notification(mentor_offer.id)
    end

    mentor_offer.update_column(:status, MentorOffer::Status::WITHDRAWN)

    assert_emails 1 do
      MentorOffer.send_mentor_offer_withdrawn_notification(mentor_offer.id)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [users(:f_student).email], email.to
    assert_equal "#{users(:f_mentor).name} has withdrawn their offer for mentoring", email.subject

    assert_no_emails do
      MentorOffer.send_mentor_offer_withdrawn_notification(0)
    end
  end

  def test_pending_notifications_should_dependent_destroy_on_mentor_offer_deletion
    group =groups(:mygroup)
    mentor_offer = create_mentor_offer(group: group)
    #Testing has_many association
    pending_notifications = []
    action_types = [RecentActivityConstants::Type::MENTOR_REQUEST_CREATION, RecentActivityConstants::Type::MENTOR_REQUEST_ACCEPTANCE]
    assert_difference "PendingNotification.count", 2 do
      action_types.each do |action_type|
        pending_notifications << mentor_offer.pending_notifications.create!(
                  ref_obj_creator: mentor_offer.mentor,
                  ref_obj: mentor_offer,
                  program: group.program,
                  action_type:  action_type)
      end
    end
    #Testing dependent destroy
    assert_equal pending_notifications, mentor_offer.pending_notifications
    assert_difference 'MentorOffer.count', -1 do
      assert_difference 'PendingNotification.count', -2 do
        mentor_offer.destroy
      end
    end
  end
end
