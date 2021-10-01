require_relative './../test_helper.rb'

class ResourcePublicationTest < ActiveSupport::TestCase
  def test_validations
    resource_publication = ResourcePublication.new
    assert_false resource_publication.valid?
    assert_equal ["can't be blank"], resource_publication.errors[:program]
    assert_equal ["can't be blank"], resource_publication.errors[:position]
    assert_equal ["can't be blank"], resource_publication.errors[:resource]

    resource = create_resource
    resource_publication = ResourcePublication.new(program: programs(:albers), position: 1, resource: resource)
    assert resource_publication.valid?

    assert_equal programs(:albers), resource_publication.program
    assert_equal resource, resource_publication.resource
  end

  def test_position
    program = programs(:albers)
    resource = create_resource(title: "Cercei Lannister", content: "Jaime Lannister")
    resource_publication = program.resource_publications.create!(resource: resource, show_in_quick_links: true)
    assert_equal 7, resource_publication.position
    assert resource_publication.show_in_quick_links
    assert_equal resource, resource_publication.resource

    resource = create_resource(title: "Claire Underwood", content: "Frank Underwood")
    resource_publication = program.resource_publications.create!(resource: resource, show_in_quick_links: false)
    assert_equal 8, resource_publication.position
    assert_false resource_publication.show_in_quick_links?
    assert_equal resource, resource_publication.resource

    resource = create_resource(title: "Skyler White", content: "Walter White")
    resource_publication = program.resource_publications.create!(resource: resource, position: 5, show_in_quick_links: true)
    assert_equal 5, resource_publication.position
    assert resource_publication.show_in_quick_links?
    assert_equal resource, resource_publication.resource

    resource = create_resource(title: "Betty Draper", content: "Don Draper")
    resource_publication = program.resource_publications.create!(resource: resource, show_in_quick_links: false)
    assert_equal 9, resource_publication.position
    assert_false resource_publication.show_in_quick_links?
    assert_equal resource, resource_publication.resource
  end

  def test_roles_association
    program = programs(:albers)
    resource = create_resource(title: "Cercei Lannister", content: "Jaime Lannister")
    resource_publication = program.resource_publications.create!(resource: resource)
    assert_empty resource.roles
    mentor_role = program.get_role(RoleConstants::MENTOR_NAME)
    resource_publication.role_resources.create!(role: program.get_role(RoleConstants::MENTOR_NAME))
    assert_equal [mentor_role], resource.reload.roles
  end

  def test_admin_view_association
    program = programs(:albers)
    admin_view = program.admin_views.first
    resource = create_resource(title: "Cercei Lannister", content: "Jaime Lannister")
    resource_publication = program.resource_publications.create!(resource: resource)
    resource_publication.update_attributes(admin_view_id: admin_view.id)
    resource_publication.reload
    assert_equal admin_view, resource_publication.admin_view
    admin_view.destroy
    resource_publication.reload
    assert_nil resource_publication.admin_view
  end
end
