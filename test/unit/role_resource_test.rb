require_relative './../test_helper.rb'

class RoleResourceTest < ActiveSupport::TestCase

  def test_valdiations_creation
    roleres = RoleResource.new()

    assert_false roleres.valid?

    assert_equal ["can't be blank"], roleres.errors[:role]
    assert_equal ["can't be blank"], roleres.errors[:resource_publication]

    res = Resource.create!(:organization => programs(:org_primary), :title => "test", :content => "Content")
    mentor_role = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
    resource_publication = create_resource_publication(resource: res)

    assert_difference "RoleResource.count" do
      RoleResource.create!(:role => mentor_role, resource_publication: resource_publication)
    end

    roleres = RoleResource.last
    assert_equal mentor_role, roleres.role
    assert_equal resource_publication, roleres.resource_publication
    assert_equal res, roleres.resource_publication.resource

    newroleres = RoleResource.new(:resource_publication => resource_publication, :role => mentor_role)
    assert_false newroleres.valid?
    assert_equal ["has already been taken"], newroleres.errors[:role_id]
  end
end
