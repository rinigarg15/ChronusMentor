require_relative './../test_helper.rb'

class MentorRecommendationTest < ActiveSupport::TestCase

  def test_has_many_recommendation_preferences
    mentor_recommendation = mentor_recommendations(:mentor_recommendation_1)
    expected_recommendation_preferences = []
    expected_recommendation_preferences << recommendation_preferences(:recommendation_preference_1)
    expected_recommendation_preferences << recommendation_preferences(:recommendation_preference_2)
    assert_equal_unordered expected_recommendation_preferences, mentor_recommendation.recommendation_preferences 
  end

  def test_recommendation_preferences_depended_destroy
    mentor_recommendation = mentor_recommendations(:mentor_recommendation_1)
    recommendation_preference1 =  recommendation_preferences(:recommendation_preference_1)
    recommendation_preference2 = recommendation_preferences(:recommendation_preference_2)
    assert recommendation_preference1.valid?
    assert recommendation_preference2.valid?
    mentor_recommendation.destroy
    assert_raise(ActiveRecord::RecordNotFound) do
      recommendation_preference1.reload
    end
    assert_raise(ActiveRecord::RecordNotFound) do
      recommendation_preference2.reload
    end
  end

  def test_mentor_recommendation_validates_sender_reciever
    # initial config
    recommendation = MentorRecommendation.new
    program = programs(:albers)
    mentor = users(:f_mentor)
    student = users(:f_student)
    admin = users(:f_admin)
    ram = users(:ram)

    # saving the recommendation
    recommendation.program = program
    assert_false recommendation.valid?
    assert_equal_unordered ["Sender can't be blank", "Receiver can't be blank", "Status can't be blank", "Status is not included in the list"], recommendation.errors.full_messages 
    recommendation.sender = admin
    recommendation.receiver = ram
    recommendation.status = MentorRecommendation::Status::DRAFTED
    assert recommendation.save!
  end

  def test_mentor_recommendation_belongs_to_sender
    mentor_recommendation = mentor_recommendations(:mentor_recommendation_1)
    assert_equal users(:f_admin), mentor_recommendation.sender
  end

  def test_mentor_recommendation_belongs_to_receiver
    mentor_recommendation = mentor_recommendations(:mentor_recommendation_1)
    assert_equal users(:rahim), mentor_recommendation.receiver
  end

  def test_program_has_many_recommendations
    # initial config
    program = programs(:albers)
    recommendation = mentor_recommendations(:mentor_recommendation_1)
    assert_equal program, recommendation.program
  end

  def test_recommended_users
    mentor_recommendation = mentor_recommendations(:mentor_recommendation_1)
    assert_equal_unordered [users(:ram), users(:robert)], mentor_recommendation.recommended_users
  end

  def test_preferred_users_ordered_on_position
    rahim = users(:rahim)
    ram = users(:ram)
    robert = users(:robert)
    recommendation_preference1 = recommendation_preferences(:recommendation_preference_1)
    assert_equal [ram, robert], rahim.mentor_recommendation.recommended_users
    recommendation_preference1.position = 3
    recommendation_preference1.save!
    assert_equal [robert, ram], rahim.mentor_recommendation.reload.recommended_users
  end

  def test_valid_recommendation_preferences
    mentor_recommendation = mentor_recommendations(:mentor_recommendation_1)
    valid_recommendation_preferences = mentor_recommendation.valid_recommendation_preferences
    recommendation_preference_1 = recommendation_preferences(:recommendation_preference_1)
    recommendation_preference_2 = recommendation_preferences(:recommendation_preference_2)
    assert_equal_unordered valid_recommendation_preferences, [recommendation_preference_1, recommendation_preference_2]

    mentor = users(:ram)
    student = users(:rahim)
    group = create_group(:students => [student], :mentor => mentor, :program => programs(:albers))
    valid_recommendation_preferences = mentor_recommendation.valid_recommendation_preferences
    assert_equal_unordered valid_recommendation_preferences, [recommendation_preference_2]

    mentor = users(:robert)

    mentor_request = create_mentor_request(:student => student, :program => programs(:albers), :mentor => mentor)
    valid_recommendation_preferences = mentor_recommendation.valid_recommendation_preferences
    assert_equal_unordered valid_recommendation_preferences, []

    mentor_request.close_request!
    valid_recommendation_preferences = mentor_recommendation.valid_recommendation_preferences
    assert_equal_unordered valid_recommendation_preferences, [recommendation_preference_2]

    group.terminate!(users(:f_admin),"Test reason", group.program.permitted_closure_reasons.first.id)
    valid_recommendation_preferences = mentor_recommendation.valid_recommendation_preferences
    assert_equal_unordered valid_recommendation_preferences, [recommendation_preference_1, recommendation_preference_2]
  end

  def test_published_and_drafted
    recommendation = mentor_recommendations(:mentor_recommendation_1)
    assert recommendation.published?
    recommendation.status = MentorRecommendation::Status::DRAFTED
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, recommendation.recommendation_preferences.map(&:user_id)).once
    recommendation.save!
    assert recommendation.drafted?
    assert_false recommendation.published?
    recommendation.status = MentorRecommendation::Status::PUBLISHED
    assert recommendation.published?
    assert_false recommendation.drafted?
  end

  def test_is_drafted_mentor_recommendation_for
    recommendation = mentor_recommendations(:mentor_recommendation_1)
    user_ids = recommendation.recommendation_preferences.collect(&:user_id)
    assert_false recommendation.is_drafted_mentor_recommendation_for?(user_ids)
    recommendation.update_attributes!(status: MentorRecommendation::Status::DRAFTED)
    assert recommendation.is_drafted_mentor_recommendation_for?(user_ids)
    recommendation.recommendation_preferences.where(user_id: user_ids.last).first.destroy
    assert_false recommendation.reload.is_drafted_mentor_recommendation_for?(user_ids)
    assert recommendation.is_drafted_mentor_recommendation_for?([user_ids.first])
  end

  def test_recommendation_preferences_ordered_on_position
    recommendation_preference1 = recommendation_preferences(:recommendation_preference_1)
    recommendation_preference2 = recommendation_preferences(:recommendation_preference_2)
    rahim = users(:rahim)
    assert_equal [recommendation_preference1, recommendation_preference2], rahim.mentor_recommendation.recommendation_preferences
    recommendation_preference1.position = 2
    recommendation_preference2.position = 1
    recommendation_preference1.save!
    recommendation_preference2.save!
    assert_equal [recommendation_preference2, recommendation_preference1], rahim.reload.mentor_recommendation.recommendation_preferences
  end

  def test_mentor_recommendation_validations
    recommendation = mentor_recommendations(:mentor_recommendation_1)
    program = recommendation.program
    recommendation_2 = program.mentor_recommendations.new(receiver_id: recommendation.receiver_id)
    assert_false recommendation_2.valid?
    assert_equal ["has already been taken"], recommendation_2.errors[:receiver_id]
  end

  def test_recommendations_hash
    mentor_recommendation = mentor_recommendations(:mentor_recommendation_1)
    rahim = users(:rahim)
    ram = users(:ram)
    robert = users(:robert)
    expected_hash = {
      ram.id => true,
      robert.id => true
    }
    assert_equal expected_hash, mentor_recommendation.recommendations_hash
  end

  def test_publish
    recommendation = mentor_recommendations(:mentor_recommendation_1)
    recommendation.program.enable_feature(FeatureName::MENTOR_RECOMMENDATION)
    assert recommendation.published?
    recommendation.status = MentorRecommendation::Status::DRAFTED
    recommendation.save!
    assert_false recommendation.published?
    PushNotifier.expects(:push).once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, recommendation.recommendation_preferences.map(&:user_id)).once
    Timecop.freeze(Time.now) do
      recommendation.publish!
      assert recommendation.published?
      assert_equal Time.now.utc.to_s(:db), recommendation.published_at.utc.to_s(:db)
    end
  end

  def test_set_published_at
    options = {
      program: programs(:albers),
      admin: users(:f_admin),
      receiver: users(:f_student),
      mentor1: users(:ram),
      status: MentorRecommendation::Status::PUBLISHED
    }
    Timecop.freeze(Time.now) do
      m = setup_mentor_recommendation(options)
      assert_equal Time.now.utc.to_s(:db), m.published_at.utc.to_s(:db)
    end
  end

  def test_email_after_publish
    options = {
      program: programs(:albers),
      admin: users(:f_admin),
      receiver: users(:f_student),
      mentor1: users(:ram),
      status: MentorRecommendation::Status::DRAFTED
    }
    m = setup_mentor_recommendation(options)
    m.publish!
    
    email = ActionMailer::Base.deliveries.last
    assert_equal "Recommended Mentors for you", email['subject'].to_s
  end

  def test_recommendation_email_without_preference
    options = {
      status: MentorRecommendation::Status::DRAFTED
    }
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      m = setup_mentor_recommendation(options)
      m.publish!
      email = ActionMailer::Base.deliveries.last
    end
  end

  def test_recommendation_email_already_published_recommendation
    options = {
      status: MentorRecommendation::Status::PUBLISHED,
      mentor1: users(:f_mentor)
    }
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      m = setup_mentor_recommendation(options)
      m.publish!
      email = ActionMailer::Base.deliveries.last
    end
  end

  def test_send_bulk_publish_mails
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTOR_RECOMMENDATION)
    recommendation = mentor_recommendations(:mentor_recommendation_1)
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      MentorRecommendation.send_bulk_publish_mails(program.id, [])
    end

    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      PushNotifier.expects(:push).once
      MentorRecommendation.send_bulk_publish_mails(program.id, [recommendation.receiver_id])
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal "Recommended Mentors for you", email['subject'].to_s
    assert_equal [recommendation.receiver.email], email.to
    
    recommendation.recommendation_preferences.destroy_all
    assert_difference 'ActionMailer::Base.deliveries.size', 0 do
      MentorRecommendation.send_bulk_publish_mails(program.id, [recommendation.receiver_id])
    end
  end

  def test_send_bulk_publish_mails_without_receiver
    program = programs(:albers)
    recommendation = mentor_recommendations(:mentor_recommendation_1)
    receiver_id = recommendation.receiver_id
    recommendation.receiver.destroy
    assert_difference 'ActionMailer::Base.deliveries.size', 0 do
      MentorRecommendation.send_bulk_publish_mails(program.id, [receiver_id])
    end
  end

  private

  def setup_mentor_recommendation(options)
    options[:program] ||= programs(:albers)
    options[:status] ||= MentorRecommendation::Status::PUBLISHED
    options[:sender] ||= users(:f_admin)
    options[:receiver] ||= users(:f_student)
    #creating recommendation
    m = MentorRecommendation.new
    m.program = options[:program]
    m.sender = options[:sender]
    m.receiver = options[:receiver]
    m.status = options[:status]
    #creating recommendation preferences
    m.recommendation_preferences.build(position: 1, preferred_user: options[:mentor1]) if options[:mentor1].present?    
    m.save!
    return m
   end

end