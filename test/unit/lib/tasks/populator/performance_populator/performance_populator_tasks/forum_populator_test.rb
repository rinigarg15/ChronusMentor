require_relative './../../../../../../test_helper'

class ForumPoulatorTest < ActiveSupport::TestCase
  def test_add_remove_forums
    org = programs(:org_primary)
    to_add_program_ids = org.programs.pluck(:id).uniq.first(5)
    to_remove_program_ids = Forum.pluck(:program_id).uniq.last(5)
    populator_add_and_remove_objects("forum", "program", to_add_program_ids, to_remove_program_ids, {organization: org})
  end

  def test_add_remove_forums_for_portal
    org = programs(:org_nch)
    to_add_program_ids = org.programs.pluck(:id).uniq.first(5)
    to_remove_program_ids = Forum.pluck(:program_id).uniq.last(5)
    populator_add_and_remove_objects("forum", "program", to_add_program_ids, to_remove_program_ids, {organization: org})
  end
end