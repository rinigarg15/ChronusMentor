module ActsAsSummarizable
  extend ActiveSupport::Concern

  class_methods do
    def acts_as_summarizable
      has_one :summary, :foreign_key => 'connection_question_id', :dependent => :destroy
    end
  end

  def set_unset_summary(create_summary=true)
    create_summary ? Summary.create!(connection_question: self) : self.summary.try(:destroy)
  end
end