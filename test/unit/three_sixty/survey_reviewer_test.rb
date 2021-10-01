require_relative './../../test_helper.rb'

class ThreeSixty::SurveyReviewerTest < ActiveSupport::TestCase
  def test_belongs_to_survey_assessee
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_1), three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1).survey_assessee
  end

  def test_belongs_to_survey_reviewer_group
    assert_equal three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_1), three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1).survey_reviewer_group
  end

  def test_belongs_to_inviter
    assert_equal members(:f_admin), three_sixty_survey_reviewers(:survey_reviewer_2).inviter
  end

  def test_has_many_answers
    assert_equal 2, three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1).answers.size
    assert_difference "ThreeSixty::SurveyAnswer.count", -2 do
      three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1).destroy
    end
  end

  def test_presence_of_survey_reviewer_group
    survey_reviewer = ThreeSixty::SurveyReviewer.new(:survey_assessee => three_sixty_survey_assessees(:three_sixty_survey_assessees_5), :name => 'some text', :email => "someemail@example.com")
    survey_reviewer.save
    assert_equal ["can't be blank"], survey_reviewer.errors[:three_sixty_survey_reviewer_group_id]
    assert_equal ["survey reviewer group being selected should belong to the same survey as survey assessee"], survey_reviewer.errors[:survey_reviewer_group]
  end

  def test_presence_of_survey_assessee
    survey_reviewer = ThreeSixty::SurveyReviewer.new(:survey_reviewer_group => three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_1), :name => 'some text', :email => "someemail@example.com")
    assert_raise Module::DelegationError do
      survey_reviewer.save
    end
  end

  def test_presence_of_name
    survey_reviewer = ThreeSixty::SurveyReviewer.new(:survey_reviewer_group => three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_1), :survey_assessee => three_sixty_survey_assessees(:three_sixty_survey_assessees_5), :email => "someemail@example.com")
    survey_reviewer.save
    assert_equal ["can't be blank"], survey_reviewer.errors[:name] 
  end

  def test_presence_of_invitation_code
    reviewer = three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1)
    reviewer.update_attributes(:invitation_code => nil)
    assert_equal ["can't be blank"], reviewer.errors[:invitation_code]
  end

  def test_presence_of_email
    survey_reviewer = ThreeSixty::SurveyReviewer.new(:survey_reviewer_group => three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_1), :survey_assessee => three_sixty_survey_assessees(:three_sixty_survey_assessees_5), :name => 'some text')
    survey_reviewer.save
    assert_equal ["can't be blank", "is not a valid email address."], survey_reviewer.errors[:email] 
  end

  def test_uniqueness_of_email
    survey_reviewer = ThreeSixty::SurveyReviewer.new(:survey_reviewer_group => three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_1), :survey_assessee => three_sixty_survey_assessees(:three_sixty_survey_assessees_1), :name => 'some text', :email => "reviewer_1@example.com")
    survey_reviewer.save
    assert_equal ["has already been added"], survey_reviewer.errors[:email]
  end

  def test_survey_reviewer_group_and_assessee_belong_to_same_survey
    survey_reviewer = ThreeSixty::SurveyReviewer.new(:survey_assessee => three_sixty_surveys(:survey_1).survey_assessees.first, :name => 'some text', :email => "someemail@example.com", :survey_reviewer_group => three_sixty_surveys(:survey_2).survey_reviewer_groups.first)
    survey_reviewer.save
    assert_equal ["survey reviewer group being selected should belong to the same survey as survey assessee"], survey_reviewer.errors[:survey_reviewer_group]
  end

  def test_set_invitation_code
    reviewer = ThreeSixty::SurveyReviewer.new(:survey_reviewer_group => three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_1), :survey_assessee => three_sixty_survey_assessees(:three_sixty_survey_assessees_5), :name => 'some text', :email => "someemail@example.com")
    reviewer.valid?
    assert reviewer.invitation_code.present?
  end

  def test_survey
    assert_equal three_sixty_surveys(:survey_1), three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1).survey
  end

  def test_reviewer_group
    assert_equal three_sixty_reviewer_groups(:three_sixty_reviewer_groups_1), three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1).reviewer_group
  end

  def test_is_invited_by
    assert_false three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1).is_invited_by?(members(:f_admin))
    assert three_sixty_survey_reviewers(:survey_reviewer_9).is_invited_by?(members(:f_student))
  end

  def test_scope_except_self
    assert_equal 4, three_sixty_survey_assessees(:three_sixty_survey_assessees_1).reviewers.except_self.count
    three_sixty_survey_assessees(:three_sixty_survey_assessees_1).reviewers.except_self.each do |reviewer|
      assert_false reviewer.for_self?
    end
  end

  def test_scope_for_self
    assert_equal 1, three_sixty_survey_assessees(:three_sixty_survey_assessees_1).reviewers.for_self.count
    assert three_sixty_survey_assessees(:three_sixty_survey_assessees_1).reviewers.for_self.first.for_self?
  end

  def test_scope_invited
    assert_equal 0, three_sixty_survey_assessees(:three_sixty_survey_assessees_1).reviewers.invited.count
    survey_reviewer = three_sixty_survey_assessees(:three_sixty_survey_assessees_1).reviewers.first
    survey_reviewer.update_attribute(:invite_sent, true)

    assert_equal 1, three_sixty_survey_assessees(:three_sixty_survey_assessees_1).reload.reviewers.invited.count
  end

  def test_scope_with_pending_invites
    assert_equal 5, three_sixty_survey_assessees(:three_sixty_survey_assessees_1).reviewers.with_pending_invites.count
    survey_reviewer = three_sixty_survey_assessees(:three_sixty_survey_assessees_1).reviewers.first
    survey_reviewer.update_attribute(:invite_sent, true)

    assert_equal 4, three_sixty_survey_assessees(:three_sixty_survey_assessees_1).reload.reviewers.with_pending_invites.count
    assert_false three_sixty_survey_assessees(:three_sixty_survey_assessees_1).reload.reviewers.with_pending_invites.include?(survey_reviewer)
  end

  def test_for_self
    reviewer = three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1)
    assert reviewer.for_self?
    assert reviewer.reviewer_group.is_for_self?
  end

  def test_notify
    reviewer = three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1)
    assert_false reviewer.invite_sent?
    assert_emails 1 do
      reviewer.notify
    end
    assert reviewer.reload.invite_sent?

    assert_no_emails do
      reviewer.notify
    end
  end

  def test_answered
    assert three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1).answered?
    three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1).answers.destroy_all
    assert_false three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1).reload.answered?
  end

  def test_group_name
    assert_equal "Self", three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1).group_name
    assert_equal "Line Manager", three_sixty_survey_reviewers(:survey_reviewer_2).group_name
  end
end