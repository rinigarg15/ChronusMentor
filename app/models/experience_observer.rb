class ExperienceObserver < ActiveRecord::Observer
  def after_save(experience)
    answer = experience.profile_answer
    answer.answer_value = answer.experiences.to_a
    answer.save
  end

  def after_destroy(experience)
    answer = experience.profile_answer
    if answer.profile_question.experience?
      answer.answer_value = answer.experiences.to_a - [experience]
      answer.save
    end
  end
end