require_relative './../../../../test_helper'

class Program::Dashboard::CommunityResourcesReportTest < ActiveSupport::TestCase

  def test_community_resource_report_enabled
    program = programs(:albers)
    assert program.community_resource_report_enabled?

    program.stubs(:is_report_enabled?).with(DashboardReportSubSection::Type::CommunityResources::RESOURCES).returns(false)
    assert_false program.community_resource_report_enabled?
  end

  def test_get_resources_data
    program = programs(:albers)
    assert_equal_hash({resource_views: [{:resource=>Resource.find_by(title: "Working with the Mentoring Connection Plan"), :view_count=>0}, {:resource=> Resource.find_by(title: "How to Use Your Connection Plan"), :view_count=>0}, {:resource=>Resource.find_by(title: "Guide to Timely and Efficient Goal Setting"), :view_count=>0}], resouce_helpful_count: [{:resource=>Resource.find_by(title: "Mentee Handbook"), :helpful_count=>0}, {:resource=>Resource.find_by(title: "Mentor Handbook"), :helpful_count=>0}, {:resource=>Resource.find_by(title: "How to Get Matched"), :helpful_count=>0}]}, program.send(:get_resources_data))
  end

  def test_get_resources_viewed_data
    program = programs(:albers)
    resource_ids = program.resource_publications.pluck(:resource_id)
    resources = Resource.where(id: resource_ids)
    assert_equal 6, resources.count
    Resource.find_by(title: "Working with the Mentoring Connection Plan").hit!
    assert_equal [{:resource=>Resource.find_by(title: "Working with the Mentoring Connection Plan"), :view_count=>1}, {:resource=> Resource.find_by(title: "How to Use Your Connection Plan"), :view_count=>0}, {:resource=>Resource.find_by(title: "Guide to Timely and Efficient Goal Setting"), :view_count=>0}], program.send(:get_resources_viewed_data)

    Resource.all.destroy_all
    assert_equal 0, Resource.all.count
    assert_equal [], program.send(:get_resources_viewed_data)
  end

  def test_get_resource_and_rating_count_hash
    program = programs(:albers)
    assert_equal_hash({Resource.find_by(title: "Mentee Handbook")=>0, Resource.find_by(title: "Mentor Handbook")=>0, Resource.find_by(title: "How to Get Matched")=>0}, program.send(:get_resource_and_rating_count_hash))

    Resource.destroy_all
    assert_equal 0, Resource.all.reload.count
    assert_equal 0, program.send(:get_resources).reload.count
    assert_equal_hash({}, program.send(:get_resource_and_rating_count_hash))
  end

  def test_get_resources_marked_helpful_data
    program = programs(:albers)
    resource_ids = program.resource_publications.pluck(:resource_id)
    resources = Resource.where(id: resource_ids)
    assert_equal 6, resources.count
    resource = Resource.find_by(title: "Mentee Handbook")
    rating = Rating.new(:rating => Resource::RatingType::HELPFUL, :member => members(:f_mentor))
    resource.ratings << rating
    assert_equal [{:resource=>Resource.find_by(title: "Mentee Handbook"), :helpful_count=>1}, {:resource=>Resource.find_by(title: "Mentor Handbook"), :helpful_count=>0}, {:resource=>Resource.find_by(title: "How to Get Matched"), :helpful_count=>0}], program.send(:get_resources_marked_helpful_data)

    Resource.all.destroy_all
    assert_equal 0, Resource.all.count
    assert_equal 0, program.send(:get_resources).reload.count
    assert_equal [], program.send(:get_resources_marked_helpful_data)
  end

  def test_get_resources
    program = programs(:albers)
    program.expects(:compute_resources).once
    program.send(:get_resources)
  end

  def test_compute_resources
    resource_ids = programs(:org_primary).resource_ids
    assert_equal resource_ids, programs(:albers).send(:compute_resources).pluck(:id)
  end
end