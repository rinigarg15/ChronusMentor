class LocationObserver < ActiveRecord::Observer
  def before_save(location)
    answers = location.profile_answers
    answers.each do |answer|
      answer.answer_text = location.full_address
      answer.save
    end
    return nil
  end

end