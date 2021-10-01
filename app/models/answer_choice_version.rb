class AnswerChoiceVersion < PaperTrail::Version
  self.table_name = :answer_choice_versions

  module Event
    CREATE = "create"
    UPDATE = "update"
    DESTROY = "destroy"
  end

  belongs_to :member
  belongs_to :question_choice
end