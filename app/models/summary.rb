class Summary < ActiveRecord::Base
  belongs_to :connection_question,
           :class_name => "Connection::Question",
           :foreign_key => 'connection_question_id'

  validates_presence_of :connection_question
end
