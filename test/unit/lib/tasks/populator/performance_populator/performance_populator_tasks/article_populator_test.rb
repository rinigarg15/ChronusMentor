require_relative './../../../../../../test_helper'

class ArticlePopulatorTest < ActiveSupport::TestCase

  def test_add_remove_articles
    organization = programs(:org_primary)
    all_author_ids = organization.articles.pluck(:author_id).uniq
    to_add_member_ids = organization.members.active.pluck(:id) - all_author_ids
    to_remove_member_ids = all_author_ids.first(5)
    populator_add_and_remove_objects("article", "member", to_add_member_ids, to_remove_member_ids, organization: organization, program: programs(:albers))
  end
end