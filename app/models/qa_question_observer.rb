class QaQuestionObserver < ActiveRecord::Observer
	def after_create(qa_question)
    # Create an RA for the every one
    create_qa_question_ra(qa_question)
	end

  def create_qa_question_ra(qa_question)
    event = RecentActivityConstants::Type::QA_QUESTION_CREATION
    target = RecentActivityConstants::Target::ALL
    member = qa_question.user.member

    RecentActivity.create!(
      :member => member,
      :ref_obj => qa_question,
      :programs => [qa_question.program],
      :action_type => event,
      :target => target
    )
  end
end