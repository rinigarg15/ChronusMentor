require_relative './../../../../../../test_helper'

class ConnectionQuestionPopulatorTest < ActiveSupport::TestCase
  def test_add_removeconnection_questions
    org = programs(:org_primary)
    to_add_program_ids = org.programs.pluck(:id).first(5)
    to_remove_program_ids = Connection::Question.pluck(:program_id).uniq.first(5)
    populator_add_and_remove_objects("connection_question", "program", to_add_program_ids,  to_remove_program_ids, {organization: org, model: "connection/question", additional_populator_class_options: {common: {"translation_locales" => ["fr-CA", "en"]}}})
  end
end