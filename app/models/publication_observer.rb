class PublicationObserver < ActiveRecord::Observer
  def after_save(publication)
    answer = publication.profile_answer
    answer.answer_value = answer.publications.to_a
    answer.save
  end

  def after_destroy(publication)
    answer = publication.profile_answer
    if answer.profile_question.publication?
      answer.answer_value = answer.publications.to_a - [publication]
      answer.save
    end
  end
end