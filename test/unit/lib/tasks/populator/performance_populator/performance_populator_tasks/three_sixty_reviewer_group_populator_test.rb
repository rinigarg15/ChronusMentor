require_relative './../../../../../../test_helper'

class ThreeSixtyReviewerGroupPopulatorTest < ActiveSupport::TestCase
  def test_add_three_sixty_reviewer_groups
    to_add_organization_ids = Organization.pluck(:id).first(5)
    to_remove_organization_ids = ThreeSixty::ReviewerGroup.pluck(:organization_id).uniq.first(5)
    populator_add_and_remove_objects("three_sixty_reviewer_group", "organization", to_add_organization_ids, to_remove_organization_ids, {model: "three_sixty/reviewer_group" })
  end
end