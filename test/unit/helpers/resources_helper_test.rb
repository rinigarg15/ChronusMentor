require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/resources_helper"

class ResourcesHelperTest < ActionView::TestCase
  def test_get_shared_programs_text
    resource = create_resource
    create_resource_publication(resource: resource, program: programs(:pbe))
    set_response_text(get_shared_programs_text(resource.reload))
    assert_select "span.label", count: 1
    assert_select "span", text: "Shared with", count: 1
    assert_select "span.label", text: "Project Based Engagement", count: 1

    create_resource_publication(resource: resource, program: programs(:albers))
    set_response_text(get_shared_programs_text(resource.reload))
    assert_select "span.label", count: 2
    assert_select "span", text: "Shared with", count: 1
    assert_select "span.label", text: "Albers Mentor Program", count: 1
    assert_select "span.label", text: "Project Based Engagement", count: 1

    create_resource_publication(resource: resource, program: programs(:nwen))
    set_response_text(get_shared_programs_text(resource.reload))
    assert_select "span.label", count: 3
    assert_select "span", text: "Shared with", count: 1
    assert_select "span.label", text: "Albers Mentor Program", count: 1
    assert_select "span.label", text: "Project Based Engagement", count: 1
    assert_select "span.label", text: "NWEN", count: 1

    create_resource_publication(resource: resource, program: programs(:moderated_program))
    set_response_text(get_shared_programs_text(resource.reload))
    assert_select "span.label", count: 4
    assert_select "span", text: "Shared with", count: 1
    assert_select "span.label", text: "Albers Mentor Program", count: 1
    assert_select "span.label", text: "NWEN", count: 1
    assert_select "span.label", text: "Moderated Program", count: 1
    assert_select "span.label", text: "Project Based Engagement", count: 1
    assert_select "a.label", text: "+ 2 other programs", count: 1
  end

  def test_generate_role_names
    assert_match /span class=\"label.*\">Mentor<\/span><span class=\"label.*\">Mentee/, generate_role_names({"admin"=>"Administrator", "mentor"=>"Mentor", "student"=>"Mentee"}, ["mentor", "student"])
    assert_match /span class=\"label.*\">Mentor<\/span>/, generate_role_names({"admin"=>"Administrator", "mentor"=>"Mentor", "student"=>"Mentee"}, ["mentor"])
    assert_match /span class=\"label.*\">Administrator<\/span><span class=\"label.*\">Mentor<\/span><span class=\"label.*\">Mentee<\/span>/, generate_role_names({"admin"=>"Administrator", "mentor"=>"Mentor", "student"=>"Mentee"}, ["admin", "mentor", "student"])
  end

  def test_can_access_resource
    @current_organization = programs(:org_foster)

    m1 = programs(:foster).get_role(RoleConstants::MENTOR_NAME).id
    s1 = programs(:foster).get_role(RoleConstants::STUDENT_NAME).id

    r2 = create_resource(:organization => programs(:org_foster), :programs => {programs(:foster) => [m1, s1]})
    assert_false can_access_resource?(r2)
  end

  def test_get_button_rating_class
    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    s1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME).id
    resource = create_resource(:programs => {programs(:albers)=> [m1, s1]})
    rating_type = Resource::RatingType::HELPFUL
    assert_equal "btn-white", get_button_rating_class(resource, rating_type, members(:f_mentor))
    
    rating = Rating.new(:rating => Resource::RatingType::HELPFUL, :member => members(:f_mentor))
    resource.ratings << rating
    assert_equal "btn-success", get_button_rating_class(resource, rating_type, members(:f_mentor))
    
    rating_type = Resource::RatingType::UNHELPFUL
    assert_equal "btn-white", get_button_rating_class(resource, rating_type, members(:f_mentor))

    resource.remove_rating(members(:f_mentor))
    resource = resource.reload

    rating = Rating.new(:rating => Resource::RatingType::UNHELPFUL, :member => members(:f_mentor))
    resource.ratings << rating
    assert_equal "btn-success", get_button_rating_class(resource, rating_type, members(:f_mentor))
  end

  private

  def _program
    "program"
  end

  def _programs
    "programs"
  end
end