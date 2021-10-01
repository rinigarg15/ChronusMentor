class QaAnswerObserver < ActiveRecord::Observer
  def after_create(qa_answer)
    send_notification_to_followers(qa_answer)
    create_ra(qa_answer)
  end

  def after_save(qa_answer)
    if qa_answer.saved_change_to_content?
      QaAnswer.es_reindex(qa_answer)
    end
  end

  def after_destroy(qa_answer)
    QaAnswer.es_reindex(qa_answer)
  end

  protected

  def send_notification_to_followers(qa_answer)
    notification_list = qa_answer.qa_question.followers
    notification_list.delete(qa_answer.user)
    notification_list.each do |follower|
      # Notify only those to whom the answerer is visible.
      next unless qa_answer.user.visible_to?(follower)
      Push::Base.queued_notify(PushNotification::Type::QA_ANSWER_CREATED, qa_answer, {user_id: follower.id})
      follower.send_email(qa_answer, RecentActivityConstants::Type::QA_ANSWER_CREATION)
    end
  end

  def create_ra(qa_answer)
    event = RecentActivityConstants::Type::QA_ANSWER_CREATION
    target = RecentActivityConstants::Target::ALL
    member = qa_answer.user.member
    program = qa_answer.qa_question.program

    RecentActivity.create!(
      :member => member,
      :ref_obj => qa_answer,
      :programs => [program],
      :action_type => event,
      :target => target
    )
  end
end
