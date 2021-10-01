require_relative './../test_helper.rb'

class ResourceTest < ActiveSupport::TestCase

  def test_valdiations
    res = Resource.new()

    assert_false res.valid?

    assert_equal ["can't be blank"], res.errors[:program_id]
    assert_equal ["can't be blank"], res.errors[:content]
    assert_equal ["can't be blank"], res.errors[:title]
  end

  def test_default
    Resource.default.delete_all
    assert_blank Resource.default.all

    res = Resource.create!(:organization => programs(:org_primary), :title => "test", :content => "Content", :default => true)
    assert_equal [res], Resource.default.all
  end

  def test_non_default
    Resource.non_default.delete_all
    assert_blank Resource.non_default.all

    res = Resource.create!(:organization => programs(:org_primary), :title => "test", :content => "content", :default => false)
    assert_equal [res], Resource.non_default.all
  end
  
  def test_creation
    assert_difference "Resource.count" do
      Resource.create!(:organization => programs(:org_primary), :title => "test", :content => "Content")
    end
    
    res = Resource.last
    assert_equal "test", res.title
    assert_equal "Content", res.content
    assert_equal programs(:org_primary), res.organization
  end

  def test_belongs_to_program_or_organization
    organization_resource = nil
    program_resource = nil

    assert_difference "Resource.count" do
      organization_resource = Resource.create!(:organization => programs(:org_primary), :title => "test", :content => "Content")
    end

    assert_difference "Resource.count" do
      program_resource = Resource.create!(:organization => programs(:albers), :title => "test", :content => "Content")
    end

    assert_equal programs(:org_primary), organization_resource.organization
    assert_equal programs(:albers), program_resource.organization
  end

  def test_has_many_resource_publications
    resource = create_resource
    resource_publications = []
    resource_publications << create_resource_publication(resource: resource)
    resource_publications << create_resource_publication(resource: resource)

    assert_equal resource_publications, resource.resource_publications

    assert_difference "ResourcePublication.count", -2 do
      resource.destroy
    end
  end

  def test_is_organization
    organization_resource = nil
    program_resource = nil

    assert_difference "Resource.count" do
      organization_resource = Resource.create!(:organization => programs(:org_primary), :title => "test", :content => "Content")
    end

    assert_difference "Resource.count" do
      program_resource = Resource.create!(:organization => programs(:albers), :title => "test", :content => "Content")
    end

    assert organization_resource.is_organization?
    assert_false program_resource.is_organization?
  end

  def test_scope_programs
    resource = create_resource
    assert_empty resource.programs
    create_resource_publication(resource: resource, program: programs(:pbe))
    create_resource_publication(resource: resource, program: programs(:albers))
    resource.reload
    assert_equal_unordered [programs(:pbe), programs(:albers)], resource.programs
  end

  def test_before_save
    content = '<object width="425" height="344"><param name="movie" value="//www.youtube.com/v/blaK_tB_KQA&amp;hl=en&amp;fs=1&amp;"><param name="allowFullScreen" value="true"><param name="allowscriptaccess" value="always"><embed src="//www.youtube.com/v/blaK_tB_KQA&amp;hl=en&amp;fs=1&amp;" type="application/x-shockwave-flash" allowscriptaccess="always" allowfullscreen="true" width="425" height="344"></object>'
    program_resource = Resource.new(:organization => programs(:albers), :title => "test", :content => content)
    program_resource.current_member = members(:f_admin)
    program_resource.sanitization_version = "v1"
    program_resource.save!
    assert_match "<param name=\"allowscriptaccess\" value=\"never\">", program_resource.content
  end

  def test_remove_rating
    member = members(:f_mentor)
    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    s1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME).id
    resource = create_resource(:programs => {programs(:albers)=> [m1, s1]})
    assert_nil resource.remove_rating(member)
    
    rating = Rating.new(:rating => Resource::RatingType::HELPFUL, :member => members(:f_mentor))
    resource.ratings << rating
    assert_equal rating, resource.reload.remove_rating(member)

    rating = Rating.new(:rating => Resource::RatingType::UNHELPFUL, :member => members(:f_mentor))
    resource.ratings << rating
    assert_equal rating, resource.reload.remove_rating(member)
  end

  def test_create_rating
    member = members(:f_mentor)
    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    s1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME).id
    resource = create_resource(:programs => {programs(:albers)=> [m1, s1]})
    assert_equal [], resource.ratings

    rating = Resource::RatingType::HELPFUL
    resource.create_rating(rating, member)
    assert_equal Rating.last, resource.reload.ratings.first

    rating = Resource::RatingType::UNHELPFUL
    resource.create_rating(rating, member)
    assert_equal Rating.last, resource.reload.ratings.first
  end

  def test_get_helpful_count
    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    s1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME).id
    resource = create_resource(:programs => {programs(:albers)=> [m1, s1]})
    assert_equal 0, resource.get_helpful_count

    rating = Rating.new(:rating => Resource::RatingType::HELPFUL, :member => members(:f_mentor))
    resource.ratings << rating
    assert_equal 1, resource.get_helpful_count

    resource.remove_rating(members(:f_mentor))
    resource = resource.reload
    
    rating = Rating.new(:rating => Resource::RatingType::UNHELPFUL, :member => members(:f_mentor))
    resource.ratings << rating
    assert_equal 0, resource.get_helpful_count
  end

  def test_rating_helpful
    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    s1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME).id
    resource = create_resource(:programs => {programs(:albers)=> [m1, s1]})
    rating = Rating.new(:rating => Resource::RatingType::HELPFUL, :member => members(:f_mentor))
    resource.ratings << rating
    assert resource.rating_helpful?(rating)

    rating1 = Rating.new(:rating => Resource::RatingType::UNHELPFUL, :member => members(:f_mentor))
    resource.ratings << rating1
    assert_false resource.rating_helpful?(rating1)
  end
end
