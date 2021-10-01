class EducationObserver < ActiveRecord::Observer
  def after_save(education)
    answer = education.profile_answer
    answer.answer_value = answer.educations.to_a
    answer.save
  end

  def after_destroy(education)
    answer = education.profile_answer
    if answer.profile_question.education?
      answer.answer_value = answer.educations.to_a - [education]
      answer.save
    end
  end
end