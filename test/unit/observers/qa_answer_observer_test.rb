require_relative './../../test_helper.rb'

class QaAnswerObserverTest < ActiveSupport::TestCase

  def test_sends_mails
    qa_question = create_qa_question(:user => users(:f_student))

    followers = [users(:f_student)]

    [users(:student_1), users(:student_2), users(:mentor_1), users(:mentor_2), users(:mentor_3)].each do |user|
      qa_question.toggle_follow!(user)
      followers << user
    end

    assert_false qa_question.followers.include?(users(:f_mentor))

    followers.each do |user|
      user.update_attribute :program_notification_setting, UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE
    end

    Push::Base.expects(:queued_notify).times(6)
    assert_emails 6 do
      create_qa_answer(:user => users(:f_mentor), :qa_question => qa_question)
    end

    assert_equal_unordered(
      followers.collect(&:email),
      ActionMailer::Base.deliveries.collect(&:to).flatten
    )

    ActionMailer::Base.deliveries.clear
    assert qa_question.followers.include?(users(:f_student))
    Push::Base.expects(:queued_notify).times(5)
    assert_emails 5 do
      create_qa_answer(:user => users(:f_student), :qa_question => qa_question)
    end

    assert_equal_unordered(
      (followers - [users(:f_student)]).collect(&:email),
      ActionMailer::Base.deliveries.collect(&:to).flatten
    )

    fetch_role(:albers, :mentor).remove_permission('view_students')

    followers.collect(&:reload)

    ActionMailer::Base.deliveries.clear
    Push::Base.expects(:queued_notify).times(4)
    assert_emails 4 do
      qa = create_qa_answer(:user => users(:student_3), :qa_question => qa_question)
    end

    #Mail wil be sent to users(:mentor_1) as he is connected to student and hence, can still view him
    assert_equal_unordered(
      (followers - [users(:mentor_2), users(:mentor_3)]).collect(&:email),
      ActionMailer::Base.deliveries.collect(&:to).flatten
    )
  end

  def test_create_ra
    qa_answer = nil
    assert_difference 'RecentActivity.count',1 do
      qa_answer = create_qa_answer(:qa_question => qa_questions(:what), :user => users(:f_admin))
    end
    assert qa_answer
    re = RecentActivity.last
    assert_equal qa_answer, re.ref_obj
    assert_equal RecentActivityConstants::Type::QA_ANSWER_CREATION,re.action_type
    assert_nil re.for
    assert_equal RecentActivityConstants::Target::ALL, re.target
    assert_equal [qa_answer.qa_question.program], re.programs

    assert_difference('RecentActivity.count', -1) do
      qa_answer.destroy
    end
  end

  def test_qa_question_reindex
    qa_answer = qa_answers(:for_question_what)
    DelayedEsDocument.expects(:delayed_index_es_document).never
    qa_answer.update_attribute(:score, 5)

    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(QaQuestion, [1])
    qa_answer.update_attribute(:content, "Content Changed")

    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(QaQuestion, [1])
    qa_answer.destroy
  end
end
